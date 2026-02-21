import 'dart:async';

import '../services/message_client.dart';

/// Per-palette messaging with automatic ID filtering.
///
/// Wraps [MessageClient] to only receive messages from a specific palette.
class PaletteMessaging {
  final String paletteId;
  final MessageClient _client;

  /// Type-specific callbacks for this palette.
  final _typeCallbacks = <String, List<void Function(Map<String, dynamic>)>>{};

  PaletteMessaging(this.paletteId, this._client);

  /// Send a message to this palette (Host → Palette).
  Future<void> send(String type, [Map<String, dynamic>? data]) {
    return _client.sendToPalette(paletteId, type, data);
  }

  /// Listen for messages from this palette (Palette → Host).
  ///
  /// Only receives messages from this specific palette.
  void on(String type, void Function(Map<String, dynamic>) callback) {
    _typeCallbacks.putIfAbsent(type, () => []).add(callback);

    // Register with message client if first callback for this type
    if (_typeCallbacks[type]!.length == 1) {
      _client.on(type, (msg) {
        if (msg.paletteId == paletteId) {
          final callbacks = _typeCallbacks[type];
          if (callbacks != null) {
            for (final cb in List.of(callbacks)) {
              cb(msg.data);
            }
          }
        }
      });
    }
  }

  /// Remove a message listener.
  void off(String type, void Function(Map<String, dynamic>) callback) {
    _typeCallbacks[type]?.remove(callback);
  }

  /// Show palette and wait for result with timeout.
  ///
  /// Completes when palette sends `__palette_result__` or `__palette_cancel__`,
  /// or returns null on timeout/hide.
  Future<Map<String, dynamic>?> waitForResult({
    required Future<void> Function() showPalette,
    required void Function(void Function()) onHideCallback,
    required void Function(void Function()) removeHideCallback,
    required Future<bool> Function() isVisible,
    required Future<void> Function() hidePalette,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    final completer = Completer<Map<String, dynamic>?>();

    void resultHandler(PaletteMessage msg) {
      if (msg.paletteId != paletteId) return;

      if (msg.type == '__palette_result__') {
        if (!completer.isCompleted) {
          completer.complete(msg.data);
        }
      } else if (msg.type == '__palette_cancel__') {
        if (!completer.isCompleted) {
          completer.complete(null);
        }
      }
    }

    void hideHandler() {
      if (!completer.isCompleted) {
        completer.complete(null);
      }
    }

    _client.on('__palette_result__', resultHandler);
    _client.on('__palette_cancel__', resultHandler);
    onHideCallback(hideHandler);

    try {
      await showPalette();

      return await completer.future.timeout(
        timeout,
        onTimeout: () => null,
      );
    } finally {
      _client.off('__palette_result__', resultHandler);
      _client.off('__palette_cancel__', resultHandler);
      removeHideCallback(hideHandler);

      if (await isVisible()) {
        await hidePalette();
      }
    }
  }
}
