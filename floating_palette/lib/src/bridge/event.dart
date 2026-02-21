/// An event received from the native layer.
class NativeEvent {
  /// The service that emitted this event.
  final String service;

  /// The event name.
  final String event;

  /// The window ID this event is about (null for global events).
  final String? windowId;

  /// Event data.
  final Map<String, dynamic> data;

  const NativeEvent({
    required this.service,
    required this.event,
    this.windowId,
    this.data = const {},
  });

  factory NativeEvent.fromMap(Map<String, dynamic> map) {
    return NativeEvent(
      service: map['service'] as String,
      event: map['event'] as String,
      windowId: map['windowId'] as String?,
      data: Map<String, dynamic>.from(map['data'] as Map? ?? {}),
    );
  }
}
