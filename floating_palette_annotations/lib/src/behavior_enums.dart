/// What happens to focus when a palette is hidden.
enum OnHideFocus {
  /// Don't change focus.
  none,

  /// Activate main app window (default).
  mainWindow,

  /// Hide app, return to previous app (spotlight-style).
  previousApp,
}

/// Whether the palette takes keyboard focus when shown.
enum TakesFocus {
  /// Take keyboard focus when shown (default).
  yes,

  /// Don't take focus (for companions/tooltips).
  no,
}
