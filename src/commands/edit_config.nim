## Edit the verm configuration file
## Copyright (C) 2024 Trayambak Rai
import std/[os, logging, osproc]

proc editConfiguration*(editor: string, quitOnSuccess: bool = true) =
  if execCmd(editor & ' ' & getConfigDir() / "verm" / "config.toml") != 0:
    error "verm: the editor (" & editor & ") exited with an unsuccessful exit code."
    quit(1)
  else:
    if quitOnSuccess:
      quit(0)
