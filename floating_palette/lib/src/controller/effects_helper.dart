import 'dart:math' show Random;

import 'package:flutter/painting.dart' show Alignment;

import '../services/animation_client.dart';

/// Shake direction for visual feedback.
enum ShakeDirection { horizontal, vertical, rotate, random }

/// Shake decay style.
enum ShakeDecay { none, linear, exponential, bounce }

/// Helper for palette feedback effects (shake, pulse, bounce).
///
/// Encapsulates animation sequences that compose multiple low-level
/// animation calls into high-level feedback effects.
class EffectsHelper {
  final AnimationClient _animation;

  const EffectsHelper(this._animation);

  /// Shake the palette for attention or error feedback.
  ///
  /// ```dart
  /// await effects.shake(paletteId, direction: ShakeDirection.horizontal);
  /// ```
  Future<void> shake(
    String id, {
    ShakeDirection direction = ShakeDirection.horizontal,
    double intensity = 10,
    int count = 3,
    Duration duration = const Duration(milliseconds: 300),
    ShakeDecay decay = ShakeDecay.exponential,
  }) async {
    final resolved = direction == ShakeDirection.random
        ? const [ShakeDirection.horizontal, ShakeDirection.vertical, ShakeDirection.rotate][Random().nextInt(3)]
        : direction;

    final property = switch (resolved) {
      ShakeDirection.horizontal => AnimatableProperty.x,
      ShakeDirection.vertical => AnimatableProperty.y,
      ShakeDirection.rotate => AnimatableProperty.rotation,
      ShakeDirection.random => throw StateError('unreachable'),
    };

    final from = resolved == ShakeDirection.rotate ? -0.05 : -intensity;
    final to = resolved == ShakeDirection.rotate ? 0.05 : intensity;

    await _animation.animate(
      id,
      property: property,
      from: from,
      to: to,
      durationMs: duration.inMilliseconds ~/ count,
      repeat: count,
      autoReverse: true,
    );
  }

  /// Pulse the palette with a scale animation.
  ///
  /// ```dart
  /// await effects.pulse(paletteId, maxScale: 1.1);
  /// ```
  Future<void> pulse(
    String id, {
    double maxScale = 1.1,
    int count = 2,
    Duration duration = const Duration(milliseconds: 400),
    Alignment anchor = Alignment.center,
  }) async {
    await _animation.animate(
      id,
      property: AnimatableProperty.scale,
      from: 1.0,
      to: maxScale,
      durationMs: duration.inMilliseconds ~/ count,
      repeat: count,
      autoReverse: true,
    );
  }

  /// Bounce the palette vertically.
  ///
  /// ```dart
  /// await effects.bounce(paletteId, height: 20);
  /// ```
  Future<void> bounce(
    String id, {
    double height = 20,
    int count = 2,
    Duration duration = const Duration(milliseconds: 400),
  }) async {
    await _animation.animate(
      id,
      property: AnimatableProperty.y,
      from: 0,
      to: -height,
      durationMs: duration.inMilliseconds ~/ count,
      curve: 'easeOut',
      repeat: count,
      autoReverse: true,
    );
  }
}
