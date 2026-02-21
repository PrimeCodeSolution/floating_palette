import Cocoa

/// FFI Interface for synchronous Dart-to-native calls.
///
/// These functions are exposed via @_cdecl for direct FFI access from Dart.
/// They provide synchronous operations critical for flicker-free UX:
/// - Window resizing (SizeReporter)
/// - Cursor position queries
/// - Screen bounds queries
/// - Active app bounds queries
///
/// IMPORTANT: Keep function signatures in sync with src/ffi_interface.h

// MARK: - Window Sizing

/// Resize a palette window synchronously.
/// Called by SizeReporter when content size changes.
///
/// Implements "show-after-sized" pattern:
/// - If window.isPendingReveal is true, this is the first resize after show
/// - After resizing, trigger reveal to enable keyboard focus and send "shown" event
@_cdecl("FloatingPalette_ResizeWindow")
public func FloatingPalette_ResizeWindow(
    windowId: UnsafePointer<CChar>,
    width: Double,
    height: Double
) {
    let id = String(cString: windowId)

    DispatchQueue.main.async {
        guard let window = WindowStore.shared.get(id) else {
            return
        }

        let panel = window.panel
        var frame = panel.frame

        // Skip if size hasn't changed meaningfully (within 1 pixel)
        let widthDiff = abs(width - Double(frame.width))
        let heightDiff = abs(height - Double(frame.height))

        if widthDiff < 1 && heightDiff < 1 {
            // Size unchanged, but still trigger reveal if pending
            if window.isPendingReveal {
                VisibilityService.shared?.reveal(windowId: id)
            }
            return
        }

        // Resize from top-left (keep origin, adjust for height change)
        let heightChange = height - Double(frame.height)
        frame.origin.y -= heightChange
        frame.size.width = width
        frame.size.height = height

        panel.setFrame(frame, display: true)

        // Trigger reveal if this is the first resize after show
        // This enables keyboard focus and sends the "shown" event
        if window.isPendingReveal {
            VisibilityService.shared?.reveal(windowId: id)
        }
    }
}

/// Get the current frame (position and size) of a palette window.
@_cdecl("FloatingPalette_GetWindowFrame")
public func FloatingPalette_GetWindowFrame(
    windowId: UnsafePointer<CChar>,
    outX: UnsafeMutablePointer<Double>,
    outY: UnsafeMutablePointer<Double>,
    outWidth: UnsafeMutablePointer<Double>,
    outHeight: UnsafeMutablePointer<Double>
) -> Bool {
    let id = String(cString: windowId)

    guard let window = WindowStore.shared.get(id) else {
        return false
    }

    let frame = window.panel.frame
    outX.pointee = Double(frame.origin.x)
    outY.pointee = Double(frame.origin.y)
    outWidth.pointee = Double(frame.width)
    outHeight.pointee = Double(frame.height)

    return true
}

/// Check if a palette window is currently visible.
@_cdecl("FloatingPalette_IsWindowVisible")
public func FloatingPalette_IsWindowVisible(
    windowId: UnsafePointer<CChar>
) -> Bool {
    let id = String(cString: windowId)

    guard let window = WindowStore.shared.get(id) else {
        return false
    }

    return window.panel.isVisible
}

// MARK: - Cursor Position

/// Get the current cursor (mouse) position in screen coordinates.
@_cdecl("FloatingPalette_GetCursorPosition")
public func FloatingPalette_GetCursorPosition(
    outX: UnsafeMutablePointer<Double>,
    outY: UnsafeMutablePointer<Double>
) {
    let mouseLocation = NSEvent.mouseLocation
    outX.pointee = Double(mouseLocation.x)
    outY.pointee = Double(mouseLocation.y)
}

/// Get the screen index where the cursor is currently located.
@_cdecl("FloatingPalette_GetCursorScreen")
public func FloatingPalette_GetCursorScreen() -> Int32 {
    let mouseLocation = NSEvent.mouseLocation

    for (index, screen) in NSScreen.screens.enumerated() {
        if screen.frame.contains(mouseLocation) {
            return Int32(index)
        }
    }

    return -1
}

// MARK: - Screen Info

/// Get the number of connected screens/monitors.
@_cdecl("FloatingPalette_GetScreenCount")
public func FloatingPalette_GetScreenCount() -> Int32 {
    return Int32(NSScreen.screens.count)
}

/// Get the full bounds of a screen (including menu bar, dock areas).
@_cdecl("FloatingPalette_GetScreenBounds")
public func FloatingPalette_GetScreenBounds(
    screenIndex: Int32,
    outX: UnsafeMutablePointer<Double>,
    outY: UnsafeMutablePointer<Double>,
    outWidth: UnsafeMutablePointer<Double>,
    outHeight: UnsafeMutablePointer<Double>
) -> Bool {
    let index = Int(screenIndex)
    guard index >= 0 && index < NSScreen.screens.count else {
        return false
    }

    let screen = NSScreen.screens[index]
    let frame = screen.frame

    outX.pointee = Double(frame.origin.x)
    outY.pointee = Double(frame.origin.y)
    outWidth.pointee = Double(frame.width)
    outHeight.pointee = Double(frame.height)

    return true
}

/// Get the visible bounds of a screen (excluding menu bar, dock, taskbar).
@_cdecl("FloatingPalette_GetScreenVisibleBounds")
public func FloatingPalette_GetScreenVisibleBounds(
    screenIndex: Int32,
    outX: UnsafeMutablePointer<Double>,
    outY: UnsafeMutablePointer<Double>,
    outWidth: UnsafeMutablePointer<Double>,
    outHeight: UnsafeMutablePointer<Double>
) -> Bool {
    let index = Int(screenIndex)
    guard index >= 0 && index < NSScreen.screens.count else {
        return false
    }

    let screen = NSScreen.screens[index]
    let visibleFrame = screen.visibleFrame

    outX.pointee = Double(visibleFrame.origin.x)
    outY.pointee = Double(visibleFrame.origin.y)
    outWidth.pointee = Double(visibleFrame.width)
    outHeight.pointee = Double(visibleFrame.height)

    return true
}

/// Get the scale factor (DPI scaling) of a screen.
@_cdecl("FloatingPalette_GetScreenScaleFactor")
public func FloatingPalette_GetScreenScaleFactor(screenIndex: Int32) -> Double {
    let index = Int(screenIndex)
    guard index >= 0 && index < NSScreen.screens.count else {
        return 1.0
    }

    return Double(NSScreen.screens[index].backingScaleFactor)
}

// MARK: - Active Application

/// Get the bounds of the frontmost/active application window.
@_cdecl("FloatingPalette_GetActiveAppBounds")
public func FloatingPalette_GetActiveAppBounds(
    outX: UnsafeMutablePointer<Double>,
    outY: UnsafeMutablePointer<Double>,
    outWidth: UnsafeMutablePointer<Double>,
    outHeight: UnsafeMutablePointer<Double>
) -> Bool {
    guard let frontApp = NSWorkspace.shared.frontmostApplication else {
        return false
    }

    let pid = frontApp.processIdentifier

    // Get windows for the frontmost application
    let options = CGWindowListOption(arrayLiteral: .optionOnScreenOnly, .excludeDesktopElements)
    guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
        return false
    }

    // Find the frontmost window of the active app
    for windowInfo in windowList {
        guard let windowPID = windowInfo[kCGWindowOwnerPID as String] as? Int32,
              windowPID == pid,
              let bounds = windowInfo[kCGWindowBounds as String] as? [String: CGFloat] else {
            continue
        }

        // Note: CGWindow coordinates have Y=0 at top, NSScreen has Y=0 at bottom
        // We return CGWindow coordinates here for consistency with cursor position
        outX.pointee = Double(bounds["X"] ?? 0)
        outY.pointee = Double(bounds["Y"] ?? 0)
        outWidth.pointee = Double(bounds["Width"] ?? 0)
        outHeight.pointee = Double(bounds["Height"] ?? 0)

        return true
    }

    return false
}

/// Get the bundle identifier or process name of the active application.
@_cdecl("FloatingPalette_GetActiveAppIdentifier")
public func FloatingPalette_GetActiveAppIdentifier(
    outBuffer: UnsafeMutablePointer<CChar>,
    bufferSize: Int32
) -> Int32 {
    guard let frontApp = NSWorkspace.shared.frontmostApplication,
          let bundleId = frontApp.bundleIdentifier else {
        return 0
    }

    let cString = bundleId.utf8CString
    let length = min(Int(bufferSize) - 1, cString.count - 1) // -1 for null terminator

    for i in 0..<length {
        outBuffer[i] = cString[i]
    }
    outBuffer[length] = 0 // Null terminator

    return Int32(length)
}

// MARK: - Glass Mask Effect

/// Create a shared path buffer for a palette window.
/// Returns a pointer that Flutter can write path data to.
@_cdecl("FloatingPalette_CreateGlassPathBuffer")
public func FloatingPalette_CreateGlassPathBuffer(
    windowId: UnsafePointer<CChar>
) -> UnsafeMutableRawPointer? {
    let id = String(cString: windowId)
    return GlassMaskService.shared.createBuffer(windowId: id, layerId: 0)
}

/// Create a shared path buffer for a palette window and layer.
@_cdecl("FloatingPalette_CreateGlassPathBufferLayer")
public func FloatingPalette_CreateGlassPathBufferLayer(
    windowId: UnsafePointer<CChar>,
    layerId: Int32
) -> UnsafeMutableRawPointer? {
    let id = String(cString: windowId)
    return GlassMaskService.shared.createBuffer(windowId: id, layerId: Int(layerId))
}

/// Destroy the shared path buffer for a palette window.
@_cdecl("FloatingPalette_DestroyGlassPathBuffer")
public func FloatingPalette_DestroyGlassPathBuffer(
    windowId: UnsafePointer<CChar>
) {
    let id = String(cString: windowId)
    GlassMaskService.shared.destroyBuffer(windowId: id, layerId: 0)
}

/// Destroy the shared path buffer for a palette window and layer.
@_cdecl("FloatingPalette_DestroyGlassPathBufferLayer")
public func FloatingPalette_DestroyGlassPathBufferLayer(
    windowId: UnsafePointer<CChar>,
    layerId: Int32
) {
    let id = String(cString: windowId)
    GlassMaskService.shared.destroyBuffer(windowId: id, layerId: Int(layerId))
}

/// Enable or disable the glass effect for a palette window.
@_cdecl("FloatingPalette_SetGlassEnabled")
public func FloatingPalette_SetGlassEnabled(
    windowId: UnsafePointer<CChar>,
    enabled: Bool
) {
    let id = String(cString: windowId)
    if enabled {
        GlassMaskService.shared.enable(windowId: id)
    } else {
        GlassMaskService.shared.disable(windowId: id)
    }
}

/// Set the blur material for the glass effect.
@_cdecl("FloatingPalette_SetGlassMaterial")
public func FloatingPalette_SetGlassMaterial(
    windowId: UnsafePointer<CChar>,
    material: Int32
) {
    let id = String(cString: windowId)
    GlassMaskService.shared.setMaterial(windowId: id, layerId: 0, material: material)
}

/// Set the blur material for the glass effect for a layer.
@_cdecl("FloatingPalette_SetGlassMaterialLayer")
public func FloatingPalette_SetGlassMaterialLayer(
    windowId: UnsafePointer<CChar>,
    layerId: Int32,
    material: Int32
) {
    let id = String(cString: windowId)
    GlassMaskService.shared.setMaterial(windowId: id, layerId: Int(layerId), material: material)
}

/// Set dark mode for the glass effect.
/// isDark: false = clear glass, true = dark/regular glass
@_cdecl("FloatingPalette_SetGlassDark")
public func FloatingPalette_SetGlassDark(
    windowId: UnsafePointer<CChar>,
    isDark: Bool
) {
    let id = String(cString: windowId)
    GlassMaskService.shared.setDark(windowId: id, layerId: 0, isDark: isDark)
}

/// Set dark mode for the glass effect for a layer.
@_cdecl("FloatingPalette_SetGlassDarkLayer")
public func FloatingPalette_SetGlassDarkLayer(
    windowId: UnsafePointer<CChar>,
    layerId: Int32,
    isDark: Bool
) {
    let id = String(cString: windowId)
    GlassMaskService.shared.setDark(windowId: id, layerId: Int(layerId), isDark: isDark)
}

/// Set tint opacity for the glass effect.
/// opacity: 0.0 = fully transparent (default), 1.0 = fully opaque black
/// cornerRadius: Corner radius for the tint layer
@_cdecl("FloatingPalette_SetGlassTintOpacity")
public func FloatingPalette_SetGlassTintOpacity(
    windowId: UnsafePointer<CChar>,
    opacity: Float,
    cornerRadius: Float
) {
    let id = String(cString: windowId)
    GlassMaskService.shared.setTintOpacity(windowId: id, opacity: opacity, cornerRadius: CGFloat(cornerRadius))
}

/// Set tint opacity for the glass effect (layer parameter currently ignored).
@_cdecl("FloatingPalette_SetGlassTintOpacityLayer")
public func FloatingPalette_SetGlassTintOpacityLayer(
    windowId: UnsafePointer<CChar>,
    layerId: Int32,
    opacity: Float,
    cornerRadius: Float
) {
    let id = String(cString: windowId)
    _ = layerId
    GlassMaskService.shared.setTintOpacity(windowId: id, opacity: opacity, cornerRadius: CGFloat(cornerRadius))
}

// MARK: - Glass Animation (Native-driven)

/// Get current time (CACurrentMediaTime) for clock synchronization.
/// Used by Dart to write animation start time in sync with native.
@_cdecl("FloatingPalette_GetCurrentTime")
public func FloatingPalette_GetCurrentTime() -> Double {
    return CACurrentMediaTime()
}

/// Create an animation buffer for a palette window and layer.
/// Returns a pointer that Flutter can write animation parameters to.
@_cdecl("FloatingPalette_CreateAnimationBuffer")
public func FloatingPalette_CreateAnimationBuffer(
    windowId: UnsafePointer<CChar>,
    layerId: Int32
) -> UnsafeMutableRawPointer? {
    let id = String(cString: windowId)
    return GlassAnimationDriver.shared.createBuffer(windowId: id, layerId: Int(layerId))
}

/// Destroy the animation buffer for a palette window and layer.
@_cdecl("FloatingPalette_DestroyAnimationBuffer")
public func FloatingPalette_DestroyAnimationBuffer(
    windowId: UnsafePointer<CChar>,
    layerId: Int32
) {
    let id = String(cString: windowId)
    GlassAnimationDriver.shared.destroyBuffer(windowId: id, layerId: Int(layerId))
}
