import Cocoa
import FlutterMacOS

/// Handles window transforms: scale, rotation, flip.
final class TransformService {
    private let store = WindowStore.shared
    private var eventSink: ((String, String, String?, [String: Any]) -> Void)?

    // State tracking for getters
    private var scaleState: [String: (x: Double, y: Double)] = [:]
    private var rotationState: [String: Double] = [:]  // in degrees
    private var flipState: [String: (horizontal: Bool, vertical: Bool)] = [:]

    func setEventSink(_ sink: @escaping (String, String, String?, [String: Any]) -> Void) {
        self.eventSink = sink
    }

    // MARK: - Commands

    func handle(_ command: String, windowId: String?, params: [String: Any], result: @escaping FlutterResult) {
        switch command {
        case "setScale":
            setScale(windowId: windowId, params: params, result: result)
        case "setRotation":
            setRotation(windowId: windowId, params: params, result: result)
        case "setFlip":
            setFlip(windowId: windowId, params: params, result: result)
        case "reset":
            reset(windowId: windowId, result: result)
        case "getScale":
            getScale(windowId: windowId, result: result)
        case "getRotation":
            getRotation(windowId: windowId, result: result)
        case "getFlip":
            getFlip(windowId: windowId, result: result)
        default:
            result(FlutterError(code: "UNKNOWN_COMMAND", message: "Unknown transform command: \(command)", details: nil))
        }
    }

    // MARK: - Scale

    private func setScale(windowId: String?, params: [String: Any], result: @escaping FlutterResult) {
        guard let id = windowId, let window = store.get(id) else {
            result(FlutterError(code: "NOT_FOUND", message: "Window not found", details: nil))
            return
        }

        let scaleX = params["x"] as? Double ?? params["scale"] as? Double ?? 1.0
        let scaleY = params["y"] as? Double ?? params["scale"] as? Double ?? 1.0
        let animate = params["animate"] as? Bool ?? false
        let durationMs = params["durationMs"] as? Int ?? 200

        // Store state for getter
        scaleState[id] = (x: scaleX, y: scaleY)

        DispatchQueue.main.async { [weak self] in
            guard let layer = window.panel.contentView?.layer else {
                result(nil)
                return
            }

            layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            let transform = CATransform3DMakeScale(scaleX, scaleY, 1.0)

            if animate {
                let animation = CABasicAnimation(keyPath: "transform")
                animation.fromValue = layer.transform
                animation.toValue = transform
                animation.duration = Double(durationMs) / 1000.0
                animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                animation.fillMode = .forwards
                animation.isRemovedOnCompletion = false

                CATransaction.begin()
                CATransaction.setCompletionBlock {
                    layer.transform = transform
                    self?.eventSink?("transform", "scaled", id, ["x": scaleX, "y": scaleY])
                }
                layer.add(animation, forKey: "scale")
                CATransaction.commit()
            } else {
                layer.transform = transform
                self?.eventSink?("transform", "scaled", id, ["x": scaleX, "y": scaleY])
            }

            result(nil)
        }
    }

    // MARK: - Rotation

    private func setRotation(windowId: String?, params: [String: Any], result: @escaping FlutterResult) {
        guard let id = windowId, let window = store.get(id) else {
            result(FlutterError(code: "NOT_FOUND", message: "Window not found", details: nil))
            return
        }

        guard let degrees = params["degrees"] as? Double else {
            result(FlutterError(code: "INVALID_PARAMS", message: "degrees required", details: nil))
            return
        }

        let animate = params["animate"] as? Bool ?? false
        let durationMs = params["durationMs"] as? Int ?? 200

        // Store state for getter (in degrees)
        rotationState[id] = degrees

        DispatchQueue.main.async { [weak self] in
            guard let layer = window.panel.contentView?.layer else {
                result(nil)
                return
            }

            let radians = degrees * .pi / 180.0
            layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            let transform = CATransform3DMakeRotation(radians, 0, 0, 1)

            if animate {
                let animation = CABasicAnimation(keyPath: "transform.rotation.z")
                animation.toValue = radians
                animation.duration = Double(durationMs) / 1000.0
                animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                animation.fillMode = .forwards
                animation.isRemovedOnCompletion = false

                CATransaction.begin()
                CATransaction.setCompletionBlock {
                    layer.transform = transform
                    self?.eventSink?("transform", "rotated", id, ["degrees": degrees])
                }
                layer.add(animation, forKey: "rotation")
                CATransaction.commit()
            } else {
                layer.transform = transform
                self?.eventSink?("transform", "rotated", id, ["degrees": degrees])
            }

            result(nil)
        }
    }

    // MARK: - Flip

    private func setFlip(windowId: String?, params: [String: Any], result: @escaping FlutterResult) {
        guard let id = windowId, let window = store.get(id) else {
            result(FlutterError(code: "NOT_FOUND", message: "Window not found", details: nil))
            return
        }

        let horizontal = params["horizontal"] as? Bool ?? false
        let vertical = params["vertical"] as? Bool ?? false
        let animate = params["animate"] as? Bool ?? false
        let durationMs = params["durationMs"] as? Int ?? 200

        // Store state for getter
        flipState[id] = (horizontal: horizontal, vertical: vertical)

        DispatchQueue.main.async { [weak self] in
            guard let layer = window.panel.contentView?.layer else {
                result(nil)
                return
            }

            let scaleX: CGFloat = horizontal ? -1.0 : 1.0
            let scaleY: CGFloat = vertical ? -1.0 : 1.0
            layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            let transform = CATransform3DMakeScale(scaleX, scaleY, 1.0)

            if animate {
                let animation = CABasicAnimation(keyPath: "transform")
                animation.fromValue = layer.transform
                animation.toValue = transform
                animation.duration = Double(durationMs) / 1000.0
                animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                animation.fillMode = .forwards
                animation.isRemovedOnCompletion = false

                CATransaction.begin()
                CATransaction.setCompletionBlock {
                    layer.transform = transform
                    self?.eventSink?("transform", "flipped", id, ["horizontal": horizontal, "vertical": vertical])
                }
                layer.add(animation, forKey: "flip")
                CATransaction.commit()
            } else {
                layer.transform = transform
                self?.eventSink?("transform", "flipped", id, ["horizontal": horizontal, "vertical": vertical])
            }

            result(nil)
        }
    }

    // MARK: - Reset

    private func reset(windowId: String?, result: @escaping FlutterResult) {
        guard let id = windowId, let window = store.get(id) else {
            result(FlutterError(code: "NOT_FOUND", message: "Window not found", details: nil))
            return
        }

        // Clear state
        scaleState.removeValue(forKey: id)
        rotationState.removeValue(forKey: id)
        flipState.removeValue(forKey: id)

        DispatchQueue.main.async { [weak self] in
            guard let layer = window.panel.contentView?.layer else {
                result(nil)
                return
            }

            layer.transform = CATransform3DIdentity
            self?.eventSink?("transform", "reset", id, [:])
            result(nil)
        }
    }

    // MARK: - Getters

    private func getScale(windowId: String?, result: @escaping FlutterResult) {
        guard let id = windowId else {
            result(1.0)
            return
        }
        // Return uniform scale (x) for simple API, or could return dictionary
        let state = scaleState[id]
        result(state?.x ?? 1.0)
    }

    private func getRotation(windowId: String?, result: @escaping FlutterResult) {
        guard let id = windowId else {
            result(0.0)
            return
        }
        result(rotationState[id] ?? 0.0)
    }

    private func getFlip(windowId: String?, result: @escaping FlutterResult) {
        guard let id = windowId else {
            result(["horizontal": false, "vertical": false])
            return
        }
        let state = flipState[id]
        result([
            "horizontal": state?.horizontal ?? false,
            "vertical": state?.vertical ?? false
        ])
    }
}
