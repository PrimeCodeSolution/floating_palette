import Cocoa
import os.log
import ScreenCaptureKit

/// Capture provider using ScreenCaptureKit (macOS 12.3+).
/// Provides efficient, GPU-accelerated screen capture with automatic window exclusion.
@available(macOS 12.3, *)
class ScreenCaptureKitProvider: NSObject, CaptureProvider, SCStreamDelegate, SCStreamOutput {
    private weak var session: CaptureSession?
    private var stream: SCStream?
    private var filter: SCContentFilter?

    /// Timer to periodically update the capture rect when window moves
    private var updateTimer: Timer?

    init(session: CaptureSession) {
        self.session = session
        super.init()
    }

    func start(completion: @escaping (Error?) -> Void) {
        guard let session = session else {
            completion(NSError(domain: "BackgroundCapture", code: -1, userInfo: [NSLocalizedDescriptionKey: "Session deallocated"]))
            return
        }

        // Get shareable content
        SCShareableContent.getExcludingDesktopWindows(false, onScreenWindowsOnly: true) { [weak self] content, error in
            guard let self = self, let content = content else {
                let err = error ?? NSError(domain: "BackgroundCapture", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to get shareable content"])
                DispatchQueue.main.async { completion(err) }
                return
            }

            DispatchQueue.main.async {
                self.setupStream(content: content, session: session, completion: completion)
            }
        }
    }

    private func setupStream(content: SCShareableContent, session: CaptureSession, completion: @escaping (Error?) -> Void) {
        // Find the display containing the window
        let windowFrame = session.window.panel.frame
        let windowCenter = NSPoint(x: windowFrame.midX, y: windowFrame.midY)

        guard let display = content.displays.first(where: { display in
            NSRect(x: CGFloat(display.frame.origin.x),
                   y: CGFloat(display.frame.origin.y),
                   width: CGFloat(display.frame.width),
                   height: CGFloat(display.frame.height)).contains(windowCenter)
        }) ?? content.displays.first else {
            completion(NSError(domain: "BackgroundCapture", code: -1, userInfo: [NSLocalizedDescriptionKey: "No display found"]))
            return
        }

        // Build exclusion list
        var excludedWindows: [SCWindow] = []
        if session.config.excludeSelf {
            // Find our window in the list
            let ourWindowNumber = session.window.panel.windowNumber
            if let ourWindow = content.windows.first(where: { $0.windowID == CGWindowID(ourWindowNumber) }) {
                excludedWindows.append(ourWindow)
            }
        }

        // Create filter - capture entire display excluding our window
        let filter = SCContentFilter(display: display, excludingWindows: excludedWindows)
        self.filter = filter

        // Configure stream
        let captureRect = session.getCaptureRect()
        let config = SCStreamConfiguration()

        // Set capture size based on config
        let scaledWidth = Int(captureRect.width * session.config.pixelRatio)
        let scaledHeight = Int(captureRect.height * session.config.pixelRatio)
        config.width = scaledWidth
        config.height = scaledHeight

        // Set frame rate
        config.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(session.config.frameRate))

        // Set source rect (the region of the display to capture)
        // Convert from bottom-left (AppKit) to top-left (ScreenCaptureKit) coordinates
        let displayHeight = CGFloat(display.height)
        let sourceRect = CGRect(
            x: captureRect.origin.x - CGFloat(display.frame.origin.x),
            y: displayHeight - captureRect.origin.y - captureRect.height + CGFloat(display.frame.origin.y),
            width: captureRect.width,
            height: captureRect.height
        )
        config.sourceRect = sourceRect

        // Performance settings
        config.queueDepth = 3  // Triple buffering
        config.showsCursor = false
        config.pixelFormat = kCVPixelFormatType_32BGRA

        // Create stream
        do {
            let stream = SCStream(filter: filter, configuration: config, delegate: self)
            self.stream = stream

            // Add output
            try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: .global(qos: .userInteractive))

            // Start capture
            stream.startCapture { error in
                if let error = error {
                    os_log("start capture error: %{public}@", log: Log.capture, type: .error, error.localizedDescription)
                    completion(error)
                } else {
                    os_log("capture started", log: Log.capture, type: .info)
                    completion(nil)

                    // Start timer to update capture rect when window moves
                    DispatchQueue.main.async { [weak self] in
                        self?.startUpdateTimer()
                    }
                }
            }
        } catch {
            os_log("failed to create stream: %{public}@", log: Log.capture, type: .error, error.localizedDescription)
            completion(error)
        }
    }

    func stop() {
        os_log("stopping capture", log: Log.capture, type: .debug)

        updateTimer?.invalidate()
        updateTimer = nil

        stream?.stopCapture { error in
            if let error = error {
                os_log("stop error: %{public}@", log: Log.capture, type: .error, error.localizedDescription)
            }
        }
        stream = nil
    }

    // MARK: - SCStreamOutput

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen else { return }

        // Extract pixel buffer from sample buffer
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }

        // Pass to session
        session?.handleFrame(pixelBuffer)
    }

    // MARK: - SCStreamDelegate

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        os_log("stream stopped with error: %{public}@", log: Log.capture, type: .error, error.localizedDescription)
        session?.eventSink?("backgroundCapture", "error", session?.paletteId, ["error": error.localizedDescription])
    }

    // MARK: - Update Timer

    private func startUpdateTimer() {
        // Update capture rect periodically (in case window moves)
        updateTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.updateCaptureRect()
        }
    }

    private func updateCaptureRect() {
        guard let session = session, let stream = stream else { return }

        let captureRect = session.getCaptureRect()

        // Get current display
        SCShareableContent.getExcludingDesktopWindows(false, onScreenWindowsOnly: true) { content, _ in
            guard let content = content else { return }

            let windowCenter = NSPoint(x: captureRect.midX, y: captureRect.midY)
            guard let display = content.displays.first(where: { display in
                NSRect(x: CGFloat(display.frame.origin.x),
                       y: CGFloat(display.frame.origin.y),
                       width: CGFloat(display.frame.width),
                       height: CGFloat(display.frame.height)).contains(windowCenter)
            }) else { return }

            DispatchQueue.main.async {
                // Update configuration with new source rect
                let config = SCStreamConfiguration()

                let scaledWidth = Int(captureRect.width * session.config.pixelRatio)
                let scaledHeight = Int(captureRect.height * session.config.pixelRatio)
                config.width = scaledWidth
                config.height = scaledHeight
                config.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(session.config.frameRate))

                let displayHeight = CGFloat(display.height)
                let sourceRect = CGRect(
                    x: captureRect.origin.x - CGFloat(display.frame.origin.x),
                    y: displayHeight - captureRect.origin.y - captureRect.height + CGFloat(display.frame.origin.y),
                    width: captureRect.width,
                    height: captureRect.height
                )
                config.sourceRect = sourceRect
                config.queueDepth = 3
                config.showsCursor = false
                config.pixelFormat = kCVPixelFormatType_32BGRA

                // Update stream configuration
                stream.updateConfiguration(config) { error in
                    if let error = error {
                        os_log("failed to update config: %{public}@", log: Log.capture, type: .error, error.localizedDescription)
                    }
                }
            }
        }
    }
}
