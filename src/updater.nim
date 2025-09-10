## verm auto-updater
## Copyright (C) 2024 Trayambak Rai
import std/[os, osproc, logging, tempfiles, distros, posix]
import pkg/[semver, jsony]
import ./[http, argparser, config, sugar, meta, notifications, desktop_files, systemd]
import ./commands/init

type
  ReleaseAuthor* = object
    login*: string
    id*: uint32
    node_id*, avatar_url*, gravatar_id*, url*, html_url*, followers_url*, following_url*, gists_url*, starred_url*, subscriptions_url*, organizations_url*, repos_url*, events_url*, received_events_url*, `type`*, user_view_type*: string
    site_admin*: bool

  vermRelease* = object
    url*, assets_url*, upload_url*, html_url*: string
    id*: uint64
    author*: ReleaseAuthor
    node_id*, tag_name*, target_commitish*, name*: string
    draft*, prerelease*: bool
    created_at*, published_at*: string
    assets*: seq[string]
    tarball_url*, zipball_url*: string

const
  vermReleaseUrl {.strdefine.} = "https://api.github.com/repos/vermingov/lucem/releases/latest"

proc getLatestRelease*(): Option[vermRelease] {.inline.} =
  debug "verm: auto-updater: fetching latest release"
  try:
    return httpGet(
      vermReleaseUrl
    ).fromJson(
      vermRelease
    ).some()
  except JsonError as exc:
    warn "verm: auto-updater: cannot parse release data: " & exc.msg
  except CatchableError as exc:
    warn "verm: auto-updater: cannot get latest release: " & exc.msg & " (" & $exc.name & ')'

proc runUpdateChecker*(config: Config) =
  if not config.verm.autoUpdater:
    debug "verm: auto-updater: skipping update checks as auto-updater is disabled in config"
    return

  when defined(vermDisableAutoUpdater):
    debug "verm: auto-updater: skipping update checks as auto-updater is disabled by a compile-time flag (--define:vermDisableAutoUpdater)"
    return

  debug "verm: auto-updater: running update checks"
  let release = getLatestRelease()

  if !release:
    warn "verm: auto-updater: cannot get release, skipping checks."
    return

  let data = &release
  let newVersion = try:
    parseVersion(data.tagName).some()
  except semver.ParseError as exc:
    warn "verm: auto-updater: cannot parse new semver: " & exc.msg & " (" & data.tagName & ')'
    none(semver.Version)

  if !newVersion:
    return

  let currVersion = parseVersion(meta.Version)

  debug "verm: auto-updater: new version: " & $(&newVersion)
  debug "verm: auto-updater: current version: " & $currVersion

  let newVer = &newVersion

  if newVer > currVersion:
    info "verm: found a new release! (" & $newVer & ')'
    presentUpdateAlert(
      "verm " & $newVer & " is out!",
      "A new version of verm is out. You are strongly advised to update to this release for bug fixes and other improvements. Press Enter to update. Press any other key to close this dialog.", blocks = true
    )
  elif newVer == currVersion:
    debug "verm: user is on the latest version of verm"
  elif newVer < currVersion:
    warn "verm: version mismatch (newest release: " & $newVer & ", version this binary was tagged as: " & $currVersion & ')'
    warn "verm: are you using a development version? :P"

proc postUpdatePreparation =
  info "verm: beginning post-update preparation"

  debug "verm: killing any running verm instances and vermd"

  # FIXME: Use POSIX APIs for this.
  discard execCmd("kill $(pidof vermd)")
  discard execCmd("kill $(pidof verm)")
  
  debug "verm: initializing verm"
  initializeSober(default(Input))
  createvermDesktopFile()
  installSystemdService()

  info "verm: completed post-update preparation"

proc updateverm* =
  info "verm: checking for updates"
  let release = getLatestRelease()
  
  if !release:
    error "verm: cannot get current release"
    return

  let currVersion = parseVersion(meta.Version)
  let newVer = parseVersion((&release).tagName)

  if newVer != currVersion:
    info "verm: found new version! (" & $newVer & ')'
    let wd = getCurrentDir()
    let tmpDir = createTempDir("verm-", '-' & $newVer)
    
    let git = findExe("git")
    let nimble = findExe("nimble")

    if nimble.len < 1:
      error "verm: cannot find `nimble`!"
      quit(1)

    if git.len < 1:
      error "verm: cannot find `git`!"
      quit(1)
    
    info "verm: cloning source code"
    if (let code = execCmd(git & " clone https://github.com/vermingov/lucem.git " & tmpDir); code != 0):
      error "verm: git exited with non-zero exit code: " & $code
      quit(1)

    discard chdir(tmpDir.cstring)
    
    info "verm: switching to " & $newVer & " branch"
    if (let code = execCmd(git & " checkout " & $newVer); code != 0):
      error "verm: git exited with non-zero exit code: " & $code
      quit(1)
    
    info "verm: compiling verm"
    if not detectOs(NixOS):
      if (let code = execCmd(nimble & " install"); code != 0):
        error "verm: nimble exited with non-zero exit code: " & $code
        quit(1)
    else:
      info "verm: Nix environment detected, entering Nix shell"
      let nix = findExe("nix-shell") & "-shell" # FIXME: for some reason, `nix-shell` returns the `nix` binary instead here. Perhaps a Nim STL bug
      if nix.len < 1:
        error "verm: cannot find `nix-shell`!"
        quit(1)

      if (let code = execCmd(nix & " --run \"" & nimble & " install\""); code != 0):
        error "verm: nix-shell or nimble exited with non-zero exit code: " & $code
        quit(1)

    info "verm: updated successfully!"
    info "verm is now at version " & $newVer

    postUpdatePreparation()
  else:
    info "verm: nothing to do."
    quit(0)
