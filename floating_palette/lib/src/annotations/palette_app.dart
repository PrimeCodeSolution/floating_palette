import '../config/config.dart';

/// Annotation to define a floating palette application.
///
/// Place this on a class (typically named `PaletteSetup` or similar) to
/// generate all the boilerplate for your palettes.
///
/// Example:
/// ```dart
/// @FloatingPaletteApp(
///   defaults: PaletteDefaults(
///     size: PaletteSize(width: 400),
///     behavior: PaletteBehavior(hideOnClickOutside: true),
///   ),
///   contentWrapper: AppProviders,
///   palettes: [
///     Palette(
///       id: 'slash-menu',
///       widget: SlashMenu,
///       args: SlashMenuArgs,
///     ),
///     Palette(
///       id: 'emoji-picker',
///       widget: EmojiPicker,
///       args: EmojiPickerArgs,
///       config: PaletteConfig(
///         size: PaletteSize.small(),
///         position: PalettePosition.nearCursor(),
///       ),
///     ),
///   ],
/// )
/// class PaletteSetup {}
/// ```
///
/// This generates:
/// - `paletteMain()` entry point
/// - Type-safe controllers for each palette
/// - `Palettes` locator class
/// - Args accessors for BuildContext
class FloatingPaletteApp {
  /// Default configuration applied to all palettes.
  final PaletteDefaults? defaults;

  /// Widget wrapper applied to all palette content (for DI/state management).
  ///
  /// Example: `contentWrapper: AppProviders`
  /// Where `AppProviders` is `Widget Function(Widget child)`.
  final Type? contentWrapper;

  /// Per-palette wrappers (overrides [contentWrapper] for specific palettes).
  final Map<String, Type>? paletteWrappers;

  /// List of palette definitions.
  final List<Palette> palettes;

  const FloatingPaletteApp({
    this.defaults,
    this.contentWrapper,
    this.paletteWrappers,
    required this.palettes,
  });
}

/// Default configuration applied to all palettes unless overridden.
class PaletteDefaults {
  final PaletteSize? size;
  final PalettePosition? position;
  final PaletteBehavior? behavior;
  final PaletteKeyboard? keyboard;
  final PaletteAppearance? appearance;
  final PaletteAnimation? animation;
  final PaletteLifecycle? lifecycle;

  const PaletteDefaults({
    this.size,
    this.position,
    this.behavior,
    this.keyboard,
    this.appearance,
    this.animation,
    this.lifecycle,
  });

  PaletteConfig toConfig() => PaletteConfig(
        size: size ?? const PaletteSize(),
        position: position ?? const PalettePosition(),
        behavior: behavior ?? const PaletteBehavior(),
        keyboard: keyboard ?? const PaletteKeyboard(),
        appearance: appearance ?? const PaletteAppearance(),
        animation: animation ?? const PaletteAnimation(),
        lifecycle: lifecycle ?? PaletteLifecycle.lazy,
      );
}

/// Definition of a single palette for code generation.
class Palette {
  /// Unique identifier for this palette.
  final String id;

  /// The widget class to render. Must have a default constructor.
  final Type widget;

  /// Optional args class for type-safe data passing.
  ///
  /// If provided, the generated controller will require this type when showing.
  final Type? args;

  /// Configuration specific to this palette (overrides defaults).
  final PaletteConfig? config;

  const Palette({
    required this.id,
    required this.widget,
    this.args,
    this.config,
  });
}

/// Marker annotation for a content wrapper function.
///
/// Example:
/// ```dart
/// @PaletteContentWrapper()
/// Widget appProviders(Widget child) {
///   return MultiProvider(
///     providers: [...],
///     child: child,
///   );
/// }
/// ```
class PaletteContentWrapper {
  const PaletteContentWrapper();
}
