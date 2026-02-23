import '../bridge/native_bridge.dart' show NativeEventCallback;
import '../bridge/service_client.dart';

/// Message event from a palette.
class PaletteMessage {
  /// The palette ID that sent the message.
  final String paletteId;

  /// The message type (e.g., 'slash-trigger', 'menu-selected').
  final String type;

  /// The message data.
  final Map<String, dynamic> data;

  const PaletteMessage({
    required this.paletteId,
    required this.type,
    required this.data,
  });

  @override
  String toString() => 'PaletteMessage($paletteId, $type, $data)';
}

/// Client for receiving untyped messages from palettes.
///
/// Example:
/// ```dart
/// final messageClient = MessageClient();
///
/// // Listen for all messages
/// messageClient.onMessage((msg) {
///   print('Got message: ${msg.type} from ${msg.paletteId}');
/// });
///
/// // Listen for specific message type
/// messageClient.on('my-event', (msg) {
///   print('Received: ${msg.data}');
/// });
/// ```
class MessageClient extends ServiceClient {
  MessageClient(super.bridge) {
    _setupEventListener();
  }

  @override
  String get serviceName => 'message';

  final _typeCallbacks = <String, List<void Function(PaletteMessage)>>{};
  final _globalCallbacks = <void Function(PaletteMessage)>[];

  /// Stored reference to the event handler for proper cleanup on dispose.
  late final NativeEventCallback _eventHandler;

  void _setupEventListener() {
    // Listen to all message events (service: message, event: the message type)
    _eventHandler = (event) {
      final msg = PaletteMessage(
        paletteId: event.windowId ?? 'unknown',
        type: event.event,
        data: event.data,
      );

      // Call global callbacks
      for (final callback in _globalCallbacks) {
        callback(msg);
      }

      // Call type-specific callbacks
      final typeCallbacks = _typeCallbacks[msg.type];
      if (typeCallbacks != null) {
        for (final callback in typeCallbacks) {
          callback(msg);
        }
      }
    };
    bridge.subscribe(serviceName, _eventHandler);
  }

  /// Listen for all messages from palettes.
  void onMessage(void Function(PaletteMessage) callback) {
    _globalCallbacks.add(callback);
  }

  /// Listen for a specific message type.
  void on(String type, void Function(PaletteMessage) callback) {
    _typeCallbacks.putIfAbsent(type, () => []).add(callback);
  }

  /// Remove a callback.
  void off(String type, void Function(PaletteMessage) callback) {
    _typeCallbacks[type]?.remove(callback);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Host → Palette
  // ═══════════════════════════════════════════════════════════════════════════

  /// Send a message to a palette (Host → Palette).
  ///
  /// ```dart
  /// await messageClient.sendToPalette('slash-menu', 'filter-update', {'filter': 'hea'});
  /// ```
  Future<void> sendToPalette(
    String paletteId,
    String type, [
    Map<String, dynamic>? data,
  ]) async {
    await send('send', windowId: paletteId, params: {'type': type, 'data': data ?? {}});
  }

  @override
  void dispose() {
    bridge.unsubscribe(serviceName, _eventHandler);
    _globalCallbacks.clear();
    _typeCallbacks.clear();
    super.dispose();
  }
}
