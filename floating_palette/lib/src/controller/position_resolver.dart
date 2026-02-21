import 'dart:io' show Platform;
import 'dart:ui';

import '../config/palette_position.dart';
import '../services/screen_client.dart';

/// Resolves [PalettePosition] to screen coordinates.
///
/// Handles platform-specific coordinate systems:
/// - macOS: Y=0 at bottom, positive Y = up
/// - Windows: Y=0 at top, positive Y = down
class PositionResolver {
  final ScreenClient _screen;

  const PositionResolver(this._screen);

  /// Y multiplier for platform-aware offset calculation.
  ///
  /// User-facing API: positive Y offset = visual DOWN
  /// macOS native: positive Y = UP, so we negate
  /// Windows native: positive Y = DOWN, so we keep as-is
  static double get yMultiplier => Platform.isMacOS ? -1.0 : 1.0;

  /// Resolve a [PalettePosition] to screen coordinates.
  Future<Offset> resolve(PalettePosition position) async {
    switch (position.target) {
      case Target.cursor:
        final cursor = await _screen.getCursorPosition();
        return Offset(
          cursor.dx + position.offset.dx,
          cursor.dy + position.offset.dy * yMultiplier,
        );

      case Target.screen:
        final screens = await _screen.getScreens();
        if (screens.isEmpty) return position.offset;
        final primary =
            screens.firstWhere((s) => s.isPrimary, orElse: () => screens.first);
        final center = primary.workArea.center;
        return Offset(
          center.dx + position.offset.dx,
          center.dy + position.offset.dy * yMultiplier,
        );

      case Target.custom:
        return position.customPosition ?? Offset.zero;
    }
  }
}
