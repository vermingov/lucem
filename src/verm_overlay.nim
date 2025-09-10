## verm Overlay
## Copyright (C) 2024 Trayambak Rai

import std/[os, osproc, logging, strutils, importutils, base64, times]
import ./[argparser, sugar, config, internal_fonts]
import pkg/[siwin, opengl, nanovg, colored_logger, vmath]
import pkg/siwin/platforms/wayland/[window, windowOpengl]
import ./fflags
import ./sober_config

privateAccess(WindowWaylandOpengl)
privateAccess(WindowWaylandObj)
privateAccess(WindowWayland)
privateAccess(Window)

{.passC: gorge("pkg-config --cflags wayland-client").}
{.passL: gorge("pkg-config --libs wayland-client").}
{.passC: gorge("pkg-config --cflags x11").}
{.passL: gorge("pkg-config --libs x11").}
{.passC: gorge("pkg-config --cflags xcursor").}
{.passL: gorge("pkg-config --libs xcursor").}
{.passC: gorge("pkg-config --cflags xext").}
{.passL: gorge("pkg-config --libs xext").}
{.passC: gorge("pkg-config --cflags xkbcommon").}
{.passL: gorge("pkg-config --libs xkbcommon").}
{.passC: gorge("pkg-config --cflags gl").}
{.passL: gorge("pkg-config --libs gl").}

type
  OverlayState* = enum
    osOverlay
    osUpdateAlert

  Overlay* = object
    heading*: string
    description*: string
    expireTime*: float
    state*: OverlayState = osOverlay

    icon*: Option[string]
    closed*: bool
    config*: Config

    vermImage*: Image

    vg*: NVGContext
    wl*: WindowWaylandOpengl
    size*: IVec2 = ivec2(600, 200)

    lastEpoch*: float
    timeSpent*: float
    lastLogSecond*: int

    headingFont*: Font

proc draw*(overlay: var Overlay) =
  debug "overlay: redrawing surface"
  glViewport(0, 0, overlay.size.x, overlay.size.y)
  glClearColor(0, 0, 0, 0)
  glClear(GL_COLOR_BUFFER_BIT or
    GL_DEPTH_BUFFER_BIT or
    GL_STENCIL_BUFFER_BIT)

  overlay.vg.beginFrame(overlay.size.x.cfloat, overlay.size.y.cfloat, 1f) # TODO: fractional scaling support
  overlay.vg.roundedRect(0, 0, overlay.size.x.cfloat - 16f, overlay.size.y.cfloat, 16f)
  overlay.vg.fillColor(rgba(0.1, 0.1, 0.1, 0.6))
  overlay.wl.m_transparent = true
  overlay.vg.fill()
  
  overlay.vg.fontFace("heading")
  overlay.vg.textAlign(haLeft, vaTop)
  overlay.vg.fontSize(overlay.config.overlay.headingSize)
  overlay.vg.fillColor(white(255))

  var icon = cast[seq[byte]](vermIconPng)
  overlay.vermImage = overlay.vg.createImageMem(data = icon)

  if overlay.state == osOverlay:
    discard overlay.vg.text(16f, 16f, overlay.heading)
  else:
    let imgPaint = overlay.vg.imagePattern(16, 16, 60, 60, 0, overlay.vermImage, 1f)
    overlay.vg.beginPath()
    overlay.vg.rect(16, 16, 60, 60)
    overlay.vg.fillPaint(imgPaint)
    overlay.vg.fill()

    discard overlay.vg.text(100f, 16f, overlay.heading)
  
  overlay.vg.fontFace("heading")
  overlay.vg.textAlign(haLeft, vaTop)
  overlay.vg.fontSize(overlay.config.overlay.descriptionSize)
  overlay.vg.fillColor(white(255))
  overlay.vg.textBox(16f, 100f, 512f, overlay.description.cstring, nil)

  # TODO: icon rendering, even though we don't use them yet
  # but it'd be useful for the future

  overlay.vg.endFrame()

proc initOverlay*(input: Input) {.noReturn.} =
  var overlay: Overlay
  
  let opts = if not input.enabled("update-alert"):
    @[
      "heading",
      "description",
      "expire-time"
    ]
  else:
    @[
      "update-heading",
      "update-message"
    ]

  overlay.state = if input.enabled("update-alert"):
    osUpdateAlert
  else:
    osOverlay
  
  for opt in opts:
    if (let maybeOpt = input.flag(opt); *maybeOpt):
      case opt
      of "heading", "update-heading": overlay.heading = decode(&maybeOpt)
      of "description", "update-message": overlay.description = decode(&maybeOpt)
      of "expire-time": overlay.expireTime = parseFloat(&maybeOpt)
    else:
      error "overlay: expected flag: " & opt
      quit(1)

  if (let oIcon = input.flag("icon"); *oIcon):
    overlay.icon = oIcon
  
  debug "overlay: got all arguments, parsing config"
  var config = parseConfig(input)

  # If a non-update overlay was requested with zero/invalid expire-time, clamp to 4 seconds
  if overlay.state == osOverlay and (overlay.expireTime <= 0f or overlay.expireTime.isNaN):
    overlay.expireTime = 4f

  # Validate FFlags before proceeding
  try:
    var parsedFflags: SoberFFlags
    parseFFlags(config, parsedFflags)
  except FFlagParseError as exc:
    error "overlay: failed to parse FFlags: " & exc.msg
    quit(1)

  debug "overlay: creating surface"
  overlay.size = ivec2(config.overlay.width.int32, config.overlay.height.int32)
  overlay.wl = newOpenglWindowWayland(
    kind = WindowWaylandKind.LayerSurface,
    layer = Layer.Overlay,
    size = overlay.size,
    namespace = "verm"
  )
  overlay.wl.setKeyboardInteractivity(LayerInteractivityMode.OnDemand)
  var anchors: seq[LayerEdge]

  if overlay.state == osOverlay:
    for value in config.overlay.anchors.split('-'):
      debug "overlay: got anchor: " & value
      case value.toLowerAscii()
      of "left", "l": anchors &= LayerEdge.Left
      of "right", "r": anchors &= LayerEdge.Right
      of "top", "up", "u": anchors &= LayerEdge.Top
      of "bottom", "down", "d": anchors &= LayerEdge.Bottom
      else:
        warn "overlay: unhandled anchor: " & value
  else:
    anchors = @[LayerEdge.Left, LayerEdge.Right, LayerEdge.Top, LayerEdge.Bottom]

  overlay.wl.setAnchor(anchors)
  # overlay.wl.setExclusiveZone(10000)
  overlay.wl.m_transparent = true

  overlay.config = move(config)

  debug "overlay: loading OpenGL"
  loadExtensions()

  debug "overlay: creating NanoVG instance"
  nvgInit(glGetProc)
  overlay.vg = nvgCreateContext({
    nifAntialias
  })
  var data = 
    if (config.overlay.font.len > 0 and fileExists(config.overlay.font)):
      cast[seq[byte]](readFile(config.overlay.font))
    else:
      cast[seq[byte]](IbmPlexSans)

  overlay.headingFont = overlay.vg.createFontMem(
    "heading",
    data
  )
  overlay.lastEpoch = epochTime()
  overlay.timeSpent = 0f
  overlay.lastLogSecond = -1

  overlay.wl.eventsHandler.onRender = proc(event: RenderEvent) =
    if overlay.closed: return
    overlay.draw()

  overlay.wl.eventsHandler.onTick = proc(event: TickEvent) =
    if overlay.closed: return
    if overlay.expireTime == 0f and overlay.state == osOverlay:
      # For safety, never let regular overlays be infinite
      overlay.expireTime = 4f

    if overlay.expireTime == 0f:
      return # Infinite alert only allowed for update-alert

    let epoch = epochTime()
    let elapsed = epoch - overlay.lastEpoch

    overlay.timeSpent += elapsed
    overlay.lastEpoch = epoch

    # Throttle debug logging to once per second to avoid spamming
    let currentSec = int(floor(overlay.timeSpent))
    if currentSec != overlay.lastLogSecond:
      debug "overlay: " & $overlay.timeSpent & "s / " & $overlay.expireTime & 's'
      overlay.lastLogSecond = currentSec

    if overlay.timeSpent >= overlay.expireTime:
      info "overlay: Completed lifetime. Closing!"
      overlay.closed = true
      overlay.wl.close()

  overlay.wl.eventsHandler.onKey = proc(event: KeyEvent) =
    if overlay.closed: return
    if overlay.state == osUpdateAlert:
      case event.key
      of enter:
        overlay.description = "verm is updating itself. Please wait."
        discard execCmd(findExe("verm") & " update")
        overlay.description = "Done!"
        overlay.closed = true
        overlay.wl.close()
      else:
        overlay.closed = true
        overlay.wl.close()
    else:
      overlay.closed = true
      overlay.wl.close()

  overlay.wl.run()
  quit(0)

proc main =
  addHandler(newColoredLogger())
  setLogFilter(lvlInfo) # Suppress debug logs by default to avoid console spam
  let input = parseInput()

  initOverlay(input)

when isMainModule: main()
