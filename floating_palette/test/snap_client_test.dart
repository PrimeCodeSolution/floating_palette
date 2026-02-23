import 'package:flutter_test/flutter_test.dart';

import 'package:floating_palette/src/bridge/event.dart';
import 'package:floating_palette/src/services/snap_client.dart';
import 'package:floating_palette/src/snap/snap_events.dart';
import 'package:floating_palette/src/snap/snap_types.dart';
import 'package:floating_palette/src/testing/mock_native_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockNativeBridge mock;
  late SnapClient client;

  setUp(() {
    mock = MockNativeBridge();
    mock.stubDefaults();
    client = SnapClient(mock);
  });

  tearDown(() {
    client.dispose();
    mock.reset();
  });

  // ════════════════════════════════════════════════════════════════════════════
  // snap
  // ════════════════════════════════════════════════════════════════════════════

  group('snap', () {
    test('sends correct service, command and params', () async {
      await client.snap(
        followerId: 'follower',
        targetId: 'target',
        followerEdge: SnapEdge.top,
        targetEdge: SnapEdge.bottom,
      );

      expect(mock.sentCommands, hasLength(1));
      final cmd = mock.sentCommands.first;
      expect(cmd.service, equals('snap'));
      expect(cmd.command, equals('snap'));
      expect(cmd.windowId, isNull);
      expect(cmd.params['followerId'], equals('follower'));
      expect(cmd.params['targetId'], equals('target'));
      expect(cmd.params['followerEdge'], equals('top'));
      expect(cmd.params['targetEdge'], equals('bottom'));
      expect(cmd.params['alignment'], equals('center'));
      expect(cmd.params['gap'], equals(0.0));
    });

    test('passes custom alignment and gap', () async {
      await client.snap(
        followerId: 'f1',
        targetId: 't1',
        followerEdge: SnapEdge.left,
        targetEdge: SnapEdge.right,
        alignment: SnapAlignment.leading,
        gap: 8.0,
      );

      final cmd = mock.sentCommands.first;
      expect(cmd.params['alignment'], equals('leading'));
      expect(cmd.params['gap'], equals(8.0));
    });

    test('passes config', () async {
      await client.snap(
        followerId: 'f1',
        targetId: 't1',
        followerEdge: SnapEdge.bottom,
        targetEdge: SnapEdge.top,
        config: const SnapConfig(
          onTargetHidden: SnapOnTargetHidden.detach,
          onTargetDestroyed: SnapOnTargetDestroyed.detach,
        ),
      );

      final cmd = mock.sentCommands.first;
      final config = cmd.params['config'] as Map<String, dynamic>;
      expect(config['onTargetHidden'], equals('detach'));
      expect(config['onTargetDestroyed'], equals('detach'));
    });

    test('rejects self-snap (followerId == targetId)', () async {
      await client.snap(
        followerId: 'same',
        targetId: 'same',
        followerEdge: SnapEdge.top,
        targetEdge: SnapEdge.bottom,
      );

      expect(mock.sentCommands, isEmpty);
    });

    test('rejects empty followerId', () async {
      await client.snap(
        followerId: '',
        targetId: 'target',
        followerEdge: SnapEdge.top,
        targetEdge: SnapEdge.bottom,
      );

      expect(mock.sentCommands, isEmpty);
    });

    test('rejects empty targetId', () async {
      await client.snap(
        followerId: 'follower',
        targetId: '',
        followerEdge: SnapEdge.top,
        targetEdge: SnapEdge.bottom,
      );

      expect(mock.sentCommands, isEmpty);
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // detach
  // ════════════════════════════════════════════════════════════════════════════

  group('detach', () {
    test('sends correct params', () async {
      await client.detach('follower');

      final cmd = mock.sentCommands.first;
      expect(cmd.service, equals('snap'));
      expect(cmd.command, equals('detach'));
      expect(cmd.params['followerId'], equals('follower'));
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // reSnap
  // ════════════════════════════════════════════════════════════════════════════

  group('reSnap', () {
    test('sends correct params', () async {
      await client.reSnap('follower');

      final cmd = mock.sentCommands.first;
      expect(cmd.service, equals('snap'));
      expect(cmd.command, equals('reSnap'));
      expect(cmd.params['followerId'], equals('follower'));
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // getSnapDistance
  // ════════════════════════════════════════════════════════════════════════════

  group('getSnapDistance', () {
    test('parses double response', () async {
      mock.stubResponse('snap', 'getSnapDistance', 42.5);

      final result = await client.getSnapDistance('follower');

      expect(result, equals(42.5));
    });

    test('returns 0.0 on null response', () async {
      final result = await client.getSnapDistance('follower');

      expect(result, equals(0.0));
    });

    test('sends followerId in params', () async {
      await client.getSnapDistance('f1');

      final cmd = mock.sentCommands.first;
      expect(cmd.params['followerId'], equals('f1'));
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // setAutoSnapConfig
  // ════════════════════════════════════════════════════════════════════════════

  group('setAutoSnapConfig', () {
    test('sends config map in params', () async {
      await client.setAutoSnapConfig(
        'p1',
        const AutoSnapConfig(
          acceptsSnapOn: {SnapEdge.top, SnapEdge.bottom},
          canSnapFrom: {SnapEdge.left},
          proximityThreshold: 75.0,
        ),
      );

      final cmd = mock.sentCommands.first;
      expect(cmd.service, equals('snap'));
      expect(cmd.command, equals('setAutoSnapConfig'));
      expect(cmd.params['paletteId'], equals('p1'));

      final config = cmd.params['config'] as Map<String, dynamic>;
      expect(config['proximityThreshold'], equals(75.0));
      expect(config['showFeedback'], isTrue);
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // disableAutoSnap
  // ════════════════════════════════════════════════════════════════════════════

  group('disableAutoSnap', () {
    test('sends disabled config', () async {
      await client.disableAutoSnap('p1');

      final cmd = mock.sentCommands.first;
      expect(cmd.service, equals('snap'));
      expect(cmd.command, equals('setAutoSnapConfig'));
      expect(cmd.params['paletteId'], equals('p1'));

      final config = cmd.params['config'] as Map<String, dynamic>;
      final acceptsSnapOn = config['acceptsSnapOn'] as List;
      final canSnapFrom = config['canSnapFrom'] as List;
      expect(acceptsSnapOn, isEmpty);
      expect(canSnapFrom, isEmpty);
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // Events: onSnapEvent
  // ════════════════════════════════════════════════════════════════════════════

  group('onSnapEvent', () {
    test('fires SnapDragStarted on followerDragStarted event', () {
      SnapEvent? received;
      client.onSnapEvent('f1', (e) => received = e);

      mock.simulateEvent(const NativeEvent(
        service: 'snap',
        event: 'followerDragStarted',
        windowId: 'f1',
        data: {
          'frame': {'x': 10.0, 'y': 20.0, 'width': 100.0, 'height': 50.0},
          'snapDistance': 30.0,
        },
      ));

      expect(received, isA<SnapDragStarted>());
      final event = received as SnapDragStarted;
      expect(event.followerId, equals('f1'));
      expect(event.snapDistance, equals(30.0));
    });

    test('fires SnapDragging on followerDragging event', () {
      SnapEvent? received;
      client.onSnapEvent('f1', (e) => received = e);

      mock.simulateEvent(const NativeEvent(
        service: 'snap',
        event: 'followerDragging',
        windowId: 'f1',
        data: {
          'frame': {'x': 15.0, 'y': 25.0, 'width': 100.0, 'height': 50.0},
          'snapDistance': 20.0,
        },
      ));

      expect(received, isA<SnapDragging>());
      expect((received as SnapDragging).snapDistance, equals(20.0));
    });

    test('fires SnapDragEnded on followerDragEnded event', () {
      SnapEvent? received;
      client.onSnapEvent('f1', (e) => received = e);

      mock.simulateEvent(const NativeEvent(
        service: 'snap',
        event: 'followerDragEnded',
        windowId: 'f1',
        data: {
          'frame': {'x': 50.0, 'y': 60.0, 'width': 100.0, 'height': 50.0},
          'snapDistance': 5.0,
        },
      ));

      expect(received, isA<SnapDragEnded>());
      expect((received as SnapDragEnded).snapDistance, equals(5.0));
    });

    test('fires SnapDetached on detached event', () {
      SnapEvent? received;
      client.onSnapEvent('f1', (e) => received = e);

      mock.simulateEvent(const NativeEvent(
        service: 'snap',
        event: 'detached',
        windowId: 'f1',
        data: {'reason': 'userDrag'},
      ));

      expect(received, isA<SnapDetached>());
      expect((received as SnapDetached).reason, equals('userDrag'));
    });

    test('fires SnapSnapped on snapped event', () {
      SnapEvent? received;
      client.onSnapEvent('f1', (e) => received = e);

      mock.simulateEvent(const NativeEvent(
        service: 'snap',
        event: 'snapped',
        windowId: 'f1',
        data: {'targetId': 'target1'},
      ));

      expect(received, isA<SnapSnapped>());
      expect((received as SnapSnapped).targetId, equals('target1'));
    });

    test('fires SnapProximityEntered on proximityEntered event', () {
      SnapEvent? received;
      client.onSnapEvent('f1', (e) => received = e);

      mock.simulateEvent(const NativeEvent(
        service: 'snap',
        event: 'proximityEntered',
        windowId: 'f1',
        data: {
          'targetId': 't1',
          'draggedEdge': 'top',
          'targetEdge': 'bottom',
          'distance': 25.0,
        },
      ));

      expect(received, isA<SnapProximityEntered>());
      final event = received as SnapProximityEntered;
      expect(event.targetId, equals('t1'));
      expect(event.draggedEdge, equals('top'));
      expect(event.targetEdge, equals('bottom'));
      expect(event.distance, equals(25.0));
    });

    test('fires SnapProximityExited on proximityExited event', () {
      SnapEvent? received;
      client.onSnapEvent('f1', (e) => received = e);

      mock.simulateEvent(const NativeEvent(
        service: 'snap',
        event: 'proximityExited',
        windowId: 'f1',
        data: {'targetId': 't1'},
      ));

      expect(received, isA<SnapProximityExited>());
      expect((received as SnapProximityExited).targetId, equals('t1'));
    });

    test('fires SnapProximityUpdated on proximityUpdated event', () {
      SnapEvent? received;
      client.onSnapEvent('f1', (e) => received = e);

      mock.simulateEvent(const NativeEvent(
        service: 'snap',
        event: 'proximityUpdated',
        windowId: 'f1',
        data: {'targetId': 't1', 'distance': 12.5},
      ));

      expect(received, isA<SnapProximityUpdated>());
      final event = received as SnapProximityUpdated;
      expect(event.targetId, equals('t1'));
      expect(event.distance, equals(12.5));
    });

    test('ignores events for other followers', () {
      SnapEvent? received;
      client.onSnapEvent('f1', (e) => received = e);

      mock.simulateEvent(const NativeEvent(
        service: 'snap',
        event: 'followerDragStarted',
        windowId: 'f2',
        data: {
          'frame': {'x': 0.0, 'y': 0.0, 'width': 100.0, 'height': 50.0},
          'snapDistance': 10.0,
        },
      ));

      expect(received, isNull);
    });
  });
}
