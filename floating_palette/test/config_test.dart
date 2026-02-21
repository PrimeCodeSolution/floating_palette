import 'package:flutter/animation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:floating_palette/src/config/palette_animation.dart';
import 'package:floating_palette/src/config/palette_appearance.dart';
import 'package:floating_palette/src/config/palette_behavior.dart';
import 'package:floating_palette/src/config/palette_config.dart';
import 'package:floating_palette/src/config/palette_keyboard.dart';
import 'package:floating_palette/src/config/palette_lifecycle.dart';
import 'package:floating_palette/src/config/palette_position.dart';
import 'package:floating_palette/src/config/palette_size.dart';
import 'package:floating_palette/src/core/capability_guard.dart';
import 'package:floating_palette/src/input/click_outside_behavior.dart';

void main() {
  // ══════════════════════════════════════════════════════════════════════════
  // PaletteSize
  // ══════════════════════════════════════════════════════════════════════════

  group('PaletteSize', () {
    test('has sensible defaults', () {
      const size = PaletteSize();
      expect(size.width, 400);
      expect(size.minWidth, 200);
      expect(size.minHeight, 100);
      expect(size.maxHeight, 600);
      expect(size.resizable, false);
      expect(size.initialSize, isNull);
      expect(size.allowSnap, false);
    });

    test('.small() preset', () {
      const size = PaletteSize.small();
      expect(size.width, 280);
      expect(size.maxHeight, 200);
      expect(size.minHeight, 80);
    });

    test('.medium() preset', () {
      const size = PaletteSize.medium();
      expect(size.width, 400);
      expect(size.maxHeight, 400);
    });

    test('.large() preset', () {
      const size = PaletteSize.large();
      expect(size.width, 600);
      expect(size.minWidth, 300);
      expect(size.minHeight, 200);
      expect(size.maxHeight, 600);
    });

    test('copyWith replaces specified fields', () {
      const size = PaletteSize();
      final copied = size.copyWith(width: 500, resizable: true);
      expect(copied.width, 500);
      expect(copied.resizable, true);
      // Unchanged fields keep defaults
      expect(copied.minHeight, 100);
      expect(copied.maxHeight, 600);
    });

    test('toMap includes all fields', () {
      const size = PaletteSize(
        width: 320,
        minWidth: 150,
        minHeight: 50,
        maxHeight: 500,
        resizable: true,
        initialSize: Size(320, 200),
        allowSnap: true,
      );
      final map = size.toMap();
      expect(map['width'], 320);
      expect(map['minWidth'], 150);
      expect(map['minHeight'], 50);
      expect(map['maxHeight'], 500);
      expect(map['resizable'], true);
      expect(map['initialWidth'], 320);
      expect(map['initialHeight'], 200);
      expect(map['allowSnap'], true);
    });

    test('toMap omits initialSize when null', () {
      const size = PaletteSize();
      final map = size.toMap();
      expect(map.containsKey('initialWidth'), false);
      expect(map.containsKey('initialHeight'), false);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // PalettePosition
  // ══════════════════════════════════════════════════════════════════════════

  group('PalettePosition', () {
    test('has sensible defaults', () {
      const pos = PalettePosition();
      expect(pos.anchor, Anchor.topLeft);
      expect(pos.target, Target.cursor);
      expect(pos.offset, Offset.zero);
      expect(pos.avoidEdges, true);
      expect(pos.customPosition, isNull);
    });

    test('.nearCursor() factory', () {
      final pos = PalettePosition.nearCursor();
      expect(pos.target, Target.cursor);
      expect(pos.offset, const Offset(0, 8));
      expect(pos.anchor, Anchor.topLeft);
      expect(pos.avoidEdges, true);
    });

    test('.centerScreen() factory', () {
      final pos = PalettePosition.centerScreen(yOffset: -50);
      expect(pos.target, Target.screen);
      expect(pos.anchor, Anchor.center);
      expect(pos.offset, const Offset(0, -50));
    });

    test('.at() factory', () {
      const pos = PalettePosition.at(Offset(100, 200));
      expect(pos.target, Target.custom);
      expect(pos.customPosition, const Offset(100, 200));
      expect(pos.anchor, Anchor.topLeft);
    });

    test('copyWith replaces specified fields', () {
      const pos = PalettePosition();
      final copied = pos.copyWith(anchor: Anchor.center, avoidEdges: false);
      expect(copied.anchor, Anchor.center);
      expect(copied.avoidEdges, false);
      expect(copied.target, Target.cursor); // unchanged
    });

    test('toMap includes all fields', () {
      const pos = PalettePosition.at(Offset(50, 100));
      final map = pos.toMap();
      expect(map['anchor'], 'topLeft');
      expect(map['target'], 'custom');
      expect(map['offsetX'], 0);
      expect(map['offsetY'], 0);
      expect(map['avoidEdges'], true);
      expect(map['customX'], 50);
      expect(map['customY'], 100);
    });

    test('toMap omits customPosition when null', () {
      const pos = PalettePosition();
      final map = pos.toMap();
      expect(map.containsKey('customX'), false);
      expect(map.containsKey('customY'), false);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // PaletteBehavior
  // ══════════════════════════════════════════════════════════════════════════

  group('PaletteBehavior', () {
    test('has sensible defaults', () {
      const b = PaletteBehavior();
      expect(b.hideOnClickOutside, true);
      expect(b.hideOnEscape, true);
      expect(b.hideOnFocusLost, false);
      expect(b.focusPolicy, FocusPolicy.steal);
      expect(b.draggable, false);
      expect(b.onHideFocus, FocusRestoreMode.mainWindow);
      expect(b.group, isNull);
    });

    test('.modal() preset', () {
      const b = PaletteBehavior.modal();
      expect(b.hideOnClickOutside, false);
      expect(b.hideOnEscape, true);
      expect(b.focusPolicy, FocusPolicy.steal);
    });

    test('.tooltip() preset', () {
      const b = PaletteBehavior.tooltip();
      expect(b.hideOnClickOutside, true);
      expect(b.hideOnFocusLost, true);
      expect(b.focusPolicy, FocusPolicy.none);
      expect(b.onHideFocus, FocusRestoreMode.none);
    });

    test('.persistent() preset', () {
      const b = PaletteBehavior.persistent();
      expect(b.hideOnClickOutside, false);
      expect(b.hideOnEscape, false);
      expect(b.focusPolicy, FocusPolicy.request);
      expect(b.draggable, true);
      expect(b.onHideFocus, FocusRestoreMode.none);
    });

    test('.spotlight() preset', () {
      const b = PaletteBehavior.spotlight();
      expect(b.hideOnClickOutside, true);
      expect(b.hideOnEscape, true);
      expect(b.focusPolicy, FocusPolicy.steal);
      expect(b.onHideFocus, FocusRestoreMode.previousApp);
    });

    test('.menu() preset', () {
      const b = PaletteBehavior.menu();
      expect(b.hideOnClickOutside, true);
      expect(b.hideOnEscape, true);
      expect(b.focusPolicy, FocusPolicy.steal);
      expect(b.onHideFocus, FocusRestoreMode.mainWindow);
      expect(b.group, isNotNull);
      expect(b.group!.name, 'menu');
    });

    test('shouldFocus depends on focusPolicy', () {
      const steal = PaletteBehavior(focusPolicy: FocusPolicy.steal);
      const request = PaletteBehavior(focusPolicy: FocusPolicy.request);
      const none = PaletteBehavior(focusPolicy: FocusPolicy.none);
      expect(steal.shouldFocus, true);
      expect(request.shouldFocus, true);
      expect(none.shouldFocus, false);
    });

    test('clickOutsideBehavior maps from hideOnClickOutside', () {
      const hide = PaletteBehavior(hideOnClickOutside: true);
      const keep = PaletteBehavior(hideOnClickOutside: false);
      expect(hide.clickOutsideBehavior, ClickOutsideBehavior.dismiss);
      expect(keep.clickOutsideBehavior, ClickOutsideBehavior.passthrough);
    });

    test('copyWith replaces specified fields', () {
      const b = PaletteBehavior();
      final copied = b.copyWith(draggable: true, focusPolicy: FocusPolicy.none);
      expect(copied.draggable, true);
      expect(copied.focusPolicy, FocusPolicy.none);
      expect(copied.hideOnClickOutside, true); // unchanged
    });

    test('toMap includes all fields', () {
      const b = PaletteBehavior();
      final map = b.toMap();
      expect(map['hideOnClickOutside'], true);
      expect(map['hideOnEscape'], true);
      expect(map['hideOnFocusLost'], false);
      expect(map['focusPolicy'], 'steal');
      expect(map['draggable'], false);
      expect(map['onHideFocus'], 'mainWindow');
      expect(map['group'], isNull);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // PaletteAppearance
  // ══════════════════════════════════════════════════════════════════════════

  group('PaletteAppearance', () {
    test('has sensible defaults', () {
      const a = PaletteAppearance();
      expect(a.cornerRadius, 12);
      expect(a.shadow, PaletteShadow.medium);
      expect(a.backgroundColor, isNull);
      expect(a.transparent, true);
      expect(a.debugBorder, false);
    });

    test('.minimal() preset', () {
      const a = PaletteAppearance.minimal();
      expect(a.cornerRadius, 4);
      expect(a.shadow, PaletteShadow.none);
    });

    test('.dialog() preset', () {
      const a = PaletteAppearance.dialog();
      expect(a.cornerRadius, 16);
      expect(a.shadow, PaletteShadow.large);
    });

    test('.tooltip() preset', () {
      const a = PaletteAppearance.tooltip();
      expect(a.cornerRadius, 6);
      expect(a.shadow, PaletteShadow.small);
    });

    test('copyWith replaces specified fields', () {
      const a = PaletteAppearance();
      final copied = a.copyWith(cornerRadius: 20, debugBorder: true);
      expect(copied.cornerRadius, 20);
      expect(copied.debugBorder, true);
      expect(copied.shadow, PaletteShadow.medium); // unchanged
    });

    test('toMap includes all fields', () {
      const a = PaletteAppearance(backgroundColor: Color(0xFF112233));
      final map = a.toMap();
      expect(map['cornerRadius'], 12);
      expect(map['shadow'], 'medium');
      expect(map['backgroundColor'], isNotNull);
      expect(map['transparent'], true);
    });

    test('toMap omits backgroundColor when null', () {
      const a = PaletteAppearance();
      final map = a.toMap();
      expect(map.containsKey('backgroundColor'), false);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // PaletteAnimation
  // ══════════════════════════════════════════════════════════════════════════

  group('PaletteAnimation', () {
    test('has sensible defaults', () {
      const a = PaletteAnimation();
      expect(a.showDuration, const Duration(milliseconds: 150));
      expect(a.hideDuration, const Duration(milliseconds: 100));
      expect(a.curve, Curves.easeOutCubic);
      expect(a.enabled, true);
    });

    test('.none() preset disables animation', () {
      const a = PaletteAnimation.none();
      expect(a.showDuration, Duration.zero);
      expect(a.hideDuration, Duration.zero);
      expect(a.enabled, false);
    });

    test('.fast() preset', () {
      const a = PaletteAnimation.fast();
      expect(a.showDuration, const Duration(milliseconds: 100));
      expect(a.hideDuration, const Duration(milliseconds: 50));
      expect(a.curve, Curves.easeOut);
      expect(a.enabled, true);
    });

    test('.smooth() preset', () {
      const a = PaletteAnimation.smooth();
      expect(a.showDuration, const Duration(milliseconds: 200));
      expect(a.hideDuration, const Duration(milliseconds: 150));
      expect(a.curve, Curves.easeInOutCubic);
      expect(a.enabled, true);
    });

    test('copyWith replaces specified fields', () {
      const a = PaletteAnimation();
      final copied = a.copyWith(enabled: false);
      expect(copied.enabled, false);
      expect(copied.showDuration, const Duration(milliseconds: 150)); // unchanged
    });

    test('toMap includes all fields', () {
      const a = PaletteAnimation();
      final map = a.toMap();
      expect(map['showDurationMs'], 150);
      expect(map['hideDurationMs'], 100);
      expect(map['curve'], isA<String>());
      expect(map['enabled'], true);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // PaletteKeyboard
  // ══════════════════════════════════════════════════════════════════════════

  group('PaletteKeyboard', () {
    test('has sensible defaults', () {
      const k = PaletteKeyboard();
      expect(k.interceptKeys, true);
      expect(k.passthrough, isEmpty);
      expect(k.alwaysIntercept, isEmpty);
    });

    test('.interceptAll() preset', () {
      const k = PaletteKeyboard.interceptAll();
      expect(k.interceptKeys, true);
      expect(k.passthrough, isEmpty);
    });

    test('.passthroughAll() preset', () {
      const k = PaletteKeyboard.passthroughAll();
      expect(k.interceptKeys, false);
    });

    test('.standard() passes Tab through', () {
      final k = PaletteKeyboard.standard();
      expect(k.interceptKeys, true);
      expect(k.passthrough, contains(LogicalKeyboardKey.tab));
    });

    test('copyWith replaces specified fields', () {
      const k = PaletteKeyboard();
      final copied = k.copyWith(interceptKeys: false);
      expect(copied.interceptKeys, false);
    });

    test('toMap includes all fields', () {
      const k = PaletteKeyboard();
      final map = k.toMap();
      expect(map['interceptKeys'], true);
      expect(map['passthrough'], isA<List>());
      expect(map['alwaysIntercept'], isA<List>());
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // PaletteConfig
  // ══════════════════════════════════════════════════════════════════════════

  group('PaletteConfig', () {
    test('has sensible defaults', () {
      const c = PaletteConfig();
      expect(c.size, isA<PaletteSize>());
      expect(c.position, isA<PalettePosition>());
      expect(c.behavior, isA<PaletteBehavior>());
      expect(c.keyboard, isA<PaletteKeyboard>());
      expect(c.appearance, isA<PaletteAppearance>());
      expect(c.animation, isA<PaletteAnimation>());
      expect(c.lifecycle, PaletteLifecycle.lazy);
      expect(c.unsupportedBehavior, UnsupportedBehavior.warnOnce);
    });

    test('copyWith replaces specified fields', () {
      const c = PaletteConfig();
      final copied = c.copyWith(
        size: const PaletteSize.large(),
        lifecycle: PaletteLifecycle.eager,
      );
      expect(copied.size.width, 600);
      expect(copied.lifecycle, PaletteLifecycle.eager);
      // Unchanged
      expect(copied.behavior.hideOnClickOutside, true);
    });

    test('merge with null returns self', () {
      const c = PaletteConfig();
      final merged = c.merge(null);
      expect(identical(merged, c), true);
    });

    test('merge replaces all fields from other', () {
      const original = PaletteConfig();
      const other = PaletteConfig(
        size: PaletteSize.large(),
        lifecycle: PaletteLifecycle.eager,
      );
      final merged = original.merge(other);
      expect(merged.size.width, 600);
      expect(merged.lifecycle, PaletteLifecycle.eager);
    });

    test('toMap produces complete map', () {
      const c = PaletteConfig();
      final map = c.toMap();
      expect(map.containsKey('size'), true);
      expect(map.containsKey('position'), true);
      expect(map.containsKey('behavior'), true);
      expect(map.containsKey('keyboard'), true);
      expect(map.containsKey('appearance'), true);
      expect(map.containsKey('animation'), true);
      expect(map['lifecycle'], 'lazy');
      expect(map['unsupportedBehavior'], 'warnOnce');
    });
  });
}
