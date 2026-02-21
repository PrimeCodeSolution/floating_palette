/// Defines a group of palettes where at most one can be visible at a time.
///
/// Palettes in the same group are mutually exclusive - showing one
/// automatically hides the others.
///
/// ## Usage
///
/// ```dart
/// // Built-in groups for common patterns
/// const menuGroup = PaletteGroup.menu;
///
/// // Custom groups for domain-specific exclusivity
/// const inspectorGroup = PaletteGroup('inspectors');
/// ```
///
/// ## How It Works
///
/// When a palette with a group is shown via `registerPalette()`,
/// InputManager automatically hides any other visible palettes
/// in the same group before showing the new one.
class PaletteGroup {
  /// The unique identifier for this group.
  final String name;

  /// Create a custom palette group.
  ///
  /// Use for domain-specific exclusivity rules:
  /// ```dart
  /// const toolPaletteGroup = PaletteGroup('tools');
  /// ```
  const PaletteGroup(this.name);

  /// Mutually exclusive menus (slash menu, context menu, style menu, etc.)
  ///
  /// Only one menu can be visible at a time. Showing a new menu
  /// automatically dismisses any existing menu.
  static const menu = PaletteGroup('menu');

  /// Mutually exclusive popups/dropdowns.
  ///
  /// For dropdown selectors, color pickers, date pickers, etc.
  static const popup = PaletteGroup('popup');

  /// Mutually exclusive dialogs.
  ///
  /// For modal dialogs where only one should be visible at a time.
  static const dialog = PaletteGroup('dialog');

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PaletteGroup &&
          runtimeType == other.runtimeType &&
          name == other.name;

  @override
  int get hashCode => name.hashCode;

  @override
  String toString() => 'PaletteGroup($name)';
}
