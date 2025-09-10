## Run the Roblox client, update FFlags and optionally, provide Discord RPC and other features.
## Copyright (C) 2024 Trayambak Rai
import std/[os, logging, strutils, json, tables, times, locks, sets]
import pkg/[colored_logger, netty, jsony, pretty]
import ../api/[games, thumbnails, ipinfo]
import
  ../patches/[bring_back_oof, patch_fonts, sun_and_moon_textures, windowing_backend]
import ../shell/loading_screen
import ../[updater, sober_config, proto]
import
  ../[
    argparser, config, flatpak, common, meta, sugar, notifications, fflags, log_file,
    sober_state
  ]

const FFlagsFile* =
  "$1/.var/app/$2/data/sober/exe/ClientSettings/ClientAppSettings.json"

let fflagsFile = FFlagsFile % [getHomeDir(), SOBER_APP_ID]

proc updateConfig*(input: Input, config: Config) =
  info "verm: updating config"
  if not fileExists(fflagsFile):
    error "verm: could not open pre-existing FFlags file. Run `verm init` first."
    quit(1)

  var sober = getSoberConfig()

  info "verm: target FPS is set to: " & $config.client.fps
  sober.fflags["DFIntTaskSchedulerTargetFps"] = newJInt(int(config.client.fps))
  sober.useOpengl = config.client.renderer == Renderer.OpenGL

  if not config.client.telemetry:
    info "verm: disabling telemetry FFlags"
  else:
    warn "verm: enabling telemetry FFlags. This is not recommended!"

  if not input.enabled("skip-patching", "N"):
    enableOldOofSound(config.tweaks.oldOof)
    setWindowingBackend(config.backend())
    patchSoberState(input, config)
    setClientFont(config.tweaks.font, config.tweaks.excludeFonts)
    setSunTexture(config.tweaks.sun)
    setMoonTexture(config.tweaks.moon)
  else:
    info "verm: skipping patching (--skip-patching or -S was provided)"

  for flag in [
    "FFlagDebugDisableTelemetryEphemeralCounter",
    "FFlagDebugDisableTelemetryEphemeralStat", "FFlagDebugDisableTelemetryEventIngest",
    "FFlagDebugDisableTelemetryPoint", "FFlagDebugDisableTelemetryV2Counter",
    "FFlagDebugDisableTelemetryV2Event", "FFlagDebugDisableTelemetryV2Stat",
  ]:
    debug "verm: set flag `" & flag & "` to " & $(not config.client.telemetry)
    sober.fflags[flag] = newJBool(not config.client.telemetry)

  parseFFlags(config, sober.fflags)
  sober.saveSoberConfig()

proc eventWatcher*(
  config: Config,
  input: Input
) =
  var verbose = false

  let port =
    if (let opt = input.flag("port"); *opt):
      parseUint(&opt)
    else:
      config.daemon.port

  if input.enabled("verbose", "v"):
    verbose = true
    setLogFilter(lvlAll)

  var reactor = newReactor()
  debug "verm: connecting to vermd at port " & $port
  var server = reactor.connect("127.0.0.1", int port)

  template send[T](data: T) =
    let serialized = data.serialize()
    debug "verm: sending to daemon: " & serialized
    reactor.send(server, serialized)

    for _ in 0 .. 32:
      reactor.tick()

  var
    line = 0
    startedPlayingAt = 0.0
    startingTime = 0.0
    hasntStarted = true

    soberIsRunning = false
    ticksUntilSoberRunCheck = 0

  while hasntStarted or soberIsRunning:
    reactor.tick()

    let logFile = readFile(getSoberLogPath()).splitLines()

    if ticksUntilSoberRunCheck < 1:
      # debug "verm: checking if sober is still running"
      soberIsRunning = soberRunning()
      ticksUntilSoberRunCheck = 5000

    dec ticksUntilSoberRunCheck

    if logFile.len - 1 < line:
      continue

    let data = logFile[line]
    if data.len < 1:
      inc line
      continue

    if verbose:
      data.echo

    if data.contains(
      "[FLog::GameJoinUtil] GameJoinUtil::joinGamePostStandard: URL: https://gamejoin.roblox.com/v1/join-game BODY:"
    ):
      startedPlayingAt = epochTime()
      startingTime = startedPlayingAt

      info "verm: joined game"

      send(
        Packet(
          magic: mgOnGameJoin,
          arguments: @[
            %* data
          ]
        )
      )

    if data.contains("[FLog::Network] UDMUX Address ="):
      let str = data.split(" = ")[1].split(",")[0]

      info "verm: server IP: " & str

      send(
        Packet(
          magic: mgOnServerIp,
          arguments: @[
            %* str
          ]
        )
      )

    if data.contains("[FLog::Network] Client:Disconnect") or
        data.contains("[FLog::Network] Connection lost - Cannot contact server/client"):
      continue

    # sleep(config.verm.pollingDelay.int)
    hasntStarted = false
    inc line

  info "verm: Sober seems to have exited - we'll stop here too. Adios!"

proc runRoblox*(input: Input, config: Config) =
  info "verm: running Roblox via Sober"
  runUpdateChecker(config)

  writeFile(getSoberLogPath(), newString(0))

  info "verm: redirecting sober logs to: " & getSoberLogPath()
  discard flatpakRun(SOBER_APP_ID, getSoberLogPath(), config.client.launcher, config)
  
  eventWatcher(input = input, config = config)

  quit(0)
