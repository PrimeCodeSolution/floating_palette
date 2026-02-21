import 'dart:async';

import '../bridge/service_client.dart';
import '../config/palette_behavior.dart';

/// Client for FocusService.
///
/// Handles focus management.
class FocusClient extends ServiceClient {
  FocusClient(super.bridge);

  @override
  String get serviceName => 'focus';

  /// Focus a window.
  Future<void> focus(String id) async {
    await send<void>('focus', windowId: id);
  }

  /// Remove focus from a window.
  Future<void> unfocus(String id) async {
    await send<void>('unfocus', windowId: id);
  }

  /// Set focus policy.
  Future<void> setPolicy(String id, FocusPolicy policy) async {
    await send<void>('setPolicy', windowId: id, params: {
      'policy': policy.name,
    });
  }

  /// Check if window has focus.
  Future<bool> hasFocus(String id) async {
    final result = await send<bool>('isFocused', windowId: id);
    return result ?? false;
  }

  /// Activate the main app window.
  Future<void> focusMainWindow() async {
    await send<void>('focusMainWindow');
  }

  /// Hide the app entirely (returns to previously active app).
  Future<void> hideApp() async {
    await send<void>('hideApp');
  }

  /// Restore focus based on mode (orchestrated by Dart).
  Future<void> restoreFocus(FocusRestoreMode mode) async {
    switch (mode) {
      case FocusRestoreMode.none:
        // Don't do anything
        break;
      case FocusRestoreMode.mainWindow:
        await focusMainWindow();
      case FocusRestoreMode.previousApp:
        await hideApp();
    }
  }

  // ════════════════════════════════════════════════════════════════════════
  // Events
  // ════════════════════════════════════════════════════════════════════════

  /// Called when window gains focus.
  void onFocused(String id, void Function() callback) {
    onWindowEvent(id, 'focused', (_) => callback());
  }

  /// Called when window loses focus.
  void onUnfocused(String id, void Function() callback) {
    onWindowEvent(id, 'unfocused', (_) => callback());
  }
}
