import 'package:flutter/foundation.dart' show debugPrint;

import 'capabilities.dart';

/// How to handle unsupported platform features.
enum UnsupportedBehavior {
  /// Throw [UnsupportedError] when feature is unavailable.
  ///
  /// Good for CI, strict apps, or catching issues early.
  throwError,

  /// Log warning once per feature, then no-op.
  ///
  /// Good for graceful degradation in production.
  warnOnce,

  /// Silent no-op - feature calls do nothing.
  ///
  /// Not recommended, but available for special cases.
  ignore,
}

/// Guards against using unsupported platform features.
///
/// Create one per controller to track warned features:
/// ```dart
/// final guard = CapabilityGuard(capabilities);
///
/// // In a method that uses blur:
/// guard.require(
///   capabilities.blur,
///   'Blur effect',
///   'Using solid background color as fallback.',
/// );
/// ```
class CapabilityGuard {
  /// The platform capabilities to check against.
  final Capabilities capabilities;

  /// How to handle unsupported features.
  final UnsupportedBehavior behavior;

  /// Features that have already warned (for warnOnce mode).
  final Set<String> _warned = {};

  CapabilityGuard(
    this.capabilities, {
    this.behavior = UnsupportedBehavior.warnOnce,
  });

  /// Check if a feature is supported and handle if not.
  ///
  /// Returns `true` if the feature is supported, `false` otherwise.
  ///
  /// [supported] - The capability flag to check.
  /// [feature] - Human-readable feature name for error messages.
  /// [fallback] - Description of fallback behavior (optional).
  ///
  /// Example:
  /// ```dart
  /// if (!guard.require(capabilities.blur, 'Blur effect', 'Using solid color.')) {
  ///   // Apply fallback
  ///   return;
  /// }
  /// // Feature is supported, proceed
  /// ```
  bool require(bool supported, String feature, [String? fallback]) {
    if (supported) return true;

    switch (behavior) {
      case UnsupportedBehavior.throwError:
        final message = StringBuffer()
          ..write('$feature is not supported on ${capabilities.platform}');
        if (fallback != null) {
          message.write('. $fallback');
        }
        throw UnsupportedError(message.toString());

      case UnsupportedBehavior.warnOnce:
        if (!_warned.contains(feature)) {
          _warned.add(feature);
          final message = StringBuffer()
            ..write('[FloatingPalette] $feature not supported on ${capabilities.platform}');
          if (fallback != null) {
            message.write('. $fallback');
          }
          debugPrint(message.toString());
        }
        return false;

      case UnsupportedBehavior.ignore:
        return false;
    }
  }

  /// Check blur support.
  bool requireBlur([String? fallback]) =>
      require(capabilities.blur, 'Blur effect', fallback);

  /// Check transform support.
  bool requireTransform([String? fallback]) =>
      require(capabilities.transform, '3D transforms', fallback);

  /// Check global hotkeys support.
  bool requireGlobalHotkeys([String? fallback]) =>
      require(capabilities.globalHotkeys, 'Global hotkeys', fallback);

  /// Check glass effect support.
  bool requireGlassEffect([String? fallback]) =>
      require(capabilities.glassEffect, 'Glass effect', fallback);

  /// Check multi-monitor support.
  bool requireMultiMonitor([String? fallback]) =>
      require(capabilities.multiMonitor, 'Multi-monitor', fallback);

  /// Check content sizing support.
  bool requireContentSizing([String? fallback]) =>
      require(capabilities.contentSizing, 'Content sizing', fallback);

  /// Clear warned features (for testing).
  void clearWarnings() => _warned.clear();
}
