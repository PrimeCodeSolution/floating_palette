import Cocoa
import QuartzCore
import os.log

// MARK: - Animation Buffer Reader

/// Helper for reading the shared animation buffer from Flutter.
/// Uses raw memory access with computed offsets.
///
/// Memory layout (packed with @Packed(1) in Dart):
/// - animationId: 8 bytes (UInt64) at offset 0
/// - isAnimating: 1 byte (UInt8) at offset 8
/// - curveType: 1 byte (UInt8) at offset 9
/// - _padding: 2 bytes at offset 10
/// - startX: 4 bytes (Float) at offset 12
/// - startY: 4 bytes (Float) at offset 16
/// - startWidth: 4 bytes (Float) at offset 20
/// - startHeight: 4 bytes (Float) at offset 24
/// - targetX: 4 bytes (Float) at offset 28
/// - targetY: 4 bytes (Float) at offset 32
/// - targetWidth: 4 bytes (Float) at offset 36
/// - targetHeight: 4 bytes (Float) at offset 40
/// - cornerRadius: 4 bytes (Float) at offset 44
/// - startTime: 8 bytes (Double) at offset 48
/// - duration: 8 bytes (Double) at offset 56
/// - windowHeight: 4 bytes (Float) at offset 64
/// - _padding2: 4 bytes at offset 68
/// - animationIdPost: 8 bytes (UInt64) at offset 72
///
/// Total: 80 bytes
struct GlassAnimationBufferReader {
    static let animationIdOffset = 0
    static let isAnimatingOffset = 8
    static let curveTypeOffset = 9
    static let startXOffset = 12
    static let startYOffset = 16
    static let startWidthOffset = 20
    static let startHeightOffset = 24
    static let targetXOffset = 28
    static let targetYOffset = 32
    static let targetWidthOffset = 36
    static let targetHeightOffset = 40
    static let cornerRadiusOffset = 44
    static let startTimeOffset = 48
    static let durationOffset = 56
    static let windowHeightOffset = 64
    static let animationIdPostOffset = 72
    static let totalSize = 80

    let pointer: UnsafeRawPointer

    init(_ ptr: UnsafeRawPointer) {
        self.pointer = ptr
    }

    var animationId: UInt64 {
        pointer.load(fromByteOffset: Self.animationIdOffset, as: UInt64.self)
    }

    var isAnimating: Bool {
        pointer.load(fromByteOffset: Self.isAnimatingOffset, as: UInt8.self) != 0
    }

    var curveType: UInt8 {
        pointer.load(fromByteOffset: Self.curveTypeOffset, as: UInt8.self)
    }

    var startX: Float {
        pointer.load(fromByteOffset: Self.startXOffset, as: Float.self)
    }

    var startY: Float {
        pointer.load(fromByteOffset: Self.startYOffset, as: Float.self)
    }

    var startWidth: Float {
        pointer.load(fromByteOffset: Self.startWidthOffset, as: Float.self)
    }

    var startHeight: Float {
        pointer.load(fromByteOffset: Self.startHeightOffset, as: Float.self)
    }

    var targetX: Float {
        pointer.load(fromByteOffset: Self.targetXOffset, as: Float.self)
    }

    var targetY: Float {
        pointer.load(fromByteOffset: Self.targetYOffset, as: Float.self)
    }

    var targetWidth: Float {
        pointer.load(fromByteOffset: Self.targetWidthOffset, as: Float.self)
    }

    var targetHeight: Float {
        pointer.load(fromByteOffset: Self.targetHeightOffset, as: Float.self)
    }

    var cornerRadius: Float {
        pointer.load(fromByteOffset: Self.cornerRadiusOffset, as: Float.self)
    }

    var startTime: Double {
        pointer.load(fromByteOffset: Self.startTimeOffset, as: Double.self)
    }

    var duration: Double {
        pointer.load(fromByteOffset: Self.durationOffset, as: Double.self)
    }

    var windowHeight: Float {
        pointer.load(fromByteOffset: Self.windowHeightOffset, as: Float.self)
    }

    // animationIdPost may not be 8-byte aligned, use memcpy
    var animationIdPost: UInt64 {
        var value: UInt64 = 0
        withUnsafeMutableBytes(of: &value) { dest in
            let src = pointer.advanced(by: Self.animationIdPostOffset)
            dest.copyMemory(from: UnsafeRawBufferPointer(start: src, count: 8))
        }
        return value
    }
}

// MARK: - Animation Curve

/// Animation curve types matching Dart GlassAnimationCurve enum.
enum GlassAnimationCurve: UInt8 {
    case linear = 0
    case easeOut = 1
    case easeOutCubic = 2
    case easeInOut = 3

    /// Apply easing curve to normalized progress (0-1).
    func apply(_ t: Double) -> Double {
        switch self {
        case .linear:
            return t
        case .easeOut:
            // 1 - (1-t)^2
            let oneMinusT = 1.0 - t
            return 1.0 - oneMinusT * oneMinusT
        case .easeOutCubic:
            // 1 - (1-t)^3
            let oneMinusT = 1.0 - t
            return 1.0 - oneMinusT * oneMinusT * oneMinusT
        case .easeInOut:
            // t < 0.5 ? 2t^2 : 1 - (-2t+2)^2/2
            if t < 0.5 {
                return 2.0 * t * t
            } else {
                let v = -2.0 * t + 2.0
                return 1.0 - v * v / 2.0
            }
        }
    }
}

// MARK: - Interpolated Result

/// Result of reading animated bounds from the animation driver.
struct AnimatedBoundsResult {
    let bounds: CGRect
    let cornerRadius: CGFloat
    let isComplete: Bool  // Animation finished, native can cache
}

// MARK: - Glass Animation Driver

/// Native animation driver for glass effects.
///
/// Reads animation parameters from shared memory (written by Dart once per animation)
/// and interpolates bounds at display refresh rate (60-120Hz) for perfect VSync sync.
///
/// This eliminates per-frame FFI calls (~30/sec) during animations, reducing latency
/// from 8-16ms to <1ms.
final class GlassAnimationDriver {
    static let shared = GlassAnimationDriver()

    /// Animation buffers per window ID and layer ID.
    private var buffers: [String: [Int: UnsafeMutableRawPointer]] = [:]

    /// Last processed animation IDs per window/layer (for change detection).
    private var lastAnimationIds: [String: [Int: UInt64]] = [:]

    /// Last applied bounds per window/layer (for static caching).
    private var lastBounds: [String: [Int: (CGRect, CGFloat)]] = [:]

    private let lock = NSLock()

    private init() {}

    // MARK: - Buffer Management

    /// Create an animation buffer for a window and layer.
    /// Returns pointer that Flutter can write animation data to.
    func createBuffer(windowId: String, layerId: Int) -> UnsafeMutableRawPointer {
        lock.lock()
        defer { lock.unlock() }

        var windowBuffers = buffers[windowId] ?? [:]
        if let existing = windowBuffers[layerId] {
            existing.deallocate()
        }

        let ptr = UnsafeMutableRawPointer.allocate(
            byteCount: GlassAnimationBufferReader.totalSize,
            alignment: MemoryLayout<UInt64>.alignment
        )
        ptr.initializeMemory(as: UInt8.self, repeating: 0, count: GlassAnimationBufferReader.totalSize)
        windowBuffers[layerId] = ptr
        buffers[windowId] = windowBuffers

        os_log("animation buffer created windowId=%{public}@ layerId=%d",
               log: Log.glass, type: .debug, windowId, layerId)

        return ptr
    }

    /// Destroy the animation buffer for a window and layer.
    func destroyBuffer(windowId: String, layerId: Int) {
        lock.lock()
        defer { lock.unlock() }

        if var windowBuffers = buffers[windowId],
           let ptr = windowBuffers.removeValue(forKey: layerId) {
            ptr.deallocate()
            if windowBuffers.isEmpty {
                buffers.removeValue(forKey: windowId)
            } else {
                buffers[windowId] = windowBuffers
            }
        }

        lastAnimationIds[windowId]?.removeValue(forKey: layerId)
        lastBounds[windowId]?.removeValue(forKey: layerId)

        if lastAnimationIds[windowId]?.isEmpty == true {
            lastAnimationIds.removeValue(forKey: windowId)
        }
        if lastBounds[windowId]?.isEmpty == true {
            lastBounds.removeValue(forKey: windowId)
        }
    }

    /// Destroy all animation buffers for a window.
    func destroyAllBuffers(windowId: String) {
        lock.lock()
        let layerIds = Array((buffers[windowId] ?? [:]).keys)
        lock.unlock()

        for layerId in layerIds {
            destroyBuffer(windowId: windowId, layerId: layerId)
        }
    }

    /// Check if an animation buffer exists for a window and layer.
    func hasBuffer(windowId: String, layerId: Int) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return buffers[windowId]?[layerId] != nil
    }

    // MARK: - Animation Reading

    /// Read interpolated bounds from animation buffer.
    ///
    /// Called from GlassMaskService's display link at 60-120Hz.
    ///
    /// Returns:
    /// - Interpolated bounds if animation is active
    /// - Static bounds if not animating but buffer has data
    /// - nil if buffer doesn't exist or has no data
    func readAnimatedBounds(windowId: String, layerId: Int) -> AnimatedBoundsResult? {
        lock.lock()
        guard let ptr = buffers[windowId]?[layerId] else {
            lock.unlock()
            return nil
        }
        let lastId = lastAnimationIds[windowId]?[layerId] ?? 0
        let cachedBounds = lastBounds[windowId]?[layerId]
        lock.unlock()

        let buffer = GlassAnimationBufferReader(ptr)

        // Check for torn write
        let preId = buffer.animationId
        let postId = buffer.animationIdPost
        guard preId == postId, preId > 0 else {
            // No valid data yet, return cached if available
            if let cached = cachedBounds {
                return AnimatedBoundsResult(
                    bounds: cached.0,
                    cornerRadius: cached.1,
                    isComplete: true
                )
            }
            return nil
        }

        // Check if animation ID changed
        let isNewAnimation = preId != lastId

        if isNewAnimation {
            lock.lock()
            var windowIds = lastAnimationIds[windowId] ?? [:]
            windowIds[layerId] = preId
            lastAnimationIds[windowId] = windowIds
            lock.unlock()
        }

        let cornerRadius = CGFloat(buffer.cornerRadius)
        // windowHeight is stored in buffer but not needed for native interpolation
        // (Y-flip happens in SwiftUI which uses Y=0 at top like Flutter)

        // Not animating - return static target bounds
        if !buffer.isAnimating {
            let bounds = CGRect(
                x: CGFloat(buffer.targetX),
                y: CGFloat(buffer.targetY),
                width: CGFloat(buffer.targetWidth),
                height: CGFloat(buffer.targetHeight)
            )

            // Cache for next frame
            lock.lock()
            var windowBounds = lastBounds[windowId] ?? [:]
            windowBounds[layerId] = (bounds, cornerRadius)
            lastBounds[windowId] = windowBounds
            lock.unlock()

            return AnimatedBoundsResult(
                bounds: bounds,
                cornerRadius: cornerRadius,
                isComplete: true
            )
        }

        // Animation is active - interpolate
        let currentTime = CACurrentMediaTime()
        let startTime = buffer.startTime
        let duration = buffer.duration

        // Calculate raw progress
        var progress = duration > 0 ? (currentTime - startTime) / duration : 1.0
        let isComplete = progress >= 1.0
        progress = min(1.0, max(0.0, progress))

        // Apply easing curve
        let curve = GlassAnimationCurve(rawValue: buffer.curveType) ?? .easeOutCubic
        let easedProgress = curve.apply(progress)

        // Interpolate bounds
        let startX = CGFloat(buffer.startX)
        let startY = CGFloat(buffer.startY)
        let startWidth = CGFloat(buffer.startWidth)
        let startHeight = CGFloat(buffer.startHeight)
        let targetX = CGFloat(buffer.targetX)
        let targetY = CGFloat(buffer.targetY)
        let targetWidth = CGFloat(buffer.targetWidth)
        let targetHeight = CGFloat(buffer.targetHeight)

        let interpolatedBounds = CGRect(
            x: startX + (targetX - startX) * easedProgress,
            y: startY + (targetY - startY) * easedProgress,
            width: startWidth + (targetWidth - startWidth) * easedProgress,
            height: startHeight + (targetHeight - startHeight) * easedProgress
        )

        // Cache final bounds when complete
        if isComplete {
            lock.lock()
            var windowBounds = lastBounds[windowId] ?? [:]
            windowBounds[layerId] = (interpolatedBounds, cornerRadius)
            lastBounds[windowId] = windowBounds
            lock.unlock()
        }

        return AnimatedBoundsResult(
            bounds: interpolatedBounds,
            cornerRadius: cornerRadius,
            isComplete: isComplete
        )
    }

    // MARK: - Cleanup

    /// Clean up all resources.
    func cleanup(windowId: String) {
        destroyAllBuffers(windowId: windowId)
    }
}
