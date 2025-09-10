## Make a .desktop entry for verm
## Copyright (C) 2024 Trayambak Rai
import std/[os, strutils, logging]
import ./internal_fonts

const
  ApplicationsPath* {.strdefine: "vermAppsPath".} = "$1/.local/share/applications"

  SoberRunDesktopFile* =
    """
[Desktop Entry]
Version=1.0
Type=Application
Name=verm
Exec=$1
Comment=Run Roblox with quality of life fixes
GenericName=Wrapper around Sober
Terminal=false
Categories=Games
Icon=verm
Keywords=roblox
Categories=Game
"""

  SoberGUIDesktopFile* =
    """
[Desktop Entry]
Version=1.0
Type=Application
Name=verm Settings
Exec=$1
Comment=Configure verm as per your needs
GenericName=verm Settings
Terminal=false
Categories=Utility
Keywords=settings
Icon=verm
"""

proc createvermDesktopFile*() =
  debug "verm: create desktop files for verm"
  let
    base = ApplicationsPath % [getHomeDir()]
    pathToverm = getAppFilename()

  if not existsOrCreateDir(base):
    warn "verm: `" & base &
      "` did not exist prior to this, your system seems to be a bit weird. verm has created it itself."
  
  var iconsPath = getHomeDir() / ".local"

  for value in ["share", "icons", "hicolor", "scalable"]:
    debug "verm: creating directory " & iconsPath & " if it doesn't exist"
    discard existsOrCreateDir(iconsPath)
    iconsPath = iconsPath / value

  discard existsOrCreateDir(iconsPath)
  discard existsOrCreateDir(iconsPath / "apps")
  writeFile(iconsPath / "apps" / "verm.svg", vermIcon)

  debug "verm: path to verm binary is: " & pathToverm

  debug "verm: writing alternative to `verm run` to " & base
  writeFile(base / "verm.desktop", SoberRunDesktopFile % [pathToverm & " run"])

  debug "verm: writing alternative to `verm shell` to " & base
  writeFile(
    base / "verm_shell.desktop", SoberGUIDesktopFile % [pathToverm & " shell"]
  )

  info "verm: created desktop entries successfully!"
