import os.log

/// Centralized logging for floating_palette native layer.
/// Uses Apple's OSLog for structured logging with per-service categories.
///
/// Usage:
/// ```swift
/// os_log("action: %{public}@", log: Log.window, type: .debug, value)
/// os_log("error: %{public}@", log: Log.frame, type: .error, message)
/// ```
///
/// Viewing logs:
/// ```bash
/// # Filter by subsystem
/// log stream --predicate 'subsystem == "floating_palette"' --level debug
///
/// # Filter by category
/// log stream --predicate 'subsystem == "floating_palette" AND category == "Snap"'
/// ```
enum Log {
    private static let subsystem = "floating_palette"

    // Per-service log handles
    static let window = OSLog(subsystem: subsystem, category: "Window")
    static let visibility = OSLog(subsystem: subsystem, category: "Visibility")
    static let frame = OSLog(subsystem: subsystem, category: "Frame")
    static let snap = OSLog(subsystem: subsystem, category: "Snap")
    static let input = OSLog(subsystem: subsystem, category: "Input")
    static let focus = OSLog(subsystem: subsystem, category: "Focus")
    static let transform = OSLog(subsystem: subsystem, category: "Transform")
    static let animation = OSLog(subsystem: subsystem, category: "Animation")
    static let zorder = OSLog(subsystem: subsystem, category: "ZOrder")
    static let appearance = OSLog(subsystem: subsystem, category: "Appearance")
    static let screen = OSLog(subsystem: subsystem, category: "Screen")
    static let capture = OSLog(subsystem: subsystem, category: "Capture")
    static let message = OSLog(subsystem: subsystem, category: "Message")
    static let host = OSLog(subsystem: subsystem, category: "Host")
    static let glass = OSLog(subsystem: subsystem, category: "Glass")
    static let plugin = OSLog(subsystem: subsystem, category: "Plugin")
}
