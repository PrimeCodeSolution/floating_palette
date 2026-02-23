import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;

import '../bridge/service_client.dart';

/// Client for VisibilityService.
///
/// Handles show, hide, opacity.
class VisibilityClient extends ServiceClient {
  VisibilityClient(super.bridge);

  @override
  String get serviceName => 'visibility';

  /// Show a window.
  ///
  /// [focus] - Whether the window should take keyboard focus when shown.
  Future<void> show(String id, {bool animate = true, bool focus = true}) async {
    await send<void>('show', windowId: id, params: {
      'animate': animate,
      'focus': focus,
    });
  }

  /// Hide a window.
  Future<void> hide(String id, {bool animate = true}) async {
    await send<void>('hide', windowId: id, params: {
      'animate': animate,
    });
  }

  /// Set window opacity.
  Future<void> setOpacity(
    String id,
    double opacity, {
    bool animate = false,
    int? durationMs,
  }) async {
    await send<void>('setOpacity', windowId: id, params: {
      'opacity': opacity,
      'animate': animate,
      'durationMs': ?durationMs,
    });
  }

  /// Get current visibility state.
  Future<bool> isVisible(String id) async {
    final result = await send<bool>('isVisible', windowId: id);
    if (result == null) {
      debugPrint('[VisibilityClient] isVisible($id) returned null — using fallback');
      return false;
    }
    return result;
  }

  /// Get current opacity.
  Future<double> getOpacity(String id) async {
    final result = await send<double>('getOpacity', windowId: id);
    if (result == null) {
      debugPrint('[VisibilityClient] getOpacity($id) returned null — using fallback');
      return 1.0;
    }
    return result;
  }

  // ════════════════════════════════════════════════════════════════════════
  // Events
  // ════════════════════════════════════════════════════════════════════════

  /// Called when window becomes visible.
  void onShown(String id, void Function() callback) {
    onWindowEvent(id, 'shown', (_) => callback());
  }

  /// Called when window becomes hidden.
  void onHidden(String id, void Function() callback) {
    onWindowEvent(id, 'hidden', (_) => callback());
  }

  /// Called when show animation starts.
  void onShowStart(String id, void Function() callback) {
    onWindowEvent(id, 'showStart', (_) => callback());
  }

  /// Called when hide animation starts.
  void onHideStart(String id, void Function() callback) {
    onWindowEvent(id, 'hideStart', (_) => callback());
  }
}
