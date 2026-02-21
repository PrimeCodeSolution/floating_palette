import 'package:flutter/services.dart';

import '../events/palette_event.dart';

/// Messenger for palette-to-host communication.
///
/// Supports both typed events via [sendEvent] and untyped messages via [send].
///
/// Example (in a palette):
/// ```dart
/// // Send a typed event to host (preferred)
/// PaletteMessenger.sendEvent(ShowSlashMenuEvent(caretX: x, caretY: y));
///
/// // Send an untyped message (legacy)
/// PaletteMessenger.send('my-event', {'key': 'value'});
/// ```
class PaletteMessenger {
  static const _channel = MethodChannel('floating_palette/messenger');

  /// Send a typed event to the host app.
  ///
  /// The event's [PaletteEvent.eventId] is used as the message type,
  /// and [PaletteEvent.toMap] provides the payload.
  static Future<void> sendEvent(PaletteEvent event) async {
    await send(event.eventId, event.toMap());
  }

  /// Send an untyped message to the host app.
  ///
  /// Prefer [sendEvent] for type-safe communication.
  /// The [type] identifies the message kind.
  /// The [data] is optional payload.
  static Future<void> send(String type, [Map<String, dynamic>? data]) async {
    await _channel.invokeMethod('send', {
      'type': type,
      'data': data ?? {},
    });
  }
}
