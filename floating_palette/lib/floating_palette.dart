/// Floating Palette - Native floating panels for Flutter desktop apps.
///
/// ## Quick Start
///
/// 1. Define palettes with code generation:
/// ```dart
/// // palette_setup.dart
/// @FloatingPaletteApp(palettes: [
///   Palette(id: 'menu', widget: MyMenu, preset: PalettePreset.menu),
/// ])
/// class PaletteSetup {}
/// ```
///
/// 2. Initialize and use:
/// ```dart
/// // main.dart
/// void main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///   await Palettes.init();
///   runApp(const MyApp());
/// }
///
/// // Show the palette
/// Palettes.menu.show();
/// ```
///
/// 3. Build palette widgets:
/// ```dart
/// class MyMenu extends StatelessWidget {
///   Widget build(BuildContext context) {
///     return ListView(
///       children: items.map((item) => ListTile(
///         title: Text(item.name),
///         onTap: () {
///           Palette.of(context).emit(ItemSelected(item.id));
///           Palette.of(context).hide();
///         },
///       )).toList(),
///     );
///   }
/// }
/// ```
///
/// ## Advanced Usage
///
/// For power users who need direct access to services, bridge, FFI, etc.,
/// import `floating_palette_advanced.dart` instead.
library;

// ════════════════════════════════════════════════════════════════════════════════
// Entry Points
// ════════════════════════════════════════════════════════════════════════════════

// Host initialization
export 'src/core/palette_host.dart' show PaletteHost;

// Palette window entry point (used by generated code)
export 'src/runner/palette_runner.dart' show initPaletteEngine;

// Capabilities (for checking platform support)
export 'src/core/capabilities.dart' show Capabilities;
export 'src/core/capability_guard.dart' show UnsupportedBehavior;

// ════════════════════════════════════════════════════════════════════════════════
// Configuration
// ════════════════════════════════════════════════════════════════════════════════

// Main config class
export 'src/config/palette_config.dart' show PaletteConfig;

// Presets (menu, tooltip, modal, spotlight)
export 'src/config/palette_preset.dart' show PalettePreset, PalettePresetConfig;

// Config components (for customization)
export 'src/config/palette_size.dart' show PaletteSize;
export 'src/config/palette_position.dart' show PalettePosition, Anchor, Target;
export 'src/config/palette_behavior.dart'
    show PaletteBehavior, FocusPolicy, FocusRestoreMode;
export 'src/config/palette_appearance.dart' show PaletteAppearance, PaletteShadow;
export 'src/config/palette_animation.dart' show PaletteAnimation;
export 'src/config/palette_lifecycle.dart' show PaletteLifecycle;
export 'src/config/palette_keyboard.dart' show PaletteKeyboard;

// ════════════════════════════════════════════════════════════════════════════════
// Controller (main API)
// ════════════════════════════════════════════════════════════════════════════════

export 'src/controller/palette_controller.dart' show PaletteController;

// ════════════════════════════════════════════════════════════════════════════════
// Events (for type-safe communication)
// ════════════════════════════════════════════════════════════════════════════════

export 'src/events/palette_event.dart' show PaletteEvent, UnknownEventError;

// ════════════════════════════════════════════════════════════════════════════════
// Palette Widgets (used inside palette content)
// ════════════════════════════════════════════════════════════════════════════════

// Context accessor
export 'src/runner/palette.dart' show PaletteContext;
export 'src/runner/palette_api.dart' show Palette;

// Content widgets
export 'src/widgets/palette_scaffold.dart' show PaletteScaffold;
export 'src/widgets/size_reporter.dart' show SizeReporter;
export 'src/widgets/animated_gradient_border.dart' show AnimatedGradientBorder;

// Palette self-control (static utilities for inside palettes)
export 'src/widgets/palette_window.dart' show PaletteWindow;
export 'src/runner/palette_messenger.dart' show PaletteMessenger;
export 'src/runner/palette_self.dart' show PaletteSelf, PaletteSizeConfig;

// Glass effect (native blur with custom shapes)
export 'src/services/glass_effect_service.dart' show GlassEffectService, GlassMaterial;
export 'src/ffi/glass_animation_bridge.dart' show GlassAnimationCurve;

// ════════════════════════════════════════════════════════════════════════════════
// Positioning (for show(position:))
// ════════════════════════════════════════════════════════════════════════════════

export 'src/positioning/screen_rect.dart' show ScreenRect, RectToScreenRect, ScreenOffset;

// ════════════════════════════════════════════════════════════════════════════════
// Input (for group management)
// ════════════════════════════════════════════════════════════════════════════════

export 'src/input/palette_group.dart' show PaletteGroup;
export 'src/input/click_outside_behavior.dart' show ClickOutsideBehavior, ClickOutsideScope;

// ════════════════════════════════════════════════════════════════════════════════
// Data Types (returned by PaletteHost convenience methods)
// ════════════════════════════════════════════════════════════════════════════════

// ActiveAppInfo is returned by PaletteHost.getActiveAppBounds()
export 'src/services/screen_client.dart' show ActiveAppInfo;

// ════════════════════════════════════════════════════════════════════════════════
// Keyboard Events (for palette widgets)
// ════════════════════════════════════════════════════════════════════════════════

export 'src/runner/palette_runner.dart' show PaletteKeyEvent, PaletteKeyReceiver;

// ════════════════════════════════════════════════════════════════════════════════
// Snap (for palette-to-palette snapping)
// ════════════════════════════════════════════════════════════════════════════════

export 'src/snap/snap_types.dart' show SnapEdge, SnapAlignment, SnapConfig, AutoSnapConfig, SnapMode;
export 'src/snap/snap_events.dart'
    show SnapEvent, SnapDragStarted, SnapDragging, SnapDragEnded, SnapDetached, SnapSnapped,
         SnapProximityEntered, SnapProximityExited, SnapProximityUpdated;

// ════════════════════════════════════════════════════════════════════════════════
// Text Selection (system-wide text selection detection)
// ════════════════════════════════════════════════════════════════════════════════

export 'src/services/text_selection.dart' show SelectedText, AccessibilityPermission;
export 'src/services/text_selection_monitor.dart' show TextSelectionMonitor;
