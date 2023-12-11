import std/exitprocs, system
from posix import signal, SIGHUP

import wisp/[server, file_manager, templates]

proc shutdown() {.noconv.} =
  echo "Shutting down..."
  quit()

proc cleanup() {.noconv.} =
  echo "Cleaning up..."
  quit()

proc signal_handler(signal: cint) {.noconv.} =
  if signal == SIGHUP:
    echo "Reloading..."
    create_index("./public")
  else:
    discard

when isMainModule:
  setControlCHook(shutdown)
  addExitProc(cleanup)
  signal(SIGHUP, signal_handler)
  create_index("./public")
  serve( http_root = "public", port = "8080" )
