## Copyright (C) 2024 Trayambak Rai
import std/[os, osproc, logging, strutils, posix, base64]
import ./sugar

proc notifyFallback*(
    heading: string,
    description: string,
    expireTime: uint64 = 240000,
    icon: Option[string] = none(string),
) =
  debug "notifications: using libnotify fallback (cringe guhnome user detected)"
  debug "notifications: preparing notify-send command"
  debug "notifications: heading = $1, description = $2, expireTime = $3" %
    [heading, description, $expireTime]

  let exe = findExe("notify-send")
  if exe.len < 1:
    warn "notifications: notify-send was not found; ignoring."
    return

  var cmd = exe & ' '
  cmd &= '"' & heading & "\" "
  cmd &= '"' & description & "\" "
  cmd &= "--expire-time=" & $expireTime & ' '
  cmd &= "--app-name=verm "

  if *icon:
    debug "notifications: icon was specified: " & &icon
    cmd &= "--icon=" & &icon
  else:
    debug "notifications: icon was not specified."

  let code = execCmd(cmd)
  if code == 0:
    debug "notifications: notify-send exited successfully."
  else:
    warn "notifications: notify-send exited with abnormal exit code (" & $code & ')'
    warn "notifications: command was: " & cmd

proc notify*(
  heading: string,
  description: string,
  expireTime: uint64 = 240000,
  icon: Option[string] = none(string)
) =
  var worker = findExe("verm_overlay")
  if worker.len < 1 and not defined(release):
    worker = "./verm_overlay"

  var usedOverlay = false
  if worker.len > 0:
    let pid = fork()
    if pid == 0:
      let cmd = worker & " --heading:\"" & heading.encode() & "\" --description:\"" & description.encode() & "\" --expire-time:" & $(expireTime.int / 1000) & ' ' & (if *icon: "--icon:" & &icon else: "")
      debug "notifications: executing command: " & cmd
      discard execCmd(cmd)
      quit(0)
    usedOverlay = true

  if not usedOverlay:
    warn "notifications: overlay not available; using notify-send fallback."
    notifyFallback(heading, description, expireTime, icon)

proc presentUpdateAlert*(
  heading: string,
  message: string,
  blocks: bool = false
) =
  var worker = findExe("verm_overlay")
  if worker.len < 1 and not defined(release):
    worker = "./verm_overlay"

  if worker.len > 0:
    let pid = if not blocks:
      debug "notifications: blocks = false, forking process"
      fork()
    else:
      debug "notifications: blocks = true, billions must hang up"
      0

    if pid == 0:
      let cmd = worker & " --update-alert --update-heading:\"" & heading.encode() & "\" --update-message:\"" & message.encode() & '"'
      debug "notifications: executing command: " & cmd
      discard execCmd(cmd)
      quit(0)
  else:
    warn "notifications: overlay not available; using notify-send fallback."
    notifyFallback(heading, message, 240000)
