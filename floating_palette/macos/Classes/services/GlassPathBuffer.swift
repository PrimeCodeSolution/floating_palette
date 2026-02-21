import Foundation

// MARK: - Shared Memory Buffer

/// Helper for reading the shared memory buffer from Flutter.
/// Uses raw memory access with computed offsets instead of massive tuple structs.
///
/// Memory layout (packed with @Packed(1) in Dart - NO alignment padding):
/// - frameId: 8 bytes (UInt64) at offset 0
/// - commandCount: 4 bytes (UInt32) at offset 8
/// - commands: 1024 bytes (1024 x UInt8) at offset 12
/// - pointCount: 4 bytes (UInt32) at offset 1036
/// - points: 8192 bytes (2048 x Float) at offset 1040
/// - windowHeight: 4 bytes (Float) at offset 9232
/// - frameIdPost: 8 bytes (UInt64) at offset 9236 (NOT aligned - use memcpy!)
///
/// Total: 9244 bytes (packed, no padding)
/// Supports up to 1024 path commands and 2048 floats (1024 points).
struct GlassPathBufferReader {
    // Computed offsets for packed struct (no alignment padding)
    static let frameIdOffset = 0
    static let commandCountOffset = 8
    static let commandsOffset = 12
    static let pointCountOffset = 1036  // 12 + 1024
    static let pointsOffset = 1040      // 1036 + 4
    static let windowHeightOffset = 9232  // 1040 + (2048 * 4)
    static let frameIdPostOffset = 9236   // 9232 + 4 (no padding - packed!)
    static let totalSize = 9244           // 9236 + 8

    let pointer: UnsafeRawPointer

    init(_ ptr: UnsafeRawPointer) {
        self.pointer = ptr
    }

    // frameId is at offset 0 which is 8-byte aligned, so direct load is safe
    var frameId: UInt64 {
        pointer.load(fromByteOffset: Self.frameIdOffset, as: UInt64.self)
    }

    var commandCount: UInt32 {
        pointer.load(fromByteOffset: Self.commandCountOffset, as: UInt32.self)
    }

    var pointCount: UInt32 {
        pointer.load(fromByteOffset: Self.pointCountOffset, as: UInt32.self)
    }

    var windowHeight: Float {
        pointer.load(fromByteOffset: Self.windowHeightOffset, as: Float.self)
    }

    // frameIdPost is at offset 9236 which is NOT 8-byte aligned
    // Must use unaligned read (memcpy) to avoid crash
    var frameIdPost: UInt64 {
        var value: UInt64 = 0
        withUnsafeMutableBytes(of: &value) { dest in
            let src = pointer.advanced(by: Self.frameIdPostOffset)
            dest.copyMemory(from: UnsafeRawBufferPointer(start: src, count: 8))
        }
        return value
    }

    /// Get command at index (0-1023)
    func getCommand(at index: Int) -> UInt8 {
        guard index >= 0 && index < 1024 else { return 0 }
        return pointer.load(fromByteOffset: Self.commandsOffset + index, as: UInt8.self)
    }

    /// Get point (float) at index (0-2047)
    /// Points array is at offset 1040 which is 4-byte aligned, Float requires 4-byte alignment, so this is safe
    func getPoint(at index: Int) -> Float {
        guard index >= 0 && index < 2048 else { return 0 }
        return pointer.load(fromByteOffset: Self.pointsOffset + index * MemoryLayout<Float>.size, as: Float.self)
    }
}

// MARK: - Buffer Allocation

extension GlassPathBufferReader {
    /// Allocate a zeroed buffer suitable for GlassPathBufferReader.
    static func allocateBuffer() -> UnsafeMutableRawPointer {
        let ptr = UnsafeMutableRawPointer.allocate(
            byteCount: totalSize,
            alignment: MemoryLayout<UInt64>.alignment
        )
        ptr.initializeMemory(as: UInt8.self, repeating: 0, count: totalSize)
        return ptr
    }
}
