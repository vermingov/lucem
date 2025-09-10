## This file implements `verm init`
## Copyright (C) 2024 Trayambak Rai

import std/[logging]
import ../[flatpak, argparser]

const SOBER_FLATPAK_URL* {.strdefine: "SoberFlatpakUrl".} =
  "https://sober.vinegarhq.org/sober.flatpakref"

proc initializeSober*(input: Input) {.inline.} =
  info "verm: initializing sober"

  if not flatpakInstall(SOBER_FLATPAK_URL):
    error "verm: failed to initialize sober."
    quit(1)

  info "verm: Installed Sober successfully!"
  info "verm: You may run Roblox using `verm run`"
