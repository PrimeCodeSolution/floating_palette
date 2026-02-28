/// Controls what counts as "clicking outside" the palette.
enum ClickOutsideScope {
  /// Only clicks in non-palette areas trigger click-outside.
  /// Clicking on a sibling palette does NOT dismiss this palette.
  nonPalette,

  /// Any click outside this specific palette triggers click-outside,
  /// including clicks on sibling palettes.
  anywhere,
}

/// Behavior when user clicks outside the palette.
enum ClickOutsideBehavior {
  /// Hide the palette when clicking outside.
  dismiss,

  /// Let the click pass through to underlying app, palette stays visible.
  passthrough,

  /// Block the click, palette stays visible.
  block,

  /// Just lose focus, palette stays visible.
  unfocus,
}
