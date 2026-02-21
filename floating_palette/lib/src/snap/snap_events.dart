import 'dart:ui' show Rect;

/// Base class for snap-related events from native.
sealed class SnapEvent {
  final String followerId;

  const SnapEvent(this.followerId);
}

/// Emitted when user starts dragging a snapped follower.
class SnapDragStarted extends SnapEvent {
  final Rect frame;
  final double snapDistance;

  const SnapDragStarted({
    required String followerId,
    required this.frame,
    required this.snapDistance,
  }) : super(followerId);

  factory SnapDragStarted.fromEventData(String followerId, Map<String, dynamic> data) {
    final frameData = data['frame'] as Map<dynamic, dynamic>? ?? {};
    return SnapDragStarted(
      followerId: followerId,
      frame: Rect.fromLTWH(
        (frameData['x'] as num?)?.toDouble() ?? 0,
        (frameData['y'] as num?)?.toDouble() ?? 0,
        (frameData['width'] as num?)?.toDouble() ?? 0,
        (frameData['height'] as num?)?.toDouble() ?? 0,
      ),
      snapDistance: (data['snapDistance'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// Emitted during dragging of a snapped follower (throttled).
class SnapDragging extends SnapEvent {
  final Rect frame;
  final double snapDistance;

  const SnapDragging({
    required String followerId,
    required this.frame,
    required this.snapDistance,
  }) : super(followerId);

  factory SnapDragging.fromEventData(String followerId, Map<String, dynamic> data) {
    final frameData = data['frame'] as Map<dynamic, dynamic>? ?? {};
    return SnapDragging(
      followerId: followerId,
      frame: Rect.fromLTWH(
        (frameData['x'] as num?)?.toDouble() ?? 0,
        (frameData['y'] as num?)?.toDouble() ?? 0,
        (frameData['width'] as num?)?.toDouble() ?? 0,
        (frameData['height'] as num?)?.toDouble() ?? 0,
      ),
      snapDistance: (data['snapDistance'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// Emitted when user releases a dragged snapped follower.
class SnapDragEnded extends SnapEvent {
  final Rect frame;
  final double snapDistance;

  const SnapDragEnded({
    required String followerId,
    required this.frame,
    required this.snapDistance,
  }) : super(followerId);

  factory SnapDragEnded.fromEventData(String followerId, Map<String, dynamic> data) {
    final frameData = data['frame'] as Map<dynamic, dynamic>? ?? {};
    return SnapDragEnded(
      followerId: followerId,
      frame: Rect.fromLTWH(
        (frameData['x'] as num?)?.toDouble() ?? 0,
        (frameData['y'] as num?)?.toDouble() ?? 0,
        (frameData['width'] as num?)?.toDouble() ?? 0,
        (frameData['height'] as num?)?.toDouble() ?? 0,
      ),
      snapDistance: (data['snapDistance'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// Emitted when a snap binding is removed.
class SnapDetached extends SnapEvent {
  final String reason;

  const SnapDetached({
    required String followerId,
    required this.reason,
  }) : super(followerId);

  factory SnapDetached.fromEventData(String followerId, Map<String, dynamic> data) {
    return SnapDetached(
      followerId: followerId,
      reason: data['reason'] as String? ?? 'unknown',
    );
  }
}

/// Emitted when a follower is snapped to a target.
class SnapSnapped extends SnapEvent {
  final String targetId;

  const SnapSnapped({
    required String followerId,
    required this.targetId,
  }) : super(followerId);

  factory SnapSnapped.fromEventData(String followerId, Map<String, dynamic> data) {
    return SnapSnapped(
      followerId: followerId,
      targetId: data['targetId'] as String? ?? '',
    );
  }
}

/// Emitted when a dragged palette enters a snap zone of another palette.
class SnapProximityEntered extends SnapEvent {
  final String targetId;
  final String draggedEdge;
  final String targetEdge;
  final double distance;

  const SnapProximityEntered({
    required String followerId,
    required this.targetId,
    required this.draggedEdge,
    required this.targetEdge,
    required this.distance,
  }) : super(followerId);

  factory SnapProximityEntered.fromEventData(String followerId, Map<String, dynamic> data) {
    return SnapProximityEntered(
      followerId: followerId,
      targetId: data['targetId'] as String? ?? '',
      draggedEdge: data['draggedEdge'] as String? ?? '',
      targetEdge: data['targetEdge'] as String? ?? '',
      distance: (data['distance'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// Emitted when a dragged palette exits a snap zone.
class SnapProximityExited extends SnapEvent {
  final String targetId;

  const SnapProximityExited({
    required String followerId,
    required this.targetId,
  }) : super(followerId);

  factory SnapProximityExited.fromEventData(String followerId, Map<String, dynamic> data) {
    return SnapProximityExited(
      followerId: followerId,
      targetId: data['targetId'] as String? ?? '',
    );
  }
}

/// Emitted during drag while in snap proximity (distance changes).
class SnapProximityUpdated extends SnapEvent {
  final String targetId;
  final double distance;

  const SnapProximityUpdated({
    required String followerId,
    required this.targetId,
    required this.distance,
  }) : super(followerId);

  factory SnapProximityUpdated.fromEventData(String followerId, Map<String, dynamic> data) {
    return SnapProximityUpdated(
      followerId: followerId,
      targetId: data['targetId'] as String? ?? '',
      distance: (data['distance'] as num?)?.toDouble() ?? 0,
    );
  }
}
