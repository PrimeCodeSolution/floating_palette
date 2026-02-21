import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart';

import '../bridge/service_client.dart';

/// Client for InputService.
///
/// Handles keyboard capture, pointer, cursor.
class InputClient extends ServiceClient {
  InputClient(super.bridge);

  @override
  String get serviceName => 'input';

  /// Capture keyboard events.
  Future<void> captureKeyboard(
    String id, {
    Set<LogicalKeyboardKey>? keys,
    bool allKeys = false,
  }) async {
    final keyIds = keys?.map((k) => k.keyId).toList();
    debugPrint('[InputClient] captureKeyboard($id): allKeys=$allKeys, keyIds=$keyIds');
    await send<void>('captureKeyboard', windowId: id, params: {
      if (keys != null) 'keys': keyIds,
      'allKeys': allKeys,
    });
    debugPrint('[InputClient] captureKeyboard($id) completed');
  }

  /// Release keyboard capture.
  Future<void> releaseKeyboard(String id) async {
    await send<void>('releaseKeyboard', windowId: id);
  }

  /// Capture all pointer events.
  Future<void> capturePointer(String id) async {
    await send<void>('capturePointer', windowId: id);
  }

  /// Release pointer capture.
  Future<void> releasePointer(String id) async {
    await send<void>('releasePointer', windowId: id);
  }

  /// Set cursor style.
  Future<void> setCursor(String id, SystemMouseCursor cursor) async {
    await send<void>('setCursor', windowId: id, params: {
      'cursor': cursor.kind,
    });
  }

  /// Reset cursor to default.
  Future<void> resetCursor(String id) async {
    await send<void>('resetCursor', windowId: id);
  }

  /// Enable click passthrough.
  Future<void> setPassthrough(
    String id, {
    bool enabled = true,
    List<Rect>? regions,
  }) async {
    await send<void>('setPassthrough', windowId: id, params: {
      'enabled': enabled,
      if (regions != null)
        'regions': regions
            .map((r) => {
                  'x': r.left,
                  'y': r.top,
                  'width': r.width,
                  'height': r.height,
                })
            .toList(),
    });
  }

  // ════════════════════════════════════════════════════════════════════════
  // Events
  // ════════════════════════════════════════════════════════════════════════

  /// Called on key down.
  void onKeyDown(
    String id,
    void Function(LogicalKeyboardKey key, Set<LogicalKeyboardKey> modifiers)
        callback,
  ) {
    onWindowEvent(id, 'keyDown', (event) {
      final keyId = event.data['keyId'] as int;
      final modifierIds =
          (event.data['modifiers'] as List?)?.cast<int>() ?? [];

      callback(
        LogicalKeyboardKey(keyId),
        modifierIds.map((id) => LogicalKeyboardKey(id)).toSet(),
      );
    });
  }

  /// Called on key up.
  void onKeyUp(
    String id,
    void Function(LogicalKeyboardKey key) callback,
  ) {
    onWindowEvent(id, 'keyUp', (event) {
      final keyId = event.data['keyId'] as int;
      callback(LogicalKeyboardKey(keyId));
    });
  }

  /// Called on click outside.
  void onClickOutside(String id, void Function(Offset position) callback) {
    onWindowEvent(id, 'clickOutside', (event) {
      callback(Offset(
        (event.data['x'] as num).toDouble(),
        (event.data['y'] as num).toDouble(),
      ));
    });
  }

  /// Called on pointer enter.
  void onPointerEnter(String id, void Function() callback) {
    onWindowEvent(id, 'pointerEnter', (_) => callback());
  }

  /// Called on pointer exit.
  void onPointerExit(String id, void Function() callback) {
    onWindowEvent(id, 'pointerExit', (_) => callback());
  }
}
