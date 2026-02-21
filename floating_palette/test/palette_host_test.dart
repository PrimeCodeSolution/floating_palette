import 'package:flutter_test/flutter_test.dart';

import 'package:floating_palette/src/core/palette_host.dart';
import 'package:floating_palette/src/testing/mock_native_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockNativeBridge mock;

  setUp(() {
    PaletteHost.reset();
    mock = MockNativeBridge()..stubDefaults();
  });

  tearDown(() {
    PaletteHost.reset();
  });

  // ══════════════════════════════════════════════════════════════════════════
  // Initialization
  // ══════════════════════════════════════════════════════════════════════════

  group('initialization', () {
    test('forTesting creates instance', () {
      final host = PaletteHost.forTesting(bridge: mock);
      expect(host, isNotNull);
      expect(PaletteHost.isInitialized, true);
    });

    test('isInitialized is false before init', () {
      expect(PaletteHost.isInitialized, false);
    });

    test('instance getter works after init', () {
      PaletteHost.forTesting(bridge: mock);
      expect(PaletteHost.instance, isNotNull);
    });

    test('instance getter throws before init', () {
      expect(() => PaletteHost.instance, throwsStateError);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // Controller Management
  // ══════════════════════════════════════════════════════════════════════════

  group('controller management', () {
    test('palette() creates controller', () {
      final host = PaletteHost.forTesting(bridge: mock);
      final controller = host.palette('test-1');
      expect(controller, isNotNull);
      expect(controller.id, 'test-1');
    });

    test('same ID returns same controller', () {
      final host = PaletteHost.forTesting(bridge: mock);
      final first = host.palette('test-1');
      final second = host.palette('test-1');
      expect(identical(first, second), true);
    });

    test('different IDs return different controllers', () {
      final host = PaletteHost.forTesting(bridge: mock);
      final a = host.palette('a');
      final b = host.palette('b');
      expect(identical(a, b), false);
    });

    test('getController returns null for unknown ID', () {
      final host = PaletteHost.forTesting(bridge: mock);
      expect(host.getController('unknown'), isNull);
    });

    test('getController returns existing controller', () {
      final host = PaletteHost.forTesting(bridge: mock);
      final created = host.palette('test-1');
      expect(identical(host.getController('test-1'), created), true);
    });

    test('controllers returns all created controllers', () {
      final host = PaletteHost.forTesting(bridge: mock);
      host.palette('a');
      host.palette('b');
      host.palette('c');
      expect(host.controllers.length, 3);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // Recovery
  // ══════════════════════════════════════════════════════════════════════════

  group('recovery', () {
    test('recover() syncs visible palettes from snapshot', () async {
      final host = PaletteHost.forTesting(bridge: mock);

      // Register controllers BEFORE recovery
      final controller = host.palette('existing-palette');

      // Stub snapshot with a visible window
      mock.stubResponse('host', 'getSnapshot', [
        {
          'id': 'existing-palette',
          'visible': true,
          'focused': false,
          'x': 100.0,
          'y': 200.0,
          'width': 400.0,
          'height': 300.0,
        },
      ]);

      await host.recover();

      expect(controller.isVisible, true);
      expect(controller.isWarm, true);
    });

    test('recover() destroys orphan windows', () async {
      final host = PaletteHost.forTesting(bridge: mock);

      // No controllers registered, but snapshot has a window
      mock.stubResponse('host', 'getSnapshot', [
        {
          'id': 'orphan-window',
          'visible': true,
          'focused': false,
          'x': 0.0,
          'y': 0.0,
          'width': 100.0,
          'height': 100.0,
        },
      ]);

      await host.recover();

      // Should have sent destroy command for orphan
      expect(mock.wasCalledFor('window', 'destroy', 'orphan-window'), true);
    });

    test('recover() handles empty snapshot', () async {
      final host = PaletteHost.forTesting(bridge: mock);
      host.palette('test');

      // Empty snapshot (already stubbed by stubDefaults)
      await host.recover();

      // Should complete without error, no destroy commands sent
      expect(mock.wasCalled('window', 'destroy'), false);
    });

    test('recover() handles null snapshot', () async {
      final host = PaletteHost.forTesting(bridge: mock);
      mock.stubResponse('host', 'getSnapshot', null);

      await host.recover();

      // Should complete without error
      expect(mock.wasCalled('window', 'destroy'), false);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // Disposal
  // ══════════════════════════════════════════════════════════════════════════

  group('disposal', () {
    test('dispose() resets singleton', () async {
      PaletteHost.forTesting(bridge: mock);
      expect(PaletteHost.isInitialized, true);

      await PaletteHost.instance.dispose();
      expect(PaletteHost.isInitialized, false);
    });

    test('reset() allows re-initialization', () {
      PaletteHost.forTesting(bridge: mock);
      PaletteHost.reset();
      expect(PaletteHost.isInitialized, false);

      // Can re-init
      final newMock = MockNativeBridge()..stubDefaults();
      PaletteHost.forTesting(bridge: newMock);
      expect(PaletteHost.isInitialized, true);
    });
  });
}
