import 'dart:ui';

/// Shadow presets for palettes.
enum PaletteShadow {
  /// No shadow.
  none,

  /// Subtle shadow for tooltips.
  small,

  /// Standard shadow for menus.
  medium,

  /// Prominent shadow for dialogs.
  large,
}

/// Visual appearance configuration for a palette.
class PaletteAppearance {
  /// Corner radius of the palette window.
  final double cornerRadius;

  /// Shadow style.
  final PaletteShadow shadow;

  /// Background color (null = use widget's background).
  final Color? backgroundColor;

  /// Whether the window is transparent (for rounded corners).
  ///
  /// Defaults to `true` to support rounded corners properly.
  /// Set to `false` only for rectangular windows without corner radius.
  final bool transparent;

  /// Debug: show red border around native panel bounds.
  final bool debugBorder;

  const PaletteAppearance({
    this.cornerRadius = 12,
    this.shadow = PaletteShadow.medium,
    this.backgroundColor,
    this.transparent = true,
    this.debugBorder = false,
  });

  /// Minimal appearance: no shadow, subtle radius.
  const PaletteAppearance.minimal()
      : cornerRadius = 4,
        shadow = PaletteShadow.none,
        backgroundColor = null,
        transparent = true,
        debugBorder = false;

  /// Dialog appearance: prominent shadow, larger radius.
  const PaletteAppearance.dialog()
      : cornerRadius = 16,
        shadow = PaletteShadow.large,
        backgroundColor = null,
        transparent = true,
        debugBorder = false;

  /// Tooltip appearance: small shadow, small radius.
  const PaletteAppearance.tooltip()
      : cornerRadius = 6,
        shadow = PaletteShadow.small,
        backgroundColor = null,
        transparent = true,
        debugBorder = false;

  PaletteAppearance copyWith({
    double? cornerRadius,
    PaletteShadow? shadow,
    Color? backgroundColor,
    bool? transparent,
    bool? debugBorder,
  }) {
    return PaletteAppearance(
      cornerRadius: cornerRadius ?? this.cornerRadius,
      shadow: shadow ?? this.shadow,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      transparent: transparent ?? this.transparent,
      debugBorder: debugBorder ?? this.debugBorder,
    );
  }

  Map<String, dynamic> toMap() => {
        'cornerRadius': cornerRadius,
        'shadow': shadow.name,
        if (backgroundColor != null) 'backgroundColor': backgroundColor!.toARGB32(),
        'transparent': transparent,
      };
}
