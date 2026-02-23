import 'package:flutter/foundation.dart' show debugPrint;

import '../bridge/service_client.dart';
import '../snap/snap_events.dart';
import '../snap/snap_types.dart';

export '../snap/snap_types.dart' show AutoSnapConfig;

/// Client for SnapService.
///
/// Handles palette-to-palette snapping. All snap logic lives in native
/// for zero-latency follower movement.
class SnapClient extends ServiceClient {
  SnapClient(super.bridge);

  @override
  String get serviceName => 'snap';

  /// Snap a follower palette to a target palette.
  ///
  /// The follower will be positioned relative to the target's edge
  /// and will follow the target's movement.
  Future<void> snap({
    required String followerId,
    required String targetId,
    required SnapEdge followerEdge,
    required SnapEdge targetEdge,
    SnapAlignment alignment = SnapAlignment.center,
    double gap = 0,
    SnapConfig config = const SnapConfig(),
  }) async {
    if (followerId.isEmpty || targetId.isEmpty) {
      debugPrint('[SnapClient] snap() called with empty ID — ignoring');
      return;
    }
    if (followerId == targetId) {
      debugPrint('[SnapClient] snap() called with self-snap — ignoring');
      return;
    }
    await send<void>('snap', params: {
      'followerId': followerId,
      'targetId': targetId,
      'followerEdge': followerEdge.name,
      'targetEdge': targetEdge.name,
      'alignment': alignment.name,
      'gap': gap,
      'config': config.toMap(),
    });
  }

  /// Detach a follower from its snap target.
  ///
  /// This removes both the snap binding and the child window relationship,
  /// so the follower will no longer follow the target's movement.
  Future<void> detach(String followerId) async {
    await send<void>('detach', params: {
      'followerId': followerId,
    });
  }

  /// Re-snap follower to its target's snap position.
  ///
  /// Use this to snap the follower back after user drags it.
  /// Only works if follower has an existing snap binding.
  Future<void> reSnap(String followerId) async {
    await send<void>('reSnap', params: {
      'followerId': followerId,
    });
  }

  /// Get current distance from follower to its snap position.
  ///
  /// Returns the Euclidean distance in screen points.
  /// Useful for implementing magnetic snap behavior.
  Future<double> getSnapDistance(String followerId) async {
    final result = await send<double>('getSnapDistance', params: {
      'followerId': followerId,
    });
    if (result == null) {
      debugPrint('[SnapClient] getSnapDistance($followerId) returned null — using fallback');
      return 0.0;
    }
    return result;
  }

  /// Register auto-snap configuration for a palette.
  ///
  /// When enabled, the palette will automatically snap to compatible
  /// palettes when dragged within proximity threshold.
  Future<void> setAutoSnapConfig(String paletteId, AutoSnapConfig config) async {
    await send<void>('setAutoSnapConfig', params: {
      'paletteId': paletteId,
      'config': config.toMap(),
    });
  }

  /// Disable auto-snap for a palette.
  Future<void> disableAutoSnap(String paletteId) async {
    await send<void>('setAutoSnapConfig', params: {
      'paletteId': paletteId,
      'config': AutoSnapConfig.disabled.toMap(),
    });
  }

  /// Listen for snap events on a specific follower.
  ///
  /// Events include:
  /// - [SnapDragStarted] - User starts dragging the follower
  /// - [SnapDragging] - During drag (for live distance updates)
  /// - [SnapDragEnded] - User releases the drag
  /// - [SnapDetached] - Snap binding was removed
  /// - [SnapSnapped] - Follower was snapped to target
  /// - [SnapProximityEntered] - Dragged palette enters snap zone
  /// - [SnapProximityExited] - Dragged palette exits snap zone
  /// - [SnapProximityUpdated] - Distance changes during drag in snap zone
  ///
  /// Example: Implement magnetic snap behavior:
  /// ```dart
  /// snapClient.onSnapEvent(followerId, (event) {
  ///   if (event is SnapDragEnded) {
  ///     if (event.snapDistance < 50) {
  ///       snapClient.reSnap(followerId);  // Close enough, snap back
  ///     } else {
  ///       snapClient.detach(followerId);  // Too far, fully detach
  ///     }
  ///   }
  /// });
  /// ```
  void onSnapEvent(String followerId, void Function(SnapEvent) callback) {
    onWindowEvent(followerId, 'followerDragStarted', (e) {
      callback(SnapDragStarted.fromEventData(
        followerId,
        Map<String, dynamic>.from(e.data),
      ));
    });
    onWindowEvent(followerId, 'followerDragging', (e) {
      callback(SnapDragging.fromEventData(
        followerId,
        Map<String, dynamic>.from(e.data),
      ));
    });
    onWindowEvent(followerId, 'followerDragEnded', (e) {
      callback(SnapDragEnded.fromEventData(
        followerId,
        Map<String, dynamic>.from(e.data),
      ));
    });
    onWindowEvent(followerId, 'detached', (e) {
      callback(SnapDetached.fromEventData(
        followerId,
        Map<String, dynamic>.from(e.data),
      ));
    });
    onWindowEvent(followerId, 'snapped', (e) {
      callback(SnapSnapped.fromEventData(
        followerId,
        Map<String, dynamic>.from(e.data),
      ));
    });
    onWindowEvent(followerId, 'proximityEntered', (e) {
      callback(SnapProximityEntered.fromEventData(
        followerId,
        Map<String, dynamic>.from(e.data),
      ));
    });
    onWindowEvent(followerId, 'proximityExited', (e) {
      callback(SnapProximityExited.fromEventData(
        followerId,
        Map<String, dynamic>.from(e.data),
      ));
    });
    onWindowEvent(followerId, 'proximityUpdated', (e) {
      callback(SnapProximityUpdated.fromEventData(
        followerId,
        Map<String, dynamic>.from(e.data),
      ));
    });
  }
}
