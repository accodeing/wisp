import os, posix

import wisp/[server, file_manager]

proc signal_handler(signal: cint) {.cdecl.} =
  case signal
  of SIGHUP:
    index_files("./public")
  else:
    discard

when isMainModule:
  setControlCHook(signal_handler)
  posix.signal(SIGHUP, signal_handler)
  serve( http_root = "public", port = "8080" )
