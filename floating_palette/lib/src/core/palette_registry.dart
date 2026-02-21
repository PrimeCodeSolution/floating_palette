import 'package:flutter/widgets.dart';

/// Registry for palette widget builders.
///
/// Maps palette IDs to their widget builder functions.
/// Used by the palette engine to instantiate palette content.
class PaletteRegistry {
  final Map<String, Widget Function()> _builders = {};

  /// Register a palette widget builder.
  void register(String id, Widget Function() builder) {
    _builders[id] = builder;
  }

  /// Register multiple palette widget builders.
  void registerAll(Map<String, Widget Function()> builders) {
    _builders.addAll(builders);
  }

  /// Get the builder for a palette ID.
  Widget Function()? get(String id) => _builders[id];

  /// Check if a palette is registered.
  bool has(String id) => _builders.containsKey(id);

  /// Get all registered palette IDs.
  Set<String> get ids => _builders.keys.toSet();

  /// Unregister a palette.
  void unregister(String id) {
    _builders.remove(id);
  }

  /// Clear all registrations.
  void clear() {
    _builders.clear();
  }
}
