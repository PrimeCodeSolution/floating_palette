import 'package:flutter_test/flutter_test.dart';

import 'package:floating_palette/src/config/palette_behavior.dart';
import 'package:floating_palette/src/config/palette_config.dart';
import 'package:floating_palette/src/config/palette_size.dart';
import 'package:floating_palette/src/testing/palette_test_host.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PaletteTestHost testHost;

  setUp(() async {
    testHost = await PaletteTestHost.create();
  });

  tearDown(() async {
    await testHost.dispose();
  });

  // ══════════════════════════════════════════════════════════════════════════
  // Lifecycle
  // ══════════════════════════════════════════════════════════════════════════

  group('lifecycle', () {
    test('warmUp sends create command', () async {
      final controller = testHost.createController('test');
      await controller.warmUp();

      testHost.verifyCommand('window', 'create', windowId: 'test');
      expect(controller.isWarm, true);
    });

    test('warmUp is idempotent', () async {
      final controller = testHost.createController('test');
      await controller.warmUp();
      await controller.warmUp();

      expect(testHost.mock.callCount('window', 'create'), 1);
    });

    test('coolDown sends destroy command', () async {
      final controller = testHost.createController('test');
      await controller.warmUp();
      testHost.clearCommands();

      await controller.coolDown();

      testHost.verifyCommand('window', 'destroy', windowId: 'test');
      expect(controller.isWarm, false);
    });

    test('coolDown does nothing if not warm', () async {
      final controller = testHost.createController('test');
      await controller.coolDown();

      testHost.verifyNoCommand('window', 'destroy');
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // Show / Hide
  // ══════════════════════════════════════════════════════════════════════════

  group('show/hide', () {
    test('show warms up and sends show command', () async {
      final controller = testHost.createController('test');
      await controller.show();

      testHost.verifyCommand('window', 'create', windowId: 'test');
      testHost.verifyCommand('visibility', 'show', windowId: 'test');
    });

    test('show stores args', () async {
      final controller = testHost.createController<String>('test');
      await controller.show(args: 'hello');

      expect(controller.currentArgs, 'hello');
    });

    test('hide sends hide command', () async {
      final controller = testHost.createController('test');
      await controller.show();
      testHost.simulateShown('test');
      testHost.clearCommands();

      await controller.hide();

      testHost.verifyCommand('visibility', 'hide', windowId: 'test');
    });

    test('hide clears args', () async {
      final controller = testHost.createController<String>('test');
      await controller.show(args: 'hello');
      testHost.simulateShown('test');

      await controller.hide();

      expect(controller.currentArgs, isNull);
    });

    test('hide does nothing if not visible', () async {
      final controller = testHost.createController('test');
      await controller.hide();

      testHost.verifyNoCommand('visibility', 'hide');
    });

    test('toggle shows if hidden', () async {
      final controller = testHost.createController('test');
      await controller.toggle();

      testHost.verifyCommand('visibility', 'show', windowId: 'test');
    });

    test('toggle hides if visible', () async {
      final controller = testHost.createController('test');
      await controller.show();
      testHost.simulateShown('test');
      testHost.clearCommands();

      await controller.toggle();

      testHost.verifyCommand('visibility', 'hide', windowId: 'test');
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // Position & Size
  // ══════════════════════════════════════════════════════════════════════════

  group('position and size', () {
    test('move(to:) sends frame setPosition', () async {
      final controller = testHost.createController('test');
      await controller.show();
      testHost.simulateShown('test');
      testHost.clearCommands();

      await controller.move(to: const Offset(100, 200));

      testHost.verifyCommand('frame', 'setPosition', windowId: 'test');
    });

    test('move does nothing when not visible', () async {
      final controller = testHost.createController('test');
      await controller.move(to: const Offset(100, 200));

      testHost.verifyNoCommand('frame', 'setPosition');
    });

    test('move(by:) sends frame setPosition with offset', () async {
      final controller = testHost.createController('test');
      await controller.show();
      testHost.simulateShown('test');

      // Stub current position
      testHost.mock.stubResponse('frame', 'getPosition', {'x': 50.0, 'y': 50.0});
      testHost.clearCommands();

      await controller.move(by: const Offset(10, 20));

      testHost.verifyCommand('frame', 'setPosition', windowId: 'test');
    });

    test('resize sends frame setSize', () async {
      final controller = testHost.createController('test');
      await controller.show();
      testHost.simulateShown('test');

      // Stub current size
      testHost.mock.stubResponse('frame', 'getSize', {'width': 400.0, 'height': 300.0});
      testHost.clearCommands();

      await controller.resize(width: 500);

      testHost.verifyCommand('frame', 'setSize', windowId: 'test');
    });

    test('resize does nothing when not visible', () async {
      final controller = testHost.createController('test');
      await controller.resize(width: 500);

      testHost.verifyNoCommand('frame', 'setSize');
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // Effects
  // ══════════════════════════════════════════════════════════════════════════

  group('effects', () {
    test('shake sends animation command when visible', () async {
      final controller = testHost.createController('test');
      await controller.show();
      testHost.simulateShown('test');
      testHost.clearCommands();

      await controller.shake();

      testHost.verifyCommand('animation', 'animate', windowId: 'test');
      final cmd = testHost.mock.findCommands('animation', 'animate').last;
      expect(cmd.params['property'], 'x'); // horizontal default
    });

    test('shake does nothing when not visible', () async {
      final controller = testHost.createController('test');
      await controller.shake();

      testHost.verifyNoCommand('animation', 'animate');
    });

    test('pulse sends scale animation', () async {
      final controller = testHost.createController('test');
      await controller.show();
      testHost.simulateShown('test');
      testHost.clearCommands();

      await controller.pulse();

      final cmd = testHost.mock.findCommands('animation', 'animate').last;
      expect(cmd.params['property'], 'scale');
    });

    test('bounce sends y animation', () async {
      final controller = testHost.createController('test');
      await controller.show();
      testHost.simulateShown('test');
      testHost.clearCommands();

      await controller.bounce();

      final cmd = testHost.mock.findCommands('animation', 'animate').last;
      expect(cmd.params['property'], 'y');
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // Callbacks
  // ══════════════════════════════════════════════════════════════════════════

  group('callbacks', () {
    test('onShow fires when palette becomes visible', () async {
      final controller = testHost.createController('test');
      var fired = false;
      controller.onShow(() => fired = true);

      await controller.show();
      testHost.simulateShown('test');

      expect(fired, true);
    });

    test('onHide fires when palette becomes hidden', () async {
      final controller = testHost.createController('test');
      var fired = false;
      controller.onHide(() => fired = true);

      await controller.show();
      testHost.simulateShown('test');
      testHost.simulateHidden('test');

      expect(fired, true);
    });

    test('onDispose fires on dispose', () {
      final controller = testHost.createController('test');
      var fired = false;
      controller.onDispose(() => fired = true);

      controller.dispose();

      expect(fired, true);
    });

    test('removeAllCallbacks clears all callbacks', () async {
      final controller = testHost.createController('test');
      var showFired = false;
      var hideFired = false;
      controller.onShow(() => showFired = true);
      controller.onHide(() => hideFired = true);

      controller.removeAllCallbacks();

      await controller.show();
      testHost.simulateShown('test');
      testHost.simulateHidden('test');

      expect(showFired, false);
      expect(hideFired, false);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // Config
  // ══════════════════════════════════════════════════════════════════════════

  group('config', () {
    test('updateConfig replaces fields', () {
      final controller = testHost.createController('test');
      expect(controller.config.size.width, 400); // default

      controller.updateConfig(size: const PaletteSize.large());

      expect(controller.config.size.width, 600);
    });

    test('updateConfig preserves other fields', () {
      final controller = testHost.createController(
        'test',
        config: const PaletteConfig(
          behavior: PaletteBehavior.persistent(),
        ),
      );

      controller.updateConfig(size: const PaletteSize.large());

      expect(controller.config.size.width, 600);
      expect(controller.config.behavior.draggable, true); // preserved
    });

    test('resetConfig restores defaults', () {
      final controller = testHost.createController(
        'test',
        config: const PaletteConfig(
          size: PaletteSize(width: 200),
        ),
      );

      controller.updateConfig(size: const PaletteSize.large());
      expect(controller.config.size.width, 600);

      controller.resetConfig();
      expect(controller.config.size.width, 200); // back to original
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // State
  // ══════════════════════════════════════════════════════════════════════════

  group('state', () {
    test('isVisible reflects visibility', () async {
      final controller = testHost.createController('test');
      expect(controller.isVisible, false);

      await controller.show();
      testHost.simulateShown('test');
      expect(controller.isVisible, true);

      testHost.simulateHidden('test');
      expect(controller.isVisible, false);
    });

    test('isWarm reflects warmup state', () async {
      final controller = testHost.createController('test');
      expect(controller.isWarm, false);

      await controller.warmUp();
      expect(controller.isWarm, true);

      await controller.coolDown();
      expect(controller.isWarm, false);
    });

    test('isFrozen reflects freeze state', () {
      final controller = testHost.createController('test');
      expect(controller.isFrozen, false);

      controller.freeze();
      expect(controller.isFrozen, true);

      controller.unfreeze();
      expect(controller.isFrozen, false);
    });

    test('visibilityStream emits changes', () async {
      final controller = testHost.createController('test');
      final events = <bool>[];
      controller.visibilityStream.listen(events.add);

      await controller.show();
      testHost.simulateShown('test');
      testHost.simulateHidden('test');

      expect(events, [true, false]);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // Show/Hide Serialization
  // ══════════════════════════════════════════════════════════════════════════

  group('show/hide serialization', () {
    test('concurrent show and hide execute sequentially', () async {
      final controller = testHost.createController('test');

      // Fire both concurrently
      final showFuture = controller.show();
      final hideFuture = controller.hide();

      await showFuture;
      await hideFuture;

      // Show should have completed before hide ran
      testHost.verifyCommand('visibility', 'show', windowId: 'test');
    });

    test('rapid double show only creates one window', () async {
      final controller = testHost.createController('test');

      await Future.wait([controller.show(), controller.show()]);

      // warmUp is idempotent, so create is called once
      expect(testHost.mock.callCount('window', 'create'), 1);
    });

    test('hide when already hidden is idempotent', () async {
      final controller = testHost.createController('test');

      // Never shown, so hide should be a no-op
      await controller.hide();
      await controller.hide();

      testHost.verifyNoCommand('visibility', 'hide');
    });

    test('hide after show+simulateShown sends hide', () async {
      final controller = testHost.createController('test');
      await controller.show();
      testHost.simulateShown('test');
      testHost.clearCommands();

      await controller.hide();

      testHost.verifyCommand('visibility', 'hide', windowId: 'test');
    });
  });
}
