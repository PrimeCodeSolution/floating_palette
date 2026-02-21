import Cocoa
import FlutterMacOS

/// Handles window appearance: corner radius, shadow, background.
final class AppearanceService {
    private let store = WindowStore.shared
    private var eventSink: ((String, String, String?, [String: Any]) -> Void)?

    func setEventSink(_ sink: @escaping (String, String, String?, [String: Any]) -> Void) {
        self.eventSink = sink
    }

    // MARK: - Commands

    func handle(_ command: String, windowId: String?, params: [String: Any], result: @escaping FlutterResult) {
        switch command {
        case "setCornerRadius":
            setCornerRadius(windowId: windowId, params: params, result: result)
        case "setShadow":
            setShadow(windowId: windowId, params: params, result: result)
        case "setBackgroundColor":
            setBackgroundColor(windowId: windowId, params: params, result: result)
        case "setTransparent":
            setTransparent(windowId: windowId, params: params, result: result)
        case "setBlur":
            setBlur(windowId: windowId, params: params, result: result)
        case "applyAppearance":
            applyAppearance(windowId: windowId, params: params, result: result)
        default:
            result(FlutterError(code: "UNKNOWN_COMMAND", message: "Unknown appearance command: \(command)", details: nil))
        }
    }

    // MARK: - Corner Radius

    private func setCornerRadius(windowId: String?, params: [String: Any], result: @escaping FlutterResult) {
        guard let id = windowId, let window = store.get(id) else {
            result(FlutterError(code: "NOT_FOUND", message: "Window not found", details: nil))
            return
        }

        guard let radius = params["radius"] as? Double else {
            result(FlutterError(code: "INVALID_PARAMS", message: "radius required", details: nil))
            return
        }

        DispatchQueue.main.async {
            window.panel.contentView?.wantsLayer = true
            window.panel.contentView?.layer?.cornerRadius = radius
            window.panel.contentView?.layer?.masksToBounds = true
            result(nil)
        }
    }

    // MARK: - Shadow

    private func setShadow(windowId: String?, params: [String: Any], result: @escaping FlutterResult) {
        guard let id = windowId, let window = store.get(id) else {
            result(FlutterError(code: "NOT_FOUND", message: "Window not found", details: nil))
            return
        }

        // Accept both 'type' and 'shadow' param names for compatibility
        let shadowType = params["type"] as? String ?? params["shadow"] as? String ?? "standard"

        DispatchQueue.main.async {
            let panel = window.panel

            switch shadowType {
            case "none":
                panel.hasShadow = false

            case "subtle":
                panel.hasShadow = true
                if let layer = panel.contentView?.layer {
                    layer.shadowColor = NSColor.black.cgColor
                    layer.shadowOpacity = 0.1
                    layer.shadowOffset = CGSize(width: 0, height: -2)
                    layer.shadowRadius = 4
                }

            case "standard":
                panel.hasShadow = true
                if let layer = panel.contentView?.layer {
                    layer.shadowColor = NSColor.black.cgColor
                    layer.shadowOpacity = 0.2
                    layer.shadowOffset = CGSize(width: 0, height: -4)
                    layer.shadowRadius = 8
                }

            case "prominent":
                panel.hasShadow = true
                if let layer = panel.contentView?.layer {
                    layer.shadowColor = NSColor.black.cgColor
                    layer.shadowOpacity = 0.35
                    layer.shadowOffset = CGSize(width: 0, height: -6)
                    layer.shadowRadius = 16
                }

            default:
                panel.hasShadow = true
            }

            result(nil)
        }
    }

    // MARK: - Background Color

    private func setBackgroundColor(windowId: String?, params: [String: Any], result: @escaping FlutterResult) {
        guard let id = windowId, let window = store.get(id) else {
            result(FlutterError(code: "NOT_FOUND", message: "Window not found", details: nil))
            return
        }

        DispatchQueue.main.async {
            if let colorValue = params["color"] as? Int {
                let color = NSColor(
                    red: CGFloat((colorValue >> 16) & 0xFF) / 255.0,
                    green: CGFloat((colorValue >> 8) & 0xFF) / 255.0,
                    blue: CGFloat(colorValue & 0xFF) / 255.0,
                    alpha: CGFloat((colorValue >> 24) & 0xFF) / 255.0
                )
                window.panel.backgroundColor = color
            } else {
                window.panel.backgroundColor = .clear
            }
            result(nil)
        }
    }

    // MARK: - Transparency

    private func setTransparent(windowId: String?, params: [String: Any], result: @escaping FlutterResult) {
        guard let id = windowId, let window = store.get(id) else {
            result(FlutterError(code: "NOT_FOUND", message: "Window not found", details: nil))
            return
        }

        let transparent = params["transparent"] as? Bool ?? true

        DispatchQueue.main.async {
            window.panel.isOpaque = !transparent
            if transparent {
                window.panel.backgroundColor = .clear
            }
            result(nil)
        }
    }

    // MARK: - Apply All

    private func applyAppearance(windowId: String?, params: [String: Any], result: @escaping FlutterResult) {
        guard let id = windowId, let window = store.get(id) else {
            result(FlutterError(code: "NOT_FOUND", message: "Window not found", details: nil))
            return
        }

        DispatchQueue.main.async {
            let panel = window.panel

            // Corner radius
            if let radius = params["cornerRadius"] as? Double {
                panel.contentView?.wantsLayer = true
                panel.contentView?.layer?.cornerRadius = radius
                panel.contentView?.layer?.masksToBounds = true
            }

            // Shadow
            if let shadowType = params["shadow"] as? String {
                self.applyShadow(panel: panel, type: shadowType)
            }

            // Transparency
            if let transparent = params["transparent"] as? Bool {
                panel.isOpaque = !transparent
                if transparent {
                    panel.backgroundColor = .clear
                }
            }

            // Background color
            if let colorValue = params["backgroundColor"] as? Int {
                let color = NSColor(
                    red: CGFloat((colorValue >> 16) & 0xFF) / 255.0,
                    green: CGFloat((colorValue >> 8) & 0xFF) / 255.0,
                    blue: CGFloat(colorValue & 0xFF) / 255.0,
                    alpha: CGFloat((colorValue >> 24) & 0xFF) / 255.0
                )
                panel.backgroundColor = color
            }

            result(nil)
        }
    }

    private func applyShadow(panel: NSPanel, type: String) {
        switch type {
        case "none":
            panel.hasShadow = false

        case "subtle":
            panel.hasShadow = true
            if let layer = panel.contentView?.layer {
                layer.shadowColor = NSColor.black.cgColor
                layer.shadowOpacity = 0.1
                layer.shadowOffset = CGSize(width: 0, height: -2)
                layer.shadowRadius = 4
            }

        case "standard":
            panel.hasShadow = true
            if let layer = panel.contentView?.layer {
                layer.shadowColor = NSColor.black.cgColor
                layer.shadowOpacity = 0.2
                layer.shadowOffset = CGSize(width: 0, height: -4)
                layer.shadowRadius = 8
            }

        case "prominent":
            panel.hasShadow = true
            if let layer = panel.contentView?.layer {
                layer.shadowColor = NSColor.black.cgColor
                layer.shadowOpacity = 0.35
                layer.shadowOffset = CGSize(width: 0, height: -6)
                layer.shadowRadius = 16
            }

        default:
            panel.hasShadow = true
        }
    }

    // MARK: - Blur

    private func setBlur(windowId: String?, params: [String: Any], result: @escaping FlutterResult) {
        guard let id = windowId, let window = store.get(id) else {
            result(FlutterError(code: "NOT_FOUND", message: "Window not found", details: nil))
            return
        }

        let enabled = params["enabled"] as? Bool ?? true
        let material = params["material"] as? String ?? "hudWindow"

        DispatchQueue.main.async {
            let panel = window.panel

            if enabled {
                // Add visual effect view for blur
                let blurView = NSVisualEffectView()
                blurView.material = self.blurMaterial(for: material)
                blurView.blendingMode = .behindWindow
                blurView.state = .active
                blurView.wantsLayer = true

                if let contentView = panel.contentView {
                    blurView.frame = contentView.bounds
                    blurView.autoresizingMask = [.width, .height]
                    contentView.addSubview(blurView, positioned: .below, relativeTo: nil)
                }
            } else {
                // Remove blur views
                panel.contentView?.subviews.filter { $0 is NSVisualEffectView }.forEach { $0.removeFromSuperview() }
            }

            result(nil)
        }
    }

    private func blurMaterial(for name: String) -> NSVisualEffectView.Material {
        switch name {
        case "titlebar": return .titlebar
        case "selection": return .selection
        case "menu": return .menu
        case "popover": return .popover
        case "sidebar": return .sidebar
        case "headerView": return .headerView
        case "sheet": return .sheet
        case "windowBackground": return .windowBackground
        case "hudWindow": return .hudWindow
        case "fullScreenUI": return .fullScreenUI
        case "toolTip": return .toolTip
        case "contentBackground": return .contentBackground
        case "underWindowBackground": return .underWindowBackground
        case "underPageBackground": return .underPageBackground
        default: return .hudWindow
        }
    }
}
