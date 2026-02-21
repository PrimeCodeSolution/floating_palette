import 'package:flutter/services.dart';

import 'click_outside_behavior.dart';
import 'palette_group.dart';

/// Input handling configuration for a palette.
///
/// Controls how keyboard events are captured and routed,
/// and how clicks outside the palette are handled.
class InputBehavior {
  /// Whether this palette should take keyboard focus when shown.
  final bool focus;

  /// Keys this palette wants to receive.
  ///
  /// - When focused: captures these keys (prevents host app from receiving)
  /// - When unfocused but visible: still receives these keys via routing
  /// - When null: captures all keys if focused, none if unfocused
  final Set<LogicalKeyboardKey>? keys;

  /// Behavior when user clicks outside the palette.
  final ClickOutsideBehavior clickOutside;

  /// Optional exclusive group membership.
  ///
  /// Palettes in the same group are mutually exclusive - showing one
  /// automatically hides the others.
  ///
  /// See [PaletteGroup] for built-in groups like [PaletteGroup.menu].
  final PaletteGroup? group;

  const InputBehavior({
    this.focus = true,
    this.keys,
    this.clickOutside = ClickOutsideBehavior.dismiss,
    this.group,
  });

  /// Default behavior: takes focus, captures all keys, dismisses on click outside.
  const InputBehavior.focused()
      : focus = true,
        keys = null,
        clickOutside = ClickOutsideBehavior.dismiss,
        group = null;

  /// Overlay behavior: no focus, no key capture, click passes through.
  const InputBehavior.overlay()
      : focus = false,
        keys = null,
        clickOutside = ClickOutsideBehavior.passthrough,
        group = null;

  /// Menu behavior: takes focus, captures navigation keys, dismisses on click outside.
  ///
  /// Part of the [PaletteGroup.menu] exclusive group - only one menu
  /// can be visible at a time.
  static InputBehavior menu() => InputBehavior(
        focus: true,
        keys: {
          LogicalKeyboardKey.arrowUp,
          LogicalKeyboardKey.arrowDown,
          LogicalKeyboardKey.arrowLeft,
          LogicalKeyboardKey.arrowRight,
          LogicalKeyboardKey.enter,
          LogicalKeyboardKey.escape,
          LogicalKeyboardKey.tab,
        },
        clickOutside: ClickOutsideBehavior.dismiss,
        group: PaletteGroup.menu,
      );

  /// Creates a copy with the specified fields replaced.
  InputBehavior copyWith({
    bool? focus,
    Set<LogicalKeyboardKey>? keys,
    ClickOutsideBehavior? clickOutside,
    PaletteGroup? group,
  }) {
    return InputBehavior(
      focus: focus ?? this.focus,
      keys: keys ?? this.keys,
      clickOutside: clickOutside ?? this.clickOutside,
      group: group ?? this.group,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InputBehavior &&
          runtimeType == other.runtimeType &&
          focus == other.focus &&
          _setEquals(keys, other.keys) &&
          clickOutside == other.clickOutside &&
          group == other.group;

  @override
  int get hashCode => Object.hash(focus, keys, clickOutside, group);

  static bool _setEquals<T>(Set<T>? a, Set<T>? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    return a.containsAll(b);
  }
}
