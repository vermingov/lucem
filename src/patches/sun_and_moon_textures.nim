## Tweak the sun and moon textures
## Copyright (C) 2024 Trayambak Rai
import std/[os, strutils, logging]
import ../common

const SoberSkyTexturesPath* {.strdefine.} =
  "$1/.var/app/" & SOBER_APP_ID & "/data/sober/assets/content/sky/"

proc setSunTexture*(path: string) =
  var path = deepCopy(path)
  let basePath = SoberSkyTexturesPath % [getHomeDir()]

  if fileExists(basePath / "verm_patched_sun") and
      readFile(basePath / "verm_patched_sun") == path:
    debug "verm: skipping patching sun texture - already marked as patched"
    return

  if path.len > 0:
    debug "verm: patching sun texture to: " & path
    if not fileExists(path) and not symlinkExists(path):
      error "verm: cannot find file: " & path & " as a substitute for the sun texture!"
      quit(1)

    if symlinkExists(path):
      path = expandSymlink(path)
      debug "verm: resolving symlink to: " & path

    moveFile(basePath / "sun.jpg", basePath / "sun.jpg.old")
    copyFile(path, basePath / "sun.jpg")
    writeFile(basePath / "verm_patched_sun", path)

    info "verm: patched sun texture successfully!"
  else:
    if not fileExists(basePath / "verm_patched_sun"):
      return

    debug "verm: reverting sun texture to default"

    if not fileExists(basePath / "sun.jpg.old"):
      error "verm: cannot restore sun texture to default as `sun.jpg.old` is missing!"
      error "verm: you probably messed around with the files, run `verm init` to fix everything."
      quit(1)

    removeFile(basePath / "verm_patched_sun")
    moveFile(basePath / "sun.jpg.old", basePath / "sun.jpg")

    info "verm: restored sun texture back to default successfully!"

proc setMoonTexture*(path: string) =
  let basePath = SoberSkyTexturesPath % [getHomeDir()]
  if fileExists(basePath / "verm_patched_moon") and
      readFile(basePath / "verm_patched_moon") == path:
    debug "verm: skipping patching moon texture - already marked as patched"
    return

  if path.len > 0:
    debug "verm: patching moon texture to: " & path
    if not fileExists(path):
      error "verm: cannot find file: " & path & " as a substitute for the moon texture!"
      quit(1)

    moveFile(basePath / "moon.jpg", basePath / "moon.jpg.old")
    copyFile(path, basePath / "moon.jpg")
    writeFile(basePath / "verm_patched_moon", path)

    info "verm: patched moon texture successfully!"
  else:
    if not fileExists(basePath / "verm_patched_moon"):
      return

    debug "verm: reverting moon texture to default"

    if not fileExists(basePath / "moon.jpg.old"):
      error "verm: cannot restore sun texture to default as `moon.jpg.old` is missing!"
      error "verm: you probably messed around with the files, run `verm init` to fix everything."
      quit(1)

    removeFile(basePath / "verm_patched_moon")
    moveFile(basePath / "moon.jpg.old", basePath / "moon.jpg")

    info "verm: restored moon texture back to default successfully!"
