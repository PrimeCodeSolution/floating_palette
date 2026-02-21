/// Coordinates palette dismiss requests.
///
/// Manages per-palette dismiss callbacks and a legacy global callback.
/// When a dismiss is requested, tries the per-palette callback first,
/// then falls back to the legacy global callback.
class DismissCoordinator {
  /// Legacy global callback for dismiss requests.
  void Function(String paletteId)? _onDismissRequested;

  /// Per-palette dismiss callbacks.
  final _dismissCallbacks = <String, void Function()>{};

  /// Set callback for when a palette requests dismissal.
  ///
  /// This is the legacy API. Prefer using [registerDismissCallback] for
  /// per-palette callbacks, which are called automatically by the package.
  void onDismissRequested(void Function(String paletteId) callback) {
    _onDismissRequested = callback;
  }

  /// Register a dismiss callback for a specific palette.
  ///
  /// Called automatically by [PaletteController.show] when hideOnClickOutside is true.
  /// The callback is removed when [unregisterDismissCallback] is called.
  void registerDismissCallback(String paletteId, void Function() callback) {
    _dismissCallbacks[paletteId] = callback;
  }

  /// Unregister a dismiss callback for a specific palette.
  ///
  /// Called automatically by [PaletteController.hide].
  void unregisterDismissCallback(String paletteId) {
    _dismissCallbacks.remove(paletteId);
  }

  /// Request dismissal of a palette.
  ///
  /// Tries per-palette callback first, falls back to legacy callback.
  void requestDismiss(String paletteId) {
    final callback = _dismissCallbacks[paletteId];
    if (callback != null) {
      callback();
    } else {
      _onDismissRequested?.call(paletteId);
    }
  }
}
