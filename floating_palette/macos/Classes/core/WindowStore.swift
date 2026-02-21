import Cocoa
import FlutterMacOS

/// Stores and tracks all palette windows.
/// Single source of truth for window handles.
final class WindowStore {
    static let shared = WindowStore()

    private var windows: [String: PaletteWindow] = [:]
    private let lock = NSLock()

    private init() {}

    // MARK: - Access

    func get(_ id: String) -> PaletteWindow? {
        lock.lock()
        defer { lock.unlock() }
        return windows[id]
    }

    func exists(_ id: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return windows[id] != nil
    }

    func all() -> [String: PaletteWindow] {
        lock.lock()
        defer { lock.unlock() }
        return windows
    }

    // MARK: - Mutation

    func store(_ id: String, window: PaletteWindow) {
        lock.lock()
        defer { lock.unlock() }
        windows[id] = window
    }

    @discardableResult
    func remove(_ id: String) -> PaletteWindow? {
        lock.lock()
        defer { lock.unlock() }
        return windows.removeValue(forKey: id)
    }

    func clear() {
        lock.lock()
        defer { lock.unlock() }
        windows.removeAll()
    }
}

/// Represents a palette window with its Flutter engine.
final class PaletteWindow {
    let id: String
    let panel: NSPanel
    let flutterViewController: FlutterViewController
    let engine: FlutterEngine

    /// Set once by `WindowService.destroy()` before the window is removed from the store.
    /// Closures that captured this reference can check this flag to bail out early.
    private(set) var isDestroyed: Bool = false

    /// Mark this window as destroyed. Must be called before removing from WindowStore.
    func markDestroyed() { isDestroyed = true }

    /// Method channel for host ↔ palette messaging.
    var messengerChannel: FlutterMethodChannel?

    /// Entry channel for sending commands to palette Flutter engine.
    var entryChannel: FlutterMethodChannel?

    /// Whether the panel is waiting to be revealed after first resize.
    /// Part of "show-after-sized" pattern for flicker-free display.
    var isPendingReveal: Bool = false

    /// Whether to take keyboard focus when revealed.
    /// Set by show command based on focusPolicy.
    var shouldFocus: Bool = true

    /// Size configuration for this palette.
    var sizeConfig: [String: Any] = [:]

    /// Keep the palette engine rendering when unfocused.
    var keepAlive: Bool = false

    /// Whether the palette can be dragged by the user.
    var draggable: Bool = true

    var isVisible: Bool { panel.isVisible }
    var frame: NSRect { panel.frame }

    init(id: String, panel: NSPanel, flutterViewController: FlutterViewController, engine: FlutterEngine) {
        self.id = id
        self.panel = panel
        self.flutterViewController = flutterViewController
        self.engine = engine
    }

    /// Start native window drag using current event.
    /// Returns true if drag was initiated, false if no current event available.
    @discardableResult
    func startDrag() -> Bool {
        guard let event = NSApp.currentEvent else {
            return false
        }

        // Ensure app is active before dragging
        if !NSApp.isActive {
            NSApp.activate(ignoringOtherApps: true)
        }

        panel.performDrag(with: event)
        return true
    }

    /// Reveal the panel after Flutter has rendered content.
    /// Called by FFI after first resize or by safety timer.
    func reveal(eventSink: ((String, String, String?, [String: Any]) -> Void)?) {
        guard isPendingReveal else { return }
        isPendingReveal = false

        if shouldFocus {
            // Remove nonactivatingPanel to allow keyboard focus
            panel.styleMask.remove(.nonactivatingPanel)

            // Activate the application so panel can become key window
            NSApp.activate(ignoringOtherApps: true)

            // Make key and ensure focus
            panel.makeKeyAndOrderFront(nil)

            // Make the Flutter view first responder for keyboard input
            if let contentView = panel.contentView {
                panel.makeFirstResponder(contentView)
            }
        } else {
            // Remember current key window before showing
            let previousKeyWindow = NSApp.keyWindow

            // Show without stealing focus - keep nonactivatingPanel style
            panel.orderFront(nil)

            // Restore focus to previous key window if it lost focus
            if let prev = previousKeyWindow, !prev.isKeyWindow {
                prev.makeKey()
            }
        }

        // Notify that panel is now shown
        eventSink?("visibility", "shown", id, [:])
    }
}
