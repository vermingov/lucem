## verm shell
## "soon:tm:" - tray
## Copyright (C) 2024 Trayambak Rai
import std/[os, strutils, json, logging, posix, tables, osproc]
import owlkettle, owlkettle/adw
import
  ../[config, argparser, cache_calls, fflags, notifications, desktop_files, fs, sober_config]

type ShellState* {.pure.} = enum
  Client
  verm
  Tweaks
  FflagEditor

viewable vermShell:
  state:
    ShellState = Client
  config:
    ptr Config

  showFpsCapOpt:
    bool
  showFpsCapBuff:
    string

  telemetryOpt:
    bool

  backendOpt:
    seq[string] = @["Wayland", "X11"]
  backendBuff:
    int

  launcherBuff:
    string

  discordRpcOpt:
    bool
  serverLocationOpt:
    bool

  oldOofSound:
    bool
  customFontPath:
    string

  sunImgPath:
    string
  moonImgPath:
    string

  apkVersionBuff:
    string
  currFflagBuff:
    string

  prevFflagBuff:
    string

  automaticApkUpdates:
    bool

  pollingDelayBuff:
    string

# This method builds and returns the main GUI for the verm shell, handling all state and user interactions.
method view(app: vermShellState): Widget =
  var parsedFflags: SoberFFlags
  try:
    parseFflags(app.config[], parsedFflags)
  except FFlagParseError as exc:
    warn "shell: failed to parse fflags: " & exc.msg
    notify("Failed to parse FFlags", exc.msg)
    debug "shell: reverting to previous state"
    app.config[].client.fflags = app.prevFflagBuff
    app.currFflagBuff = app.prevFflagBuff

  result = gui:
    Window:
      title = "verm"
      defaultSize = (860, 640)

      AdwHeaderBar {.addTitlebar.}:
        centeringPolicy = CenteringPolicyLoose
        showTitle = true
        sizeRequest = (-1, -1)

        Button {.addLeft.}:
          sensitive = true
          #icon = "view-list-bullet-rtl-symbolic"
          text = "Features"
          tooltip = "The features provided by verm"

          # Switches to the verm features page
          proc clicked() =
            app.state = ShellState.verm

        Button {.addLeft.}:
          sensitive = true
          #icon = "applications-games-symbolic"
          text = "Client"
          tooltip = "Basic settings for Sober (e.g. framerate cap)"

          # Switches to the client settings page
          proc clicked() =
            app.state = ShellState.Client

        Button {.addLeft.}:
          sensitive = true
          #icon = "applications-science-symbolic"
          text = "Tweaks"
          tooltip = "Restore the Oof sound, use custom fonts and more"

          # Switches to the tweaks page
          proc clicked() =
            app.state = ShellState.Tweaks

        Button {.addLeft.}:
          sensitive = true
          #icon = "utilities-terminal-symbolic"
          text = "FFlags"
          tooltip = "Add and remove FFlags easily"

          # Switches to the FFlag editor page
          proc clicked() =
            app.state = ShellState.FflagEditor

        Button {.addRight.}:
          style = [ButtonFlat]
          icon = "media-floppy-symbolic" # floppy disk as a save icon (system icon)
          tooltip = "Save the modified configuration"

          # Saves the current configuration to disk
          proc clicked() =
            debug "shell: updated configuration file"
            app.config[].save()

        Button {.addRight.}:
          style = [ButtonFlat]
          icon = "bookmark-new-symbolic"
          tooltip = "Add desktop entries for verm"

          # Creates .desktop files for verm
          proc clicked() =
            debug "shell: created .desktop files"
            createvermDesktopFile()

        Button {.addRight.}:
          style = [ButtonFlat]
          icon = "input-gaming-symbolic"
          tooltip = "Save configuration and launch Sober through verm"

          # Saves config, closes the window, and launches Sober through verm
          proc clicked() =
            debug "shell: save config, exit config editor and launch verm"
            app.config[].save()
            app.scheduleCloseWindow()

            if fork() == 0:
              debug "shell: we are the child - launching `verm run`"
              quit(execCmd("verm run"))
            else:
              debug "shell: we are the parent - quitting"
              quit(0)

      Box:

        case app.state
        of ShellState.Tweaks:
          PreferencesPage:

            PreferencesGroup:
              sizeRequest = (760, 560)
              title = "Tweaks and Patches"
              description = "These are some optional tweaks to customize your experience."

              ActionRow:
                title = "Bring Back the \"Oof\" Sound"
                subtitle =
                  "This replaces the new \"Eugh\" death sound with the classic \"Oof\" sound."
                CheckButton {.addSuffix.}:
                  state = app.oldOofSound

                  # Toggles the "Oof" sound option and updates config
                  proc changed(state: bool) =
                    app.oldOofSound = not app.oldOofSound
                    app.config[].tweaks.oldOof = app.oldOofSound

                    debug "shell: old oof sound state: " & $app.oldOofSound

              ActionRow:
                title = "Custom Client Font"
                subtitle =
                  "Override the Roblox fonts using your own font, Note: Emojis will not be overriden."

                Entry {.addSuffix.}:
                  text = app.customFontPath

                  # Updates the custom font path buffer
                  proc changed(text: string) =
                    debug "shell: custom font entry changed: " & text
                    app.customFontPath = text

                  # Validates and sets the custom font path in config
                  proc activate() =
                    let font = app.customFontPath.expandTilde()
                    if font.len > 0 and not isAccessible(font):
                      notify("Cannot set custom font", "File not accessible.")
                      return

                    app.config[].tweaks.font = font
                    debug "shell: custom font path is set to: " & app.customFontPath

              ActionRow:
                title = "Custom Sun Texture"
                subtitle =
                  "For games that don't use a custom sun texture, your specified texture will be shown instead."

                Entry {.addSuffix.}:
                  text = app.sunImgPath
                  placeholder = ""

                  # Updates the sun image path buffer
                  proc changed(text: string) =
                    debug "shell: sun image entry changed: " & text
                    app.sunImgPath = text

                  # Validates and sets the sun texture path in config
                  proc activate() =
                    let path = app.sunImgPath.expandTilde()
                    if path.len > 0 and not isAccessible(path):
                      notify("Cannot set sun texture", "Texture file not accessible.")
                      return

                    app.config[].tweaks.sun = path
                    debug "shell: custom sun texture path is set to: " & app.sunImgPath

              ActionRow:
                title = "Custom Moon Texture"
                subtitle =
                  "For games that don't use a custom moon texture, your specified texture will be shown instead."

                Entry {.addSuffix.}:
                  text = app.moonImgPath
                  placeholder = ""

                  # Updates the moon image path buffer
                  proc changed(text: string) =
                    debug "shell: moon image entry changed: " & text
                    app.moonImgPath = text

                  # Validates and sets the moon texture path in config
                  proc activate() =
                    let path = app.moonImgPath.expandTilde()
                    if path.len > 0 and not isAccessible(path):
                      notify("Cannot set moon texture", "Texture file not accessible.")
                      return

                    app.config[].tweaks.moon = path
                    debug "shell: custom moon texture path is set to: " & app.sunImgPath

        of ShellState.verm:
          PreferencesPage:

            PreferencesGroup:
              sizeRequest = (760, 560)
              title = "Verm Settings"
              description =
                "These are settings to tweak the features that verm provides."

              ActionRow:
                title = "Discord Rich Presence"
                subtitle =
                  "This requires you to have either the official Discord client or an arRPC-based one."
                CheckButton {.addSuffix.}:
                  state = app.discordRpcOpt

                  # Toggles Discord RPC option and updates config
                  proc changed(state: bool) =
                    app.discordRpcOpt = not app.discordRpcOpt
                    app.config[].verm.discordRpc = app.discordRpcOpt

                    debug "shell: discord rpc option state: " &
                      $app.config[].verm.discordRpc

              ActionRow:
                title = "Notify the Server Region"
                subtitle =
                  "When joining a game, a notification will be sent containing the location of the server."
                CheckButton {.addSuffix.}:
                  state = app.serverLocationOpt

                  # Toggles server region notification and updates config
                  proc changed(state: bool) =
                    app.serverLocationOpt = not app.serverLocationOpt
                    app.config[].verm.notifyServerRegion = app.serverLocationOpt

                    debug "shell: notify server region option state: " &
                      $app.config[].verm.notifyServerRegion

              ActionRow:
                title = "Clear all API caches"
                subtitle =
                  "This will clear all the API call caches. Some features might be slower the next time you run verm."
                Button {.addSuffix.}:
                  icon = "user-trash-symbolic"
                  style = [ButtonDestructive]

                  # Clears all API caches and notifies the user
                  proc clicked() =
                    let savedMb = clearCache()
                    info "shell: cleared out cache and reclaimed " & $savedMb &
                      " MB of space."
                    notify("Cleared API cache", $savedMb & " MB of space was freed.")

        of ShellState.FflagEditor:
          PreferencesPage:

            PreferencesGroup:
              sizeRequest = (760, 560)
              title = "FFlag Editor"
              description =
                "Please keep in mind that some games prohibit the modifications of FFlags. You might get banned from them due to modifying FFlags. Modifying FFlags can also make the Roblox client unstable in some cases. Do not touch these if you don't know what you're doing!"

              Box(orient = OrientY, spacing = 6, margin = 12):
                Box(orient = OrientX, spacing = 6) {.expand: false.}:
                  Entry:
                    text = app.currFflagBuff
                    placeholder = "Key=Value"

                    # Updates the FFlag entry buffer
                    proc changed(text: string) =
                      app.currFflagBuff = text
                      debug "shell: fflag entry mutated: " & app.currFflagBuff

                    # Adds the FFlag entry to the config (no validation yet)
                    proc activate() =
                      debug "shell: fflag entry: " & app.currFflagBuff

                      # TODO: add validation
                      app.config.client.fflags &= '\n' & app.currFflagBuff

                  Button {.expand: false.}:
                    icon = "list-add-symbolic"
                    style = [ButtonSuggested]

                    # Adds the FFlag entry to the config (no validation yet)
                    proc clicked() =
                      # TODO: add validation
                      app.config[].client.fflags &= '\n' & app.currFflagBuff

                      debug "shell: fflag entry: " & app.currFflagBuff

                Frame:
                  ScrolledWindow:
                    ListBox:
                      for key, value in parsedFflags:
                        Box:
                          spacing = 6
                          Label:
                            xAlign = 0
                            text =
                              key & " = " & (
                                if value.kind == JString:
                                  value.getStr()
                                elif value.kind == JInt:
                                  $value.getInt()
                                elif value.kind == JBool:
                                  $value.getBool()
                                elif value.kind == JFloat:
                                  $value.getFloat()
                                else: "<invalid type>"
                              )

                          Button {.expand: false.}:
                            icon = "list-remove-symbolic"
                            style = [ButtonDestructive]

                            # Removes the selected FFlag from the config
                            proc clicked() =
                              debug "shell: deleting fflag: " & key
                              app.prevFflagBuff = app.currFflagBuff

                              var
                                fflags = app.config[].client.fflags.splitLines()
                                newFflags: seq[string] = @[]

                              for l in fflags:
                                # Only remove the line if it matches the key exactly (before the first '=')
                                let eqIdx = l.find('=')
                                if eqIdx != -1:
                                  let k = l[0 ..< eqIdx].strip()
                                  if k != key and l.strip().len > 0:
                                    newFflags.add(l)
                                else:
                                  # If the line doesn't contain '=', keep it (or skip? safer to keep)
                                  if l.strip().len > 0:
                                    newFflags.add(l)

                              # Rebuild the fflags string, joining with '\n'
                              if newFflags.len > 0:
                                app.config[].client.fflags = newFflags.join("\n") & '\n'
                              else:
                                app.config[].client.fflags = ""

        of ShellState.Client:
          PreferencesPage:

            PreferencesGroup:
              sizeRequest = (760, 560)
              title = "Client Settings"
              description = "These settings are mostly applied via FFlags."
              ActionRow:
                title = "Disable Telemetry"
                subtitle =
                  "Disable the Roblox client telemetry via FFlags. Note: This only enables/disables relevant FFLags."
                CheckButton {.addSuffix.}:
                  state = app.telemetryOpt

                  # Toggles telemetry option and updates config
                  proc changed(state: bool) =
                    app.telemetryOpt = not app.telemetryOpt
                    app.config[].client.telemetry = app.telemetryOpt

                    debug "shell: disable telemetry is now set to: " & $app.telemetryOpt

              ActionRow:
                title = "Disable FPS cap"
                subtitle = "Some games might ban you if they detect this. Note: Games dependent on framerate might misbehave."
                CheckButton {.addSuffix.}:
                  state = app.showFpsCapOpt

                  # Toggles FPS cap option and updates config
                  proc changed(state: bool) =
                    app.showFpsCapOpt = not app.showFpsCapOpt
                    app.config[].client.fps = if state: 60 else: 60

                    debug "shell: disable/enable fps cap button state: " &
                      $app.showFpsCapOpt
                    debug "shell: fps is now set to: " & $app.config[].client.fps
              if app.showFpsCapOpt:
                ActionRow:
                  title = "FPS Cap"
                  subtitle = "Change the FPS cap to values Roblox doesn't offer. Avoid using a value above the monitor refresh rate."
                  Entry {.addSuffix.}:
                    text = app.showFpsCapBuff
                    placeholder = "e.g. 30, 60 (default), 144, etc."

                    # Updates the FPS cap buffer
                    proc changed(text: string) =
                      debug "shell: fps cap entry changed: " & text
                      app.showFpsCapBuff = text

                    # Parses and sets the FPS cap value in config
                    proc activate() =
                      try:
                        debug "shell: parse fps cap buffer as integer: " &
                          app.showFpsCapBuff
                        let val = parseInt(app.showFpsCapBuff)
                        app.config[].client.fps = val
                        debug "shell: fps cap is now set to: " & $app.config[].client.fps
                      except ValueError as exc:
                        debug "shell: fps cap buffer has invalid value: " &
                          app.showFpsCapBuff
                        debug "shell: " & exc.msg

              ComboRow:
                title = "Backend"
                subtitle =
                  "Which display server Sober will use, on Wayland X11 will use Xwayland."
                items = app.backendOpt
                selected = app.backendBuff

                # Updates the selected backend buffer
                proc select(selectedIndex: int) =
                  debug "shell: launcher entry changed: " & app.backendOpt[selectedIndex]
                  app.backendBuff = selectedIndex

                # Sets the backend in config
                proc activate() =
                  app.config[].client.backend = app.backendOpt[app.backendBuff]
                  debug "shell: backend is set to: " & app.backendOpt[app.backendBuff]

              ActionRow:
                title = "Launcher"
                subtitle =
                  "verm will launch Sober with a specified command. This is optional."
                Entry {.addSuffix.}:
                  text = app.launcherBuff
                  placeholder = "e.g. gamemoderun"

                  # Updates the launcher buffer
                  proc changed(text: string) =
                    debug "shell: launcher entry changed: " & text
                    app.launcherBuff = text

                  # Sets the launcher command in config
                  proc activate() =
                    app.config[].client.launcher = app.launcherBuff
                    debug "shell: launcher is set to: " & app.launcherBuff

              ActionRow:
                title = "Polling Delay"
                subtitle =
                  "Add a tiny delay in seconds to the event watcher thread. This is unlikely to impact performance on modern systems."

                Entry {.addSuffix.}:
                  text = app.pollingDelayBuff
                  placeholder = "100 is sufficient for most modern systems"

                  # Updates the polling delay buffer
                  proc changed(text: string) =
                    debug "shell: polling delay entry changed: " & text
                    app.pollingDelayBuff = text

                  # Parses and sets the polling delay in config
                  proc activate() =
                    try:
                      app.config[].verm.pollingDelay = app.pollingDelayBuff.parseUint()
                      debug "shell: polling delay is set to: " & app.pollingDelayBuff
                    except ValueError as exc:
                      warn "shell: failed to parse polling delay (" & app.pollingDelayBuff &
                        "): " & exc.msg

              ActionRow:
                title = "Automatic APK Updates"
                subtitle =
                  "If enabled, Sober will automatically fetch the latest versions of Roblox's APK for you from the Play Store."
                CheckButton {.addSuffix.}:
                  state = app.automaticApkUpdates

                  # Toggles automatic APK updates and updates config
                  proc changed(state: bool) =
                    app.automaticApkUpdates = state
                    app.config[].client.apkUpdates = state

# Initializes the verm shell GUI, loads config, and starts the main event loop.
proc initvermShell*(input: Input) {.inline.} =
  info "shell: initializing GTK4 shell"
  info "shell: libadwaita version: v" & $AdwVersion[0] & '.' & $AdwVersion[1]
  var config = parseConfig(input)

  adw.brew(
    gui(
      vermShell(
        config = addr(config),
        state = ShellState.verm,
        showFpsCapOpt = config.client.fps != 60,
        showFpsCapBuff = $config.client.fps,
        discordRpcOpt = config.verm.discordRpc,
        telemetryOpt = config.client.telemetry,
        launcherBuff = config.client.launcher,
        serverLocationOpt = config.verm.notifyServerRegion,
        customFontPath = config.tweaks.font,
        oldOofSound = config.tweaks.oldOof,
        sunImgPath = config.tweaks.sun,
        moonImgPath = config.tweaks.moon,
        pollingDelayBuff = $config.verm.pollingDelay,
        automaticApkUpdates = config.client.apkUpdates,
      )
    )
  )

  info "verm: saving configuration changes"
  config.save()
  info "verm: done!"
