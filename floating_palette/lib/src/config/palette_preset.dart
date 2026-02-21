import 'dart:ui' show Offset;

import 'palette_animation.dart';
import 'palette_appearance.dart';
import 'palette_behavior.dart';
import 'palette_config.dart';
import 'palette_position.dart';
import 'palette_size.dart';

/// Pre-configured palette types for common use cases.
///
/// Presets provide sensible defaults for size, behavior, position, and appearance.
/// Use [PalettePreset.config] to get the full configuration.
///
/// **Junior path (annotation):**
/// ```dart
/// @Palette(id: 'menu', widget: MyMenu, preset: PalettePreset.menu)
/// ```
///
/// **Power user path (runtime override):**
/// ```dart
/// final config = PalettePreset.menu.config.copyWith(
///   size: PaletteSize(width: 320),
/// );
/// ```
enum PalettePreset {
  /// Dropdown/context menu.
  ///
  /// - Shows near cursor
  /// - Hides on click outside, escape
  /// - Takes focus
  /// - Part of exclusive menu group
  menu,

  /// Tooltip/hint popup.
  ///
  /// - Shows near cursor
  /// - Hides on click outside, escape, focus lost
  /// - Does NOT take focus
  /// - Smaller default size
  tooltip,

  /// Modal dialog.
  ///
  /// - Centered on screen
  /// - Hides on escape only (not click outside)
  /// - Takes focus
  /// - Larger default size
  modal,

  /// Spotlight/command palette (like macOS Spotlight or VS Code command palette).
  ///
  /// - Centered near top of screen
  /// - Hides on click outside, escape
  /// - Takes focus
  /// - Returns to previous app when dismissed
  spotlight,

  /// Persistent floating panel.
  ///
  /// - Shows where specified
  /// - Does NOT auto-hide
  /// - Draggable
  /// - Stays until explicitly hidden
  persistent,

  /// No preset - use explicit config.
  ///
  /// All defaults from [PaletteConfig].
  custom,
}

/// Extension to get [PaletteConfig] from a preset.
extension PalettePresetConfig on PalettePreset {
  /// Get the full configuration for this preset.
  PaletteConfig get config => switch (this) {
        PalettePreset.menu => PaletteConfig(
            size: const PaletteSize(width: 280, maxHeight: 400),
            position: PalettePosition.nearCursor(),
            behavior: const PaletteBehavior.menu(),
            appearance: const PaletteAppearance(
              cornerRadius: 8,
              shadow: PaletteShadow.medium,
            ),
            animation: const PaletteAnimation(
              showDuration: Duration(milliseconds: 150),
              hideDuration: Duration(milliseconds: 100),
            ),
          ),
        PalettePreset.tooltip => PaletteConfig(
            size: const PaletteSize(width: 200, maxHeight: 150),
            position: PalettePosition.nearCursor(offset: const Offset(0, 8)),
            behavior: const PaletteBehavior.tooltip(),
            appearance: const PaletteAppearance.tooltip(),
            animation: const PaletteAnimation(
              showDuration: Duration(milliseconds: 100),
              hideDuration: Duration(milliseconds: 50),
            ),
          ),
        PalettePreset.modal => PaletteConfig(
            size: const PaletteSize(width: 480, minHeight: 200),
            position: PalettePosition.centerScreen(),
            behavior: const PaletteBehavior.modal(),
            appearance: const PaletteAppearance.dialog(),
            animation: const PaletteAnimation(
              showDuration: Duration(milliseconds: 200),
              hideDuration: Duration(milliseconds: 150),
            ),
          ),
        PalettePreset.spotlight => PaletteConfig(
            size: const PaletteSize(width: 600, maxHeight: 400),
            position: PalettePosition.centerScreen(yOffset: -100),
            behavior: const PaletteBehavior.spotlight(),
            appearance: const PaletteAppearance(
              cornerRadius: 10,
              shadow: PaletteShadow.large,
            ),
            animation: const PaletteAnimation(
              showDuration: Duration(milliseconds: 150),
              hideDuration: Duration(milliseconds: 100),
            ),
          ),
        PalettePreset.persistent => const PaletteConfig(
            size: PaletteSize(width: 300),
            position: PalettePosition(),
            behavior: PaletteBehavior.persistent(),
            appearance: PaletteAppearance(
              cornerRadius: 8,
              shadow: PaletteShadow.medium,
            ),
          ),
        PalettePreset.custom => const PaletteConfig(),
      };

  /// Get the default width for this preset.
  double get defaultWidth => config.size.width;

  /// Get the default behavior for this preset.
  PaletteBehavior get defaultBehavior => config.behavior;
}
