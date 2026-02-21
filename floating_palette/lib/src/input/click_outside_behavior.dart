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
