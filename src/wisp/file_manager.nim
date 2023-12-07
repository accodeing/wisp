import os

type
  FileInfo = object
    path: string
    size: uint64
    chunked: bool
    # Add more properties as needed

var index: Table[string, FileInfo]

proc index_files*( root: string, max_file_size_before_chunking: uint64 ) =
  index.clear()

  for kind, path in walk_dir(root):
    if kind == pcFile:
      let size = getFileSize(path)
      index[path] = FileInfo(
        path: path,
        size: size
        chunked: size > max_file_size_before_chunking
      )

proc exists*( path: string ): bool =
  return index.has_hey(path)

proc size*( path: string ): uint64 =
  return index[path].size

