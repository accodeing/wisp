# Package

version       = "0.1.0"
author        = "Jonas Schubert Erlandsson"
description   = "Static file web server"
license       = "Proprietary"
srcDir        = "src"
installExt    = @["nim"]
bin           = @["wisp"]


# Dependencies

requires "nim >= 2.0.0"
requires "httpbeast >= 0.4.0"
