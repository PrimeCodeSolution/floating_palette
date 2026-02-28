import Cocoa
import FlutterMacOS

/// Service for host-level operations.
///
/// Handles protocol version, capabilities, and window snapshots.
class HostService {
    /// Protocol version - increment when API changes.
    private static let protocolVersion = 1

    /// Minimum Dart version this native plugin supports.
    private static let minDartVersion = 1

    /// Maximum Dart version this native plugin supports.
    private static let maxDartVersion = 1

    private var eventSink: ((String, String, String?, [String: Any]) -> Void)?

    func setEventSink(_ sink: @escaping (String, String, String?, [String: Any]) -> Void) {
        self.eventSink = sink
    }

    func handle(_ command: String, windowId: String?, params: [String: Any], result: @escaping FlutterResult) {
        switch command {
        case "getProtocolVersion":
            result([
                "version": HostService.protocolVersion,
                "minDartVersion": HostService.minDartVersion,
                "maxDartVersion": HostService.maxDartVersion,
            ])

        case "getCapabilities":
            result(getCapabilities())

        case "getServiceVersion":
            if let service = params["service"] as? String {
                result(getServiceVersion(service))
            } else {
                result(FlutterError(code: "INVALID_PARAMS", message: "Missing 'service' parameter", details: nil))
            }

        case "getSnapshot":
            result(getSnapshot())

        case "ping":
            result(true)

        default:
            result(FlutterError(code: "UNKNOWN_COMMAND", message: "Unknown host command: \(command)", details: nil))
        }
    }

    // MARK: - Capabilities

    private func getCapabilities() -> [String: Any] {
        let osVersion = ProcessInfo.processInfo.operatingSystemVersionString

        return [
            "blur": true,
            "transform": true,
            "globalHotkeys": true,
            "glassEffect": true,
            "multiMonitor": true,
            "contentSizing": true,
            "textSelection": true,
            "platform": "macos",
            "osVersion": osVersion,
        ]
    }

    // MARK: - Service Versions

    private func getServiceVersion(_ service: String) -> [String: Any] {
        // All services are at version 1
        let versions: [String: Int] = [
            "window": 1,
            "visibility": 1,
            "frame": 1,
            "transform": 1,
            "animation": 1,
            "input": 1,
            "focus": 1,
            "zorder": 1,
            "appearance": 1,
            "screen": 1,
            "message": 1,
            "host": 1,
        ]

        return [
            "service": service,
            "version": versions[service] ?? 0,
        ]
    }

    // MARK: - Snapshot (Hot Restart Recovery)

    private func getSnapshot() -> [[String: Any]] {
        var snapshots: [[String: Any]] = []

        for (id, window) in WindowStore.shared.all() {
            let frame = window.frame
            let isVisible = window.isVisible
            let isKey = window.panel.isKeyWindow

            snapshots.append([
                "id": id,
                "visible": isVisible,
                "x": frame.origin.x,
                "y": frame.origin.y,
                "width": frame.size.width,
                "height": frame.size.height,
                "focused": isKey,
            ])
        }

        return snapshots
    }

    // MARK: - Events

    func sendAppActivated() {
        eventSink?("host", "appActivated", nil, [:])
    }

    func sendAppDeactivated() {
        eventSink?("host", "appDeactivated", nil, [:])
    }

    func sendAppWillTerminate() {
        eventSink?("host", "appWillTerminate", nil, [:])
    }
}
