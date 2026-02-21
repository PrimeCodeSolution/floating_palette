import Cocoa
import CoreVideo
import os.log

/// Fallback capture provider using CGWindowListCreateImage.
/// Works on all macOS versions but is less efficient than ScreenCaptureKit.
class CGWindowCaptureProvider: CaptureProvider {
    private weak var session: CaptureSession?
    private var captureTimer: Timer?
    private var pixelBufferPool: CVPixelBufferPool?
    private var isRunning = false

    init(session: CaptureSession) {
        self.session = session
    }

    func start(completion: @escaping (Error?) -> Void) {
        guard let session = session else {
            completion(NSError(domain: "BackgroundCapture", code: -1, userInfo: [NSLocalizedDescriptionKey: "Session deallocated"]))
            return
        }

        isRunning = true

        // Create pixel buffer pool for efficient buffer reuse
        let captureRect = session.getCaptureRect()
        let width = Int(captureRect.width * session.config.pixelRatio)
        let height = Int(captureRect.height * session.config.pixelRatio)

        let poolAttributes: [String: Any] = [
            kCVPixelBufferPoolMinimumBufferCountKey as String: 3
        ]

        let pixelBufferAttributes: [String: Any] = [
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:],
            kCVPixelBufferMetalCompatibilityKey as String: true
        ]

        var pool: CVPixelBufferPool?
        let status = CVPixelBufferPoolCreate(
            kCFAllocatorDefault,
            poolAttributes as CFDictionary,
            pixelBufferAttributes as CFDictionary,
            &pool
        )

        if status != kCVReturnSuccess {
            completion(NSError(domain: "BackgroundCapture", code: Int(status), userInfo: [NSLocalizedDescriptionKey: "Failed to create pixel buffer pool"]))
            return
        }

        pixelBufferPool = pool

        // Start capture timer
        let interval = 1.0 / Double(session.config.frameRate)
        DispatchQueue.main.async { [weak self] in
            self?.captureTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
                self?.captureFrame()
            }
            // Fire immediately for first frame
            self?.captureFrame()
        }

        os_log("capture started at %d fps", log: Log.capture, type: .info, session.config.frameRate)
        completion(nil)
    }

    func stop() {
        os_log("stopping capture (CGWindowList)", log: Log.capture, type: .debug)
        isRunning = false

        captureTimer?.invalidate()
        captureTimer = nil
        pixelBufferPool = nil
    }

    private func captureFrame() {
        guard isRunning, let session = session, let pool = pixelBufferPool else { return }

        let captureRect = session.getCaptureRect()

        // Build window list options
        var windowListOption: CGWindowListOption = [.optionOnScreenOnly]

        // Get the window ID to exclude
        var excludeWindowID: CGWindowID = 0
        if session.config.excludeSelf {
            excludeWindowID = CGWindowID(session.window.panel.windowNumber)
            // Capture everything below our window
            windowListOption = [.optionOnScreenBelowWindow]
        }

        // Capture the screen region
        // CGWindowListCreateImage uses top-left origin, so we need to convert
        guard let mainScreen = NSScreen.main else { return }
        let screenHeight = mainScreen.frame.height

        let cgRect = CGRect(
            x: captureRect.origin.x,
            y: screenHeight - captureRect.origin.y - captureRect.height,
            width: captureRect.width,
            height: captureRect.height
        )

        guard let cgImage = CGWindowListCreateImage(
            cgRect,
            windowListOption,
            excludeWindowID,
            [.bestResolution]
        ) else {
            return
        }

        // Convert CGImage to CVPixelBuffer
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &pixelBuffer)

        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            return
        }

        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: CVPixelBufferGetWidth(buffer),
            height: CVPixelBufferGetHeight(buffer),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ) else {
            return
        }

        // Scale image to fit buffer if needed
        let bufferWidth = CVPixelBufferGetWidth(buffer)
        let bufferHeight = CVPixelBufferGetHeight(buffer)
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: bufferWidth, height: bufferHeight))

        // Pass to session
        session.handleFrame(buffer)
    }
}
