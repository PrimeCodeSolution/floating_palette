import '../core/capability_guard.dart';
import 'palette_animation.dart';
import 'palette_appearance.dart';
import 'palette_behavior.dart';
import 'palette_keyboard.dart';
import 'palette_lifecycle.dart';
import 'palette_position.dart';
import 'palette_size.dart';

/// Complete configuration for a palette.
///
/// Combines all individual config classes into one.
/// Used both for annotation defaults and runtime overrides.
class PaletteConfig {
  final PaletteSize size;
  final PalettePosition position;
  final PaletteBehavior behavior;
  final PaletteKeyboard keyboard;
  final PaletteAppearance appearance;
  final PaletteAnimation animation;
  final PaletteLifecycle lifecycle;

  /// How to handle unsupported platform features.
  ///
  /// - [UnsupportedBehavior.throwError]: Throw when feature unavailable
  /// - [UnsupportedBehavior.warnOnce]: Log warning once, then no-op (default)
  /// - [UnsupportedBehavior.ignore]: Silent no-op
  final UnsupportedBehavior unsupportedBehavior;

  const PaletteConfig({
    this.size = const PaletteSize(),
    this.position = const PalettePosition(),
    this.behavior = const PaletteBehavior(),
    this.keyboard = const PaletteKeyboard(),
    this.appearance = const PaletteAppearance(),
    this.animation = const PaletteAnimation(),
    this.lifecycle = PaletteLifecycle.lazy,
    this.unsupportedBehavior = UnsupportedBehavior.warnOnce,
  });

  PaletteConfig copyWith({
    PaletteSize? size,
    PalettePosition? position,
    PaletteBehavior? behavior,
    PaletteKeyboard? keyboard,
    PaletteAppearance? appearance,
    PaletteAnimation? animation,
    PaletteLifecycle? lifecycle,
    UnsupportedBehavior? unsupportedBehavior,
  }) {
    return PaletteConfig(
      size: size ?? this.size,
      position: position ?? this.position,
      behavior: behavior ?? this.behavior,
      keyboard: keyboard ?? this.keyboard,
      appearance: appearance ?? this.appearance,
      animation: animation ?? this.animation,
      lifecycle: lifecycle ?? this.lifecycle,
      unsupportedBehavior: unsupportedBehavior ?? this.unsupportedBehavior,
    );
  }

  /// Merge with another config, preferring non-null values from [other].
  PaletteConfig merge(PaletteConfig? other) {
    if (other == null) return this;
    return PaletteConfig(
      size: other.size,
      position: other.position,
      behavior: other.behavior,
      keyboard: other.keyboard,
      appearance: other.appearance,
      animation: other.animation,
      lifecycle: other.lifecycle,
      unsupportedBehavior: other.unsupportedBehavior,
    );
  }

  Map<String, dynamic> toMap() => {
        'size': size.toMap(),
        'position': position.toMap(),
        'behavior': behavior.toMap(),
        'keyboard': keyboard.toMap(),
        'appearance': appearance.toMap(),
        'animation': animation.toMap(),
        'lifecycle': lifecycle.name,
        'unsupportedBehavior': unsupportedBehavior.name,
      };
}
