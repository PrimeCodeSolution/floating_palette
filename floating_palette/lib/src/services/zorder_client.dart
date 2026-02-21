import 'dart:async';

import '../bridge/service_client.dart';

/// Pin levels for windows.
enum PinLevel {
  /// Above other palettes but below other apps.
  abovePalettes,

  /// Above host app.
  aboveApp,

  /// Above everything (OS level).
  aboveAll,
}

/// Client for ZOrderService.
///
/// Handles window layering and pinning.
class ZOrderClient extends ServiceClient {
  ZOrderClient(super.bridge);

  @override
  String get serviceName => 'zorder';

  /// Bring window to front.
  Future<void> bringToFront(String id) async {
    await send<void>('bringToFront', windowId: id);
  }

  /// Send window to back.
  Future<void> sendToBack(String id) async {
    await send<void>('sendToBack', windowId: id);
  }

  /// Move window above another.
  Future<void> moveAbove(String id, String otherId) async {
    await send<void>('moveAbove', windowId: id, params: {
      'otherId': otherId,
    });
  }

  /// Move window below another.
  Future<void> moveBelow(String id, String otherId) async {
    await send<void>('moveBelow', windowId: id, params: {
      'otherId': otherId,
    });
  }

  /// Set explicit z-index.
  Future<void> setZIndex(String id, int index) async {
    await send<void>('setZIndex', windowId: id, params: {
      'index': index,
    });
  }

  /// Pin window to always be on top.
  Future<void> pin(String id, {PinLevel level = PinLevel.abovePalettes}) async {
    await send<void>('pin', windowId: id, params: {
      'level': level.name,
    });
  }

  /// Unpin window.
  Future<void> unpin(String id) async {
    await send<void>('unpin', windowId: id);
  }

  /// Get current z-index.
  Future<int> getZIndex(String id) async {
    final result = await send<int>('getZIndex', windowId: id);
    return result ?? 0;
  }

  /// Check if window is pinned.
  Future<bool> isPinned(String id) async {
    final result = await send<bool>('isPinned', windowId: id);
    return result ?? false;
  }

  // ════════════════════════════════════════════════════════════════════════
  // Events
  // ════════════════════════════════════════════════════════════════════════

  /// Called when z-order changes.
  void onZOrderChanged(String id, void Function(int index) callback) {
    onWindowEvent(id, 'zOrderChanged', (event) {
      callback(event.data['index'] as int);
    });
  }
}
