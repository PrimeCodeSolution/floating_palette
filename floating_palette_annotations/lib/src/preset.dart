/// Pre-configured palette types for common use cases.
///
/// Use presets to quickly configure palettes with sensible defaults:
///
/// ```dart
/// @FloatingPaletteApp(palettes: [
///   PaletteAnnotation(
///     id: 'menu',
///     widget: MyMenu,
///     preset: Preset.menu,  // Sensible defaults for a menu
///     width: 320,           // Override specific values
///   ),
/// ])
/// ```
///
/// Individual fields (width, hideOnEscape, etc.) override preset defaults.
enum Preset {
  /// Dropdown/context menu.
  ///
  /// Defaults:
  /// - Shows near cursor
  /// - Hides on click outside, escape
  /// - Takes focus
  /// - Width: 280, maxHeight: 400
  menu,

  /// Tooltip/hint popup.
  ///
  /// Defaults:
  /// - Shows near cursor
  /// - Hides on click outside, escape, focus lost
  /// - Does NOT take focus
  /// - Width: 200, maxHeight: 150
  tooltip,

  /// Modal dialog.
  ///
  /// Defaults:
  /// - Centered on screen
  /// - Hides on escape only (not click outside)
  /// - Takes focus
  /// - Width: 480, minHeight: 200
  modal,

  /// Spotlight/command palette.
  ///
  /// Defaults:
  /// - Centered near top of screen
  /// - Hides on click outside, escape
  /// - Takes focus
  /// - Returns to previous app when dismissed
  /// - Width: 600, maxHeight: 400
  spotlight,

  /// Persistent floating panel.
  ///
  /// Defaults:
  /// - Does NOT auto-hide
  /// - Draggable
  /// - Stays until explicitly hidden
  /// - Width: 300
  persistent,
}
