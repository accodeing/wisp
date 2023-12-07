import tables, strutils, options, asyncdispatch, os, mimetypes, asyncfile

import httpbeast

import cache_manager
import path

template kb*(value: untyped): untyped = value * 1024
template mb*(value: untyped): untyped = value * 1024 * 1024
template gb*(value: untyped): untyped = value * 1024 * 1024 * 1024

var
  cache = new_cache()

let
  mime_db = newMimetypes()
  chunk_size = 4.kb
  max_file_size_before_chunking = 10.mb


proc handle_request*(request: Request): Future[void] {.async.} =
  let 
    root = "./public"
    filePath = root.normalise_path( $request.path.get )
  if fileExists(filePath):
    let file = openAsync(filePath, fmRead)
    try:
      # Set Content-Type header
      let
        (_, ext, _) = filePath.splitFile()
        mimeType = mime_db.getMimeType(ext)
      var headers = newHttpHeaders()
      headers.add("Content-Type", mimeType)
      
      # Optionally, set Content-Length
      let fileSize = getFileSize(filePath)
      headers.add("Content-Length", $fileSize)

      # Send headers
      await request.client.sendHeaders(Http200, headers)

      # Send file content
      var buffer = newStringOfCap(4096)  # Adjust buffer size as needed
      while not file.atEnd():
        let bytesRead = await file.readInto(buffer)
        await request.client.send(buffer[0..<bytesRead])  # Send the chunk
    finally:
      file.close()
  else:
    # Handle file not found
    await request.client.sendHeaders(Http404, newHttpHeaders())
    await request.client.send("File not found")

proc serve*( http_root: string, port: string = "8080", log_level: string = "INFO" ) =
  echo "Starting at port " & $port
  run(handle_request, initSettings(
    port = Port(8080),
    numThreads = 0,
    reusePort = true,
  ))
  echo "Stopped"
