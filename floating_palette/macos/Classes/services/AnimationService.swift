import Cocoa
import FlutterMacOS

/// Handles property animation.
final class AnimationService {
    private let store = WindowStore.shared
    private var eventSink: ((String, String, String?, [String: Any]) -> Void)?

    // Track active animations: windowId -> Set of property names
    private var activeAnimations: [String: Set<String>] = [:]

    func setEventSink(_ sink: @escaping (String, String, String?, [String: Any]) -> Void) {
        self.eventSink = sink
    }

    // MARK: - Commands

    func handle(_ command: String, windowId: String?, params: [String: Any], result: @escaping FlutterResult) {
        switch command {
        case "animate":
            animate(windowId: windowId, params: params, result: result)
        case "animateMultiple":
            animateMultiple(windowId: windowId, params: params, result: result)
        case "stop":
            stop(windowId: windowId, params: params, result: result)
        case "stopAll":
            stopAll(windowId: windowId, result: result)
        case "isAnimating":
            isAnimating(windowId: windowId, params: params, result: result)
        default:
            result(FlutterError(code: "UNKNOWN_COMMAND", message: "Unknown animation command: \(command)", details: nil))
        }
    }

    // MARK: - Animate

    private func animate(windowId: String?, params: [String: Any], result: @escaping FlutterResult) {
        guard let id = windowId, let window = store.get(id) else {
            result(FlutterError(code: "NOT_FOUND", message: "Window not found", details: nil))
            return
        }

        guard let property = params["property"] as? String else {
            result(FlutterError(code: "INVALID_PARAMS", message: "property required", details: nil))
            return
        }

        let from = params["from"] as? Double
        let to = params["to"] as? Double ?? 1.0
        let durationMs = params["durationMs"] as? Int ?? 300
        let curve = params["curve"] as? String ?? "easeInOut"
        let repeatCount = params["repeatCount"] as? Int ?? params["repeat"] as? Int ?? 1
        let autoReverse = params["autoReverse"] as? Bool ?? false

        // Track animation start
        markAnimationStarted(windowId: id, property: property)

        DispatchQueue.main.async { [weak self] in
            self?.performAnimation(
                windowId: id,
                window: window,
                property: property,
                from: from,
                to: to,
                durationMs: durationMs,
                curve: curve,
                repeatCount: repeatCount,
                autoReverse: autoReverse
            )
            result(nil)
        }
    }

    // MARK: - Animate Multiple

    private func animateMultiple(windowId: String?, params: [String: Any], result: @escaping FlutterResult) {
        guard let id = windowId, let window = store.get(id) else {
            result(FlutterError(code: "NOT_FOUND", message: "Window not found", details: nil))
            return
        }

        guard let animations = params["animations"] as? [[String: Any]] else {
            result(FlutterError(code: "INVALID_PARAMS", message: "animations array required", details: nil))
            return
        }

        let durationMs = params["durationMs"] as? Int ?? 300
        let curve = params["curve"] as? String ?? "easeOut"

        // Track all properties being animated
        for anim in animations {
            if let property = anim["property"] as? String {
                markAnimationStarted(windowId: id, property: property)
            }
        }

        DispatchQueue.main.async { [weak self] in
            let panel = window.panel
            let duration = Double(durationMs) / 1000.0
            let timing = self?.timingFunction(for: curve) ?? CAMediaTimingFunction(name: .easeOut)

            // Collect target values for frame animations
            var targetFrame = panel.frame
            var hasFrameChange = false
            var targetOpacity: Double?

            for anim in animations {
                guard let property = anim["property"] as? String else { continue }
                let from = anim["from"] as? Double
                let to = anim["to"] as? Double ?? 0

                switch property {
                case "x":
                    if let fromVal = from { targetFrame.origin.x = fromVal; panel.setFrameOrigin(targetFrame.origin) }
                    targetFrame.origin.x = to
                    hasFrameChange = true
                case "y":
                    if let fromVal = from { targetFrame.origin.y = fromVal; panel.setFrameOrigin(targetFrame.origin) }
                    targetFrame.origin.y = to
                    hasFrameChange = true
                case "width":
                    if let fromVal = from { targetFrame.size.width = fromVal; panel.setFrame(targetFrame, display: true) }
                    targetFrame.size.width = to
                    hasFrameChange = true
                case "height":
                    if let fromVal = from { targetFrame.size.height = fromVal; panel.setFrame(targetFrame, display: true) }
                    targetFrame.size.height = to
                    hasFrameChange = true
                case "opacity":
                    if let fromVal = from { panel.alphaValue = fromVal }
                    targetOpacity = to
                default:
                    break
                }
            }

            // Run the combined animation
            NSAnimationContext.runAnimationGroup { context in
                context.duration = duration
                context.timingFunction = timing

                if hasFrameChange {
                    panel.animator().setFrame(targetFrame, display: true)
                }
                if let opacity = targetOpacity {
                    panel.animator().alphaValue = opacity
                }
            } completionHandler: { [weak self] in
                // Mark all properties as completed
                for anim in animations {
                    if let property = anim["property"] as? String {
                        self?.markAnimationCompleted(windowId: id, property: property)
                    }
                }
            }

            result(nil)
        }
    }

    private func markAnimationStarted(windowId: String, property: String) {
        if activeAnimations[windowId] == nil {
            activeAnimations[windowId] = []
        }
        activeAnimations[windowId]?.insert(property)
    }

    private func markAnimationCompleted(windowId: String, property: String) {
        activeAnimations[windowId]?.remove(property)
        eventSink?("animation", "complete", windowId, ["property": property])
    }

    private func performAnimation(
        windowId: String,
        window: PaletteWindow,
        property: String,
        from: Double?,
        to: Double,
        durationMs: Int,
        curve: String,
        repeatCount: Int,
        autoReverse: Bool
    ) {
        let panel = window.panel
        let duration = Double(durationMs) / 1000.0
        let timing = timingFunction(for: curve)

        // Completion handler to mark animation done
        let onComplete: () -> Void = { [weak self] in
            self?.markAnimationCompleted(windowId: windowId, property: property)
        }

        switch property {
        case "opacity":
            if let fromValue = from {
                panel.alphaValue = fromValue
            }
            animateProperty(panel: panel, keyPath: "alphaValue", to: to, duration: duration, timing: timing, repeatCount: repeatCount, autoReverse: autoReverse, onComplete: onComplete)

        case "x":
            var frame = panel.frame
            if let fromValue = from {
                frame.origin.x = fromValue
                panel.setFrameOrigin(frame.origin)
            }
            animateFrame(panel: panel, property: "x", to: to, duration: duration, timing: timing, repeatCount: repeatCount, autoReverse: autoReverse, onComplete: onComplete)

        case "y":
            var frame = panel.frame
            if let fromValue = from {
                frame.origin.y = fromValue
                panel.setFrameOrigin(frame.origin)
            }
            animateFrame(panel: panel, property: "y", to: to, duration: duration, timing: timing, repeatCount: repeatCount, autoReverse: autoReverse, onComplete: onComplete)

        case "width":
            var frame = panel.frame
            if let fromValue = from {
                frame.size.width = fromValue
                panel.setFrame(frame, display: true)
            }
            animateFrame(panel: panel, property: "width", to: to, duration: duration, timing: timing, repeatCount: repeatCount, autoReverse: autoReverse, onComplete: onComplete)

        case "height":
            var frame = panel.frame
            if let fromValue = from {
                frame.size.height = fromValue
                panel.setFrame(frame, display: true)
            }
            animateFrame(panel: panel, property: "height", to: to, duration: duration, timing: timing, repeatCount: repeatCount, autoReverse: autoReverse, onComplete: onComplete)

        default:
            // Unknown property, mark completed immediately
            onComplete()
        }
    }

    private func animateProperty(panel: NSPanel, keyPath: String, to: Double, duration: Double, timing: CAMediaTimingFunction, repeatCount: Int, autoReverse: Bool, onComplete: @escaping () -> Void) {
        var remaining = repeatCount

        func runOnce(forward: Bool) {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = duration
                context.timingFunction = timing
                panel.animator().alphaValue = forward ? to : 1.0
            } completionHandler: {
                if autoReverse && forward {
                    runOnce(forward: false)
                } else {
                    remaining -= 1
                    if remaining > 0 {
                        runOnce(forward: true)
                    } else {
                        onComplete()
                    }
                }
            }
        }

        runOnce(forward: true)
    }

    private func animateFrame(panel: NSPanel, property: String, to: Double, duration: Double, timing: CAMediaTimingFunction, repeatCount: Int, autoReverse: Bool, onComplete: @escaping () -> Void) {
        let originalFrame = panel.frame
        var remaining = repeatCount

        func runOnce(forward: Bool) {
            var targetFrame = panel.frame

            switch property {
            case "x": targetFrame.origin.x = forward ? to : originalFrame.origin.x
            case "y": targetFrame.origin.y = forward ? to : originalFrame.origin.y
            case "width": targetFrame.size.width = forward ? to : originalFrame.width
            case "height": targetFrame.size.height = forward ? to : originalFrame.height
            default: break
            }

            NSAnimationContext.runAnimationGroup { context in
                context.duration = duration
                context.timingFunction = timing
                panel.animator().setFrame(targetFrame, display: true)
            } completionHandler: {
                if autoReverse && forward {
                    runOnce(forward: false)
                } else {
                    remaining -= 1
                    if remaining > 0 {
                        runOnce(forward: true)
                    } else {
                        onComplete()
                    }
                }
            }
        }

        runOnce(forward: true)
    }

    private func timingFunction(for curve: String) -> CAMediaTimingFunction {
        switch curve {
        case "linear": return CAMediaTimingFunction(name: .linear)
        case "easeIn": return CAMediaTimingFunction(name: .easeIn)
        case "easeOut": return CAMediaTimingFunction(name: .easeOut)
        case "easeInOut": return CAMediaTimingFunction(name: .easeInEaseOut)
        default: return CAMediaTimingFunction(name: .easeInEaseOut)
        }
    }

    // MARK: - Stop

    private func stop(windowId: String?, params: [String: Any], result: @escaping FlutterResult) {
        guard let id = windowId, let window = store.get(id) else {
            result(FlutterError(code: "NOT_FOUND", message: "Window not found", details: nil))
            return
        }

        let property = params["property"] as? String

        // Clear tracking for this property (or all if no property specified)
        if let prop = property {
            activeAnimations[id]?.remove(prop)
        } else {
            activeAnimations[id]?.removeAll()
        }

        // Stop animations on the window layer
        // Note: NSAnimationContext doesn't support per-property stopping easily,
        // so we stop all animations but only clear tracking for the requested property
        DispatchQueue.main.async {
            window.panel.contentView?.layer?.removeAllAnimations()
            result(nil)
        }
    }

    private func stopAll(windowId: String?, result: @escaping FlutterResult) {
        guard let id = windowId, let window = store.get(id) else {
            result(FlutterError(code: "NOT_FOUND", message: "Window not found", details: nil))
            return
        }

        // Clear all tracking for this window
        activeAnimations[id]?.removeAll()

        DispatchQueue.main.async {
            window.panel.contentView?.layer?.removeAllAnimations()
            result(nil)
        }
    }

    // MARK: - Query

    private func isAnimating(windowId: String?, params: [String: Any], result: @escaping FlutterResult) {
        guard let id = windowId else {
            result(false)
            return
        }

        let property = params["property"] as? String

        if let prop = property {
            // Check if specific property is animating
            let animating = activeAnimations[id]?.contains(prop) ?? false
            result(animating)
        } else {
            // Check if any property is animating
            let animating = !(activeAnimations[id]?.isEmpty ?? true)
            result(animating)
        }
    }
}
