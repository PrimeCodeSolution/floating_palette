import 'dart:ui';

/// How the palette anchors to its target.
enum Anchor {
  topLeft,
  topCenter,
  topRight,
  centerLeft,
  center,
  centerRight,
  bottomLeft,
  bottomCenter,
  bottomRight,
}

/// What the palette positions relative to.
enum Target {
  /// Position near the cursor.
  cursor,

  /// Position relative to screen center.
  screen,

  /// Position at a specific offset (use [PalettePosition.at]).
  custom,
}

/// Position configuration for a palette.
class PalettePosition {
  /// Which corner/edge of the palette anchors to the target.
  final Anchor anchor;

  /// What the palette positions relative to.
  final Target target;

  /// Offset from the target point.
  final Offset offset;

  /// Whether to adjust position to stay within screen bounds.
  final bool avoidEdges;

  /// Custom position (only used when [target] is [Target.custom]).
  final Offset? customPosition;

  const PalettePosition({
    this.anchor = Anchor.topLeft,
    this.target = Target.cursor,
    this.offset = Offset.zero,
    this.avoidEdges = true,
    this.customPosition,
  });

  /// Position near the cursor with optional offset.
  PalettePosition.nearCursor({
    this.offset = const Offset(0, 8),
    this.anchor = Anchor.topLeft,
  })  : target = Target.cursor,
        avoidEdges = true,
        customPosition = null;

  /// Position at screen center with optional Y offset.
  ///
  /// The palette is centered horizontally and vertically on screen,
  /// with optional Y offset to position slightly above center.
  PalettePosition.centerScreen({
    double yOffset = 0,
  })  : target = Target.screen,
        anchor = Anchor.center,
        offset = Offset(0, yOffset),
        avoidEdges = true,
        customPosition = null;

  /// Position at a specific screen coordinate.
  const PalettePosition.at(Offset position)
      : target = Target.custom,
        anchor = Anchor.topLeft,
        offset = Offset.zero,
        avoidEdges = true,
        customPosition = position;

  PalettePosition copyWith({
    Anchor? anchor,
    Target? target,
    Offset? offset,
    bool? avoidEdges,
    Offset? customPosition,
  }) {
    return PalettePosition(
      anchor: anchor ?? this.anchor,
      target: target ?? this.target,
      offset: offset ?? this.offset,
      avoidEdges: avoidEdges ?? this.avoidEdges,
      customPosition: customPosition ?? this.customPosition,
    );
  }

  Map<String, dynamic> toMap() => {
        'anchor': anchor.name,
        'target': target.name,
        'offsetX': offset.dx,
        'offsetY': offset.dy,
        'avoidEdges': avoidEdges,
        if (customPosition != null) 'customX': customPosition!.dx,
        if (customPosition != null) 'customY': customPosition!.dy,
      };
}
