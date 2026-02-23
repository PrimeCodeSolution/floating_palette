import 'package:flutter_test/flutter_test.dart';
import 'package:floating_palette/src/bridge/event.dart';
import 'package:floating_palette/src/events/palette_event.dart';
import 'package:floating_palette/src/services/message_client.dart';
import 'package:floating_palette/src/testing/mock_native_bridge.dart';

// Test event classes
class TestEvent extends PaletteEvent {
  @override
  String get eventId => 'test.event';

  final String value;
  const TestEvent({required this.value});

  @override
  Map<String, dynamic> toMap() => {'value': value};

  static TestEvent fromMap(Map<String, dynamic> m) =>
      TestEvent(value: m['value'] as String);
}

class AnotherTestEvent extends PaletteEvent {
  @override
  String get eventId => 'test.another_event';

  final int count;
  const AnotherTestEvent({required this.count});

  @override
  Map<String, dynamic> toMap() => {'count': count};

  static AnotherTestEvent fromMap(Map<String, dynamic> m) =>
      AnotherTestEvent(count: m['count'] as int);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PaletteEvent', () {
    setUp(() {
      // Clear any previously registered factories
      // (PaletteEvent uses static state)
    });

    test('register and deserialize event', () {
      PaletteEvent.register('TestEvent', TestEvent.fromMap);

      final event = PaletteEvent.deserialize('TestEvent', {'value': 'hello'});

      expect(event, isA<TestEvent>());
      expect((event as TestEvent).value, equals('hello'));
    });

    test('returns null for unregistered event type', () {
      final event = PaletteEvent.deserialize('UnknownEvent', {'data': 123});

      expect(event, isNull);
    });

    test('multiple event types can be registered', () {
      PaletteEvent.register('TestEvent', TestEvent.fromMap);
      PaletteEvent.register('AnotherTestEvent', AnotherTestEvent.fromMap);

      final event1 = PaletteEvent.deserialize('TestEvent', {'value': 'test'});
      final event2 = PaletteEvent.deserialize('AnotherTestEvent', {'count': 42});

      expect(event1, isA<TestEvent>());
      expect((event1 as TestEvent).value, equals('test'));

      expect(event2, isA<AnotherTestEvent>());
      expect((event2 as AnotherTestEvent).count, equals(42));
    });

    test('toMap serializes event data', () {
      final event = TestEvent(value: 'serialized');

      expect(event.toMap(), equals({'value': 'serialized'}));
    });

    test('base PaletteEvent toMap returns empty map', () {
      // Create a minimal concrete implementation
      final event = _MinimalEvent();
      expect(event.toMap(), equals({}));
    });
  });

  group('PaletteMessage', () {
    test('constructs with required fields', () {
      final msg = PaletteMessage(
        paletteId: 'test-palette',
        type: 'test-type',
        data: {'key': 'value'},
      );

      expect(msg.paletteId, equals('test-palette'));
      expect(msg.type, equals('test-type'));
      expect(msg.data, equals({'key': 'value'}));
    });

    test('toString includes all fields', () {
      final msg = PaletteMessage(
        paletteId: 'p1',
        type: 'msg-type',
        data: {'a': 1},
      );

      final str = msg.toString();
      expect(str, contains('p1'));
      expect(str, contains('msg-type'));
      expect(str, contains('a'));
    });
  });

  group('MessageClient', () {
    late MockNativeBridge mockBridge;
    late MessageClient client;

    setUp(() {
      mockBridge = MockNativeBridge();
      mockBridge.stubDefaults();
      client = MessageClient(mockBridge);
    });

    tearDown(() {
      client.dispose();
      mockBridge.reset();
    });

    test('sendToPalette sends command to native', () async {
      await client.sendToPalette('target-palette', 'my-type', {'key': 'val'});

      expect(mockBridge.sentCommands.length, equals(1));
      final cmd = mockBridge.sentCommands[0];
      expect(cmd.service, equals('message'));
      expect(cmd.command, equals('send'));
      expect(cmd.windowId, equals('target-palette'));
      expect(cmd.params['type'], equals('my-type'));
      expect(cmd.params['data'], equals({'key': 'val'}));
    });

    test('sendToPalette with null data sends empty map', () async {
      await client.sendToPalette('p1', 'type');

      final cmd = mockBridge.sentCommands[0];
      expect(cmd.params['data'], equals({}));
    });

    test('dispose clears all callbacks', () async {
      client.onMessage((_) {});
      client.on('test', (_) {});

      client.dispose();

      // After dispose, callbacks should be cleared
      // (we can't easily test this without accessing private state,
      // but at least verify dispose doesn't throw)
      expect(true, isTrue);
    });
  });

  group('MessageClient dispose cleanup', () {
    test('after dispose, event handler is unsubscribed from bridge', () {
      final bridge = MockNativeBridge();
      bridge.stubDefaults();
      final disposableClient = MessageClient(bridge);

      var callbackFired = false;
      disposableClient.onMessage((_) => callbackFired = true);

      // Dispose the client, which should unsubscribe from the bridge
      disposableClient.dispose();

      // Simulate a message event after dispose
      bridge.simulateEvent(const NativeEvent(
        service: 'message',
        event: 'test-type',
        windowId: 'test-palette',
        data: {'key': 'value'},
      ));

      // The callback should NOT fire because dispose unsubscribed
      expect(callbackFired, isFalse);
    });

    test('after dispose, type-specific callbacks do not fire', () {
      final bridge = MockNativeBridge();
      bridge.stubDefaults();
      final disposableClient = MessageClient(bridge);

      var callbackFired = false;
      disposableClient.on('specific-type', (_) => callbackFired = true);

      disposableClient.dispose();

      bridge.simulateEvent(const NativeEvent(
        service: 'message',
        event: 'specific-type',
        windowId: 'p1',
        data: {},
      ));

      expect(callbackFired, isFalse);
    });

    test('after dispose, global callbacks do not fire', () {
      final bridge = MockNativeBridge();
      bridge.stubDefaults();
      final disposableClient = MessageClient(bridge);

      var globalFired = false;
      disposableClient.onMessage((_) => globalFired = true);

      disposableClient.dispose();

      bridge.simulateEvent(const NativeEvent(
        service: 'message',
        event: 'any-type',
        windowId: 'p1',
        data: {'hello': 'world'},
      ));

      expect(globalFired, isFalse);
    });
  });
}

// Minimal event for testing base class
class _MinimalEvent extends PaletteEvent {
  @override
  String get eventId => 'test.minimal';

  const _MinimalEvent();
}
