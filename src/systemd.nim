## professional vermd systemd service installer
## Copyright (C) 2024 Trayambak Rai
import std/[os, strutils, logging, osproc]
import ./meta

const
  SystemdServiceTemplate = """
[Unit]
Description=verm $1
After=network.target

[Service]
ExecStart=$2
Restart=on-failure

[Install]
WantedBy=default.target
"""

proc installSystemdService* =
  info "verm: installing systemd service"
  let service = SystemdServiceTemplate % [
    Version, getAppDir() / "vermd"
  ]
  let servicesDir = getConfigDir() / "systemd" / "user"

  if not dirExists(servicesDir):
    discard existsOrCreateDir(getConfigDir() / "systemd")
    discard existsOrCreateDir(servicesDir)

  writeFile(servicesDir / "verm.service", service)
  if execCmd(findExe("systemctl") & " enable verm.service --user --now") != 0:
    error "verm: failed to install systemd service for daemon!"

proc relaunchSystemdService* =
  info "verm: relaunching systemd service"
  if execCmd(
    findExe("systemctl") & " restart verm.service --user"
  ) != 0:
    error "verm: failed to restart verm daemon!"
