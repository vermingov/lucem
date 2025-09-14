## Flatpak helper
## Copyright (C) 2024 Trayambak Rai

import std/[os, osproc, posix, logging, strutils, times]
import ./[config, common]
proc runCmdExitCodeTimeout(cmd: string, timeoutMs: int): int {.inline.} =
  var p: Process
  try:
    p = startProcess(
      command = "/bin/sh",
      args = @["-lc", cmd],
      options = {poUsePath, poStdErrToStdOut}
    )
    let startT = epochTime()
    while p.running:
      if int((epochTime() - startT) * 1000).int >= timeoutMs:
        try: p.terminate()
        except CatchableError: discard
        try: p.kill()
        except CatchableError: discard
        return -9999
      sleep(10)
    return p.waitForExit()
  except CatchableError as exc:
    warn "flatpak: command failed ('" & cmd & "'): " & exc.msg
    return -1
  finally:
    try:
      if p != nil:
        close(p)
    except CatchableError:
      discard

## simplified bounded runner: returns only exit code

proc flatpakInstall*(id: string, user: bool = true): bool {.inline, discardable.} =
  if findExe("flatpak").len < 1:
    error "flatpak: could not find flatpak executable! Are you sure that you have flatpak installed?"

  # If Sober is already installed, skip reinstallation
  let infoCmd = (if user: "flatpak info --user " else: "flatpak info ") & SOBER_APP_ID
  if runCmdExitCodeTimeout(infoCmd, 10000) == 0:
    info "flatpak: '" & SOBER_APP_ID & "' is already installed; skipping install."
    return true

  info "flatpak: install package \"" & id & '"'
  let exitCode = runCmdExitCodeTimeout("flatpak install --assumeyes " & id & (if user: " --user" else: ""), 60000)

  if exitCode != 0:
    error "flatpak: failed to install package \"" & id &
      "\"; flatpak process exited with abnormal exit code " & $exitCode
    false
  else:
    info "flatpak: successfully installed \"" & id & "\"!"
    true

proc soberRunning*(): bool {.inline.} =
  let code = runCmdExitCodeTimeout("flatpak ps | grep -q " & SOBER_APP_ID, 2000)
  if code == -9999:
    # On timeout, assume still running to avoid premature shutdowns
    return true
  code == 0

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
    var flags = O_WRONLY or O_CREAT or O_TRUNC
    when declared(O_CLOEXEC): flags = flags or O_CLOEXEC
    var file = posix.open(path, flags, 0644)
    if file < 0:
      warn "verm: failed to open log output path (" & path & ") for writing; falling back to /dev/null"
      let nul = posix.open("/dev/null", O_WRONLY, 0644)
      if nul >= 0:
        file = nul
      else:
        error "verm: failed to open /dev/null for writing; continuing without redirection"

    debug "flatpak: child launching \"" & id & '"'
    var cmd = launcherExe & " flatpak run " & id

    debug "flatpak: final command: " & cmd
    if file >= 0 and dup2(file, STDOUT_FILENO) < 0:
      error "verm: dup2() for stdout failed: " & $strerror(errno)
    else:
      debug "verm: dup2() successful, sober's logs are now directed at: " & path

    # Also redirect stderr so Sober doesn't spam the console
    if file >= 0 and dup2(file, STDERR_FILENO) < 0:
      error "verm: dup2() for stderr failed: " & $strerror(errno)
    else:
      debug "verm: stderr is also redirected to: " & path

    # Close the original file descriptor after duplicating it
    if file >= 0:
      discard posix.close(file)

    discard execCmd(cmd)
    debug "verm: sober has exited, forked verm process is exiting..."
    quit(0)
  else:
    debug "flatpak: parent continuing"

proc flatpakKill*(id: string): bool {.inline, discardable.} =
  info "flatpak: killing flatpak app \"" & id & '"'
  runCmdExitCodeTimeout("flatpak kill " & id, 5000) == 0
