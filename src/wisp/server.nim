import strutils, strformat, options, asyncdispatch, os, mimetypes, asyncfile, locks, times

import httpbeast

import path, templates, file_manager

var
  mime_db_lock: Lock

const
  mime_db = newMimetypes()
  chunk_size = 4.kb
  max_file_size_before_chunking = 10.mb


initLock(mime_db_lock)


proc get_mime_type(ext: string): string {.gcsafe.} =
  with_lock(mime_db_lock):
    result = mime_db.get_mime_type(ext)


proc to_string(headers: HttpHeaders): string =
  result = ""

  for (key, value) in headers.pairs:
    result &= key & ": " & value & "\r\n"

# FILEPATH: /Users/jonas/Library/CloudStorage/Dropbox/projects/accodeing/accelerate/wisp/src/wisp/server.nim

# This procedure starts the response by setting the response code and headers.
# 
# Parameters:
# - request: The incoming request object.
# - response_code: The HTTP response code to be set.
# - headers: The headers to be included in the response.
proc startResponse(request: Request, response_code: HttpCode, headers: HttpHeaders) =
  request.unsafeSend("HTTP/1.1 " & $response_code & "\r\n" & headers.to_string)
  request.unsafeSend("\r\n")



proc startChunkedResponse(request: Request, headers: HttpHeaders) =
  headers.add("Transfer-Encoding", "chunked")
  startResponse(request, Http200, headers)



proc sendBody(request: Request, data: string) =
    request.unsafeSend(data)



proc sendChunk(request: Request, data: string) =
  let chunkSize = fmt"{data.len:X}"
  let chunk = chunkSize & "\r\n" & data & "\r\n"
  request.unsafeSend(chunk)



proc endChunkedResponse(request: Request) =
  request.unsafeSend("0\r\n\r\n" & "Server-Timing: total;desc=\"Works!\"dur=0.0\r\n")





proc serveChunked(request: Request, filePath: string, headers: HttpHeaders, request_start_time: Time) {.async.} =
  let
    file = openAsync(filePath, fmRead)

  try:
    request.startChunkedResponse(headers)

    # Send file content
    var
      buffer: array[chunk_size, byte]  # Buffer as an array of bytes
    while true:
      let bytesRead = await file.readBuffer(addr(buffer[0]), buffer.len)
      let dataToSend = cast[string](buffer[0..<bytesRead])
      request.sendChunk(dataToSend)  # Send the chunk
      if bytesRead < chunk_size:
        break

    # End chunked response
    request.endChunkedResponse()
  finally:
    file.close()



proc serveFile(request: Request, filePath: string, headers: HttpHeaders, request_start_time: Time ) =
  let 
    (data, timing_string) = get_file(filePath)

  headers["Server-Timing"] = timing_string

  request.send(Http200, data, headers.to_string)



proc onRequest(request: Request): Future[void] {.async gcsafe.} =
  let 
    start_time = getTime()
    root = "./public"
    filePath = root.normalise_path( $request.path.get )

  #echo $request.httpMethod.get & " " & $request.path.get " " 

  if exists(filePath):
    var
      headers = newHttpHeaders()

    let
      (_, _, ext) = filePath.splitFile()
      mimeType = get_mime_type(ext)
      fileSize = size(filePath)

    headers.add("Content-Type", mimeType)
    headers.add("Content-Length", $fileSize)
    headers.add("Server-Timing", "")

    if chunked(filePath):
      await serveChunked(request, filePath, headers, start_time)
    else:
      serveFile(request, filePath, headers, start_time)
  else:
    echo "File does not exist"
    request.send("File not found", Http404)

proc serve*( http_root: string, port: string = "8080", log_level: string = "INFO" ) =
  echo "Starting at port " & $port
  run(onRequest, initSettings(
    port = Port(8080),
    numThreads = 0,
    reusePort = true,
  ))
  echo "Stopped"
