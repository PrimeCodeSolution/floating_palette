import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart' show debugPrint;

import '../bridge/service_client.dart';

/// Client for FrameService.
///
/// Handles position and size.
class FrameClient extends ServiceClient {
  FrameClient(super.bridge);

  @override
  String get serviceName => 'frame';

  /// Set window position.
  ///
  /// The [anchor] specifies which point of the window is placed at [position].
  /// For example, `Anchor.center` centers the window at [position].
  Future<void> setPosition(
    String id,
    Offset position, {
    String? anchor,
    bool animate = false,
    int? durationMs,
    String? curve,
  }) async {
    await send<void>('setPosition', windowId: id, params: {
      'x': position.dx,
      'y': position.dy,
      'anchor': ?anchor,
      'animate': animate,
      'durationMs': ?durationMs,
      'curve': ?curve,
    });
  }

  /// Set window size.
  Future<void> setSize(
    String id,
    Size size, {
    bool animate = false,
    int? durationMs,
    String? curve,
  }) async {
    await send<void>('setSize', windowId: id, params: {
      'width': size.width,
      'height': size.height,
      'animate': animate,
      'durationMs': ?durationMs,
      'curve': ?curve,
    });
  }

  /// Set window bounds (position + size).
  Future<void> setBounds(
    String id,
    Rect bounds, {
    bool animate = false,
    int? durationMs,
    String? curve,
  }) async {
    await send<void>('setBounds', windowId: id, params: {
      'x': bounds.left,
      'y': bounds.top,
      'width': bounds.width,
      'height': bounds.height,
      'animate': animate,
      'durationMs': ?durationMs,
      'curve': ?curve,
    });
  }

  /// Get current position.
  Future<Offset> getPosition(String id) async {
    final result = await sendForMap('getPosition', windowId: id);
    if (result == null) {
      debugPrint('[FrameClient] getPosition($id) returned null — using fallback');
      return Offset.zero;
    }
    return Offset(
      (result['x'] as num).toDouble(),
      (result['y'] as num).toDouble(),
    );
  }

  /// Get current size.
  Future<Size> getSize(String id) async {
    final result = await sendForMap('getSize', windowId: id);
    if (result == null) {
      debugPrint('[FrameClient] getSize($id) returned null — using fallback');
      return Size.zero;
    }
    return Size(
      (result['width'] as num).toDouble(),
      (result['height'] as num).toDouble(),
    );
  }

  /// Enable or disable dragging for a window.
  Future<void> setDraggable(String id, {required bool draggable}) async {
    await send<void>('setDraggable', windowId: id, params: {
      'draggable': draggable,
    });
  }

  /// Get current bounds.
  Future<Rect> getBounds(String id) async {
    final result = await sendForMap('getBounds', windowId: id);
    if (result == null) {
      debugPrint('[FrameClient] getBounds($id) returned null — using fallback');
      return Rect.zero;
    }
    return Rect.fromLTWH(
      (result['x'] as num).toDouble(),
      (result['y'] as num).toDouble(),
      (result['width'] as num).toDouble(),
      (result['height'] as num).toDouble(),
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  // Events
  // ════════════════════════════════════════════════════════════════════════

  /// Called when window moves.
  void onMoved(String id, void Function(Offset position) callback) {
    onWindowEvent(id, 'moved', (event) {
      callback(Offset(
        (event.data['x'] as num).toDouble(),
        (event.data['y'] as num).toDouble(),
      ));
    });
  }

  /// Called when window resizes.
  void onResized(String id, void Function(Size size) callback) {
    onWindowEvent(id, 'resized', (event) {
      callback(Size(
        (event.data['width'] as num).toDouble(),
        (event.data['height'] as num).toDouble(),
      ));
    });
  }
}
