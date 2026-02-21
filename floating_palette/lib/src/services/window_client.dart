import 'dart:async';

import '../bridge/service_client.dart';
import '../config/config.dart';

/// Client for WindowService.
///
/// Handles window lifecycle: create, destroy, content.
class WindowClient extends ServiceClient {
  WindowClient(super.bridge);

  @override
  String get serviceName => 'window';

  /// Create a new window.
  ///
  /// Returns the window handle/ID on success.
  Future<String?> create(
    String id, {
    required PaletteAppearance appearance,
    required PaletteSize size,
    String? entryPoint,
    bool keepAlive = false,
  }) async {
    final result = await send<String>('create', params: {
      'id': id,
      'entryPoint': entryPoint ?? 'paletteMain',
      'cornerRadius': appearance.cornerRadius,
      'shadow': appearance.shadow.name,
      'transparent': appearance.transparent,
      'debugBorder': appearance.debugBorder,
      if (appearance.backgroundColor != null)
        'backgroundColor': appearance.backgroundColor!.toARGB32(),
      // Size config - stored on native side for runtime queries
      ...size.toMap(),
      'keepAlive': keepAlive,
    });
    return result;
  }

  /// Destroy a window.
  Future<void> destroy(String id) async {
    await send<void>('destroy', windowId: id);
  }

  /// Check if a window exists.
  Future<bool> exists(String id) async {
    final result = await send<bool>('exists', windowId: id);
    assert(result != null, '[WindowClient] exists($id) returned null');
    return result ?? false;
  }

  /// Set the Flutter entry point for a window.
  Future<void> setEntryPoint(String id, String entryPoint) async {
    await send<void>('setEntryPoint', windowId: id, params: {
      'entryPoint': entryPoint,
    });
  }

  // ════════════════════════════════════════════════════════════════════════
  // Events
  // ════════════════════════════════════════════════════════════════════════

  /// Called when a window is created.
  void onCreated(String id, void Function() callback) {
    onWindowEvent(id, 'created', (_) => callback());
  }

  /// Called when a window is destroyed.
  void onDestroyed(String id, void Function() callback) {
    onWindowEvent(id, 'destroyed', (_) => callback());
  }

  /// Called when Flutter content is ready.
  void onContentReady(String id, void Function() callback) {
    onWindowEvent(id, 'contentReady', (_) => callback());
  }
}
