import 'dart:ui';

/// Size configuration for a palette.
class PaletteSize {
  /// Initial/fixed width of the palette.
  final double width;

  /// Minimum width when resizable.
  final double minWidth;

  /// Minimum height (content can grow up to [maxHeight]).
  final double minHeight;

  /// Maximum height before scrolling.
  final double maxHeight;

  /// Whether the palette can be resized by the user.
  final bool resizable;

  /// Initial size when showing resizable palettes.
  ///
  /// When null, uses [width] x [minHeight].
  final Size? initialSize;

  /// Allow macOS window snapping when resizable.
  final bool allowSnap;

  const PaletteSize({
    this.width = 400,
    this.minWidth = 200,
    this.minHeight = 100,
    this.maxHeight = 600,
    this.resizable = false,
    this.initialSize,
    this.allowSnap = false,
  });

  /// Small preset: 280x200.
  const PaletteSize.small()
      : width = 280,
        minWidth = 200,
        minHeight = 80,
        maxHeight = 200,
        resizable = false,
        initialSize = null,
        allowSnap = false;

  /// Medium preset: 400x400.
  const PaletteSize.medium()
      : width = 400,
        minWidth = 200,
        minHeight = 100,
        maxHeight = 400,
        resizable = false,
        initialSize = null,
        allowSnap = false;

  /// Large preset: 600x600.
  const PaletteSize.large()
      : width = 600,
        minWidth = 300,
        minHeight = 200,
        maxHeight = 600,
        resizable = false,
        initialSize = null,
        allowSnap = false;

  PaletteSize copyWith({
    double? width,
    double? minWidth,
    double? minHeight,
    double? maxHeight,
    bool? resizable,
    Size? initialSize,
    bool? allowSnap,
  }) {
    return PaletteSize(
      width: width ?? this.width,
      minWidth: minWidth ?? this.minWidth,
      minHeight: minHeight ?? this.minHeight,
      maxHeight: maxHeight ?? this.maxHeight,
      resizable: resizable ?? this.resizable,
      initialSize: initialSize ?? this.initialSize,
      allowSnap: allowSnap ?? this.allowSnap,
    );
  }

  Map<String, dynamic> toMap() => {
        'width': width,
        'minWidth': minWidth,
        'minHeight': minHeight,
        'maxHeight': maxHeight,
        'resizable': resizable,
        if (initialSize != null) 'initialWidth': initialSize!.width,
        if (initialSize != null) 'initialHeight': initialSize!.height,
        'allowSnap': allowSnap,
      };
}
