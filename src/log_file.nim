## Determines where the Sober log file has to be stored.
## Copyright (C) 2024 Trayambak Rai
import std/[os]

proc getvermDir*(): string {.inline.} =
  let tmp = getEnv("XDG_RUNTIME_DIR", "/tmp")

  if not dirExists(tmp / "verm"):
    createDir(tmp / "verm")

  tmp / "verm"

proc getSoberLogPath*(): string {.inline.} =
  getvermDir() / "sober.log"
