/// When the palette's Flutter view is created.
enum PaletteLifecycle {
  /// Create on first show. Slight delay on first show, but saves resources.
  lazy,

  /// Create immediately on app start. Instant show, but uses more memory.
  eager,

  /// Don't create automatically. User must call warmUp() explicitly.
  manual,
}
