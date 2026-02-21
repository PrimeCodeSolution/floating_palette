/// Guards against re-showing palettes during dismiss cycles.
///
/// When a palette is dismissed via click-outside, there's a brief window
/// where the click might trigger re-show logic. The guard blocks shows
/// for a configurable duration after dismiss.
class ShowGuard {
  final Map<String, DateTime> _dismissTimestamps = {};
  final Duration guardDuration;

  ShowGuard({this.guardDuration = const Duration(milliseconds: 100)});

  /// Record that a palette was just dismissed.
  void markDismissed(String paletteId) {
    _dismissTimestamps[paletteId] = DateTime.now();
  }

  /// Check if showing this palette is currently blocked.
  bool isBlocked(String paletteId) {
    final dismissTime = _dismissTimestamps[paletteId];
    if (dismissTime == null) return false;

    final elapsed = DateTime.now().difference(dismissTime);
    if (elapsed > guardDuration) {
      _dismissTimestamps.remove(paletteId);
      return false;
    }
    return true;
  }

  /// Clear the guard for a palette (allow immediate re-show).
  void clear(String paletteId) {
    _dismissTimestamps.remove(paletteId);
  }
}
