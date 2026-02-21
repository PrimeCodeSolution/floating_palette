import 'package:flutter/widgets.dart';

/// Base class for palette arguments.
///
/// Extend this for type-safe args passing:
/// ```dart
/// class SlashMenuArgs extends PaletteArgs {
///   final List<MenuItem> items;
///   final void Function(MenuItem) onSelect;
///
///   SlashMenuArgs({required this.items, required this.onSelect});
/// }
/// ```
abstract class PaletteArgs {
  const PaletteArgs();
}

/// Provides access to palette args within a palette widget.
class PaletteArgsProvider<T extends PaletteArgs> extends InheritedWidget {
  final T args;

  const PaletteArgsProvider({
    super.key,
    required this.args,
    required super.child,
  });

  static T of<T extends PaletteArgs>(BuildContext context) {
    final provider =
        context.dependOnInheritedWidgetOfExactType<PaletteArgsProvider<T>>();
    assert(provider != null, 'No PaletteArgsProvider<$T> found in context');
    return provider!.args;
  }

  static T? maybeOf<T extends PaletteArgs>(BuildContext context) {
    final provider =
        context.dependOnInheritedWidgetOfExactType<PaletteArgsProvider<T>>();
    return provider?.args;
  }

  @override
  bool updateShouldNotify(PaletteArgsProvider<T> oldWidget) {
    return args != oldWidget.args;
  }
}

/// Extension for convenient args access.
extension PaletteArgsContext on BuildContext {
  /// Get args of type [T] from the nearest [PaletteArgsProvider].
  T paletteArgs<T extends PaletteArgs>() => PaletteArgsProvider.of<T>(this);

  /// Get args of type [T] or null if not available.
  T? maybePaletteArgs<T extends PaletteArgs>() =>
      PaletteArgsProvider.maybeOf<T>(this);
}
