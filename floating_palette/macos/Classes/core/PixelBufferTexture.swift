import Cocoa
import FlutterMacOS
import CoreVideo

/// A FlutterTexture implementation that wraps a CVPixelBuffer.
/// Used to stream captured screen content to Flutter.
class PixelBufferTexture: NSObject, FlutterTexture {
    /// The current pixel buffer to be displayed.
    /// Thread-safe access via lock.
    private var currentBuffer: CVPixelBuffer?
    private let bufferLock = NSLock()

    /// Update the pixel buffer with new content.
    /// Called from the capture provider when a new frame is available.
    func updateBuffer(_ buffer: CVPixelBuffer) {
        bufferLock.lock()
        defer { bufferLock.unlock() }

        // Retain the new buffer (CVPixelBuffer is reference counted)
        currentBuffer = buffer
    }

    /// Called by Flutter when it needs to render the texture.
    /// Returns the current pixel buffer, or nil if none available.
    func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
        bufferLock.lock()
        defer { bufferLock.unlock() }

        guard let buffer = currentBuffer else {
            return nil
        }

        // Return retained reference - Flutter will release when done
        return Unmanaged.passRetained(buffer)
    }

    /// Clear the current buffer.
    func clear() {
        bufferLock.lock()
        defer { bufferLock.unlock() }
        currentBuffer = nil
    }
}
