import Cocoa
import FlutterMacOS
import os.log

struct SnapBinding {
    let followerId: String
    let targetId: String
    let followerEdge: String  // top, bottom, left, right
    let targetEdge: String
    let alignment: String     // leading, center, trailing
    let gap: Double
    let onTargetHidden: String
    let onTargetDestroyed: String
    let useChildWindow: Bool  // true = native child window (instant), false = manual positioning
}

struct AutoSnapConfig {
    let acceptsSnapOn: Set<String>  // edges that accept incoming snaps
    let canSnapFrom: Set<String>    // edges that can snap to others
    let targetIds: Set<String>?     // nil = all palettes
    let proximityThreshold: Double
    let showFeedback: Bool
}

struct ProximityState {
    let draggedId: String
    let targetId: String
    let draggedEdge: String
    let targetEdge: String
}

/// Handles palette-to-palette snapping.
///
/// Uses native child windows for instant following - no lag.
/// Child windows automatically move with their parent at the OS level.
final class SnapService {
    private let store = WindowStore.shared
    private var eventSink: ((String, String, String?, [String: Any]) -> Void)?

    private var bindings: [String: SnapBinding] = [:]  // followerId -> binding
    private var hiddenFollowers: Set<String> = []      // Track hidden state

    // Auto-snap configuration per palette
    private var autoSnapConfigs: [String: AutoSnapConfig] = [:]

    // Current proximity state (dragged palette -> potential target)
    private var proximityState: ProximityState?

    // Note: userDraggingId removed - DragCoordinator now owns drag lifecycle

    // Track recently detached windows to prevent immediate re-snap
    // Maps windowId -> detach time
    private var recentlyDetached: [String: Date] = [:]
    private let detachCooldown: TimeInterval = 0.3  // 300ms cooldown before re-snap allowed

    func setEventSink(_ sink: @escaping (String, String, String?, [String: Any]) -> Void) {
        self.eventSink = sink
    }

    // MARK: - Commands

    func handle(_ command: String, windowId: String?, params: [String: Any], result: @escaping FlutterResult) {
        switch command {
        case "snap":
            snap(params: params, result: result)
        case "detach":
            detach(params: params, result: result)
        case "reSnap":
            reSnap(params: params, result: result)
        case "getSnapDistance":
            getSnapDistance(params: params, result: result)
        case "setAutoSnapConfig":
            setAutoSnapConfig(params: params, result: result)
        default:
            result(FlutterError(code: "UNKNOWN_COMMAND", message: "Unknown snap command: \(command)", details: nil))
        }
    }

    // MARK: - Auto-Snap Config Command

    private func setAutoSnapConfig(params: [String: Any], result: @escaping FlutterResult) {
        guard let paletteId = params["paletteId"] as? String,
              let configMap = params["config"] as? [String: Any] else {
            result(FlutterError(code: "INVALID_PARAMS", message: "paletteId and config required", details: nil))
            return
        }

        let acceptsOn = Set((configMap["acceptsSnapOn"] as? [String]) ?? [])
        let canFrom = Set((configMap["canSnapFrom"] as? [String]) ?? [])
        let targetIds = (configMap["targetIds"] as? [String]).map { Set($0) }

        // If config is effectively disabled, remove it
        if acceptsOn.isEmpty && canFrom.isEmpty {
            autoSnapConfigs.removeValue(forKey: paletteId)
        } else {
            autoSnapConfigs[paletteId] = AutoSnapConfig(
                acceptsSnapOn: acceptsOn,
                canSnapFrom: canFrom,
                targetIds: targetIds,
                proximityThreshold: configMap["proximityThreshold"] as? Double ?? 50,
                showFeedback: configMap["showFeedback"] as? Bool ?? true
            )
        }
        result(nil)
    }

    // MARK: - Snap Command

    private static let validEdges: Set<String> = ["top", "bottom", "left", "right"]

    private func snap(params: [String: Any], result: @escaping FlutterResult) {
        guard let followerId = params["followerId"] as? String,
              let targetId = params["targetId"] as? String,
              let followerEdge = params["followerEdge"] as? String,
              let targetEdge = params["targetEdge"] as? String else {
            result(FlutterError(code: "INVALID_PARAMS", message: "followerId, targetId, followerEdge, targetEdge required", details: nil))
            return
        }

        // Self-snap check
        if followerId == targetId {
            result(FlutterError(code: "INVALID_PARAMS", message: "Cannot snap a palette to itself", details: nil))
            return
        }

        // Edge validation
        if !SnapService.validEdges.contains(followerEdge) || !SnapService.validEdges.contains(targetEdge) {
            result(FlutterError(code: "INVALID_PARAMS", message: "Invalid edge: followerEdge=\(followerEdge), targetEdge=\(targetEdge)", details: nil))
            return
        }

        let alignment = params["alignment"] as? String ?? "center"
        let gap = params["gap"] as? Double ?? 0
        let config = params["config"] as? [String: Any] ?? [:]

        // Check if this is part of a bidirectional relationship
        // If target already follows this follower, we need manual positioning (not child windows)
        let isBidirectional = bindings[targetId]?.targetId == followerId

        let binding = SnapBinding(
            followerId: followerId,
            targetId: targetId,
            followerEdge: followerEdge,
            targetEdge: targetEdge,
            alignment: alignment,
            gap: gap,
            onTargetHidden: config["onTargetHidden"] as? String ?? "hideFollower",
            onTargetDestroyed: config["onTargetDestroyed"] as? String ?? "hideAndDetach",
            useChildWindow: !isBidirectional  // Use child window for simple follower mode
        )
        bindings[followerId] = binding

        // Clear any stale proximity state for this follower
        if proximityState?.draggedId == followerId {
            proximityState = nil
        }

        DispatchQueue.main.async { [weak self] in
            guard let self = self,
                  let followerWindow = self.store.get(followerId),
                  let targetWindow = self.store.get(targetId) else {
                result(FlutterError(code: "NOT_FOUND", message: "Window not found: follower=\(followerId), target=\(targetId)", details: nil))
                return
            }

            // Position follower at snap position
            self.positionFollower(binding)

            if binding.useChildWindow {
                // Use native child window for instant following (no lag)
                targetWindow.panel.addChildWindow(followerWindow.panel, ordered: .above)
            }

            self.eventSink?("snap", "snapped", followerId, ["targetId": targetId])
            result(nil)
        }
    }

    // MARK: - Detach Command

    private func detach(params: [String: Any], result: @escaping FlutterResult) {
        guard let followerId = params["followerId"] as? String else {
            result(FlutterError(code: "INVALID_PARAMS", message: "followerId required", details: nil))
            return
        }

        // Remove child window relationship if it exists
        if let binding = bindings[followerId],
           binding.useChildWindow,
           let followerWindow = store.get(followerId),
           let targetWindow = store.get(binding.targetId) {
            targetWindow.panel.removeChildWindow(followerWindow.panel)
        }

        bindings.removeValue(forKey: followerId)
        hiddenFollowers.remove(followerId)
        eventSink?("snap", "detached", followerId, ["reason": "command"])
        result(nil)
    }

    // MARK: - ReSnap Command

    private func reSnap(params: [String: Any], result: @escaping FlutterResult) {
        guard let followerId = params["followerId"] as? String,
              let binding = bindings[followerId],
              let followerWindow = store.get(followerId),
              let targetWindow = store.get(binding.targetId) else {
            result(FlutterError(code: "NOT_FOUND", message: "No binding for follower", details: nil))
            return
        }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else {
                result(nil)
                return
            }

            // Reposition follower
            self.positionFollower(binding)

            // Re-add as child window if using child window mode
            if binding.useChildWindow {
                // Remove first in case it's already a child
                targetWindow.panel.removeChildWindow(followerWindow.panel)
                targetWindow.panel.addChildWindow(followerWindow.panel, ordered: .above)
            }

            self.eventSink?("snap", "snapped", followerId, ["targetId": binding.targetId])
            result(nil)
        }
    }

    // MARK: - Get Snap Distance Command

    private func getSnapDistance(params: [String: Any], result: @escaping FlutterResult) {
        guard let followerId = params["followerId"] as? String,
              let binding = bindings[followerId],
              let follower = store.get(followerId) else {
            result(FlutterError(code: "NOT_FOUND", message: "No binding for follower", details: nil))
            return
        }

        let snapPosition = calculateSnapPosition(binding)
        let currentFrame = follower.panel.frame
        let distance = hypot(currentFrame.origin.x - snapPosition.x, currentFrame.origin.y - snapPosition.y)
        result(distance)
    }

    /// Public detach for internal use (e.g., when follower is destroyed)
    func detachFollower(_ followerId: String) {
        // Remove child window relationship if it exists
        if let binding = bindings[followerId],
           binding.useChildWindow,
           let followerWindow = store.get(followerId),
           let targetWindow = store.get(binding.targetId) {
            targetWindow.panel.removeChildWindow(followerWindow.panel)
            os_log("detachFollower removed child follower=%{public}@ target=%{public}@", log: Log.snap, type: .debug, followerId, binding.targetId)
        }

        bindings.removeValue(forKey: followerId)
        hiddenFollowers.remove(followerId)
        os_log("detachFollower cleared binding follower=%{public}@", log: Log.snap, type: .debug, followerId)
    }

    // Threshold for auto-detach when dragging a snapped follower (in points)
    private let detachThreshold: Double = 50

    // MARK: - Event Handlers (called by FrameService/WindowService)

    /// Called when user begins dragging a window.
    /// Now called by DragCoordinator via delegate.
    func onUserDragBegan(id: String) {
        os_log("dragBegan id=%{public}@", log: Log.snap, type: .debug, id)

        // If this is a snapped follower with child window, remove child relationship
        // so it can be dragged freely. Keep the binding for distance checking.
        if let binding = bindings[id],
           binding.useChildWindow,
           let followerWindow = store.get(id),
           let targetWindow = store.get(binding.targetId) {
            targetWindow.panel.removeChildWindow(followerWindow.panel)
            os_log("removed child link follower=%{public}@ target=%{public}@", log: Log.snap, type: .debug, id, binding.targetId)
        }

        // Clear any stale proximity state from previous drag
        if proximityState?.draggedId == id {
            proximityState = nil
        }
    }

    /// Called for non-drag window moves (programmatic, snap repositioning).
    /// User drags now go through onUserDragMoved via DragCoordinator.
    func onWindowMoved(id: String, frame: NSRect, isUserDrag: Bool) {
        // With DragCoordinator, isUserDrag should always be false here
        // User drag moves go through onUserDragMoved instead
        if isUserDrag {
            os_log("onWindowMoved with isUserDrag=true (legacy path) id=%{public}@", log: Log.snap, type: .debug, id)
        }
        // Non-drag moves don't trigger snap detection or follower drag handling
    }

    /// Called when a dragged window moves. Called by DragCoordinator via delegate.
    func onUserDragMoved(id: String, frame: NSRect) {
        os_log("onUserDragMoved ENTER id=%{public}@ hasBinding=%{public}@", log: Log.snap, type: .debug, id, String(bindings[id] != nil))

        // Handle snapped follower being dragged - check for auto-detach
        if let binding = bindings[id], binding.useChildWindow {
            os_log("followerDrag id=%{public}@ useChildWindow=%{public}@ frame=%{public}@", log: Log.snap, type: .debug, id, String(binding.useChildWindow), NSStringFromRect(frame))
            handleFollowerDrag(binding: binding, currentFrame: frame)
            return
        }

        // Check proximity for auto-snap when dragging an unsnapped window
        if bindings[id] == nil {
            os_log("freeDrag id=%{public}@ frame=%{public}@", log: Log.snap, type: .debug, id, NSStringFromRect(frame))
            checkProximity(draggedId: id, frame: frame)
        } else {
            os_log("onUserDragMoved SKIPPED - binding exists but useChildWindow=false id=%{public}@", log: Log.snap, type: .debug, id)
        }
    }

    /// Handle a snapped follower being dragged by the user.
    /// Checks distance from snap position and auto-detaches if beyond threshold.
    private func handleFollowerDrag(binding: SnapBinding, currentFrame: NSRect) {
        let snapPosition = calculateSnapPosition(binding)
        let distance = hypot(currentFrame.origin.x - snapPosition.x,
                             currentFrame.origin.y - snapPosition.y)

        // Emit dragging event with distance for visual feedback
        eventSink?("snap", "followerDragging", binding.followerId, [
            "targetId": binding.targetId,
            "snapDistance": distance,
            "frame": frameToMap(currentFrame)
        ])
        os_log("dragDistance follower=%{public}@ target=%{public}@ distance=%.1f", log: Log.snap, type: .debug, binding.followerId, binding.targetId, distance)

        if distance > detachThreshold {
            // Auto-detach: remove child window relationship
            detachFollower(binding.followerId)
            eventSink?("snap", "detached", binding.followerId, ["reason": "draggedAway"])
            os_log("detached follower=%{public}@ reason=draggedAway distance=%.1f", log: Log.snap, type: .debug, binding.followerId, distance)

            // Clear any proximity state to prevent stale state from causing re-snap
            if proximityState?.draggedId == binding.followerId {
                proximityState = nil
            }

            // Set cooldown to prevent immediate re-snap
            recentlyDetached[binding.followerId] = Date()
        }
    }

    /// Called when user stops dragging a window. Called by DragCoordinator via delegate.
    func onWindowDragEnded(id: String, frame: NSRect) {
        os_log("dragEnded id=%{public}@ frame=%{public}@", log: Log.snap, type: .debug, id, NSStringFromRect(frame))

        // If binding still exists (wasn't detached during drag), re-snap as child window
        if let binding = bindings[id], binding.useChildWindow {
            guard let followerWindow = store.get(id),
                  let targetWindow = store.get(binding.targetId) else {
                os_log("resnap failed: missing window follower=%{public}@ target=%{public}@", log: Log.snap, type: .error, id, binding.targetId)
                return
            }

            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }

                self.positionFollower(binding)
                targetWindow.panel.addChildWindow(followerWindow.panel, ordered: .above)

                self.eventSink?("snap", "snapped", id, ["targetId": binding.targetId])
                os_log("resnapped follower=%{public}@ target=%{public}@ (binding persisted)", log: Log.snap, type: .debug, id, binding.targetId)
            }
            return
        }

        // Check cooldown - don't auto-snap if recently detached
        if let detachTime = recentlyDetached[id] {
            if Date().timeIntervalSince(detachTime) < detachCooldown {
                // Still in cooldown, clear proximity state but don't snap
                if proximityState?.draggedId == id {
                    eventSink?("snap", "proximityExited", id, ["targetId": proximityState!.targetId])
                    proximityState = nil
                }
                return
            } else {
                // Cooldown expired, remove from tracking
                recentlyDetached.removeValue(forKey: id)
            }
        }

        // Auto-snap if in proximity
        if let prox = proximityState, prox.draggedId == id {
            guard let followerWindow = store.get(id),
                  let targetWindow = store.get(prox.targetId) else {
                proximityState = nil
                os_log("autoSnap failed: missing windows follower=%{public}@ target=%{public}@", log: Log.snap, type: .error, id, prox.targetId)
                return
            }

            // Create binding with child window for instant following
            let binding = SnapBinding(
                followerId: id,
                targetId: prox.targetId,
                followerEdge: prox.draggedEdge,
                targetEdge: prox.targetEdge,
                alignment: "center",
                gap: 4,
                onTargetHidden: "hideFollower",
                onTargetDestroyed: "hideAndDetach",
                useChildWindow: true
            )
            bindings[id] = binding

            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }

                self.positionFollower(binding)
                targetWindow.panel.addChildWindow(followerWindow.panel, ordered: .above)

                self.eventSink?("snap", "snapped", id, ["targetId": prox.targetId])
                os_log("autoSnapped follower=%{public}@ target=%{public}@ edge=%{public}@->%{public}@", log: Log.snap, type: .debug, id, prox.targetId, prox.draggedEdge, prox.targetEdge)
            }
            proximityState = nil
        }
    }

    func onWindowResized(id: String, frame: NSRect) {
        // When target resizes, reposition followers to maintain snap edge alignment
        for binding in bindings.values where binding.targetId == id {
            positionFollower(binding)
        }

        // When follower resizes, reposition to maintain snap
        if let binding = bindings[id] {
            positionFollower(binding)
        }
    }

    func onWindowHidden(id: String) {
        // If hidden window is a target, handle its followers
        for binding in bindings.values where binding.targetId == id {
            handleTargetHidden(binding)
        }
    }

    func onWindowShown(id: String) {
        // If shown window is a target, show hidden followers
        for binding in bindings.values where binding.targetId == id {
            if hiddenFollowers.contains(binding.followerId) {
                hiddenFollowers.remove(binding.followerId)
                if let followerWindow = store.get(binding.followerId) {
                    positionFollower(binding)
                    followerWindow.panel.orderFront(nil)
                    eventSink?("visibility", "shown", binding.followerId, [:])
                }
            }
        }
    }

    func onWindowDestroyed(id: String) {
        // Remove bindings where destroyed window is follower
        bindings.removeValue(forKey: id)
        hiddenFollowers.remove(id)

        // Remove auto-snap config for destroyed window
        autoSnapConfigs.removeValue(forKey: id)

        // Clear cooldown tracking
        recentlyDetached.removeValue(forKey: id)

        // Clear proximity state if it involves this window
        if proximityState?.draggedId == id || proximityState?.targetId == id {
            proximityState = nil
        }

        // Note: userDraggingId cleanup removed - DragCoordinator owns drag lifecycle

        // Handle bindings where destroyed window is target
        for binding in bindings.values where binding.targetId == id {
            handleTargetDestroyed(binding)
        }
    }

    // MARK: - Position Calculation

    private func positionFollower(_ binding: SnapBinding) {
        guard let followerWindow = store.get(binding.followerId) else { return }
        let position = calculateSnapPosition(binding)
        let currentSize = followerWindow.panel.frame.size
        followerWindow.panel.setFrame(
            NSRect(origin: position, size: currentSize),
            display: true
        )
    }

    /// Calculate the snap position for a follower without moving it.
    private func calculateSnapPosition(_ binding: SnapBinding) -> NSPoint {
        guard let targetWindow = store.get(binding.targetId),
              let followerWindow = store.get(binding.followerId) else {
            return NSPoint.zero
        }

        let targetFrame = targetWindow.panel.frame
        let followerSize = followerWindow.panel.frame.size

        let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)

        var x: CGFloat = 0
        var y: CGFloat = 0

        // Calculate position based on edges
        // Note: macOS Y is bottom-up
        switch (binding.followerEdge, binding.targetEdge) {
        case ("top", "bottom"):
            y = targetFrame.minY - followerSize.height - binding.gap
        case ("bottom", "top"):
            y = targetFrame.maxY + binding.gap
        case ("left", "right"):
            x = targetFrame.maxX + binding.gap
        case ("right", "left"):
            x = targetFrame.minX - followerSize.width - binding.gap
        default:
            break
        }

        // Calculate alignment
        let isVerticalSnap = binding.followerEdge == "top" || binding.followerEdge == "bottom"
        if isVerticalSnap {
            switch binding.alignment {
            case "leading":
                x = targetFrame.minX
            case "center":
                x = targetFrame.midX - followerSize.width / 2
            case "trailing":
                x = targetFrame.maxX - followerSize.width
            default:
                x = targetFrame.midX - followerSize.width / 2
            }
        } else {
            switch binding.alignment {
            case "leading":
                y = targetFrame.maxY - followerSize.height  // top in visual terms
            case "center":
                y = targetFrame.midY - followerSize.height / 2
            case "trailing":
                y = targetFrame.minY  // bottom in visual terms
            default:
                y = targetFrame.midY - followerSize.height / 2
            }
        }

        // Clamp to screen bounds
        let clampedX = max(screen.minX, min(x, screen.maxX - followerSize.width))
        let clampedY = max(screen.minY, min(y, screen.maxY - followerSize.height))

        return NSPoint(x: clampedX, y: clampedY)
    }

    /// Convert NSRect to a map for event payload.
    private func frameToMap(_ frame: NSRect) -> [String: Double] {
        return [
            "x": frame.origin.x,
            "y": frame.origin.y,
            "width": frame.size.width,
            "height": frame.size.height
        ]
    }

    private func handleTargetHidden(_ binding: SnapBinding) {
        switch binding.onTargetHidden {
        case "hideFollower":
            hiddenFollowers.insert(binding.followerId)
            if let followerWindow = store.get(binding.followerId) {
                followerWindow.panel.orderOut(nil)
                eventSink?("visibility", "hidden", binding.followerId, [:])
                os_log("targetHidden hideFollower follower=%{public}@ target=%{public}@", log: Log.snap, type: .debug, binding.followerId, binding.targetId)
            }
        case "detach":
            detachFollower(binding.followerId)
            eventSink?("snap", "detached", binding.followerId, ["reason": "targetHidden"])
            os_log("targetHidden detach follower=%{public}@ target=%{public}@", log: Log.snap, type: .debug, binding.followerId, binding.targetId)
        case "keepBinding":
            // Keep binding for re-attach on show
            break
        default:
            break
        }
    }

    private func handleTargetDestroyed(_ binding: SnapBinding) {
        switch binding.onTargetDestroyed {
        case "hideAndDetach":
            if let window = store.get(binding.followerId) {
                window.panel.orderOut(nil)
                eventSink?("visibility", "hidden", binding.followerId, [:])
            }
            detachFollower(binding.followerId)
            eventSink?("snap", "detached", binding.followerId, ["reason": "targetDestroyed"])
        case "detach":
            detachFollower(binding.followerId)
            eventSink?("snap", "detached", binding.followerId, ["reason": "targetDestroyed"])
        default:
            break
        }
    }

    // MARK: - Auto-Snap Proximity Detection

    /// Check if dragged window is in proximity of any snap-compatible window.
    private func checkProximity(draggedId: String, frame: NSRect) {
        // Skip proximity detection during cooldown after detach
        if let detachTime = recentlyDetached[draggedId] {
            if Date().timeIntervalSince(detachTime) < detachCooldown {
                // Still in cooldown - don't detect proximity
                // Clear any existing proximity state
                if proximityState?.draggedId == draggedId {
                    eventSink?("snap", "proximityExited", draggedId, ["targetId": proximityState!.targetId])
                    proximityState = nil
                }
                return
            } else {
                // Cooldown expired, remove from tracking
                recentlyDetached.removeValue(forKey: draggedId)
            }
        }

        guard let dragConfig = autoSnapConfigs[draggedId],
              !dragConfig.canSnapFrom.isEmpty else {
            // Clear proximity state if no longer configured
            if proximityState?.draggedId == draggedId {
                if let prox = proximityState {
                    eventSink?("snap", "proximityExited", draggedId, ["targetId": prox.targetId])
                }
                proximityState = nil
            }
            return
        }

        var bestMatch: (targetId: String, draggedEdge: String, targetEdge: String, distance: Double)?

        // Check all registered palettes with auto-snap configs
        for (targetId, targetConfig) in autoSnapConfigs {
            guard targetId != draggedId,
                  !targetConfig.acceptsSnapOn.isEmpty,
                  dragConfig.targetIds == nil || dragConfig.targetIds!.contains(targetId),
                  let targetWindow = store.get(targetId) else { continue }

            let targetFrame = targetWindow.panel.frame

            // Check each edge combination
            for dragEdge in dragConfig.canSnapFrom {
                for targetEdge in targetConfig.acceptsSnapOn {
                    guard areCompatibleEdges(dragEdge, targetEdge) else { continue }

                    let distance = calculateEdgeDistance(
                        dragged: frame, draggedEdge: dragEdge,
                        target: targetFrame, targetEdge: targetEdge
                    )

                    if distance < dragConfig.proximityThreshold {
                        if bestMatch == nil || distance < bestMatch!.distance {
                            bestMatch = (targetId, dragEdge, targetEdge, distance)
                        }
                    }
                }
            }
        }

        // Update proximity state
        if let match = bestMatch {
            if proximityState?.targetId != match.targetId ||
               proximityState?.draggedEdge != match.draggedEdge ||
               proximityState?.targetEdge != match.targetEdge {
                // New proximity or edge change
                if let prox = proximityState {
                    eventSink?("snap", "proximityExited", draggedId, ["targetId": prox.targetId])
                }
                proximityState = ProximityState(
                    draggedId: draggedId,
                    targetId: match.targetId,
                    draggedEdge: match.draggedEdge,
                    targetEdge: match.targetEdge
                )
                eventSink?("snap", "proximityEntered", draggedId, [
                    "targetId": match.targetId,
                    "draggedEdge": match.draggedEdge,
                    "targetEdge": match.targetEdge,
                    "distance": match.distance
                ])
            } else {
                // Same proximity, update distance
                eventSink?("snap", "proximityUpdated", draggedId, [
                    "targetId": match.targetId,
                    "distance": match.distance
                ])
            }
        } else if proximityState?.draggedId == draggedId {
            // Exited proximity
            eventSink?("snap", "proximityExited", draggedId, ["targetId": proximityState!.targetId])
            proximityState = nil
        }
    }

    /// Check if two edges are compatible for snapping (opposite edges).
    private func areCompatibleEdges(_ dragEdge: String, _ targetEdge: String) -> Bool {
        switch (dragEdge, targetEdge) {
        case ("top", "bottom"), ("bottom", "top"),
             ("left", "right"), ("right", "left"):
            return true
        default:
            return false
        }
    }

    /// Calculate distance between edges for proximity detection.
    private func calculateEdgeDistance(dragged: NSRect, draggedEdge: String,
                                       target: NSRect, targetEdge: String) -> Double {
        // First check if edges overlap (they need to be in range on the perpendicular axis)
        let isVerticalSnap = draggedEdge == "top" || draggedEdge == "bottom"

        if isVerticalSnap {
            // For vertical snap (top/bottom), check horizontal overlap
            let overlapX = max(0, min(dragged.maxX, target.maxX) - max(dragged.minX, target.minX))
            if overlapX <= 0 {
                return Double.infinity  // No horizontal overlap, can't snap
            }
        } else {
            // For horizontal snap (left/right), check vertical overlap
            let overlapY = max(0, min(dragged.maxY, target.maxY) - max(dragged.minY, target.minY))
            if overlapY <= 0 {
                return Double.infinity  // No vertical overlap, can't snap
            }
        }

        // Calculate edge distance
        switch (draggedEdge, targetEdge) {
        case ("top", "bottom"):
            return abs(dragged.maxY - target.minY)
        case ("bottom", "top"):
            return abs(dragged.minY - target.maxY)
        case ("left", "right"):
            return abs(dragged.minX - target.maxX)
        case ("right", "left"):
            return abs(dragged.maxX - target.minX)
        default:
            return Double.infinity
        }
    }
}

// MARK: - DragCoordinatorDelegate

extension SnapService: DragCoordinatorDelegate {
    func dragBegan(_ id: String) {
        onUserDragBegan(id: id)
    }

    func dragMoved(_ id: String, frame: NSRect) {
        onUserDragMoved(id: id, frame: frame)
    }

    func dragEnded(_ id: String, frame: NSRect) {
        onWindowDragEnded(id: id, frame: frame)
    }
}
