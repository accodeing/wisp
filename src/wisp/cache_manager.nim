import tables, times

import path

type
  CachedContent = object
    content: string  # Store the file content
    lastUsed: Time   # Timestamp for LRU

  Cache = object
    items: Table[string, CachedContent]
    root: string
    maxSize: int
    currentSize: int

proc new_cache*(maxSize: int = 4 * 1024 * 1024, root: string = "/public"): Cache =
  result = Cache(items: initTable[string, CachedContent](), maxSize: maxSize, currentSize: 0, root: root)

proc evict_cache(cache: var Cache) =
  # Implement LRU eviction logic
  var oldest: Time = get_time()

proc cache_get(cache: var Cache, path: string, http_root: string): string =
  let normalised_path = cache.root.normalise_path(path)

  if normalised_path in cache.items:
    cache.items[normalised_path].last_used = get_time()
    return cache.items[normalised_path].content

  let content = readFile(normalised_path)
  cache.items[normalised_path] = CachedContent(content: content, lastUsed: getTime())
  cache.currentSize += content.len

  if cache.currentSize > cache.maxSize:
    evict_cache(cache)

  return content
