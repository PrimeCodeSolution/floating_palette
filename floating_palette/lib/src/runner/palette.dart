import 'package:flutter/services.dart';

import '../events/palette_event.dart';
import '../snap/snap_types.dart';

/// Callback for receiving typed events from host.
typedef EventCallback<T extends PaletteEvent> = void Function(T event);

/// Callback for receiving untyped messages from host.
typedef MessageCallback = void Function(String type, Map<String, dynamic> data);

/// Provides access to the current palette from within a palette widget.
///
/// Use this to communicate with the host app:
/// ```dart
/// // Notify host of a custom event
/// PaletteContext.current.notify(MyCustomEvent(data: 'value'));
///
/// // Request to be hidden
/// PaletteContext.current.requestHide();
///
/// // Listen for events from host
/// PaletteContext.current.on<FilterUpdateEvent>((event) {
///   print('Filter: ${event.filter}');
/// });
///
/// // Listen for untyped messages
/// PaletteContext.current.onMessage((type, data) {
///   print('Got $type: $data');
/// });
/// ```
class PaletteContext {
  static PaletteContext? _current;

  /// The current palette instance.
  ///
  /// Only available within a palette widget (after runPalette is called).
  static PaletteContext get current {
    assert(_current != null, 'PaletteContext.current accessed outside of a palette');
    return _current!;
  }

  /// Check if running inside a palette.
  static bool get isInPalette => _current != null;

  // ═══════════════════════════════════════════════════════════════════════════
  // Internal
  // ═══════════════════════════════════════════════════════════════════════════

  final String _id;
  static const _channel = MethodChannel('floating_palette/messenger');

  // Callback storage
  final _typedCallbacks = <Type, List<Function>>{};
  final _messageCallbacks = <MessageCallback>[];

  PaletteContext._(this._id) {
    _setupMessageHandler();
  }

  void _setupMessageHandler() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'receive') {
        final args = call.arguments as Map<dynamic, dynamic>;
        final type = args['type'] as String;
        final data = Map<String, dynamic>.from(args['data'] as Map? ?? {});
        _handleIncomingMessage(type, data);
      }
    });
  }

  void _handleIncomingMessage(String type, Map<String, dynamic> data) {
    // Only attempt typed deserialization if a factory is registered
    if (PaletteEvent.isRegistered(type)) {
      final event = PaletteEvent.deserialize(type, data);
      if (event != null) {
        final callbacks = _typedCallbacks[event.runtimeType];
        if (callbacks != null) {
          for (final callback in callbacks) {
            callback(event);
          }
        }
      }
    }

    // Always notify untyped listeners
    for (final callback in _messageCallbacks) {
      callback(type, data);
    }
  }

  /// Initialize the current palette. Called by runPalette/runPaletteApp.
  /// @nodoc
  static void init(String paletteId) {
    // Dispose previous instance if any (handles hot restart)
    _current?._dispose();
    _current = PaletteContext._(paletteId);
  }

  /// Reset the current palette context.
  ///
  /// Called on dispose or for testing. Clears all callbacks and resets state.
  /// @nodoc
  static void reset() {
    _current?._dispose();
    _current = null;
  }

  void _dispose() {
    _typedCallbacks.clear();
    _messageCallbacks.clear();
    _channel.setMethodCallHandler(null);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Public API
  // ═══════════════════════════════════════════════════════════════════════════

  /// The palette ID.
  String get id => _id;

  /// Notify the host app with an event.
  ///
  /// ```dart
  /// Palette.of(context).emit(MyCustomEvent(data: 'value'));
  /// ```
  Future<void> notify(PaletteEvent event) async {
    await _channel.invokeMethod('notify', {
      'type': event.eventId,
      'paletteId': _id,
      'data': event.toMap(),
    });
  }

  /// Alias for [notify] - emit an event to the host.
  ///
  /// ```dart
  /// Palette.of(context).emit(ItemSelected(itemId: 'foo'));
  /// ```
  Future<void> emit(PaletteEvent event) => notify(event);

  /// Request the host to hide this palette.
  Future<void> requestHide() async {
    await _channel.invokeMethod('requestHide', {'paletteId': _id});
  }

  /// Shorthand for [requestHide].
  ///
  /// ```dart
  /// Palette.of(context).hide();
  /// ```
  Future<void> hide() => requestHide();

  /// Request the host to show another palette.
  Future<void> requestShow(String paletteId) async {
    await _channel.invokeMethod('requestShow', {'paletteId': paletteId});
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Receiving from Host
  // ═══════════════════════════════════════════════════════════════════════════

  /// Listen for typed events from the host.
  ///
  /// The event type must be registered with [PaletteEvent.register] first.
  ///
  /// ```dart
  /// // In your palette's initialization:
  /// PaletteContext.current.on<FilterUpdateEvent>((event) {
  ///   setState(() => _filter = event.filter);
  /// });
  /// ```
  ///
  /// Throws [StateError] if the event type hasn't been registered.
  void on<T extends PaletteEvent>(EventCallback<T> callback) {
    final eventId = PaletteEvent.idFor<T>();
    if (eventId == null) {
      throw StateError(
        'Event type $T is not registered. '
        'Call PaletteEvent.register<$T>() at app startup before using on<$T>(). '
        'Hint: Use Palettes.init(onInit: registerMyEvents) to register events.',
      );
    }
    _typedCallbacks.putIfAbsent(T, () => []).add(callback);
  }

  /// Remove a typed event listener.
  void off<T extends PaletteEvent>(EventCallback<T> callback) {
    _typedCallbacks[T]?.remove(callback);
  }

  /// Listen for all messages from the host (typed or untyped).
  ///
  /// ```dart
  /// PaletteContext.current.onMessage((type, data) {
  ///   print('Received $type: $data');
  /// });
  /// ```
  void onMessage(MessageCallback callback) {
    _messageCallbacks.add(callback);
  }

  /// Remove a message listener.
  void offMessage(MessageCallback callback) {
    _messageCallbacks.remove(callback);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Snap API (for palette-to-palette snapping from within a palette)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Snap this palette to another palette by ID.
  ///
  /// [mode] determines the relationship:
  /// - [SnapMode.follower] (default): One-way. This palette follows target.
  /// - [SnapMode.bidirectional]: Two-way. Drag either, both move together.
  ///
  /// ```dart
  /// // Snap to another palette (bidirectional)
  /// await PaletteContext.current.snapTo(
  ///   'other-palette-id',
  ///   myEdge: SnapEdge.top,
  ///   targetEdge: SnapEdge.bottom,
  ///   mode: SnapMode.bidirectional,
  /// );
  /// ```
  Future<void> snapTo(
    String targetId, {
    required SnapEdge myEdge,
    required SnapEdge targetEdge,
    SnapAlignment alignment = SnapAlignment.center,
    double gap = 0,
    SnapConfig config = const SnapConfig(),
    SnapMode mode = SnapMode.follower,
  }) async {
    // Forward snap binding: this → target
    await _channel.invokeMethod('snap', {
      'paletteId': _id,
      'followerId': _id,
      'targetId': targetId,
      'followerEdge': myEdge.name,
      'targetEdge': targetEdge.name,
      'alignment': alignment.name,
      'gap': gap,
      'config': config.toMap(),
    });

    // For bidirectional mode, also create reverse binding
    if (mode == SnapMode.bidirectional) {
      await _channel.invokeMethod('snap', {
        'paletteId': targetId,
        'followerId': targetId,
        'targetId': _id,
        'followerEdge': targetEdge.name,
        'targetEdge': myEdge.name,
        'alignment': alignment.name,
        'gap': gap,
        'config': config.toMap(),
      });
    }
  }

  /// Detach this palette from its snap target.
  Future<void> detachSnap() async {
    await _channel.invokeMethod('detachSnap', {'paletteId': _id});
  }

  /// Enable auto-snapping for this palette.
  Future<void> enableAutoSnap([AutoSnapConfig config = const AutoSnapConfig()]) async {
    await _channel.invokeMethod('setAutoSnapConfig', {
      'paletteId': _id,
      'config': config.toMap(),
    });
  }

  /// Disable auto-snapping for this palette.
  Future<void> disableAutoSnap() async {
    await _channel.invokeMethod('setAutoSnapConfig', {
      'paletteId': _id,
      'config': AutoSnapConfig.disabled.toMap(),
    });
  }
}
