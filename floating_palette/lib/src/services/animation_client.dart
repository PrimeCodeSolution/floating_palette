import 'dart:async';

import '../bridge/service_client.dart';

/// Animatable properties.
enum AnimatableProperty {
  x,
  y,
  width,
  height,
  opacity,
  scale,
  scaleX,
  scaleY,
  rotation,
}

/// Client for AnimationService.
///
/// Runs smooth 60fps animations natively.
class AnimationClient extends ServiceClient {
  AnimationClient(super.bridge);

  @override
  String get serviceName => 'animation';

  /// Animate a property.
  Future<void> animate(
    String id, {
    required AnimatableProperty property,
    required double from,
    required double to,
    required int durationMs,
    String curve = 'easeOut',
    int repeat = 1,
    bool autoReverse = false,
  }) async {
    await send<void>('animate', windowId: id, params: {
      'property': property.name,
      'from': from,
      'to': to,
      'durationMs': durationMs,
      'curve': curve,
      'repeat': repeat,
      'autoReverse': autoReverse,
    });
  }

  /// Animate multiple properties together.
  Future<void> animateMultiple(
    String id, {
    required List<PropertyAnimation> animations,
    required int durationMs,
    String curve = 'easeOut',
  }) async {
    await send<void>('animateMultiple', windowId: id, params: {
      'animations': animations.map((a) => a.toMap()).toList(),
      'durationMs': durationMs,
      'curve': curve,
    });
  }

  /// Stop animation on a property.
  Future<void> stop(String id, AnimatableProperty property) async {
    await send<void>('stop', windowId: id, params: {
      'property': property.name,
    });
  }

  /// Stop all animations on a window.
  Future<void> stopAll(String id) async {
    await send<void>('stopAll', windowId: id);
  }

  /// Check if a property is animating.
  Future<bool> isAnimating(String id, AnimatableProperty property) async {
    final result = await send<bool>('isAnimating', windowId: id, params: {
      'property': property.name,
    });
    return result ?? false;
  }

  // ════════════════════════════════════════════════════════════════════════
  // Events
  // ════════════════════════════════════════════════════════════════════════

  /// Called when an animation completes.
  void onCompleted(
    String id,
    AnimatableProperty property,
    void Function() callback,
  ) {
    onWindowEvent(id, 'complete', (event) {
      if (event.data['property'] == property.name) {
        callback();
      }
    });
  }

  /// Called when any animation completes.
  void onAnyCompleted(String id, void Function(AnimatableProperty) callback) {
    onWindowEvent(id, 'complete', (event) {
      final propName = event.data['property'] as String?;
      if (propName != null) {
        final prop = AnimatableProperty.values.firstWhere(
          (p) => p.name == propName,
          orElse: () => AnimatableProperty.x,
        );
        callback(prop);
      }
    });
  }
}

/// A single property animation spec.
class PropertyAnimation {
  final AnimatableProperty property;
  final double from;
  final double to;

  const PropertyAnimation({
    required this.property,
    required this.from,
    required this.to,
  });

  Map<String, dynamic> toMap() => {
        'property': property.name,
        'from': from,
        'to': to,
      };
}
