import system

import templates

const
  CacheSize = 1.mb

var
  memory_ptr = cast[ptr UncheckedArray[byte]](alloc0(CacheSize))
  memory_current_end: int64 = 0

proc cache_put*(data: string, size: int64): int64 =
  let
    data_ptr = cast[ptr byte](data[0].unsafeAddr)
    destination = cast[ptr byte](memory_ptr[memory_current_end].addr)

  if memory_current_end + size > CacheSize:
    raise newException(ValueError, "Not enough memory in cache to store data")

  copyMem(destination, data_ptr, size)

  result = memory_current_end
  memory_current_end += size

proc cache_get*(start: int64, size: int64): string =
  if start + size > CacheSize:
    raise newException(ValueError, "Trying to access cache data outside of cache")

  result = newString(size)
  
  let
    result_ptr = cast[ptr byte](result[0].addr)
    start_ptr = cast[ptr byte](memory_ptr[start].addr)

  copyMem(result_ptr, start_ptr, size)

proc cache_clear*() =
  memory_current_end = 0

proc cache_dealloc*() =
  dealloc(memory_ptr)

