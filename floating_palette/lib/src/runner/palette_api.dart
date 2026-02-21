import 'dart:async';
import 'dart:ui' show Rect;

import 'package:flutter/widgets.dart' show BuildContext;

import '../ffi/native_bridge.dart';
import 'palette.dart';
import 'palette_messenger.dart';
import 'palette_self.dart';

/// Simplified static API for palette-side operations.
///
/// Provides a clean, unified interface for common palette tasks:
/// - Messaging (send/receive)
/// - Result handling (for showAndWait pattern)
/// - Cross-palette visibility queries
/// - Self operations (hide, bounds)
///
/// Example:
/// ```dart
/// // Send message to host
/// Palette.send('item-selected', {'id': item.id});
///
/// // Receive messages from host
/// Palette.on('filter-update', (data) {
///   setState(() => _filter = data['query']);
/// });
///
/// // Return result (for showAndWait callers)
/// Palette.returnResult(selectedItem);
///
/// // Check if another palette is visible
/// if (Palette.isVisibleById('slash-menu')) {
///   // Skip handling
/// }
/// ```
abstract class Palette {
  Palette._(); // Prevent instantiation

  // ════════════════════════════════════════════════════════════════════════════
  // Context Access (Flutter-like API)
  // ════════════════════════════════════════════════════════════════════════════

  /// Access the palette context from within a palette widget.
  ///
  /// This is the recommended way to access palette functionality:
  /// ```dart
  /// class MyMenu extends StatelessWidget {
  ///   Widget build(BuildContext context) {
  ///     return ListTile(
  ///       onTap: () {
  ///         Palette.of(context).emit(ItemSelected(id: 'foo'));
  ///         Palette.of(context).hide();
  ///       },
  ///     );
  ///   }
  /// }
  /// ```
  ///
  /// The [context] parameter is accepted for API consistency with Flutter's
  /// `Theme.of(context)` pattern, but is not currently used since palette
  /// widgets run in their own engine with a single palette per window.
  ///
  /// Throws if called outside of a palette widget.
  static PaletteContext of(BuildContext context) {
    return PaletteContext.current;
  }

  /// Get the current palette context.
  ///
  /// Equivalent to [PaletteContext.current]. Prefer [of] for widget code.
  static PaletteContext get current => PaletteContext.current;

  /// Check if currently running inside a palette widget.
  static bool get isInPalette => PaletteContext.isInPalette;

  // ════════════════════════════════════════════════════════════════════════════
  // Identity
  // ════════════════════════════════════════════════════════════════════════════

  /// The current palette's ID.
  static String get id => PaletteContext.current.id;

  // ════════════════════════════════════════════════════════════════════════════
  // Messaging: Palette → Host
  // ════════════════════════════════════════════════════════════════════════════

  /// Send a message to the host app.
  ///
  /// ```dart
  /// Palette.send('item-selected', {'id': 'item-1'});
  /// ```
  static Future<void> send(String type, [Map<String, dynamic>? data]) {
    return PaletteMessenger.send(type, data);
  }

  // ════════════════════════════════════════════════════════════════════════════
  // Messaging: Host → Palette
  // ════════════════════════════════════════════════════════════════════════════

  // Callback storage for type-specific handlers
  static final _typeCallbacks = <String, List<void Function(Map<String, dynamic>)>>{};
  static bool _messageListenerSetup = false;

  /// Listen for a specific message type from the host.
  ///
  /// ```dart
  /// Palette.on('filter-update', (data) {
  ///   setState(() => _filter = data['query']);
  /// });
  /// ```
  static void on(String type, void Function(Map<String, dynamic>) callback) {
    _ensureMessageListener();
    _typeCallbacks.putIfAbsent(type, () => []).add(callback);
  }

  /// Remove a message listener.
  static void off(String type, void Function(Map<String, dynamic>) callback) {
    _typeCallbacks[type]?.remove(callback);
  }

  static void _ensureMessageListener() {
    if (_messageListenerSetup) return;
    _messageListenerSetup = true;

    PaletteContext.current.onMessage((type, data) {
      // Handle internal visibility messages
      if (type == '__visibility_changed__') {
        _handleVisibilityChange(data);
        return;
      }

      // Dispatch to type-specific callbacks
      final callbacks = _typeCallbacks[type];
      if (callbacks != null) {
        for (final callback in List.of(callbacks)) {
          callback(data);
        }
      }
    });
  }

  // ════════════════════════════════════════════════════════════════════════════
  // Result Handling (for showAndWait pattern)
  // ════════════════════════════════════════════════════════════════════════════

  /// Return a result to the host (for showAndWait callers).
  ///
  /// The result is serialized and sent as a special message type.
  /// The palette is automatically hidden after sending.
  ///
  /// ```dart
  /// void _onItemSelected(Item item) {
  ///   Palette.returnResult(item.toMap());
  /// }
  /// ```
  static Future<void> returnResult(Map<String, dynamic> result) async {
    await send('__palette_result__', result);
  }

  /// Cancel and hide without returning a result.
  ///
  /// ```dart
  /// void _onCancel() {
  ///   Palette.cancel();
  /// }
  /// ```
  static Future<void> cancel() async {
    await send('__palette_cancel__', {});
  }

  // ════════════════════════════════════════════════════════════════════════════
  // Cross-Palette Visibility
  // ════════════════════════════════════════════════════════════════════════════

  // Visibility cache (updated via messages from host)
  static final _visibilityCache = <String, bool>{};
  static final _visibilityCallbacks = <String, List<void Function(bool)>>{};

  /// Check if another palette is currently visible.
  ///
  /// Uses synchronous FFI call for real-time accuracy.
  /// Falls back to cached state if FFI is unavailable.
  ///
  /// ```dart
  /// if (Palette.isVisibleById('slash-menu')) {
  ///   return; // Let slash menu handle the key
  /// }
  /// ```
  static bool isVisibleById(String paletteId) {
    // Try FFI first for real-time accuracy
    try {
      if (SyncNativeBridge.instance.isAvailable) {
        return SyncNativeBridge.instance.isWindowVisible(paletteId);
      }
    } catch (_) {
      // FFI not available, fall through to cache
    }

    // Fallback to cached state
    return _visibilityCache[paletteId] ?? false;
  }

  /// Subscribe to visibility changes of another palette.
  ///
  /// ```dart
  /// Palette.onVisibilityChanged('slash-menu', (visible) {
  ///   setState(() => _slashMenuOpen = visible);
  /// });
  /// ```
  static void onVisibilityChanged(
    String paletteId,
    void Function(bool visible) callback,
  ) {
    _visibilityCallbacks.putIfAbsent(paletteId, () => []).add(callback);
  }

  /// Remove a visibility change listener.
  static void offVisibilityChanged(
    String paletteId,
    void Function(bool visible) callback,
  ) {
    _visibilityCallbacks[paletteId]?.remove(callback);
  }

  static void _handleVisibilityChange(Map<String, dynamic> data) {
    final paletteId = data['paletteId'] as String?;
    final visible = data['visible'] as bool? ?? false;

    if (paletteId == null) return;

    // Update cache
    _visibilityCache[paletteId] = visible;

    // Notify listeners
    final callbacks = _visibilityCallbacks[paletteId];
    if (callbacks != null) {
      for (final callback in List.of(callbacks)) {
        callback(visible);
      }
    }
  }

  // ════════════════════════════════════════════════════════════════════════════
  // Self Operations
  // ════════════════════════════════════════════════════════════════════════════

  /// Request to hide this palette.
  ///
  /// ```dart
  /// void _onDone() {
  ///   Palette.hide();
  /// }
  /// ```
  static Future<void> hide() {
    return PaletteContext.current.requestHide();
  }

  /// Get this palette's current bounds.
  static Future<Rect> get bounds => PaletteSelf.bounds;
}
