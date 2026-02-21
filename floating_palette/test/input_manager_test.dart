import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:floating_palette/src/core/palette_host.dart';
import 'package:floating_palette/src/input/click_outside_behavior.dart';
import 'package:floating_palette/src/input/input_behavior.dart';
import 'package:floating_palette/src/input/input_manager.dart';
import 'package:floating_palette/src/input/palette_group.dart';
import 'package:floating_palette/src/testing/mock_native_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockNativeBridge mock;
  late InputManager inputManager;

  setUp(() {
    PaletteHost.reset();
    mock = MockNativeBridge()..stubDefaults();
    PaletteHost.forTesting(bridge: mock);
    inputManager = InputManager(mock);
  });

  tearDown(() {
    inputManager.dispose();
    PaletteHost.reset();
  });

  // ══════════════════════════════════════════════════════════════════════════
  // Registration
  // ══════════════════════════════════════════════════════════════════════════

  group('registration', () {
    test('registerPalette adds to visible set', () async {
      await inputManager.registerPalette('test', const InputBehavior());
      expect(inputManager.isPaletteVisible('test'), true);
      expect(inputManager.visiblePaletteIds, contains('test'));
    });

    test('registerPalette captures keyboard when keys provided', () async {
      await inputManager.registerPalette(
        'test',
        InputBehavior(keys: {LogicalKeyboardKey.escape}),
      );

      expect(mock.wasCalled('input', 'captureKeyboard'), true);
    });

    test('registerPalette captures pointer for dismiss behavior', () async {
      await inputManager.registerPalette(
        'test',
        const InputBehavior(clickOutside: ClickOutsideBehavior.dismiss),
      );

      expect(mock.wasCalled('input', 'capturePointer'), true);
    });

    test('registerPalette does not capture pointer for passthrough', () async {
      await inputManager.registerPalette(
        'test',
        const InputBehavior(clickOutside: ClickOutsideBehavior.passthrough),
      );

      expect(mock.wasCalled('input', 'capturePointer'), false);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // Unregistration
  // ══════════════════════════════════════════════════════════════════════════

  group('unregistration', () {
    test('unregisterPalette removes from visible set', () async {
      await inputManager.registerPalette('test', const InputBehavior());
      await inputManager.unregisterPalette('test');

      expect(inputManager.isPaletteVisible('test'), false);
    });

    test('unregisterPalette releases keyboard and pointer', () async {
      await inputManager.registerPalette(
        'test',
        InputBehavior(
          keys: {LogicalKeyboardKey.escape},
          clickOutside: ClickOutsideBehavior.dismiss,
        ),
      );
      mock.sentCommands.clear();

      await inputManager.unregisterPalette('test');

      expect(mock.wasCalled('input', 'releaseKeyboard'), true);
      expect(mock.wasCalled('input', 'releasePointer'), true);
    });

    test('unregisterPalette restores focus if it was focused', () async {
      await inputManager.registerPalette('test', const InputBehavior());
      await inputManager.setFocus(const PaletteFocused('test'));

      await inputManager.unregisterPalette('test');

      expect(inputManager.focusedEntity, isA<HostFocused>());
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // Exclusive Groups
  // ══════════════════════════════════════════════════════════════════════════

  group('exclusive groups', () {
    test('showing palette in group hides others in same group', () async {
      var dismissed = false;
      inputManager.registerDismissCallback('menu-1', () => dismissed = true);

      await inputManager.registerPalette(
        'menu-1',
        const InputBehavior(group: PaletteGroup.menu),
      );

      // Register second menu in same group
      await inputManager.registerPalette(
        'menu-2',
        const InputBehavior(group: PaletteGroup.menu),
      );

      expect(dismissed, true);
    });

    test('different groups dont interfere', () async {
      var dismissed = false;
      inputManager.registerDismissCallback('menu-1', () => dismissed = true);

      await inputManager.registerPalette(
        'menu-1',
        const InputBehavior(group: PaletteGroup.menu),
      );

      // Register palette in different group
      await inputManager.registerPalette(
        'popup-1',
        const InputBehavior(group: PaletteGroup.popup),
      );

      expect(dismissed, false);
    });

    test('getVisibleInGroup returns correct palettes', () async {
      await inputManager.registerPalette(
        'menu-1',
        const InputBehavior(group: PaletteGroup.menu),
      );
      await inputManager.registerPalette(
        'popup-1',
        const InputBehavior(group: PaletteGroup.popup),
      );

      expect(inputManager.getVisibleInGroup(PaletteGroup.menu), {'menu-1'});
      expect(inputManager.getVisibleInGroup(PaletteGroup.popup), {'popup-1'});
    });

    test('hideGroup requests dismiss for all palettes in group', () async {
      var menu1Dismissed = false;

      inputManager.onDismissRequested((id) {
        if (id == 'menu-1') menu1Dismissed = true;
      });

      await inputManager.registerPalette(
        'menu-1',
        const InputBehavior(
          clickOutside: ClickOutsideBehavior.passthrough,
          group: PaletteGroup.menu,
        ),
      );

      await inputManager.hideGroup(PaletteGroup.menu);

      expect(menu1Dismissed, true);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // Focus
  // ══════════════════════════════════════════════════════════════════════════

  group('focus', () {
    test('initial focus is HostFocused', () {
      expect(inputManager.focusedEntity, isA<HostFocused>());
      expect(inputManager.isPaletteFocused, false);
      expect(inputManager.focusedPaletteId, isNull);
    });

    test('setFocus to palette updates state', () async {
      await inputManager.registerPalette('test', const InputBehavior());
      await inputManager.setFocus(const PaletteFocused('test'));

      expect(inputManager.focusedEntity, isA<PaletteFocused>());
      expect(inputManager.isPaletteFocused, true);
      expect(inputManager.focusedPaletteId, 'test');
    });

    test('setFocus sends correct native commands', () async {
      await inputManager.registerPalette('test', const InputBehavior());
      mock.sentCommands.clear();

      await inputManager.setFocus(const PaletteFocused('test'));

      expect(mock.wasCalled('focus', 'focus'), true);
    });

    test('setFocus back to host restores focus', () async {
      await inputManager.registerPalette('test', const InputBehavior());
      await inputManager.setFocus(const PaletteFocused('test'));
      mock.sentCommands.clear();

      await inputManager.setFocus(const HostFocused());

      expect(inputManager.focusedEntity, isA<HostFocused>());
      expect(mock.wasCalled('focus', 'restoreFocus'), true);
    });

    test('focusStream emits changes', () async {
      final events = <FocusedEntity>[];
      inputManager.focusStream.listen(events.add);

      await inputManager.registerPalette('test', const InputBehavior());
      await inputManager.setFocus(const PaletteFocused('test'));
      await inputManager.setFocus(const HostFocused());

      expect(events, hasLength(2));
      expect(events[0], isA<PaletteFocused>());
      expect(events[1], isA<HostFocused>());
    });

    test('setFocus is idempotent', () async {
      await inputManager.registerPalette('test', const InputBehavior());
      await inputManager.setFocus(const PaletteFocused('test'));
      mock.sentCommands.clear();

      await inputManager.setFocus(const PaletteFocused('test'));

      // No commands should be sent for redundant focus change
      expect(mock.wasCalled('focus', 'focus'), false);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // Show Guard
  // ══════════════════════════════════════════════════════════════════════════

  group('show guard', () {
    test('isShowBlocked returns false normally', () {
      expect(inputManager.isShowBlocked('test'), false);
    });

    test('clearShowGuard allows re-show', () {
      // The show guard is internal, but clearShowGuard should always clear it
      inputManager.clearShowGuard('test');
      expect(inputManager.isShowBlocked('test'), false);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // Behavior
  // ══════════════════════════════════════════════════════════════════════════

  group('behavior', () {
    test('getBehavior returns registered behavior', () async {
      const behavior = InputBehavior(focus: false);
      await inputManager.registerPalette('test', behavior);

      expect(inputManager.getBehavior('test'), behavior);
    });

    test('getBehavior returns null for unregistered palette', () {
      expect(inputManager.getBehavior('unknown'), isNull);
    });
  });
}
