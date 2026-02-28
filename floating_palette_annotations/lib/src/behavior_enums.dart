/// What happens to focus when a palette is hidden.
enum OnHideFocus {
  /// Don't change focus.
  none,

  /// Activate main app window (default).
  mainWindow,

  /// Hide app, return to previous app (spotlight-style).
  previousApp,
}

/// Controls what counts as "clicking outside" the palette.
enum ClickOutsideScope {
  /// Only clicks in non-palette areas trigger click-outside.
  /// Clicking on a sibling palette does NOT dismiss this palette.
  nonPalette,

  /// Any click outside this specific palette triggers click-outside,
  /// including clicks on sibling palettes.
  anywhere,
}

/// Whether the palette takes keyboard focus when shown.
enum TakesFocus {
  /// Take keyboard focus when shown (default).
  yes,

  /// Don't take focus (for companions/tooltips).
  no,
}
