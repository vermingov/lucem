## verm - a QoL wrapper over Sober
##
## Copyright (C) 2024 Trayambak Rai

import std/[os, logging, strutils, terminal]
import colored_logger, nimgl/vulkan
import ./[meta, argparser, config, cache_calls, desktop_files, sober_state, gpu_info, systemd, updater]
import ./shell/core
import ./commands/[init, run, edit_config, explain]

proc showHelp(exitCode: int = 1) {.inline, noReturn.} =
  echo """
verm [command] [arguments]

Commands:
  init                      Install Sober and initialize verm's internals
  run                       Run Sober
  meta                      Get build metadata
  list-gpus                 List all GPUs on this system
  update                    Check for verm updates and install them
  edit-config               Edit the configuration file
  clear-cache               Clear the API caches that verm maintains
  shell                     Launch the verm configuration GUI
  install-desktop-files     Install verm's desktop files
  explain                   Get documentation on a verm configuration value or command
  help                      Show this message

Flags:
  --verbose, -v              Show additional debug logs, useful for diagnosing issues.
  --skip-patching, -N        Don't apply your selected patches to Roblox, use this to see if a crash is caused by them. This won't undo patches!
  --use-sober-patching, -P   Use Sober's patches (bring back old oof) instead of verm's. There's no need to use this since verm already works just as well.
  --dont-check-vulkan        Don't try to initialize Vulkan to ensure that Sober can run on your GPU.
"""
  quit(exitCode)

proc showMeta() {.inline, noReturn.} =
  let state = loadSoberState()

  echo """
verm $1
Copyright (C) 2024 Trayambak Rai
This software is licensed under the MIT license.

* Compiled with Nim $2
* Compiled on $3
* Roblox client version $6
* Protocol: $7

[ $4 ]

==== LICENSE ====
$5
==== LEGAL DISCLAIMER ====
verm is a free unofficial application that wraps around Sober, a runtime for Roblox on Linux. verm does not generate any revenue for its authors whatsoever.
verm is NOT affiliated with Roblox or its partners, nor is it endorsed by them. The verm developers do not support misuse of the Roblox platform and there are restrictions
in place to prevent such abuse. The verm developers or anyone involved with the project is NOT responsible for any damages caused by this software as it comes with NO WARRANTY.
""" %
  [
    Version,
    NimVersion,
    CompileDate & ' ' & CompileTime,
    when defined(release): "Release Build" else: "Development Build",
    LicenseString,
    state.v1.appVersion,
    $autodetectWindowingBackend(),
  ]

proc listGpus(inst: VkInstance) =
  let gpus = inst.getAllGPUs()

  info "Found " & $gpus.len &
    (if gpus.len == 1: " GPU" else: " GPUs" & " that support Vulkan.")
  for gpu in gpus:
    stdout.styledWriteLine(fgRed, "-", resetStyle, " ", styleBright, gpu, resetStyle)

proc main() {.inline.} =
  addHandler(newColoredLogger())
  setLogFilter(lvlInfo)
  let input = parseInput()

  if input.enabled("verbose", "v"):
    setLogFilter(lvlAll)

  let config = parseConfig(input)

  if config.apk.version.len > 0:
    warn "verm: you have set up an APK version in the configuration - that feature is now deprecated as Sober now has a built-in APK fetcher."
    warn "verm: feel free to remove it."

  case input.command
  of "meta":
    showMeta()
  of "help":
    showHelp(0)
  of "init":
    initializeSober(input)
    createvermDesktopFile()
    installSystemdService()
  of "update":
    updateverm()
  of "check-for-updates":
    runUpdateChecker(parseConfig(input))
  of "install-systemd-service":
    installSystemdService()
  of "relaunch-daemon":
    relaunchSystemdService()
  of "explain":
    input.generateQuestion().explain()
  of "edit-config":
    if existsEnv("EDITOR"):
      let editor = getEnv("EDITOR")
      debug "verm: editor is `" & editor & '`'

      editConfiguration(editor, false)
    else:
      warn "verm: you have not specified an editor in your environment variables."

      for editor in ["nano", "vscode", "vim", "nvim", "emacs", "vi", "ed"]:
        warn "verm: trying editor `" & editor & '`'
        editConfiguration(editor)

    # validate the config on-the-go
    updateConfig(input, config)
  of "run":
    info "verm@" & Version & " is now starting up!"
    if input.enabled("dont-check-vulkan"):
      info "verm: --dont-check-vulkan is enabled, ignoring Vulkan initialization test."
    else:
      deinitVulkan(initVulkan())

    updateConfig(input, config)
    runRoblox(input, config)
  of "install-desktop-files":
    createvermDesktopFile()
  of "list-gpus":
    let instance = initVulkan()
    listGpus(instance)
    deinitVulkan(instance)
  of "clear-cache":
    let savedMb = clearCache()
    info "verm: cleared cache calls to reclaim " & $savedMb & " MB of space"
  of "shell":
    initvermShell(input)
  else:
    error "verm: invalid command `" & input.command &
      "`; run `verm help` for more information."

when isMainModule:
  main()
