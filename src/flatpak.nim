## Flatpak helper
## Copyright (C) 2024 Trayambak Rai

import std/[os, osproc, posix, logging, strutils]
import ./[config]

proc flatpakInstall*(id: string, user: bool = true): bool {.inline, discardable.} =
  if findExe("flatpak").len < 1:
    error "flatpak: could not find flatpak executable! Are you sure that you have flatpak installed?"

  info "flatpak: install package \"" & id & '"'
  let (output, exitCode) =
    execCmdEx("flatpak install --assumeyes " & id & (if user: " --user" else: ""))

  if exitCode != 0 and not output.contains("is already installed"):
    error "flatpak: failed to install package \"" & id &
      "\"; flatpak process exited with abnormal exit code " & $exitCode
    error "flatpak: it also outputted the following:"
    error output
    false
  else:
    info "flatpak: successfully installed \"" & id & "\"!"
    true

proc soberRunning*(): bool {.inline.} =
  execCmdEx("pidof sober").output.len > 2

proc flatpakRun*(
  id: string, path: string = "/dev/stdout", launcher: string = "",
  config: Config
): bool {.inline.} =
  info "flatpak: launching flatpak app \"" & id & '"'
  debug "flatpak: launcher = " & launcher

  let launcherExe = 
    if config.client.resolveExe:
      debug "flatpak: resolving executable to launcher program: " & launcher
      findExe(launcher)
    else:
      debug "flatpak: user has asked executable path to not be resolved: " & launcher
      launcher

  if config.client.resolveExe and launcherExe.len < 1 and launcher.len > 0:
    warn "flatpak: failed to find launcher executable for `" & launcher &
      "`; are you sure that it's in your PATH?"
    warn "flatpak: ignoring for now."

  if fork() == 0:
    var file = posix.open(path, O_WRONLY or O_CREAT or O_TRUNC, 0644)
    assert(file >= 0)

    debug "flatpak: we are the child - launching \"" & id & '"'
    var cmd = launcherExe & " flatpak run " & id

    debug "flatpak: final command: " & cmd
    if dup2(file, STDOUT_FILENO) < 0:
      error "verm: dup2() for stdout failed: " & $strerror(errno)
    else:
      debug "verm: dup2() successful, sober's logs are now directed at: " & path

    discard execCmd(cmd)
    debug "verm: sober has exited, forked verm process is exiting..."
    quit(0)
  else:
    debug "flatpak: we are the parent - continuing"

proc flatpakKill*(id: string): bool {.inline, discardable.} =
  info "flatpak: killing flatpak app \"" & id & '"'
  bool(execCmd("flatpak kill " & id))
