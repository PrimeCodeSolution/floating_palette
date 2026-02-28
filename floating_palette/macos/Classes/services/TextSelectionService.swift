import Cocoa
import FlutterMacOS
import ApplicationServices
import os.log

/// Detects text selection in any macOS application using the Accessibility API.
///
/// Uses AXObserver for event-driven monitoring of text selection changes.
/// Requires Accessibility permission and no App Sandbox.
final class TextSelectionService {
    private var eventSink: ((String, String, String?, [String: Any]) -> Void)?

    // AXObserver state (per frontmost app)
    private var observer: AXObserver?
    private var observedPid: pid_t?
    private var observedElement: AXUIElement?

    // Dedup state
    private var lastText: String?
    private var lastBounds: CGRect?

    // Debounce — delays selectionCleared to avoid flicker
    private var clearDebounceWork: DispatchWorkItem?

    // Workspace notification listeners (app switch + space change)
    private var workspaceObservers: [Any] = []

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
        case "getSelection":
            getSelection(result: result)
        case "startMonitoring":
            startMonitoring(result: result)
        case "stopMonitoring":
            stopMonitoring(result: result)
        default:
            result(FlutterError(code: "UNKNOWN_COMMAND", message: "Unknown textSelection command: \(command)", details: nil))
        }
    }

    // MARK: - Permission

    private func checkPermission(result: @escaping FlutterResult) {
        let granted = AXIsProcessTrusted()
        result(["granted": granted])
    }

    private func requestPermission(result: @escaping FlutterResult) {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
        result(nil)
    }

    // MARK: - One-shot Query

    private func getSelection(result: @escaping FlutterResult) {
        let systemWide = AXUIElementCreateSystemWide()

        // Get focused element
        var focusedValue: AFTRef?
        let focusedErr = AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &focusedValue)
        guard focusedErr == .success, let focused = focusedValue else {
            result(nil)
            return
        }

        let element = focused as! AXUIElement

        // Get selected text
        var textValue: AFTRef?
        let textErr = AXUIElementCopyAttributeValue(element, kAXSelectedTextAttribute as CFString, &textValue)
        guard textErr == .success, let text = textValue as? String, !text.isEmpty else {
            result(nil)
            return
        }

        // Get bounds (with retry + text marker fallback)
        let (bounds, boundsError) = getSelectionBoundsWithRetry(element: element)

        // Get app info
        let (appBundleId, appName) = getFrontmostAppInfo()

        var data: [String: Any] = [
            "text": text,
            "appBundleId": appBundleId,
            "appName": appName,
        ]

        if let bounds = bounds {
            let screenRect = convertToScreenCoordinates(bounds)
            data["x"] = screenRect.origin.x
            data["y"] = screenRect.origin.y
            data["width"] = screenRect.size.width
            data["height"] = screenRect.size.height
        } else if let reason = boundsError {
            data["boundsError"] = reason
        }

        result(data)
    }

    // MARK: - Monitoring

    private func startMonitoring(result: @escaping FlutterResult) {
        guard AXIsProcessTrusted() else {
            result(FlutterError(code: "PERMISSION_DENIED", message: "Accessibility permission not granted", details: nil))
            return
        }

        // Listen for app switches
        let appSwitchToken = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.observeFrontmostApp()
        }

        // Listen for space changes (fullscreen transitions via green button)
        let spaceChangeToken = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.observeFrontmostApp(force: true)
        }

        workspaceObservers = [appSwitchToken, spaceChangeToken]

        // Observe the currently active app
        observeFrontmostApp()

        result(nil)
    }

    private func stopMonitoring(result: @escaping FlutterResult) {
        tearDown()
        result(nil)
    }

    // MARK: - AXObserver Management

    private func observeFrontmostApp(force: Bool = false) {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else { return }
        let pid = frontApp.processIdentifier

        // Skip if already observing this app (unless forced, e.g. after space change)
        if pid == observedPid && !force { return }

        // Tear down old observer
        tearDownObserver()

        os_log("observing app pid=%{public}d name=%{public}@",
               log: Log.textSelection, type: .debug,
               pid, frontApp.localizedName ?? "unknown")

        observedPid = pid
        let appElement = AXUIElementCreateApplication(pid)

        // Enable enhanced AX support — needed for Chromium-based apps (Chrome, Brave, Edge,
        // Arc, Electron) to expose text marker APIs. Native apps ignore this harmlessly.
        AXUIElementSetAttributeValue(appElement, "AXEnhancedUserInterface" as CFString, true as CFTypeRef)

        // Get focused element
        var focusedValue: AFTRef?
        let err = AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &focusedValue)

        // Create AXObserver
        var newObserver: AXObserver?
        let createErr = AXObserverCreate(pid, textSelectionCallback, &newObserver)
        guard createErr == .success, let obs = newObserver else {
            os_log("failed to create AXObserver: %{public}d", log: Log.textSelection, type: .error, createErr.rawValue)
            return
        }

        observer = obs

        // Always observe selectedTextChanged on the app element — this catches notifications
        // from apps like iTerm2 where the specific focused element may not fire them.
        let appAddErr = AXObserverAddNotification(obs, appElement, kAXSelectedTextChangedNotification as CFString, Unmanaged.passUnretained(self).toOpaque())
        os_log("selectedTextChanged on app element: %{public}@",
               log: Log.textSelection, type: .debug, axErrorName(appAddErr))

        // Also observe on the focused element if available (some apps only fire on the element)
        if err == .success, let focused = focusedValue {
            let focusedElement = focused as! AXUIElement
            let focusAddErr = AXObserverAddNotification(obs, focusedElement, kAXSelectedTextChangedNotification as CFString, Unmanaged.passUnretained(self).toOpaque())
            os_log("selectedTextChanged on focused element: %{public}@",
                   log: Log.textSelection, type: .debug, axErrorName(focusAddErr))
            observedElement = focusedElement
        } else {
            os_log("no focused element (err=%{public}@), using app element only",
                   log: Log.textSelection, type: .debug, axErrorName(err))
            observedElement = appElement
        }

        // Also observe focus changes to re-register when focus moves within the app
        AXObserverAddNotification(obs, appElement, kAXFocusedUIElementChangedNotification as CFString, Unmanaged.passUnretained(self).toOpaque())

        // Add to run loop — use .commonModes so notifications are delivered during
        // modal/tracking states adjacent to fullscreen transitions
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(obs), .commonModes)
    }

    /// Re-observe when the focused element changes within the same app.
    /// Keeps the old element's notification active to avoid losing events when
    /// the floating palette briefly shifts focus (e.g. in fullscreen spaces).
    fileprivate func handleFocusChanged() {
        guard let pid = observedPid, let obs = observer else { return }

        let appElement = AXUIElementCreateApplication(pid)

        var focusedValue: AFTRef?
        let err = AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &focusedValue)
        guard err == .success, let focused = focusedValue else { return }

        let newElement = focused as! AXUIElement

        // Add notification on new element (keep old element's notification active —
        // removing it can kill future events when focus shifts due to our own palette)
        let addErr = AXObserverAddNotification(obs, newElement, kAXSelectedTextChangedNotification as CFString, Unmanaged.passUnretained(self).toOpaque())
        if addErr == .success {
            os_log("focus changed, added observer on new element (keeping old)",
                   log: Log.textSelection, type: .debug)
            observedElement = newElement
        } else if addErr == .notificationAlreadyRegistered {
            // Same element — no change needed
        } else {
            os_log("focus changed, failed to add on new element: %{public}d",
                   log: Log.textSelection, type: .debug, addErr.rawValue)
        }
    }

    /// Handle text selection change from AXObserver callback.
    /// Emits selections immediately; debounces clears to avoid flicker.
    fileprivate func handleSelectionChanged(_ notificationElement: AXUIElement) {
        // Use system-wide focused element — more reliable than the notification element,
        // which may be the app root or a stale element.
        let element: AXUIElement
        let systemWide = AXUIElementCreateSystemWide()
        var focusedValue: AFTRef?
        let focusedErr = AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &focusedValue)
        if focusedErr == .success, let focused = focusedValue {
            element = focused as! AXUIElement
        } else {
            os_log("system-wide focused element failed (%{public}@), falling back to notification element",
                   log: Log.textSelection, type: .debug, axErrorName(focusedErr))
            element = notificationElement
        }

        // Read selected text
        var textValue: AFTRef?
        let textErr = AXUIElementCopyAttributeValue(element, kAXSelectedTextAttribute as CFString, &textValue)

        let text: String?
        if textErr == .success, let str = textValue as? String, !str.isEmpty {
            text = str
        } else {
            text = nil
        }

        if let text = text {
            // Cancel any pending clear — selection is active
            clearDebounceWork?.cancel()
            clearDebounceWork = nil

            // Get bounds (with retry for timing issues)
            let (bounds, boundsError) = getSelectionBoundsWithRetry(element: element)
            let (appBundleId, appName) = getFrontmostAppInfo()

            if let axBounds = bounds {
                os_log("AX bounds: x=%{public}.1f y=%{public}.1f w=%{public}.1f h=%{public}.1f",
                       log: Log.textSelection, type: .info,
                       axBounds.origin.x, axBounds.origin.y, axBounds.size.width, axBounds.size.height)
            }

            // Dedup
            let screenRect = bounds.map { convertToScreenCoordinates($0) }
            if text == lastText && screenRect == lastBounds { return }

            if let rect = screenRect {
                os_log("screen coords: x=%{public}.1f y=%{public}.1f w=%{public}.1f h=%{public}.1f",
                       log: Log.textSelection, type: .info,
                       rect.origin.x, rect.origin.y, rect.size.width, rect.size.height)
            }

            lastText = text
            lastBounds = screenRect

            var data: [String: Any] = [
                "text": text,
                "appBundleId": appBundleId,
                "appName": appName,
            ]

            if let rect = screenRect {
                data["x"] = rect.origin.x
                data["y"] = rect.origin.y
                data["width"] = rect.size.width
                data["height"] = rect.size.height
            } else if let reason = boundsError {
                data["boundsError"] = reason
            }

            eventSink?("textSelection", "selectionChanged", nil, data)
        } else {
            // Debounce clears — wait 0.2s to avoid flicker from rapid select/clear cycles
            if lastText != nil {
                clearDebounceWork?.cancel()
                let work = DispatchWorkItem { [weak self] in
                    self?.lastText = nil
                    self?.lastBounds = nil
                    self?.eventSink?("textSelection", "selectionCleared", nil, [:])
                }
                clearDebounceWork = work
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: work)
            }
        }
    }

    // MARK: - Helpers

    /// Try to get bounds using two strategies, each with retries:
    /// 1. Standard CFRange-based bounds (works for native apps)
    /// 2. Text-marker-based bounds (fallback for Chromium/Electron apps)
    private func getSelectionBoundsWithRetry(element: AXUIElement, attempts: Int = 3) -> (CGRect?, String?) {
        // Strategy 1: Standard CFRange bounds
        var lastError: String?
        for attempt in 1...attempts {
            let (rect, error) = getSelectionBounds(element: element)
            if let rect = rect {
                os_log("bounds via standard (attempt %{public}d)", log: Log.textSelection, type: .debug, attempt)
                return (rect, nil)
            }
            lastError = error
            if attempt < attempts {
                Thread.sleep(forTimeInterval: Double(attempt) * 0.015)
            }
        }

        // Strategy 2: Text marker fallback (Chromium/Electron)
        os_log("standard bounds failed (%{public}@), trying textMarker fallback",
               log: Log.textSelection, type: .debug, lastError ?? "unknown")
        for attempt in 1...attempts {
            let (rect, error) = getSelectionBoundsViaTextMarkers(element: element)
            if let rect = rect {
                return (rect, nil)
            }
            lastError = error
            if attempt < attempts {
                Thread.sleep(forTimeInterval: Double(attempt) * 0.015)
            }
        }

        return (nil, lastError)
    }

    /// Returns (rect, errorReason).
    private func getSelectionBounds(element: AXUIElement) -> (CGRect?, String?) {
        // Check if element supports the parameterized attribute
        var pNamesRef: CFArray?
        let pNamesErr = AXUIElementCopyParameterizedAttributeNames(element, &pNamesRef)
        if pNamesErr == .success, let names = pNamesRef as? [String] {
            if !names.contains(kAXBoundsForRangeParameterizedAttribute as String) {
                let supported = names.isEmpty ? "(none)" : names.joined(separator: ", ")
                let reason = "boundsForRange unsupported; params: \(supported)"
                os_log("%{public}@", log: Log.textSelection, type: .debug, reason)
                return (nil, reason)
            }
        } else {
            os_log("copyParameterizedAttributeNames failed: %{public}@",
                   log: Log.textSelection, type: .debug, axErrorName(pNamesErr))
        }

        // Get selected text range
        var rangeValue: AFTRef?
        let rangeErr = AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &rangeValue)
        guard rangeErr == .success, let rawRange = rangeValue else {
            let reason = "selectedTextRange: \(axErrorName(rangeErr))"
            os_log("%{public}@", log: Log.textSelection, type: .debug, reason)
            return (nil, reason)
        }

        // Type-check: must be AXValue of cfRange type
        let rangeAX = rawRange as! AXValue
        guard AXValueGetType(rangeAX) == .cfRange else {
            let reason = "selectedTextRange not AXValue(cfRange)"
            os_log("%{public}@", log: Log.textSelection, type: .debug, reason)
            return (nil, reason)
        }

        var cfRange = CFRange()
        AXValueGetValue(rangeAX, .cfRange, &cfRange)
        os_log("selected range: location=%{public}ld length=%{public}ld",
               log: Log.textSelection, type: .debug, cfRange.location, cfRange.length)

        // Bounds for empty range (caret) are often unavailable
        if cfRange.length == 0 {
            return (nil, "caret (length=0)")
        }

        // Get bounds for range (parameterized attribute)
        var boundsValue: AFTRef?
        let boundsErr = AXUIElementCopyParameterizedAttributeValue(
            element,
            kAXBoundsForRangeParameterizedAttribute as CFString,
            rangeAX,
            &boundsValue
        )
        guard boundsErr == .success, let rawBounds = boundsValue else {
            let reason = "boundsForRange: \(axErrorName(boundsErr))"
            os_log("%{public}@", log: Log.textSelection, type: .info, reason)
            return (nil, reason)
        }

        // Type-check bounds
        let boundsAX = rawBounds as! AXValue
        guard AXValueGetType(boundsAX) == .cgRect else {
            let reason = "boundsForRange returned non-CGRect AXValue"
            os_log("%{public}@", log: Log.textSelection, type: .debug, reason)
            return (nil, reason)
        }

        // Extract CGRect from AXValue
        var rect = CGRect.zero
        guard AXValueGetValue(boundsAX, .cgRect, &rect), !rect.isEmpty else {
            let reason = "boundsForRange returned empty rect"
            os_log("%{public}@", log: Log.textSelection, type: .debug, reason)
            return (nil, reason)
        }

        return (rect, nil)
    }

    /// Fallback for Chromium-based apps that stub out `kAXBoundsForRangeParameterizedAttribute`
    /// but implement `AXBoundsForTextMarkerRange` via their accessibility layer.
    private func getSelectionBoundsViaTextMarkers(element: AXUIElement) -> (CGRect?, String?) {
        // 1. Get the selected text marker range (regular attribute, not parameterized)
        var markerRangeValue: AFTRef?
        let markerErr = AXUIElementCopyAttributeValue(
            element, "AXSelectedTextMarkerRange" as CFString, &markerRangeValue)
        guard markerErr == .success, let markerRange = markerRangeValue else {
            let reason = "textMarker: selectedTextMarkerRange: \(axErrorName(markerErr))"
            os_log("%{public}@", log: Log.textSelection, type: .debug, reason)
            return (nil, reason)
        }

        // 2. Pass marker range to AXBoundsForTextMarkerRange (parameterized attribute)
        var boundsValue: AFTRef?
        let boundsErr = AXUIElementCopyParameterizedAttributeValue(
            element,
            "AXBoundsForTextMarkerRange" as CFString,
            markerRange,
            &boundsValue
        )
        guard boundsErr == .success, let rawBounds = boundsValue else {
            let reason = "textMarker: boundsForTextMarkerRange: \(axErrorName(boundsErr))"
            os_log("%{public}@", log: Log.textSelection, type: .debug, reason)
            return (nil, reason)
        }

        // 3. Extract CGRect — text marker API returns opaque types, check AXValue type
        let boundsAX = rawBounds as! AXValue
        guard AXValueGetType(boundsAX) == .cgRect else {
            let reason = "textMarker: boundsForTextMarkerRange returned non-CGRect value"
            os_log("%{public}@", log: Log.textSelection, type: .debug, reason)
            return (nil, reason)
        }

        var rect = CGRect.zero
        guard AXValueGetValue(boundsAX, .cgRect, &rect), !rect.isEmpty else {
            let reason = "textMarker: boundsForTextMarkerRange returned empty rect"
            os_log("%{public}@", log: Log.textSelection, type: .debug, reason)
            return (nil, reason)
        }

        os_log("bounds via textMarker: x=%{public}.1f y=%{public}.1f w=%{public}.1f h=%{public}.1f",
               log: Log.textSelection, type: .info,
               rect.origin.x, rect.origin.y, rect.size.width, rect.size.height)
        return (rect, nil)
    }

    private func axErrorName(_ err: AXError) -> String {
        switch err {
        case .success: return "success"
        case .failure: return "failure"
        case .illegalArgument: return "illegalArgument"
        case .invalidUIElement: return "invalidUIElement"
        case .invalidUIElementObserver: return "invalidUIElementObserver"
        case .cannotComplete: return "cannotComplete"
        case .attributeUnsupported: return "attributeUnsupported"
        case .actionUnsupported: return "actionUnsupported"
        case .notificationUnsupported: return "notificationUnsupported"
        case .notImplemented: return "notImplemented"
        case .notificationAlreadyRegistered: return "notificationAlreadyRegistered"
        case .notificationNotRegistered: return "notificationNotRegistered"
        case .apiDisabled: return "apiDisabled"
        case .noValue: return "noValue"
        case .parameterizedAttributeUnsupported: return "parameterizedAttributeUnsupported"
        case .notEnoughPrecision: return "notEnoughPrecision"
        @unknown default: return "unknown(\(err.rawValue))"
        }
    }

    /// Convert AX coordinates (top-left origin) to macOS screen coordinates (bottom-left origin).
    ///
    /// The Accessibility API returns bounds with Y=0 at the top of the primary screen,
    /// increasing downward. macOS NSWindow uses Y=0 at the bottom, increasing upward.
    private func convertToScreenCoordinates(_ axRect: CGRect) -> CGRect {
        guard let primaryScreen = NSScreen.screens.first else { return axRect }
        let primaryHeight = primaryScreen.frame.height
        // Flip Y: macOS_y = primaryHeight - ax_y - rect_height
        let flippedY = primaryHeight - axRect.origin.y - axRect.size.height
        return CGRect(x: axRect.origin.x, y: flippedY, width: axRect.size.width, height: axRect.size.height)
    }

    private func getFrontmostAppInfo() -> (String, String) {
        guard let app = NSWorkspace.shared.frontmostApplication else {
            return ("", "")
        }
        return (
            app.bundleIdentifier ?? "",
            app.localizedName ?? ""
        )
    }

    // MARK: - Teardown

    private func tearDownObserver() {
        clearDebounceWork?.cancel()
        clearDebounceWork = nil

        if let obs = observer {
            if let element = observedElement {
                AXObserverRemoveNotification(obs, element, kAXSelectedTextChangedNotification as CFString)
            }
            if let pid = observedPid {
                let appElement = AXUIElementCreateApplication(pid)
                AXObserverRemoveNotification(obs, appElement, kAXFocusedUIElementChangedNotification as CFString)
            }
            CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(obs), .commonModes)
        }

        observer = nil
        observedPid = nil
        observedElement = nil
        lastText = nil
        lastBounds = nil
    }

    private func tearDown() {
        // Remove workspace observers
        for token in workspaceObservers {
            NSWorkspace.shared.notificationCenter.removeObserver(token)
        }
        workspaceObservers = []

        tearDownObserver()
    }
}

// MARK: - Type Alias

/// AXUIElementCopyAttributeValue uses `CFTypeRef?` (aliased here for clarity).
private typealias AFTRef = CFTypeRef

// MARK: - AXObserver C Callback

/// Global callback for AXObserver — routes to the TextSelectionService instance.
private func textSelectionCallback(
    _ observer: AXObserver,
    _ element: AXUIElement,
    _ notification: CFString,
    _ refcon: UnsafeMutableRawPointer?
) {
    guard let refcon = refcon else { return }
    let service = Unmanaged<TextSelectionService>.fromOpaque(refcon).takeUnretainedValue()

    let name = notification as String
    if name == kAXSelectedTextChangedNotification as String {
        service.handleSelectionChanged(element)
    } else if name == kAXFocusedUIElementChangedNotification as String {
        service.handleFocusChanged()
    }
}
