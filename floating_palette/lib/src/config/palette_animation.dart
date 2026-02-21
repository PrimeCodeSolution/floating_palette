import 'package:flutter/animation.dart';

/// Animation configuration for palette show/hide transitions.
class PaletteAnimation {
  /// Duration of the show animation.
  final Duration showDuration;

  /// Duration of the hide animation.
  final Duration hideDuration;

  /// Curve for animations.
  final Curve curve;

  /// Whether to animate at all.
  final bool enabled;

  const PaletteAnimation({
    this.showDuration = const Duration(milliseconds: 150),
    this.hideDuration = const Duration(milliseconds: 100),
    this.curve = Curves.easeOutCubic,
    this.enabled = true,
  });

  /// No animation - instant show/hide.
  const PaletteAnimation.none()
      : showDuration = Duration.zero,
        hideDuration = Duration.zero,
        curve = Curves.linear,
        enabled = false;

  /// Fast animation for responsive feel.
  const PaletteAnimation.fast()
      : showDuration = const Duration(milliseconds: 100),
        hideDuration = const Duration(milliseconds: 50),
        curve = Curves.easeOut,
        enabled = true;

  /// Smooth animation for polished feel.
  const PaletteAnimation.smooth()
      : showDuration = const Duration(milliseconds: 200),
        hideDuration = const Duration(milliseconds: 150),
        curve = Curves.easeInOutCubic,
        enabled = true;

  PaletteAnimation copyWith({
    Duration? showDuration,
    Duration? hideDuration,
    Curve? curve,
    bool? enabled,
  }) {
    return PaletteAnimation(
      showDuration: showDuration ?? this.showDuration,
      hideDuration: hideDuration ?? this.hideDuration,
      curve: curve ?? this.curve,
      enabled: enabled ?? this.enabled,
    );
  }

  Map<String, dynamic> toMap() => {
        'showDurationMs': showDuration.inMilliseconds,
        'hideDurationMs': hideDuration.inMilliseconds,
        'curve': curve.toString(),
        'enabled': enabled,
      };
}
