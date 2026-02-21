/// Default configuration applied to all palettes.
///
/// This is a simplified version for code generation.
/// The full config with Flutter types is in the main package.
class PaletteDefaults {
  /// Default width in logical pixels.
  final double? width;

  /// Default height in logical pixels.
  final double? height;

  /// Whether to hide when clicking outside.
  final bool? hideOnClickOutside;

  /// Whether to hide when pressing escape.
  final bool? hideOnEscape;

  const PaletteDefaults({
    this.width,
    this.height,
    this.hideOnClickOutside,
    this.hideOnEscape,
  });
}
