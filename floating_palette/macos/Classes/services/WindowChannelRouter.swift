import Cocoa
import FlutterMacOS

/// Sets up Flutter method channels on palette engines and routes incoming calls.
///
/// Each palette engine gets three channels:
/// - `floating_palette/entry` — provides palette ID
/// - `floating_palette/messenger` — palette→host messaging, snap commands, events
/// - `floating_palette/self` — palette self-query: bounds, position, size, drag, hide
enum WindowChannelRouter {

    /// Set up all channels for a newly created palette engine.
    ///
    /// Returns the (entryChannel, messengerChannel) for storage on the PaletteWindow.
    static func setupChannels(
        id: String,
        engine: FlutterEngine,
        eventSink: ((String, String, String?, [String: Any]) -> Void)?,
        backgroundCaptureService: BackgroundCaptureService?,
        snapService: SnapService?,
        dragCoordinator: DragCoordinator?
    ) -> (entry: FlutterMethodChannel, messenger: FlutterMethodChannel) {
        let entryChannel = setupEntryChannel(id: id, engine: engine)
        let messengerChannel = setupMessengerChannel(
            id: id,
            engine: engine,
            eventSink: eventSink,
            snapService: snapService
        )
        setupSelfChannel(
            id: id,
            engine: engine,
            eventSink: eventSink,
            backgroundCaptureService: backgroundCaptureService,
            dragCoordinator: dragCoordinator
        )

        return (entry: entryChannel, messenger: messengerChannel)
    }

    // MARK: - Entry Channel

    private static func setupEntryChannel(id: String, engine: FlutterEngine) -> FlutterMethodChannel {
        let channel = FlutterMethodChannel(
            name: "floating_palette/entry",
            binaryMessenger: engine.binaryMessenger
        )
        channel.setMethodCallHandler { call, result in
            if call.method == "getPaletteId" {
                result(id)
            } else {
                result(FlutterMethodNotImplemented)
            }
        }
        return channel
    }

    // MARK: - Messenger Channel

    private static func setupMessengerChannel(
        id: String,
        engine: FlutterEngine,
        eventSink: ((String, String, String?, [String: Any]) -> Void)?,
        snapService: SnapService?
    ) -> FlutterMethodChannel {
        let channel = FlutterMethodChannel(
            name: "floating_palette/messenger",
            binaryMessenger: engine.binaryMessenger
        )
        channel.setMethodCallHandler { call, channelResult in
            switch call.method {
            case "send":
                // Forward message to host via event sink
                if let args = call.arguments as? [String: Any],
                   let type = args["type"] as? String,
                   let data = args["data"] as? [String: Any] {
                    eventSink?("message", type, id, data)
                }
                channelResult(nil)

            case "snap":
                // Handle snap command from palette
                guard let args = call.arguments as? [String: Any] else {
                    channelResult(FlutterError(code: "INVALID_ARGS", message: "Arguments required", details: nil))
                    return
                }
                snapService?.handle("snap", windowId: id, params: args, result: channelResult)

            case "detachSnap":
                // Handle detach command from palette
                snapService?.handle("detach", windowId: id, params: ["followerId": id], result: channelResult)

            case "setAutoSnapConfig":
                // Handle auto-snap config from palette
                guard let args = call.arguments as? [String: Any] else {
                    channelResult(FlutterError(code: "INVALID_ARGS", message: "Arguments required", details: nil))
                    return
                }
                snapService?.handle("setAutoSnapConfig", windowId: id, params: args, result: channelResult)

            case "notify":
                // Forward typed event to host via event sink
                if let args = call.arguments as? [String: Any],
                   let type = args["type"] as? String,
                   let data = args["data"] as? [String: Any] {
                    eventSink?("event", type, id, data)
                }
                channelResult(nil)

            case "requestHide":
                // Palette requesting to hide itself
                eventSink?("requestHide", "hide", id, [:])
                channelResult(nil)

            default:
                channelResult(FlutterMethodNotImplemented)
            }
        }
        return channel
    }

    // MARK: - Self Channel

    private static func setupSelfChannel(
        id: String,
        engine: FlutterEngine,
        eventSink: ((String, String, String?, [String: Any]) -> Void)?,
        backgroundCaptureService: BackgroundCaptureService?,
        dragCoordinator: DragCoordinator?
    ) {
        let channel = FlutterMethodChannel(
            name: "floating_palette/self",
            binaryMessenger: engine.binaryMessenger
        )
        channel.setMethodCallHandler { call, channelResult in
            // Get window from store (using closure capture of id)
            guard let window = WindowStore.shared.get(id) else {
                channelResult(FlutterError(code: "NOT_FOUND", message: "Window not found", details: nil))
                return
            }

            let frame = window.panel.frame

            switch call.method {
            case "getBounds":
                channelResult([
                    "x": frame.origin.x,
                    "y": frame.origin.y,
                    "width": frame.width,
                    "height": frame.height
                ])
            case "getPosition":
                channelResult([
                    "x": frame.origin.x,
                    "y": frame.origin.y
                ])
            case "getSize":
                channelResult([
                    "width": frame.width,
                    "height": frame.height
                ])
            case "getSizeConfig":
                channelResult(window.sizeConfig)
            case "startDrag":
                DispatchQueue.main.async {
                    // Delegate to DragCoordinator which handles the full drag lifecycle
                    dragCoordinator?.startDrag(id, window: window)
                    channelResult(nil)
                }

            case "setSize":
                guard let args = call.arguments as? [String: Any],
                      let width = args["width"] as? Double,
                      let height = args["height"] as? Double else {
                    channelResult(FlutterError(code: "INVALID_ARGS", message: "width and height required", details: nil))
                    return
                }
                DispatchQueue.main.async {
                    let currentFrame = window.panel.frame
                    // Keep top-left position stable (macOS coordinates have Y=0 at bottom)
                    let newY = currentFrame.origin.y + currentFrame.height - CGFloat(height)
                    let newFrame = NSRect(
                        x: currentFrame.origin.x,
                        y: newY,
                        width: CGFloat(width),
                        height: CGFloat(height)
                    )
                    window.panel.setFrame(newFrame, display: true, animate: false)
                    channelResult(nil)
                }

            case "hide":
                DispatchQueue.main.async {
                    window.panel.orderOut(nil)
                    eventSink?("visibility", "hidden", id, [:])
                    channelResult(nil)
                }

            // Background capture commands (use palette's texture registry)
            case "backgroundCapture.checkPermission":
                backgroundCaptureService?.handle("checkPermission", windowId: id, params: [:], result: channelResult)

            case "backgroundCapture.requestPermission":
                backgroundCaptureService?.handle("requestPermission", windowId: id, params: [:], result: channelResult)

            case "backgroundCapture.start":
                // Get texture registry from palette's engine
                let registrar = window.engine.registrar(forPlugin: "FloatingPalettePlugin")
                let textureRegistry = registrar.textures
                let params = call.arguments as? [String: Any] ?? [:]
                backgroundCaptureService?.startCapture(
                    windowId: id,
                    params: params,
                    textureRegistry: textureRegistry,
                    result: channelResult
                )

            case "backgroundCapture.stop":
                backgroundCaptureService?.handle("stop", windowId: id, params: [:], result: channelResult)

            case "backgroundCapture.getTextureId":
                backgroundCaptureService?.handle("getTextureId", windowId: id, params: [:], result: channelResult)

            case "getAppIcon":
                guard let args = call.arguments as? [String: Any],
                      let appPath = args["path"] as? String else {
                    channelResult(FlutterError(code: "INVALID_ARGS", message: "path required", details: nil))
                    return
                }
                DispatchQueue.global(qos: .userInitiated).async {
                    let icon = NSWorkspace.shared.icon(forFile: appPath)
                    // Resize to 64x64 for efficiency
                    let size = NSSize(width: 64, height: 64)
                    let resized = NSImage(size: size)
                    resized.lockFocus()
                    icon.draw(in: NSRect(origin: .zero, size: size),
                              from: NSRect(origin: .zero, size: icon.size),
                              operation: .copy,
                              fraction: 1.0)
                    resized.unlockFocus()

                    // Convert to PNG
                    if let tiffData = resized.tiffRepresentation,
                       let bitmap = NSBitmapImageRep(data: tiffData),
                       let pngData = bitmap.representation(using: .png, properties: [:]) {
                        DispatchQueue.main.async {
                            channelResult(FlutterStandardTypedData(bytes: pngData))
                        }
                    } else {
                        DispatchQueue.main.async {
                            channelResult(nil)
                        }
                    }
                }

            default:
                channelResult(FlutterMethodNotImplemented)
            }
        }
    }
}
