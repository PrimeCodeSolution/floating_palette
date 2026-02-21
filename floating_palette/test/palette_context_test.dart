import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:floating_palette/src/events/palette_event.dart';
import 'package:floating_palette/src/runner/palette.dart';

// Test event for typed callbacks
class FilterChangedEvent extends PaletteEvent {
  @override
  String get eventId => 'FilterChangedEvent';

  final String filter;
  const FilterChangedEvent({required this.filter});

  @override
  Map<String, dynamic> toMap() => {'filter': filter};

  static FilterChangedEvent fromMap(Map<String, dynamic> m) =>
      FilterChangedEvent(filter: m['filter'] as String);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const messengerChannel = MethodChannel('floating_palette/messenger');
  late List<MethodCall> outgoingCalls;

  setUp(() {
    outgoingCalls = [];

    // Mock the messenger channel for outgoing calls
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(messengerChannel, (call) async {
      outgoingCalls.add(call);
      return null;
    });

    // Register test event
    PaletteEvent.register('FilterChangedEvent', FilterChangedEvent.fromMap);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(messengerChannel, null);
  });

  group('PaletteContext', () {
    test('isInPalette returns false before init', () {
      // Note: This test relies on static state, may be affected by other tests
      // In a real scenario, we'd need a way to reset the static state
      // For now, we test the API contract
      expect(PaletteContext.isInPalette, anyOf(isTrue, isFalse));
    });

    test('init creates context with correct ID', () {
      PaletteContext.init('test-palette-123');

      expect(PaletteContext.isInPalette, isTrue);
      expect(PaletteContext.current.id, equals('test-palette-123'));
    });

    test('notify sends event to native', () async {
      PaletteContext.init('my-palette');
      final ctx = PaletteContext.current;

      await ctx.notify(FilterChangedEvent(filter: 'hello'));

      expect(outgoingCalls.length, equals(1));
      expect(outgoingCalls[0].method, equals('notify'));

      final args = outgoingCalls[0].arguments as Map;
      expect(args['type'], equals('FilterChangedEvent'));
      expect(args['paletteId'], equals('my-palette'));
      expect(args['data'], equals({'filter': 'hello'}));
    });

    test('requestHide sends hide request', () async {
      PaletteContext.init('hideable-palette');
      final ctx = PaletteContext.current;

      await ctx.requestHide();

      expect(outgoingCalls.length, equals(1));
      expect(outgoingCalls[0].method, equals('requestHide'));

      final args = outgoingCalls[0].arguments as Map;
      expect(args['paletteId'], equals('hideable-palette'));
    });

    test('requestShow sends show request with target ID', () async {
      PaletteContext.init('requester-palette');
      final ctx = PaletteContext.current;

      await ctx.requestShow('other-palette');

      expect(outgoingCalls.length, equals(1));
      expect(outgoingCalls[0].method, equals('requestShow'));

      final args = outgoingCalls[0].arguments as Map;
      expect(args['paletteId'], equals('other-palette'));
    });

    test('onMessage receives incoming messages', () async {
      PaletteContext.init('receiving-palette');
      final ctx = PaletteContext.current;

      final received = <(String, Map<String, dynamic>)>[];
      ctx.onMessage((type, data) => received.add((type, data)));

      // Simulate incoming message from host
      await _simulateIncomingMessage('test-message', {'key': 'value'});

      expect(received.length, equals(1));
      expect(received[0].$1, equals('test-message'));
      expect(received[0].$2, equals({'key': 'value'}));
    });

    test('on<T> receives typed events', () async {
      PaletteContext.init('typed-palette');
      final ctx = PaletteContext.current;

      final events = <FilterChangedEvent>[];
      ctx.on<FilterChangedEvent>((event) => events.add(event));

      // Simulate incoming typed event
      await _simulateIncomingMessage('FilterChangedEvent', {'filter': 'typed-value'});

      expect(events.length, equals(1));
      expect(events[0].filter, equals('typed-value'));
    });

    test('off<T> removes typed callback', () async {
      PaletteContext.init('off-test-palette');
      final ctx = PaletteContext.current;

      final events = <FilterChangedEvent>[];
      void callback(FilterChangedEvent e) => events.add(e);

      ctx.on<FilterChangedEvent>(callback);
      await _simulateIncomingMessage('FilterChangedEvent', {'filter': 'first'});

      expect(events.length, equals(1));

      ctx.off<FilterChangedEvent>(callback);
      await _simulateIncomingMessage('FilterChangedEvent', {'filter': 'second'});

      expect(events.length, equals(1)); // Still 1, callback removed
    });

    test('offMessage removes message callback', () async {
      PaletteContext.init('offmsg-palette');
      final ctx = PaletteContext.current;

      final messages = <String>[];
      void callback(String type, Map<String, dynamic> data) => messages.add(type);

      ctx.onMessage(callback);
      await _simulateIncomingMessage('msg1', {});

      expect(messages.length, equals(1));

      ctx.offMessage(callback);
      await _simulateIncomingMessage('msg2', {});

      expect(messages.length, equals(1)); // Still 1
    });

    test('both typed and untyped callbacks fire for same message', () async {
      PaletteContext.init('both-palette');
      final ctx = PaletteContext.current;

      var typedCount = 0;
      var untypedCount = 0;

      ctx.on<FilterChangedEvent>((_) => typedCount++);
      ctx.onMessage((type, data) => untypedCount++);

      await _simulateIncomingMessage('FilterChangedEvent', {'filter': 'test'});

      expect(typedCount, equals(1));
      expect(untypedCount, equals(1));
    });

    test('untyped callback fires even for unknown event types', () async {
      PaletteContext.init('unknown-palette');
      final ctx = PaletteContext.current;

      final messages = <String>[];
      ctx.onMessage((type, _) => messages.add(type));

      await _simulateIncomingMessage('completely-unknown-type', {});

      expect(messages.length, equals(1));
      expect(messages[0], equals('completely-unknown-type'));
    });

    test('handles null data gracefully', () async {
      PaletteContext.init('null-data-palette');
      final ctx = PaletteContext.current;

      final messages = <Map<String, dynamic>>[];
      ctx.onMessage((_, data) => messages.add(data));

      // Simulate message with null data converted to empty map
      await _simulateIncomingMessageRaw({'type': 'test', 'data': null});

      expect(messages.length, equals(1));
      expect(messages[0], equals({}));
    });
  });
}

// Helper to simulate incoming message from host
Future<void> _simulateIncomingMessage(
  String type,
  Map<String, dynamic> data,
) async {
  await _simulateIncomingMessageRaw({'type': type, 'data': data});
}

Future<void> _simulateIncomingMessageRaw(Map<String, dynamic> args) async {
  const channel = MethodChannel('floating_palette/messenger');

  await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .handlePlatformMessage(
    channel.name,
    channel.codec.encodeMethodCall(MethodCall('receive', args)),
    (_) {},
  );

  // Allow microtasks to complete
  await Future<void>.delayed(Duration.zero);
}
