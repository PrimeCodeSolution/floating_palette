import Cocoa
import FlutterMacOS

/// Handles host ↔ palette messaging.
final class MessageService {
    private let store = WindowStore.shared
    private var eventSink: ((String, String, String?, [String: Any]) -> Void)?

    func setEventSink(_ sink: @escaping (String, String, String?, [String: Any]) -> Void) {
        self.eventSink = sink
    }

    // MARK: - Commands

    func handle(_ command: String, windowId: String?, params: [String: Any], result: @escaping FlutterResult) {
        switch command {
        case "send":
            send(windowId: windowId, params: params, result: result)
        default:
            result(FlutterError(code: "UNKNOWN_COMMAND", message: "Unknown message command: \(command)", details: nil))
        }
    }

    // MARK: - Send to Palette (Host → Palette)

    private func send(windowId: String?, params: [String: Any], result: @escaping FlutterResult) {
        guard let id = windowId, let window = store.get(id) else {
            result(FlutterError(code: "NOT_FOUND", message: "Window not found", details: nil))
            return
        }

        guard let channel = window.messengerChannel else {
            result(FlutterError(code: "NO_CHANNEL", message: "Messenger channel not available", details: nil))
            return
        }

        let type = params["type"] as? String ?? ""
        let data = params["data"] as? [String: Any] ?? [:]

        DispatchQueue.main.async {
            // Send to palette via its messenger channel
            channel.invokeMethod("receive", arguments: [
                "type": type,
                "data": data
            ])
            result(nil)
        }
    }
}
