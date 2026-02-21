import Cocoa
import FlutterMacOS
import ScreenCaptureKit

/// Captures the screen content behind palette windows and streams it as a Flutter texture.
/// This enables liquid glass effects that refract the desktop background.
///
/// Usage flow:
/// 1. Dart calls "start" with paletteId and config
/// 2. Service creates texture, starts capture, returns textureId
/// 3. Captured frames are streamed to Flutter via TextureRegistry
/// 4. Dart calls "stop" to release resources
final class BackgroundCaptureService {
    private let store = WindowStore.shared
    private weak var registrar: FlutterPluginRegistrar?
    private var eventSink: ((String, String, String?, [String: Any]) -> Void)?

    /// Active capture sessions by palette ID
    private var activeSessions: [String: CaptureSession] = [:]
    private let sessionLock = NSLock()

    init(registrar: FlutterPluginRegistrar?) {
        self.registrar = registrar
    }

    func setEventSink(_ sink: @escaping (String, String, String?, [String: Any]) -> Void) {
        self.eventSink = sink
    }

    // MARK: - Commands

    func handle(_ command: String, windowId: String?, params: [String: Any], result: @escaping FlutterResult) {
        switch command {
        case "checkPermission":
            checkPermission(result: result)
        case "requestPermission":
            requestPermission(result: result)
        case "start":
            startCapture(windowId: windowId, params: params, result: result)
        case "stop":
            stopCapture(windowId: windowId, result: result)
        case "getTextureId":
            getTextureId(windowId: windowId, result: result)
        default:
            result(FlutterError(code: "UNKNOWN_COMMAND", message: "Unknown backgroundCapture command: \(command)", details: nil))
        }
    }

    // MARK: - Permission

    private func checkPermission(result: @escaping FlutterResult) {
        // Use CGPreflightScreenCaptureAccess for reliable permission check (macOS 10.15+)
        if CGPreflightScreenCaptureAccess() {
            result("granted")
        } else {
            result("denied")
        }
    }

    private func requestPermission(result: @escaping FlutterResult) {
        // CGRequestScreenCaptureAccess triggers the permission prompt or opens Settings
        let granted = CGRequestScreenCaptureAccess()
        if granted {
            result("granted")
        } else {
            result("pending")
        }
    }

    // MARK: - Start Capture

    private func startCapture(windowId: String?, params: [String: Any], result: @escaping FlutterResult) {
        startCapture(windowId: windowId, params: params, textureRegistry: nil, result: result)
    }

    /// Start capture with optional custom texture registry (for palette engine textures).
    func startCapture(windowId: String?, params: [String: Any], textureRegistry: FlutterTextureRegistry?, result: @escaping FlutterResult) {
        guard let paletteId = windowId else {
            result(FlutterError(code: "MISSING_ID", message: "Palette ID required", details: nil))
            return
        }

        guard let window = store.get(paletteId) else {
            result(FlutterError(code: "NOT_FOUND", message: "Palette \(paletteId) not found", details: nil))
            return
        }

        // Use provided texture registry, or fall back to main registrar's
        guard let textureRegistry = textureRegistry ?? registrar?.textures else {
            result(FlutterError(code: "NO_REGISTRY", message: "Texture registry not available", details: nil))
            return
        }

        // Parse config
        let frameRate = params["frameRate"] as? Int ?? 30
        let pixelRatio = params["pixelRatio"] as? Double ?? 1.0
        let excludeSelf = params["excludeSelf"] as? Bool ?? true
        let paddingTop = params["paddingTop"] as? Double ?? 0
        let paddingRight = params["paddingRight"] as? Double ?? 0
        let paddingBottom = params["paddingBottom"] as? Double ?? 0
        let paddingLeft = params["paddingLeft"] as? Double ?? 0

        let config = CaptureConfig(
            frameRate: frameRate,
            pixelRatio: pixelRatio,
            excludeSelf: excludeSelf,
            padding: NSEdgeInsets(top: paddingTop, left: paddingLeft, bottom: paddingBottom, right: paddingRight)
        )

        // Check if already capturing
        sessionLock.lock()
        if activeSessions[paletteId] != nil {
            sessionLock.unlock()
            result(FlutterError(code: "ALREADY_CAPTURING", message: "Capture already active for \(paletteId)", details: nil))
            return
        }
        sessionLock.unlock()

        // Create texture
        let texture = PixelBufferTexture()
        let textureId = textureRegistry.register(texture)

        // Create session
        let session = CaptureSession(
            paletteId: paletteId,
            window: window,
            texture: texture,
            textureId: textureId,
            textureRegistry: textureRegistry,
            config: config,
            eventSink: eventSink
        )

        sessionLock.lock()
        activeSessions[paletteId] = session
        sessionLock.unlock()

        // Start capture asynchronously
        session.start { [weak self] error in
            if let error = error {
                // Cleanup on failure
                self?.sessionLock.lock()
                self?.activeSessions.removeValue(forKey: paletteId)
                self?.sessionLock.unlock()
                textureRegistry.unregisterTexture(textureId)

                result(FlutterError(code: "START_FAILED", message: error.localizedDescription, details: nil))
            } else {
                // Send event with texture ID
                self?.eventSink?("backgroundCapture", "started", paletteId, ["textureId": textureId])
                result(textureId)
            }
        }
    }

    // MARK: - Stop Capture

    private func stopCapture(windowId: String?, result: @escaping FlutterResult) {
        guard let paletteId = windowId else {
            result(FlutterError(code: "MISSING_ID", message: "Palette ID required", details: nil))
            return
        }

        sessionLock.lock()
        guard let session = activeSessions.removeValue(forKey: paletteId) else {
            sessionLock.unlock()
            result(FlutterError(code: "NOT_CAPTURING", message: "No active capture for \(paletteId)", details: nil))
            return
        }
        sessionLock.unlock()

        session.stop()

        // Unregister texture
        if let registry = registrar?.textures {
            registry.unregisterTexture(session.textureId)
        }

        eventSink?("backgroundCapture", "stopped", paletteId, [:])
        result(nil)
    }

    // MARK: - Get Texture ID

    private func getTextureId(windowId: String?, result: @escaping FlutterResult) {
        guard let paletteId = windowId else {
            result(FlutterError(code: "MISSING_ID", message: "Palette ID required", details: nil))
            return
        }

        sessionLock.lock()
        let session = activeSessions[paletteId]
        sessionLock.unlock()

        if let session = session {
            result(session.textureId)
        } else {
            result(nil)
        }
    }

    // MARK: - Cleanup

    func cleanup() {
        sessionLock.lock()
        let sessions = activeSessions
        activeSessions.removeAll()
        sessionLock.unlock()

        for (_, session) in sessions {
            session.stop()
            if let registry = registrar?.textures {
                registry.unregisterTexture(session.textureId)
            }
        }
    }
}

// MARK: - Supporting Types

struct CaptureConfig {
    let frameRate: Int
    let pixelRatio: Double
    let excludeSelf: Bool
    let padding: NSEdgeInsets
}

/// Manages a single capture session for one palette window.
class CaptureSession {
    let paletteId: String
    let window: PaletteWindow
    let texture: PixelBufferTexture
    let textureId: Int64
    let textureRegistry: FlutterTextureRegistry
    let config: CaptureConfig
    let eventSink: ((String, String, String?, [String: Any]) -> Void)?

    private var provider: CaptureProvider?
    private var isRunning = false

    init(paletteId: String, window: PaletteWindow, texture: PixelBufferTexture, textureId: Int64, textureRegistry: FlutterTextureRegistry, config: CaptureConfig, eventSink: ((String, String, String?, [String: Any]) -> Void)?) {
        self.paletteId = paletteId
        self.window = window
        self.texture = texture
        self.textureId = textureId
        self.textureRegistry = textureRegistry
        self.config = config
        self.eventSink = eventSink
    }

    func start(completion: @escaping (Error?) -> Void) {
        guard !isRunning else {
            completion(nil)
            return
        }

        isRunning = true

        // Choose provider based on macOS version
        if #available(macOS 12.3, *) {
            provider = ScreenCaptureKitProvider(session: self)
        } else {
            provider = CGWindowCaptureProvider(session: self)
        }

        provider?.start(completion: completion)
    }

    func stop() {
        isRunning = false
        provider?.stop()
        provider = nil
    }

    /// Called by provider when a new frame is captured.
    func handleFrame(_ pixelBuffer: CVPixelBuffer) {
        texture.updateBuffer(pixelBuffer)
        textureRegistry.textureFrameAvailable(textureId)
    }

    /// Get the capture region (window frame with padding).
    func getCaptureRect() -> CGRect {
        let frame = window.panel.frame
        let padding = config.padding

        return CGRect(
            x: frame.origin.x - padding.left,
            y: frame.origin.y - padding.bottom,
            width: frame.width + padding.left + padding.right,
            height: frame.height + padding.top + padding.bottom
        )
    }
}

/// Protocol for capture providers (ScreenCaptureKit or CGWindowList).
protocol CaptureProvider {
    func start(completion: @escaping (Error?) -> Void)
    func stop()
}
