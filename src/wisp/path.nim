import os, strutils

proc normalise_path*(root: string, path: string): string =
  ## Normalizes `path` against `root`, ensuring it doesn't escape the root directory.
  ##
  ## runnableExamples:
  ##   let root = "/public"
  ##   doAssert root.normalise_path("/test/../index.html") == "/public/index.html"
  ##   doAssert root.normalise_path("/test/../../../../index.html") == "/public/index.html"
  ##   doAssert root.normalise_path("/another/path/file.txt") == "/public/another/path/file.txt"
  let full_path = join_path(root, path)
  result = normalized_path(full_path)
  if not result.starts_with(root):
    let fileName = extractFilename(path)
    result = joinPath(root, fileName)
