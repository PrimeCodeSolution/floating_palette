# floating_palette

Native floating windows for Flutter desktop apps. Build Notion-style menus, Spotlight-style search, tooltips, and more — each running in its own native window.

[![pub package](https://img.shields.io/pub/v/floating_palette.svg)](https://pub.dev/packages/floating_palette)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![Platform: macOS](https://img.shields.io/badge/platform-macOS-lightgrey.svg)](#platform-support)

![Notion-style editor demo](https://raw.githubusercontent.com/PrimeCodeSolution/floating_palette/main/floating_palette/doc/demo-notion.webp)

## Features

- **Native Windows** — Each palette runs in its own NSPanel, not a Flutter overlay
- **Code Generation** — Define palettes with annotations, get type-safe controllers
- **5 Presets** — Quick configuration for menus, tooltips, modals, spotlight, and persistent panels
- **Type-Safe Events** — Communicate between your app and palettes with typed events
- **Transforms & Effects** — Scale, rotate, flip, shake, pulse, bounce
- **Glass/Blur Effects** — Native NSVisualEffectView with custom path masking
- **Snap-to-Palette** — Attach palettes together so they move as one
- **Hot Restart Safe** — Native windows survive hot restart, Dart state syncs automatically


## Installation

```yaml
# pubspec.yaml
dependencies:
  floating_palette: ^0.1.0
  floating_palette_annotations: ^0.1.0

dev_dependencies:
  floating_palette_generator: ^0.1.0
  build_runner: ^2.4.0
```

## Quick Start

### 1. Define Your Palettes

```dart
// lib/palette_setup.dart
import 'package:flutter/widgets.dart';
import 'package:floating_palette/floating_palette.dart';
import 'package:floating_palette_annotations/floating_palette_annotations.dart';

part 'palette_setup.g.dart';

@FloatingPaletteApp(palettes: [
  PaletteAnnotation(
    id: 'command-menu',
    widget: CommandMenu,
    preset: Preset.menu,
    width: 320,
    events: [
      Event(CommandSelected),
    ],
  ),
  PaletteAnnotation(
    id: 'spotlight',
    widget: SpotlightSearch,
    preset: Preset.spotlight,
  ),
])
class PaletteSetup {}
```

### 2. Initialize at Startup

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Palettes.init();
  runApp(const MyApp());
}
```

### 3. Show Palettes

```dart
// Show near cursor
Palettes.commandMenu.show(
  position: PalettePosition.nearCursor(),
);

// Toggle visibility
Palettes.spotlight.toggle();
```

### 4. Build Palette Widgets

```dart
class CommandMenu extends StatelessWidget {
  const CommandMenu({super.key});

  @override
  Widget build(BuildContext context) {
    return PaletteScaffold(
      backgroundColor: Colors.white,
      child: ListView(
        children: commands.map((cmd) => ListTile(
          title: Text(cmd.name),
          onTap: () {
            Palette.of(context).emit(CommandSelected(cmd.id));
            Palette.of(context).hide();
          },
        )).toList(),
      ),
    );
  }
}
```

### 5. Listen for Events

```dart
@override
void initState() {
  super.initState();
  Palettes.commandMenu.onEvent<CommandSelected>((event) {
    executeCommand(event.commandId);
  });
}
```

### 6. Run Code Generation

```bash
dart run build_runner build
```

## Presets

Presets provide sensible defaults for common palette types. Individual fields override preset defaults.

| Preset | Description | Key Defaults |
|--------|-------------|--------------|
| `Preset.menu` | Dropdown/context menu | Near cursor, hides on click outside & escape, takes focus, 280×400 |
| `Preset.tooltip` | Hint popup | Near cursor, hides on click outside & escape & focus lost, no focus, 200×150 |
| `Preset.modal` | Dialog | Centered, hides on escape only, takes focus, 480×200 |
| `Preset.spotlight` | Command palette | Centered near top, hides on click outside & escape, returns to previous app, 600×400 |
| `Preset.persistent` | Floating panel | No auto-hide, draggable, keeps alive, 300 wide |

```dart
PaletteAnnotation(
  id: 'my-menu',
  widget: MyMenu,
  preset: Preset.menu,  // Use menu defaults
  width: 280,           // Override width
)
```

## Configuration Reference

### Annotation Options

All options on `PaletteAnnotation`:

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `id` | `String` | **required** | Unique palette identifier |
| `widget` | `Type` | **required** | Widget class to render |
| `args` | `Type?` | `null` | Optional typed args class |
| `events` | `List<Event>` | `[]` | Events this palette sends/receives |
| `eventNamespace` | `String?` | Same as `id` | Namespace for event IDs |
| `preset` | `Preset?` | `null` | Preset for sensible defaults |

### Size Configuration

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `width` | `double?` | `400` | Fixed width in pixels |
| `minHeight` | `double?` | `100` | Minimum height |
| `maxHeight` | `double?` | `600` | Maximum height before scrolling |
| `initialWidth` | `double?` | Same as `width` | Initial width for resizable palettes |
| `initialHeight` | `double?` | Same as `minHeight` | Initial height for resizable palettes |
| `resizable` | `bool?` | `false` | Allow user resize |
| `allowSnap` | `bool?` | `false` | Allow macOS window snapping |

### Behavior Configuration

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `hideOnClickOutside` | `bool?` | `true` | Hide when clicking outside |
| `hideOnEscape` | `bool?` | `true` | Hide on Escape key |
| `hideOnFocusLost` | `bool?` | `false` | Hide when losing focus |
| `draggable` | `bool?` | `false` | Allow dragging |
| `keepAlive` | `bool?` | `false` | Keep rendering when unfocused |
| `focus` | `TakesFocus?` | `TakesFocus.yes` | Whether to take keyboard focus |
| `onHideFocus` | `OnHideFocus?` | `OnHideFocus.mainWindow` | Where focus goes on hide |
| `alwaysOnTop` | `bool?` | `false` | Pin above all windows when shown |

### Appearance

Appearance is configured at runtime via `PaletteScaffold`:

```dart
PaletteScaffold(
  backgroundColor: Colors.white,
  cornerRadius: 12,          // Default: 12
  padding: EdgeInsets.all(8),
  border: GradientBorder(    // Animated gradient border
    width: 4.0,
    colors: [Colors.blue, Colors.purple],
  ),
  overflowPadding: EdgeInsets.only(bottom: 32), // For tooltips
  child: MyContent(),
)
```

## Positioning

```dart
// Near cursor (default for menus)
Palettes.menu.show(
  position: PalettePosition.nearCursor(offset: Offset(0, 8)),
);

// Centered on screen (default for modals/spotlight)
Palettes.modal.show(
  position: PalettePosition.centerScreen(yOffset: -100),
);

// At a specific screen coordinate
Palettes.tooltip.show(
  position: PalettePosition.at(Offset(200, 300)),
);

// Relative to another palette
Palettes.submenu.showRelativeTo(
  Palettes.menu,
  theirAnchor: Anchor.topRight,
  myAnchor: Anchor.topLeft,
  offset: Offset(4, 0),
);

// At a specific position with anchor
Palettes.tooltip.showAtPosition(
  screenPosition,
  anchor: Anchor.bottomCenter, // Tooltip appears above the point
);
```

### Anchor Points

The 9-point anchor system controls which corner/edge of the palette aligns to the target:

```
topLeft      topCenter      topRight
centerLeft   center         centerRight
bottomLeft   bottomCenter   bottomRight
```

## Events

### Defining Events

```dart
class CommandSelected extends PaletteEvent {
  static const id = 'command-menu.command_selected';

  @override
  String get eventId => id;

  final String commandId;
  const CommandSelected(this.commandId);

  @override
  Map<String, dynamic> toMap() => {'commandId': commandId};

  static CommandSelected fromMap(Map<String, dynamic> m) =>
      CommandSelected(m['commandId'] as String);
}
```

Event IDs are auto-generated as `${paletteId}.${snake_case(className)}`.

### Emitting Events (from palette widget)

```dart
Palette.of(context).emit(CommandSelected('paste'));
```

### Listening for Events (in host app)

```dart
Palettes.commandMenu.onEvent<CommandSelected>((event) {
  print('Selected: ${event.commandId}');
});
```

### Sharing Events Across Palettes

Set an explicit `eventNamespace` so event IDs remain stable across palettes:

```dart
PaletteAnnotation(
  id: 'editor',
  widget: EditorPalette,
  eventNamespace: 'notion',
  events: [Event(FilterChanged)],
),
PaletteAnnotation(
  id: 'slash-menu',
  widget: SlashMenuPalette,
  eventNamespace: 'notion',
  events: [Event(FilterChanged)],  // → notion.filter_changed (shared)
),
```

## Controller API

The generated `Palettes` class provides typed controllers for each palette.

### Visibility

```dart
await Palettes.menu.show();
await Palettes.menu.show(
  position: PalettePosition.nearCursor(),
  focus: true,
  delay: Duration(milliseconds: 100),
  autoHideAfter: Duration(seconds: 5),
  animate: true,
);
await Palettes.menu.hide(animate: true);
await Palettes.menu.toggle();
```

### State

```dart
Palettes.menu.isVisible;          // bool — current visibility
Palettes.menu.visibilityStream;   // Stream<bool>
Palettes.menu.isWarm;             // bool — window created but maybe hidden
Palettes.menu.isFrozen;           // bool — interaction disabled
Palettes.menu.isSnapped;          // bool — snapped to another palette
```

### Positioning

```dart
// Move to absolute position
await Palettes.menu.move(to: Offset(100, 200), animate: true);

// Move by relative offset
await Palettes.menu.move(by: Offset(50, 0));

// Show relative to another palette
await Palettes.submenu.showRelativeTo(
  Palettes.menu,
  theirAnchor: Anchor.bottomLeft,
  myAnchor: Anchor.topLeft,
);

// Show at specific screen position
await Palettes.tooltip.showAtPosition(
  screenPoint,
  anchor: Anchor.bottomCenter,
);
```

### Sizing

```dart
await Palettes.editor.resize(width: 600, height: 400);
await Palettes.editor.resize(to: Size(600, 400), animate: true);
```

### Transforms

```dart
await Palettes.card.scale(1.5, anchor: Alignment.center, animate: true);
await Palettes.card.rotate(0.1);  // radians
await Palettes.card.flip(axis: Axis.horizontal);
await Palettes.card.resetTransform(animate: true);
```

### Effects

```dart
// Shake for error feedback
await Palettes.form.shake(
  direction: ShakeDirection.horizontal,
  intensity: 10,
  count: 3,
);

// Pulse for attention
await Palettes.notification.pulse(maxScale: 1.1, count: 2);

// Bounce
await Palettes.badge.bounce(height: 20, count: 2);

// Fade
await Palettes.overlay.fade(0.5, duration: Duration(milliseconds: 200));
```

### Z-Order

```dart
await Palettes.menu.bringToFront();
await Palettes.menu.sendToBack();
await Palettes.menu.moveAbove('other-palette-id');
await Palettes.menu.moveBelow('other-palette-id');
await Palettes.menu.pin(level: PinLevel.aboveAll);
await Palettes.menu.unpin();
```

### Snap

Attach palettes together so they move as one:

```dart
// Attach keyboard below editor
await Palettes.keyboard.attachBelow(Palettes.editor, gap: 4);

// Or use the full API
await Palettes.keyboard.snapTo(
  Palettes.editor,
  myEdge: SnapEdge.top,
  targetEdge: SnapEdge.bottom,
  alignment: SnapAlignment.center,
  gap: 4,
  mode: SnapMode.bidirectional, // Drag either, both move
);

// Other convenience methods
await Palettes.toolbar.attachAbove(Palettes.editor);
await Palettes.sidebar.attachLeft(Palettes.editor);
await Palettes.panel.attachRight(Palettes.editor);

// Detach
await Palettes.keyboard.detach();

// Auto-snap: palettes snap when dragged near each other
await Palettes.keyboard.enableAutoSnap(AutoSnapConfig(
  proximityThreshold: 50,
));

// Listen for snap events
Palettes.keyboard.onSnapEvent((event) {
  if (event is SnapDragEnded && event.snapDistance < 50) {
    Palettes.keyboard.reSnap(); // Snap back
  }
});
```

### Focus

```dart
await Palettes.editor.focus();
await Palettes.editor.unfocus();
```

### Appearance

```dart
await Palettes.panel.setDraggable(true);
Palettes.panel.setBlur(enabled: true, material: 'hudWindow');
```

### Warm-up

Pre-create windows for instant show:

```dart
// Warm up immediately
await Palettes.menu.warmUp();

// Schedule during idle time
Palettes.menu.scheduleWarmUp(priority: Priority.idle);

// Warm up all palettes
PaletteController.scheduleWarmUpAll(Palettes.all);

// Destroy window to free resources
await Palettes.menu.coolDown();
```

### Batch Operations

```dart
// Hide all palettes
await Palettes.hideAll();
await Palettes.hideAll(except: {'spotlight'});

// Soft hide (remember state) and restore
await Palettes.softHide();
await Palettes.restore();

// Query
Palettes.isAnyVisible;   // bool
Palettes.visibleIds;     // List<String>

// Lookup
Palettes.byId('menu');   // PaletteController?

// Focus
await Palettes.focusMainWindow();
```

## Palette Widget API

Inside palette widgets, use the `Palette` static class:

```dart
class MyMenu extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);

    return PaletteScaffold(
      backgroundColor: Colors.white,
      child: Column(
        children: [
          // Emit typed event
          ListTile(
            onTap: () => palette.emit(ItemSelected('foo')),
          ),
          // Hide self
          TextButton(
            onPressed: () => palette.hide(),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }
}
```

### Messaging

```dart
// Palette → Host
Palette.send('item-selected', {'id': item.id});

// Host → Palette
Palette.on('filter-update', (data) {
  setState(() => _filter = data['query']);
});

// Return result (for showAndWait callers)
Palette.returnResult({'selected': item.id});
Palette.cancel();
```

### Cross-Palette Queries

```dart
// Check if another palette is visible
if (Palette.isVisibleById('slash-menu')) {
  // ...
}

// Subscribe to visibility changes
Palette.onVisibilityChanged('slash-menu', (visible) {
  setState(() => _slashMenuOpen = visible);
});
```

### SizeReporter

`PaletteScaffold` automatically sizes the native window to fit content. When `resizable: false` (default), the window resizes synchronously via FFI during layout — zero flicker.

When `resizable: true`, the window is user-resizable and `PaletteScaffold` expands to fill the window.

## Glass Effects

Native macOS blur effects (NSVisualEffectView) with custom path masking:

```dart
final glass = GlassEffectService();

// Enable glass effect
glass.enable(windowId, material: GlassMaterial.hudWindow);

// Update mask shape
glass.updateRRect(windowId, rrect, windowHeight: size.height);

// Or use arbitrary paths
glass.updatePath(windowId, path, windowHeight: size.height);

// Animate between shapes (native 60-120Hz interpolation)
glass.animateRRect(windowId, fromRRect, toRRect,
  windowHeight: size.height,
  duration: Duration(milliseconds: 200),
);

// Disable
glass.disable(windowId);
```

![Glass blur effect demo](https://raw.githubusercontent.com/PrimeCodeSolution/floating_palette/main/floating_palette/doc/demo-glass.webp)

### Glass Materials

| Material | Description |
|----------|-------------|
| `GlassMaterial.hudWindow` | HUD-style dark translucent |
| `GlassMaterial.sidebar` | Sidebar blur |
| `GlassMaterial.popover` | Popover blur |
| `GlassMaterial.menu` | Menu blur |
| `GlassMaterial.sheet` | Sheet blur |

## Input Management

### Keyboard

Keys are captured per-palette when shown. Configure via `PaletteKeyboard`:

```dart
// From annotation
PaletteAnnotation(
  id: 'editor',
  widget: EditorPalette,
  focus: TakesFocus.yes,  // Takes keyboard focus
)

// Listen for key events in controller
Palettes.editor.onKeyDown((key, modifiers) {
  if (key == LogicalKeyboardKey.enter) {
    // Handle enter
  }
});
```

### Click-Outside Behavior

```dart
// Per-show override
Palettes.menu.show(
  clickOutside: ClickOutsideBehavior.dismiss,
);
```

| Behavior | Description |
|----------|-------------|
| `dismiss` | Hide the palette |
| `passthrough` | Let the click through to the app |
| `block` | Block the click |
| `unfocus` | Just lose focus |

### Palette Groups

Palettes in the same group don't trigger click-outside for each other:

```dart
Palettes.menu.show(group: PaletteGroup.menu);
Palettes.submenu.show(group: PaletteGroup.menu);
// Clicking submenu won't hide menu
```

## Platform Support

| Platform | Status |
|----------|--------|
| macOS | Full support (NSPanel) |
| Windows | Planned |
| Linux | Not yet supported |

## Advanced Usage

For direct access to service clients, native bridge, FFI, and testing utilities:

```dart
import 'package:floating_palette/floating_palette_advanced.dart';

// Access bridge directly
final bridge = PaletteHost.instance.bridge;

// Use service clients
final window = WindowClient(bridge);
await window.create('my-window');

// Check capabilities
if (PaletteHost.instance.capabilities.blur) {
  // Platform supports blur
}
```

See [Advanced Guide](doc/advanced.md) for service clients, testing, FFI, custom services, and more.

## Example

The `example/` directory includes a complete demo with:

- Notion-style editor with slash menu and style toolbar
- Spotlight-style search with glass effects
- Custom shape glass palette
- AI chat bubble (resizable, snappable)
- Analog clock (transparent, keep-alive)
- Virtual keyboard (snap-to-palette)

| Notion Editor | Liquid Glass |
|---|---|
| ![Notion](https://raw.githubusercontent.com/PrimeCodeSolution/floating_palette/main/floating_palette/doc/demo-notion.webp) | ![Glass](https://raw.githubusercontent.com/PrimeCodeSolution/floating_palette/main/floating_palette/doc/demo-glass.webp) |

| Chat Bubble | Clock |
|---|---|
| ![Chat](https://raw.githubusercontent.com/PrimeCodeSolution/floating_palette/main/floating_palette/doc/demo-chat.webp) | ![Clock](https://raw.githubusercontent.com/PrimeCodeSolution/floating_palette/main/floating_palette/doc/demo-clock.webp) |

```bash
cd example
dart run build_runner build
flutter run -d macos
```

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                          DART                                   │
├─────────────────────────────────────────────────────────────────┤
│  Palettes (generated)    — Type-safe palette access             │
│  PaletteController       — Show/hide/events/transforms/snap     │
│  PaletteHost             — Central dependency injection         │
│  Service Clients         — Typed native commands                │
│  NativeBridge            — Single method channel                │
│  SyncNativeBridge (FFI)  — Zero-latency operations              │
└────────────────────────────┬────────────────────────────────────┘
                             │ MethodChannel + FFI
┌────────────────────────────▼────────────────────────────────────┐
│                         NATIVE (Swift)                          │
├─────────────────────────────────────────────────────────────────┤
│  Services: Window, Frame, Visibility, Transform, Animation,    │
│           Input, Focus, ZOrder, Appearance, Screen, Message,   │
│           Snap, GlassEffect                                    │
│  WindowStore             — Manages palette NSPanels             │
│  Flutter Engine          — Each palette runs its own engine     │
└─────────────────────────────────────────────────────────────────┘
```
