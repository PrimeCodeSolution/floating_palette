# Floating Palette

Native floating windows for Flutter desktop apps. Build Notion-style menus, Spotlight-style search, tooltips, and more.

## Features

- **Native Windows**: Each palette runs in its own native window (not a Flutter overlay)
- **Code Generation**: Define palettes once, get type-safe controllers
- **Presets**: Quick configuration for common patterns (menu, tooltip, modal, spotlight)
- **Type-Safe Events**: Communicate between app and palettes with typed events
- **Hot Restart Safe**: Native windows survive hot restart, Dart state syncs automatically

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
    preset: Preset.menu,      // Sensible defaults for menus
    width: 320,               // Override specific values
    events: [
      Event(CommandSelected), // -> command-menu.command_selected
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
// lib/main.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Palettes.init();  // Initialize palette system
  runApp(const MyApp());
}
```

### 3. Show Palettes

```dart
// Anywhere in your app
ElevatedButton(
  onPressed: () => Palettes.commandMenu.show(),
  child: Text('Open Menu'),
)

// With positioning
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
    return ListView(
      children: commands.map((cmd) => ListTile(
        title: Text(cmd.name),
        onTap: () {
          // Emit event to host app
          Palette.of(context).emit(CommandSelected(cmd.id));
          // Hide the palette
          Palette.of(context).hide();
        },
      )).toList(),
    );
  }
}
```

### 5. Listen for Events

```dart
// In your main app
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

Presets provide sensible defaults for common palette types:

| Preset | Description | Defaults |
|--------|-------------|----------|
| `menu` | Dropdown/context menu | Hides on click outside & escape, takes focus |
| `tooltip` | Hint popup | Hides on click outside, doesn't take focus |
| `modal` | Dialog | Centered, hides on escape only |
| `spotlight` | Command palette | Centered, returns to previous app on hide |
| `persistent` | Floating panel | Draggable, stays until explicitly hidden |

```dart
PaletteAnnotation(
  id: 'my-menu',
  widget: MyMenu,
  preset: Preset.menu,  // Use menu defaults
  width: 280,           // Override width
)
```

## Configuration Options

### Size

| Option | Default | Description |
|--------|---------|-------------|
| `width` | 300 | Fixed width in pixels |
| `minHeight` | 100 | Minimum height |
| `maxHeight` | 600 | Maximum before scrolling |
| `resizable` | false | Allow user resize |

### Behavior

| Option | Default | Description |
|--------|---------|-------------|
| `hideOnClickOutside` | true | Hide when clicking outside |
| `hideOnEscape` | true | Hide on Escape key |
| `hideOnFocusLost` | false | Hide when losing focus |
| `draggable` | false | Allow dragging |
| `focus` | `TakesFocus.yes` | Take keyboard focus |
| `onHideFocus` | `mainWindow` | Where focus goes on hide |

## Events

### Defining Events

```dart
class CommandSelected extends PaletteEvent {
  // Event IDs are auto-generated from the palette ID and class name:
  // "${paletteId}.${snake_case(className)}"
  // Example: command-menu + CommandSelected -> command-menu.command_selected
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

### Emitting Events (from palette)

```dart
Palette.of(context).emit(CommandSelected('paste'));
```

### Listening for Events (from host app)

```dart
Palettes.commandMenu.onEvent<CommandSelected>((event) {
  print('Selected: ${event.commandId}');
});
```

### Sharing Events Across Palettes

If you want the same event type to be shared across multiple palettes, set
an explicit namespace so IDs remain stable:

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
  events: [Event(FilterChanged)],
),
```

Both palettes will use `notion.filter_changed`.

## Controller API

The generated `Palettes` class provides controllers for each palette:

```dart
// Visibility
Palettes.menu.show();
Palettes.menu.hide();
Palettes.menu.toggle();

// State
Palettes.menu.isVisible;     // Current visibility
Palettes.menu.visibility;    // Stream<bool>

// Positioning
Palettes.menu.show(position: PalettePosition.nearCursor());
Palettes.menu.show(position: PalettePosition.centeredOnScreen());

// Batch operations
Palettes.hideAll();
Palettes.hideAll(except: {'spotlight'});

// Soft hide (remember state)
await Palettes.softHide();
await Palettes.restore();
```

## Platform Support

| Platform | Status |
|----------|--------|
| macOS | Full support |
| Windows | Partial (in progress) |
| Linux | Not yet supported |

## Advanced Usage

For power users who need direct access to services, bridge, or FFI:

```dart
import 'package:floating_palette/floating_palette_advanced.dart';

// Access bridge directly
final bridge = PaletteHost.instance.bridge;

// Use service clients
final windowClient = WindowClient(bridge);
await windowClient.setFrame(id, x: 100, y: 100, width: 400, height: 300);

// Check capabilities
if (PaletteHost.instance.capabilities.blur) {
  // Platform supports blur
}
```

See [Advanced Guide](docs/advanced.md) for more.

## Example

See the `example/` directory for a complete demo with:
- Notion-style editor with slash menu
- Spotlight-style search
- Custom glass effects
- AI chat bubble

```bash
cd example
dart run build_runner build
flutter run -d macos
```

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         DART                                     │
├─────────────────────────────────────────────────────────────────┤
│  Palettes (generated)      - Type-safe palette access           │
│  PaletteController         - Show/hide/events API               │
│  PaletteHost               - Central dependency injection       │
│  Service Clients           - Typed native commands              │
│  NativeBridge              - Single method channel              │
└──────────────────────────────┬──────────────────────────────────┘
                               │
┌──────────────────────────────▼──────────────────────────────────┐
│                        NATIVE                                    │
├─────────────────────────────────────────────────────────────────┤
│  Services: Window, Frame, Visibility, Transform, Animation,     │
│           Input, Focus, ZOrder, Appearance, Screen, Message     │
│  WindowStore               - Manages palette windows            │
│  Flutter Engine            - Each palette has own engine        │
└─────────────────────────────────────────────────────────────────┘
```
