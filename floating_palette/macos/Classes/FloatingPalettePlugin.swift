import Cocoa
import FlutterMacOS

/// Floating Palette Plugin
///
/// Architecture:
/// - Dart orchestrates (all business logic)
/// - Native executes (stateless service primitives)
///
/// Commands come in via method channel, get routed to services.
/// Events go back via method channel.
public class FloatingPalettePlugin: NSObject, FlutterPlugin {
    private var channel: FlutterMethodChannel?

    // Services
    private var windowService: WindowService?
    private var visibilityService: VisibilityService?
    private var frameService: FrameService?
    private var transformService: TransformService?
    private var animationService: AnimationService?
    private var inputService: InputService?
    private var focusService: FocusService?
    private var zorderService: ZOrderService?
    private var appearanceService: AppearanceService?
    private var screenService: ScreenService?
    private var backgroundCaptureService: BackgroundCaptureService?
    private var messageService: MessageService?
    private var hostService: HostService?
    private var snapService: SnapService?
    private var dragCoordinator: DragCoordinator?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "floating_palette",
            binaryMessenger: registrar.messenger
        )

        let instance = FloatingPalettePlugin()
        instance.channel = channel
        instance.initializeServices(registrar: registrar)

        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    private func initializeServices(registrar: FlutterPluginRegistrar) {
        // Create event sink
        let eventSink: (String, String, String?, [String: Any]) -> Void = { [weak self] service, event, windowId, data in
            self?.sendEvent(service: service, event: event, windowId: windowId, data: data)
        }

        // Initialize all services
        windowService = WindowService(registrar: registrar)
        windowService?.setEventSink(eventSink)

        visibilityService = VisibilityService()
        visibilityService?.setEventSink(eventSink)

        frameService = FrameService()
        frameService?.setEventSink(eventSink)

        transformService = TransformService()
        transformService?.setEventSink(eventSink)

        animationService = AnimationService()
        animationService?.setEventSink(eventSink)

        inputService = InputService()
        inputService?.setEventSink(eventSink)

        focusService = FocusService()
        focusService?.setEventSink(eventSink)

        zorderService = ZOrderService()
        zorderService?.setEventSink(eventSink)

        appearanceService = AppearanceService()
        appearanceService?.setEventSink(eventSink)

        screenService = ScreenService()
        screenService?.setEventSink(eventSink)

        backgroundCaptureService = BackgroundCaptureService(registrar: registrar)
        backgroundCaptureService?.setEventSink(eventSink)

        messageService = MessageService()
        messageService?.setEventSink(eventSink)

        hostService = HostService()
        hostService?.setEventSink(eventSink)

        snapService = SnapService()
        snapService?.setEventSink(eventSink)

        // Create DragCoordinator and wire it up
        dragCoordinator = DragCoordinator()
        dragCoordinator?.delegate = snapService

        // Give WindowService access to BackgroundCaptureService for self channel commands
        windowService?.setBackgroundCaptureService(backgroundCaptureService)

        // Give WindowService access to FrameService for window frame observers
        windowService?.setFrameService(frameService)

        // Give WindowService access to SnapService for snap notifications
        windowService?.setSnapService(snapService)

        // Give WindowService access to DragCoordinator for drag lifecycle management
        windowService?.setDragCoordinator(dragCoordinator)

        // Give WindowService access to InputService for cleanup on window destruction
        windowService?.setInputService(inputService)

        // Give FrameService access to SnapService for snap notifications
        frameService?.setSnapService(snapService)

        // Give FrameService access to DragCoordinator for drag lifecycle management
        frameService?.setDragCoordinator(dragCoordinator)

        // Give VisibilityService access to SnapService for snap notifications
        visibilityService?.setSnapService(snapService)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard call.method == "command",
              let args = call.arguments as? [String: Any],
              let service = args["service"] as? String,
              let command = args["command"] as? String else {
            result(FlutterMethodNotImplemented)
            return
        }

        let windowId = args["windowId"] as? String
        let params = args["params"] as? [String: Any] ?? [:]

        // Route to appropriate service
        switch service {
        case "window":
            windowService?.handle(command, windowId: windowId, params: params, result: result)
        case "visibility":
            visibilityService?.handle(command, windowId: windowId, params: params, result: result)
        case "frame":
            frameService?.handle(command, windowId: windowId, params: params, result: result)
        case "transform":
            transformService?.handle(command, windowId: windowId, params: params, result: result)
        case "animation":
            animationService?.handle(command, windowId: windowId, params: params, result: result)
        case "input":
            inputService?.handle(command, windowId: windowId, params: params, result: result)
        case "focus":
            focusService?.handle(command, windowId: windowId, params: params, result: result)
        case "zorder":
            zorderService?.handle(command, windowId: windowId, params: params, result: result)
        case "appearance":
            appearanceService?.handle(command, windowId: windowId, params: params, result: result)
        case "screen":
            screenService?.handle(command, windowId: windowId, params: params, result: result)
        case "backgroundCapture":
            backgroundCaptureService?.handle(command, windowId: windowId, params: params, result: result)
        case "message":
            messageService?.handle(command, windowId: windowId, params: params, result: result)
        case "host":
            hostService?.handle(command, windowId: windowId, params: params, result: result)
        case "snap":
            snapService?.handle(command, windowId: windowId, params: params, result: result)
        default:
            result(FlutterError(code: "UNKNOWN_SERVICE", message: "Unknown service: \(service)", details: nil))
        }
    }

    // MARK: - Event Sending

    private func sendEvent(service: String, event: String, windowId: String?, data: [String: Any]) {
        channel?.invokeMethod("event", arguments: [
            "service": service,
            "event": event,
            "windowId": windowId as Any,
            "data": data,
        ])
    }
}
