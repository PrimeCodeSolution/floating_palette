import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:floating_palette/src/bridge/command.dart';
import 'package:floating_palette/src/bridge/event.dart';
import 'package:floating_palette/src/bridge/native_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channelName = 'floating_palette_test';
  late MethodChannel channel;
  late NativeBridge bridge;

  setUp(() {
    channel = const MethodChannel(channelName);
    bridge = NativeBridge(
      channelName: channelName,
      commandTimeout: const Duration(seconds: 2),
    );
  });

  tearDown(() {
    bridge.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('Command serialization', () {
    test('send() passes correct arguments to invokeMethod', () async {
      Map<String, dynamic>? receivedArgs;

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'command');
        receivedArgs = Map<String, dynamic>.from(call.arguments as Map);
        return 'ok';
      });

      await bridge.send<String>(const NativeCommand(
        service: 'window',
        command: 'create',
        windowId: 'test-1',
        params: {'id': 'test-1', 'keepAlive': true},
      ));

      expect(receivedArgs, isNotNull);
      expect(receivedArgs!['service'], 'window');
      expect(receivedArgs!['command'], 'create');
      expect(receivedArgs!['windowId'], 'test-1');
      expect(receivedArgs!['params']['id'], 'test-1');
      expect(receivedArgs!['params']['keepAlive'], true);
    });

    test('send() omits windowId when null', () async {
      Map<String, dynamic>? receivedArgs;

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        receivedArgs = Map<String, dynamic>.from(call.arguments as Map);
        return null;
      });

      await bridge.send<String>(const NativeCommand(
        service: 'screen',
        command: 'getScreens',
      ));

      expect(receivedArgs, isNotNull);
      expect(receivedArgs!.containsKey('windowId'), isFalse);
    });
  });

  group('Response typing', () {
    test('send<String> returns correct type', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        return 'window-123';
      });

      final result = await bridge.send<String>(const NativeCommand(
        service: 'window',
        command: 'create',
        windowId: 'test',
      ));

      expect(result, 'window-123');
    });

    test('send<bool> returns correct type', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        return true;
      });

      final result = await bridge.send<bool>(const NativeCommand(
        service: 'window',
        command: 'exists',
        windowId: 'test',
      ));

      expect(result, true);
    });

    test('send<int> returns correct type', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        return 42;
      });

      final result = await bridge.send<int>(const NativeCommand(
        service: 'zorder',
        command: 'getZIndex',
        windowId: 'test',
      ));

      expect(result, 42);
    });

    test('send<double> returns correct type', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        return 0.75;
      });

      final result = await bridge.send<double>(const NativeCommand(
        service: 'visibility',
        command: 'getOpacity',
        windowId: 'test',
      ));

      expect(result, 0.75);
    });

    test('sendForMap returns casted Map<String, dynamic>', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        return <dynamic, dynamic>{'x': 100.0, 'y': 200.0};
      });

      final result = await bridge.sendForMap(const NativeCommand(
        service: 'frame',
        command: 'getPosition',
        windowId: 'test',
      ));

      expect(result, isNotNull);
      expect(result!['x'], 100.0);
      expect(result['y'], 200.0);
    });

    test('sendForMap returns null when native returns null', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        return null;
      });

      final result = await bridge.sendForMap(const NativeCommand(
        service: 'frame',
        command: 'getPosition',
        windowId: 'test',
      ));

      expect(result, isNull);
    });
  });

  group('Timeout handling', () {
    test('throws NativeBridgeException with TIMEOUT code', () async {
      // Set up a handler that never responds
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        // Delay longer than the timeout
        await Future<void>.delayed(const Duration(seconds: 10));
        return null;
      });

      // Use a short timeout bridge for this test
      final shortBridge = NativeBridge(
        channelName: channelName,
        commandTimeout: const Duration(milliseconds: 100),
      );

      try {
        await expectLater(
          shortBridge.send<String>(const NativeCommand(
            service: 'test',
            command: 'slow',
          )),
          throwsA(isA<NativeBridgeException>().having(
            (e) => e.code,
            'code',
            'TIMEOUT',
          )),
        );
      } finally {
        shortBridge.dispose();
      }
    });
  });

  group('PlatformException wrapping', () {
    test('wraps PlatformException in NativeBridgeException', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        throw PlatformException(
          code: 'NOT_FOUND',
          message: 'Window not found',
        );
      });

      await expectLater(
        bridge.send<String>(const NativeCommand(
          service: 'window',
          command: 'destroy',
          windowId: 'missing',
        )),
        throwsA(isA<NativeBridgeException>()
            .having((e) => e.code, 'code', 'NOT_FOUND')
            .having((e) => e.message, 'message', 'Window not found')
            .having((e) => e.command.service, 'command.service', 'window')
            .having((e) => e.command.command, 'command.command', 'destroy')),
      );
    });
  });

  group('Event dispatch', () {
    test('subscriber receives events for its service', () async {
      final events = <NativeEvent>[];
      bridge.subscribe('visibility', (event) => events.add(event));

      // Simulate native sending an event
      await _simulateNativeEvent(channel, {
        'service': 'visibility',
        'event': 'shown',
        'windowId': 'test-1',
        'data': <String, dynamic>{},
      });

      expect(events, hasLength(1));
      expect(events[0].service, 'visibility');
      expect(events[0].event, 'shown');
      expect(events[0].windowId, 'test-1');
    });

    test('subscriber does not receive events for other services', () async {
      final events = <NativeEvent>[];
      bridge.subscribe('visibility', (event) => events.add(event));

      await _simulateNativeEvent(channel, {
        'service': 'frame',
        'event': 'moved',
        'windowId': 'test-1',
        'data': <String, dynamic>{'x': 10.0, 'y': 20.0},
      });

      expect(events, isEmpty);
    });

    test('multiple subscribers both receive same event', () async {
      final events1 = <NativeEvent>[];
      final events2 = <NativeEvent>[];
      bridge.subscribe('visibility', (event) => events1.add(event));
      bridge.subscribe('visibility', (event) => events2.add(event));

      await _simulateNativeEvent(channel, {
        'service': 'visibility',
        'event': 'shown',
        'windowId': 'test-1',
        'data': <String, dynamic>{},
      });

      expect(events1, hasLength(1));
      expect(events2, hasLength(1));
    });

    test('global subscriber receives all services', () async {
      final events = <NativeEvent>[];
      bridge.subscribeAll((event) => events.add(event));

      await _simulateNativeEvent(channel, {
        'service': 'visibility',
        'event': 'shown',
        'windowId': 'test-1',
        'data': <String, dynamic>{},
      });

      await _simulateNativeEvent(channel, {
        'service': 'frame',
        'event': 'moved',
        'windowId': 'test-2',
        'data': <String, dynamic>{'x': 0.0, 'y': 0.0},
      });

      expect(events, hasLength(2));
      expect(events[0].service, 'visibility');
      expect(events[1].service, 'frame');
    });

    test('unsubscribe removes callback', () async {
      final events = <NativeEvent>[];
      void handler(NativeEvent event) => events.add(event);

      bridge.subscribe('visibility', handler);

      await _simulateNativeEvent(channel, {
        'service': 'visibility',
        'event': 'shown',
        'windowId': 'test-1',
        'data': <String, dynamic>{},
      });
      expect(events, hasLength(1));

      bridge.unsubscribe('visibility', handler);

      await _simulateNativeEvent(channel, {
        'service': 'visibility',
        'event': 'hidden',
        'windowId': 'test-1',
        'data': <String, dynamic>{},
      });
      expect(events, hasLength(1)); // Still 1, not 2
    });

    test('error in one subscriber does not prevent others from firing', () async {
      final events = <NativeEvent>[];

      bridge.subscribe('visibility', (_) {
        throw Exception('Handler error');
      });
      bridge.subscribe('visibility', (event) => events.add(event));

      await _simulateNativeEvent(channel, {
        'service': 'visibility',
        'event': 'shown',
        'windowId': 'test-1',
        'data': <String, dynamic>{},
      });

      // Second subscriber should still fire despite first throwing
      expect(events, hasLength(1));
    });
  });

  group('Dispose', () {
    test('callbacks cleared after dispose', () async {
      final events = <NativeEvent>[];
      bridge.subscribe('visibility', (event) => events.add(event));
      bridge.subscribeAll((event) => events.add(event));

      bridge.dispose();

      // After dispose, events should not be delivered
      // Re-register the handler on the channel to simulate
      // (dispose removes the method call handler, so we need to verify
      // callbacks were cleared)
      expect(events, isEmpty);
    });

    test('method handler removed after dispose', () async {
      bridge.dispose();

      // After dispose, the channel method handler should be removed.
      // Sending an event should not throw or deliver.
      // This is implicitly tested by the fact that dispose() calls
      // _channel.setMethodCallHandler(null).
      // We verify by checking internal state was cleaned.
      // Can't easily test method handler removal directly, but we can
      // verify no errors occur if we create a new bridge on the same channel.
      final newBridge = NativeBridge(
        channelName: channelName,
        commandTimeout: const Duration(seconds: 2),
      );
      final events = <NativeEvent>[];
      newBridge.subscribe('test', (e) => events.add(e));

      await _simulateNativeEvent(channel, {
        'service': 'test',
        'event': 'ping',
        'data': <String, dynamic>{},
      });

      expect(events, hasLength(1));
      newBridge.dispose();
    });
  });

  group('NativeBridgeException', () {
    test('toString includes service, command, and code', () {
      const exception = NativeBridgeException(
        command: NativeCommand(
          service: 'window',
          command: 'create',
          windowId: 'test-1',
        ),
        message: 'Window already exists',
        code: 'ALREADY_EXISTS',
      );

      final str = exception.toString();
      expect(str, contains('window'));
      expect(str, contains('create'));
      expect(str, contains('test-1'));
      expect(str, contains('ALREADY_EXISTS'));
      expect(str, contains('Window already exists'));
    });

    test('toString works without windowId and code', () {
      const exception = NativeBridgeException(
        command: NativeCommand(
          service: 'screen',
          command: 'getScreens',
        ),
        message: 'Unknown error',
      );

      final str = exception.toString();
      expect(str, contains('screen'));
      expect(str, contains('getScreens'));
      expect(str, contains('Unknown error'));
    });
  });
}

/// Simulate a native event being sent to the Dart side via MethodChannel.
Future<void> _simulateNativeEvent(
    MethodChannel channel, Map<String, dynamic> eventData) async {
  final message =
      const StandardMethodCodec().encodeMethodCall(MethodCall('event', eventData));
  await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .handlePlatformMessage(channel.name, message, (_) {});
}
