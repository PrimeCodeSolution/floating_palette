import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart' show MissingPluginException;

import '../bridge/native_bridge.dart';
import '../bridge/command.dart';

/// Platform capabilities detected at runtime.
///
/// Used to check what features are available on the current platform
/// and adapt behavior accordingly.
class Capabilities {
  /// Whether blur effects are supported.
  final bool blur;

  /// Whether 3D transforms are supported.
  final bool transform;

  /// Whether global hotkeys are supported.
  final bool globalHotkeys;

  /// Whether native glass effect is supported.
  final bool glassEffect;

  /// Whether multi-monitor is supported.
  final bool multiMonitor;

  /// Whether content sizing is supported.
  final bool contentSizing;

  /// Whether system-wide text selection detection is supported.
  final bool textSelection;

  /// The platform name (e.g., 'macos', 'windows').
  final String platform;

  /// The OS version string.
  final String osVersion;

  const Capabilities({
    required this.blur,
    required this.transform,
    required this.globalHotkeys,
    required this.glassEffect,
    required this.multiMonitor,
    required this.contentSizing,
    required this.textSelection,
    required this.platform,
    required this.osVersion,
  });

  /// Fetch capabilities from native layer.
  ///
  /// Returns [Capabilities.none] if the native layer doesn't support
  /// capability reporting (legacy plugin), but logs a warning.
  ///
  /// Throws on actual communication errors to surface bridge problems early.
  static Future<Capabilities> fetch(NativeBridge bridge) async {
    try {
      final result = await bridge.sendForMap(const NativeCommand(
        service: 'host',
        command: 'getCapabilities',
        params: {},
      ));

      if (result == null) {
        debugPrint(
          '[Capabilities] Native returned null. Using fallback capabilities. '
          'This may indicate an outdated native plugin.',
        );
        return const Capabilities.none();
      }

      return Capabilities(
        blur: result['blur'] as bool? ?? false,
        transform: result['transform'] as bool? ?? false,
        globalHotkeys: result['globalHotkeys'] as bool? ?? false,
        glassEffect: result['glassEffect'] as bool? ?? false,
        multiMonitor: result['multiMonitor'] as bool? ?? false,
        contentSizing: result['contentSizing'] as bool? ?? false,
        textSelection: result['textSelection'] as bool? ?? false,
        platform: result['platform'] as String? ?? 'unknown',
        osVersion: result['osVersion'] as String? ?? 'unknown',
      );
    } on MissingPluginException {
      // Legacy native plugin without capabilities support
      debugPrint(
        '[Capabilities] getCapabilities not implemented (legacy native). '
        'Using fallback capabilities.',
      );
      return const Capabilities.none();
    }
  }

  /// All capabilities enabled (for testing).
  const Capabilities.all()
      : blur = true,
        transform = true,
        globalHotkeys = true,
        glassEffect = true,
        multiMonitor = true,
        contentSizing = true,
        textSelection = true,
        platform = 'test',
        osVersion = 'test';

  /// No capabilities enabled (for testing or fallback).
  const Capabilities.none()
      : blur = false,
        transform = false,
        globalHotkeys = false,
        glassEffect = false,
        multiMonitor = false,
        contentSizing = false,
        textSelection = false,
        platform = 'unknown',
        osVersion = 'unknown';

  @override
  String toString() => 'Capabilities('
      'blur: $blur, '
      'transform: $transform, '
      'globalHotkeys: $globalHotkeys, '
      'glassEffect: $glassEffect, '
      'multiMonitor: $multiMonitor, '
      'contentSizing: $contentSizing, '
      'textSelection: $textSelection, '
      'platform: $platform, '
      'osVersion: $osVersion)';
}
