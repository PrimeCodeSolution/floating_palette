/// Which edge of the window to snap.
enum SnapEdge {
  top,
  bottom,
  left,
  right;

  /// Get the opposite edge.
  SnapEdge get opposite => switch (this) {
        top => bottom,
        bottom => top,
        left => right,
        right => left,
      };
}

/// Alignment along the snapped edge.
enum SnapAlignment { leading, center, trailing }

/// Mode for snap relationships.
///
/// Determines how palettes move together when dragged.
enum SnapMode {
  /// One-way binding: only target movement affects follower.
  /// Default mode. Dragging the follower detaches or uses event handlers.
  follower,

  /// Two-way binding: dragging either palette moves the other.
  /// Creates bindings in both directions.
  bidirectional,
}

/// Behavior when target is hidden.
enum SnapOnTargetHidden { hideFollower, detach, keepBinding }

/// Behavior when target is destroyed.
enum SnapOnTargetDestroyed { hideAndDetach, detach }

/// Configuration for snap behavior.
///
/// Follower drag behavior is now event-driven - use [SnapEvent] handlers
/// to implement custom behavior (detach, re-snap, magnetic, etc.).
class SnapConfig {
  final SnapOnTargetHidden onTargetHidden;
  final SnapOnTargetDestroyed onTargetDestroyed;

  const SnapConfig({
    this.onTargetHidden = SnapOnTargetHidden.hideFollower,
    this.onTargetDestroyed = SnapOnTargetDestroyed.hideAndDetach,
  });

  /// Follower stays attached, follows target, hides with target.
  /// Use snap event handlers for drag behavior.
  static const attached = SnapConfig();

  /// Follower detaches when target is hidden.
  /// Use snap event handlers for drag behavior.
  static const loose = SnapConfig(
    onTargetHidden: SnapOnTargetHidden.detach,
  );

  Map<String, dynamic> toMap() => {
        'onTargetHidden': onTargetHidden.name,
        'onTargetDestroyed': onTargetDestroyed.name,
      };
}

/// Interface for objects that have a palette ID.
/// Implemented by PaletteController.
abstract interface class PaletteIdentifiable {
  String get id;
}

/// Per-palette auto-snap configuration.
///
/// Defines which edges can be snapped to/from and proximity behavior.
class AutoSnapConfig {
  /// Edges where other palettes can snap TO this palette.
  final Set<SnapEdge> acceptsSnapOn;

  /// Edges where this palette can snap FROM.
  final Set<SnapEdge> canSnapFrom;

  /// Palettes this palette can auto-snap to (null = all palettes).
  /// Use [targets] for type-safe controller references.
  final Set<String>? targetIds;

  /// Distance threshold for proximity detection (screen points).
  final double proximityThreshold;

  /// Whether to show visual feedback during proximity (emits proximity events).
  final bool showFeedback;

  const AutoSnapConfig({
    this.acceptsSnapOn = const {SnapEdge.top, SnapEdge.bottom, SnapEdge.left, SnapEdge.right},
    this.canSnapFrom = const {SnapEdge.top, SnapEdge.bottom, SnapEdge.left, SnapEdge.right},
    this.targetIds,
    this.proximityThreshold = 50.0,
    this.showFeedback = true,
  });

  /// Create config with type-safe target references.
  ///
  /// Example:
  /// ```dart
  /// AutoSnapConfig.withTargets(
  ///   targets: {Palettes.editor},
  ///   canSnapFrom: {SnapEdge.top},
  /// )
  /// ```
  factory AutoSnapConfig.withTargets({
    required Iterable<PaletteIdentifiable> targets,
    Set<SnapEdge> acceptsSnapOn = const {SnapEdge.top, SnapEdge.bottom, SnapEdge.left, SnapEdge.right},
    Set<SnapEdge> canSnapFrom = const {SnapEdge.top, SnapEdge.bottom, SnapEdge.left, SnapEdge.right},
    double proximityThreshold = 50.0,
    bool showFeedback = true,
  }) {
    return AutoSnapConfig(
      acceptsSnapOn: acceptsSnapOn,
      canSnapFrom: canSnapFrom,
      targetIds: targets.map((t) => t.id).toSet(),
      proximityThreshold: proximityThreshold,
      showFeedback: showFeedback,
    );
  }

  /// Auto-snap disabled for this palette.
  static const disabled = AutoSnapConfig(
    acceptsSnapOn: {},
    canSnapFrom: {},
  );

  /// Auto-snap enabled on all edges.
  static const allEdges = AutoSnapConfig();

  Map<String, dynamic> toMap() => {
        'acceptsSnapOn': acceptsSnapOn.map((e) => e.name).toList(),
        'canSnapFrom': canSnapFrom.map((e) => e.name).toList(),
        'targetIds': targetIds?.toList(),
        'proximityThreshold': proximityThreshold,
        'showFeedback': showFeedback,
      };
}
