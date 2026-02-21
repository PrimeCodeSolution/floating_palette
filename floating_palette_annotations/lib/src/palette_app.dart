import 'palette.dart';
import 'palette_defaults.dart';

/// Annotation to define a floating palette application.
///
/// Place this on a class to generate all the boilerplate for your palettes.
///
/// Example:
/// ```dart
/// @FloatingPaletteApp(
///   defaults: PaletteDefaults(
///     width: 400,
///     hideOnClickOutside: true,
///   ),
///   palettes: [
///     PaletteAnnotation(
///       id: 'editor',
///       widget: EditorPalette,
///       events: [
///         Event(FilterChanged),
///         Event(SlashTrigger),
///       ],
///     ),
///     PaletteAnnotation(id: 'emoji-picker', widget: EmojiPicker),
///   ],
/// )
/// class PaletteSetup {}
/// ```
///
/// This generates:
/// - Entry points for each palette
/// - Type-safe controllers via `Palettes` class
/// - Automatic event registration via `_registerAllEvents()`
class FloatingPaletteApp {
  /// Default configuration applied to all palettes.
  final PaletteDefaults? defaults;

  /// Widget wrapper applied to all palette content (for DI/state management).
  final Type? contentWrapper;

  /// List of palette definitions.
  final List<PaletteAnnotation> palettes;

  const FloatingPaletteApp({
    this.defaults,
    this.contentWrapper,
    required this.palettes,
  });
}
