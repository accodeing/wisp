import os, tables, locks

import cache_manager, templates

type
  FileInfo = object
    path: string
    size: int64
    chunked: bool
    cache_start: int64
    # Add more properties as needed

var
  index: ref Table[string, FileInfo] = nil
  index_lock: Lock
  max_cachable_size_ptr: ptr int64


initLock(index_lock)


proc read_file(path: string, size: int64): string =
  result = newString(size)
  let file = open(path, fmRead)
  defer: file.close()
  discard file.readBuffer(addr result[0], result.len)

proc index_files( root: string ): ref Table[string, FileInfo] {.gcsafe.} =
  new result
  result[] = initTable[string, FileInfo]()

  echo "Indexing files in ", root

  for kind, path in walk_dir(root):
    if kind == pcFile:
      let size = getFileSize(path)
      result[][path] = FileInfo(
        path: path,
        size: size,
        chunked: size > max_cachable_size_ptr[],
        cache_start: -1
      )

  for key, metadata in result[].pairs:
    echo "\t", key, " ", metadata.size, " ", metadata.chunked
  echo ""

proc create_index* (root: string, max_file_size_before_chunking: int64 = 64.kb) =
  # Create and populate the index
  var
    max_cachable_size = max_file_size_before_chunking
  
  max_cachable_size_ptr = max_cachable_size.addr

  index = index_files(root)

proc exists*( path: string ): bool {.gcsafe.} =
  #withLock(indexLock):
  {.gcsafe.}:
    if index.isNil:
      raise newException(ValueError, "Index not initialized")

    return index[].has_key(path)

proc size*( path: string ): int64 {.gcsafe.} =
  #withLock(indexLock):
  {.gcsafe.}:
    if not index[].has_key(path):
      raise newException(ValueError, path & " not found in index")
  
    return index[][path].size

proc chunked*( path: string ): bool {.gcsafe.} =
  #withLock(indexLock):
  {.gcsafe.}:
    if not index[].has_key(path):
      raise newException(ValueError, path & " not found in index")

    return index[][path].chunked

proc get_file*( path: string ): (string, string) {.gcsafe.} =
  {.gcsafe.}:
    if not index[].has_key(path):
      raise newException(ValueError, path & " not found in index")

    var
      data: string

    let
      metadata = index[][path]

    if metadata.cache_start > -1:
      # Cache hit
      with_timing(duration):
        data = cache_get(metadata.cache_start, metadata.size)
      return (data, "read;desc=\"cache read\"dur=" & $duration)
    elif metadata.size < 64.kb:
      # Cache miss on cachable file
      with_timing(duration):
        data = read_file(path, metadata.size)
        let data_start = cache_put(data, metadata.size)
        index[][path].cache_start = data_start
      return (data, "read;desc=\"cache write\"dur=" & $duration)
    else:
      # Cache miss on non-cachable file
      with_timing(duration):
        data = read_file(path, metadata.size)
      return (data, "read;desc=\"file read\"dur=" & $duration)

