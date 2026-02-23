import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart' show debugPrint;

import '../bridge/service_client.dart';

/// Information about the active (frontmost) application window.
class ActiveAppInfo {
  final Rect bounds;
  final String appName;

  const ActiveAppInfo({
    required this.bounds,
    required this.appName,
  });

  factory ActiveAppInfo.fromMap(Map<String, dynamic> map) {
    return ActiveAppInfo(
      bounds: Rect.fromLTWH(
        (map['x'] as num?)?.toDouble() ?? 0,
        (map['y'] as num?)?.toDouble() ?? 0,
        (map['width'] as num?)?.toDouble() ?? 0,
        (map['height'] as num?)?.toDouble() ?? 0,
      ),
      appName: map['appName'] as String? ?? '',
    );
  }
}

/// Information about a screen/monitor.
class ScreenInfo {
  final int index;
  final Rect bounds;
  final Rect workArea;
  final double scaleFactor;
  final bool isPrimary;

  const ScreenInfo({
    required this.index,
    required this.bounds,
    required this.workArea,
    required this.scaleFactor,
    required this.isPrimary,
  });

  factory ScreenInfo.fromMap(Map<String, dynamic> map) {
    // Parse nested frame objects from native
    final frame = map['frame'] as Map<dynamic, dynamic>? ?? {};
    final visibleFrame = map['visibleFrame'] as Map<dynamic, dynamic>? ?? {};

    return ScreenInfo(
      index: (map['id'] as num?)?.toInt() ?? 0,
      bounds: Rect.fromLTWH(
        (frame['x'] as num?)?.toDouble() ?? 0,
        (frame['y'] as num?)?.toDouble() ?? 0,
        (frame['width'] as num?)?.toDouble() ?? 0,
        (frame['height'] as num?)?.toDouble() ?? 0,
      ),
      workArea: Rect.fromLTWH(
        (visibleFrame['x'] as num?)?.toDouble() ?? 0,
        (visibleFrame['y'] as num?)?.toDouble() ?? 0,
        (visibleFrame['width'] as num?)?.toDouble() ?? 0,
        (visibleFrame['height'] as num?)?.toDouble() ?? 0,
      ),
      scaleFactor: (map['scaleFactor'] as num?)?.toDouble() ?? 1.0,
      isPrimary: map['isPrimary'] as bool? ?? false,
    );
  }
}

/// Client for ScreenService.
///
/// Handles multi-monitor support.
class ScreenClient extends ServiceClient {
  ScreenClient(super.bridge);

  @override
  String get serviceName => 'screen';

  /// Get all available screens.
  Future<List<ScreenInfo>> getScreens() async {
    final result = await send<List<dynamic>>('getScreens');
    if (result == null) {
      debugPrint('[ScreenClient] getScreens() returned null — using fallback');
      return [];
    }
    return result
        .cast<Map<dynamic, dynamic>>()
        .map((m) => ScreenInfo.fromMap(m.cast<String, dynamic>()))
        .toList();
  }

  /// Get the screen a window is on.
  Future<int> getWindowScreen(String id) async {
    final result = await send<int>('getWindowScreen', windowId: id);
    if (result == null) {
      debugPrint('[ScreenClient] getWindowScreen($id) returned null — using fallback');
      return 0;
    }
    return result;
  }

  /// Move window to a specific screen.
  Future<void> moveToScreen(
    String id,
    int screenIndex, {
    bool animate = false,
    int? durationMs,
  }) async {
    await send<void>('moveToScreen', windowId: id, params: {
      'screenIndex': screenIndex,
      'animate': animate,
      'durationMs': ?durationMs,
    });
  }

  /// Get cursor position.
  Future<Offset> getCursorPosition() async {
    final result = await sendForMap('getCursorPosition');
    if (result == null) {
      debugPrint('[ScreenClient] getCursorPosition() returned null — using fallback');
      return Offset.zero;
    }
    return Offset(
      (result['x'] as num).toDouble(),
      (result['y'] as num).toDouble(),
    );
  }

  /// Get the screen the cursor is on.
  Future<int> getCursorScreen() async {
    final result = await send<int>('getCursorScreen');
    if (result == null) {
      debugPrint('[ScreenClient] getCursorScreen() returned null — using fallback');
      return 0;
    }
    return result;
  }

  /// Get full screen info for the screen a window is currently on.
  ///
  /// Unlike [getWindowScreen] which returns just the index, this returns
  /// complete [ScreenInfo] including bounds, work area, and scale factor.
  Future<ScreenInfo?> getCurrentScreen(String id) async {
    final result = await sendForMap('getCurrentScreen', windowId: id);
    if (result == null) return null;
    return ScreenInfo.fromMap(result);
  }

  /// Get bounds of the currently active (frontmost) application window.
  ///
  /// Useful for positioning palettes relative to the user's active app,
  /// similar to how macOS Spotlight appears near the active window.
  ///
  /// Returns null if no foreground window is found.
  Future<ActiveAppInfo?> getActiveAppBounds() async {
    final result = await sendForMap('getActiveAppBounds');
    if (result == null) return null;
    return ActiveAppInfo.fromMap(result);
  }

  // ════════════════════════════════════════════════════════════════════════
  // Events
  // ════════════════════════════════════════════════════════════════════════

  /// Called when screen configuration changes.
  void onScreensChanged(void Function(List<ScreenInfo> screens) callback) {
    onEvent('screensChanged', (event) {
      final screensData = event.data['screens'] as List<dynamic>? ?? [];
      final screens = screensData
          .cast<Map<dynamic, dynamic>>()
          .map((m) => ScreenInfo.fromMap(m.cast<String, dynamic>()))
          .toList();
      callback(screens);
    });
  }

  /// Called when a window moves to a different screen.
  void onWindowScreenChanged(String id, void Function(int screenIndex) callback) {
    onWindowEvent(id, 'screenChanged', (event) {
      callback(event.data['screenIndex'] as int);
    });
  }
}
