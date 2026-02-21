# Advanced Guide

This guide covers advanced usage patterns for power users who need direct access to the underlying infrastructure.

## Imports

```dart
// Simple API (most users)
import 'package:floating_palette/floating_palette.dart';

// Advanced API (power users)
import 'package:floating_palette/floating_palette_advanced.dart';
```

The advanced import includes everything from the simple API plus:
- Native bridge and command types
- All service clients
- Input management internals
- FFI for synchronous operations
- Testing utilities

## PaletteHost

`PaletteHost` is the central dependency injection container. It owns all shared resources.

```dart
// Access after initialization
final host = PaletteHost.instance;

// Access components
host.bridge;        // NativeBridge - method channel
host.inputManager;  // InputManager - keyboard/click handling
host.capabilities;  // Capabilities - platform features
```

### Creating Controllers Manually

```dart
// Normal usage: controllers created via generated Palettes class
Palettes.menu.show();

// Manual creation (advanced)
final controller = PaletteHost.instance.palette<MyArgs>(
  'custom-palette',
  config: PaletteConfig(
    size: PaletteSize(width: 400),
    behavior: PaletteBehavior.menu(),
  ),
);
```

### Testing with PaletteHost

```dart
// In tests, create isolated instance with mock bridge
final mockBridge = MockNativeBridge();
mockBridge.stubDefaults();

final testHost = PaletteHost.forTesting(
  bridge: mockBridge,
  capabilities: const Capabilities.all(),
);

// Create controller with test host
final controller = testHost.palette<void>('test-palette');
await controller.show();

// Verify commands sent
expect(mockBridge.wasCalled('visibility', 'show'), isTrue);

// Cleanup
await testHost.dispose();
```

## Capabilities

Check platform capabilities before using features:

```dart
final caps = PaletteHost.instance.capabilities;

// Feature checks
if (caps.blur) {
  controller.setBlur(enabled: true);
}

if (caps.transform) {
  controller.setScale(1.5);
}

if (caps.glassEffect) {
  // Use glass material
}

// Platform info
print(caps.platform);   // 'macos' or 'windows'
print(caps.osVersion);  // OS version string
```

### Capability Guard

Configure what happens when using unsupported features:

```dart
PaletteAnnotation(
  id: 'my-palette',
  widget: MyWidget,
  // Choose behavior for unsupported features
  unsupportedBehavior: UnsupportedBehavior.warnOnce,  // Default
)
```

| Behavior | Description |
|----------|-------------|
| `throwError` | Throw exception (strict) |
| `warnOnce` | Log warning once, then ignore |
| `ignore` | Silently ignore |

## Service Clients

Each native service has a typed client. You can use these directly for low-level control.

```dart
final bridge = PaletteHost.instance.bridge;

// Window management
final window = WindowClient(bridge);
await window.create('my-window', entryPoint: 'myPaletteMain');
await window.destroy('my-window');

// Positioning
final frame = FrameClient(bridge);
await frame.setFrame('my-window', x: 100, y: 100, width: 400, height: 300);
await frame.setPosition('my-window', x: 200, y: 200);
await frame.setSize('my-window', width: 500, height: 400);

// Visibility
final visibility = VisibilityClient(bridge);
await visibility.show('my-window', animate: true);
await visibility.hide('my-window', animate: true);
await visibility.setOpacity('my-window', opacity: 0.8);

// Transform
final transform = TransformClient(bridge);
await transform.setScale('my-window', scale: 1.2);
await transform.setRotation('my-window', degrees: 5);

// Animation
final animation = AnimationClient(bridge);
await animation.animateFrame(
  'my-window',
  x: 100, y: 100, width: 400, height: 300,
  duration: 300,
  curve: 'easeInOut',
);

// Appearance
final appearance = AppearanceClient(bridge);
await appearance.setCornerRadius('my-window', radius: 12);
await appearance.setShadow('my-window', type: 'medium');
await appearance.setBlur('my-window', enabled: true, material: 'hudWindow');

// Focus
final focus = FocusClient(bridge);
await focus.focus('my-window');
await focus.focusMainWindow();

// Z-Order
final zorder = ZOrderClient(bridge);
await zorder.bringToFront('my-window');
await zorder.setLevel('my-window', level: 'floating');

// Screen
final screen = ScreenClient(bridge);
final bounds = await screen.getMainScreenBounds();
final activeApp = await screen.getActiveAppBounds();

// Messages
final message = MessageClient(bridge);
await message.sendToPalette('my-window', 'custom-type', {'data': 'value'});
message.onMessage((msg) => print('${msg.type}: ${msg.data}'));
```

## Native Bridge

The `NativeBridge` handles all communication with native code.

### Sending Commands

```dart
final bridge = PaletteHost.instance.bridge;

// Send command and wait for result
final result = await bridge.send<String>(NativeCommand(
  service: 'window',
  command: 'create',
  windowId: 'my-window',
  params: {'entryPoint': 'myPaletteMain'},
));

// Fire and forget
bridge.send(NativeCommand(
  service: 'visibility',
  command: 'show',
  windowId: 'my-window',
));
```

### Listening for Events

```dart
// Listen to specific service
bridge.onEvent('visibility', (event) {
  if (event.event == 'shown') {
    print('Window ${event.windowId} is now visible');
  }
});

// Listen to all events
bridge.onAnyEvent((event) {
  print('${event.service}.${event.event}: ${event.data}');
});
```

## Input Management

### Keyboard Capture

Register keys to capture for a palette:

```dart
final input = PaletteHost.instance.inputManager;

// Register capture
input.registerCapture(
  'my-palette',
  keys: {LogicalKeyboardKey.arrowUp, LogicalKeyboardKey.arrowDown},
  priority: 50,
);

// Unregister
input.unregisterCapture('my-palette');
```

### Click Outside Handling

```dart
// Register for click-outside events
input.onClickOutside('my-palette', () {
  controller.hide();
});
```

### Palette Groups

Palette groups allow multiple palettes to act as one for click-outside handling:

```dart
// Create a group
final group = PaletteGroup(['main-menu', 'submenu', 'tooltip']);

// Register the group
input.registerGroup(group);

// Clicks on any palette in the group won't trigger click-outside
// for other palettes in the group

// Unregister
input.unregisterGroup(group);
```

## Hot Restart Recovery

When you hot restart, native windows survive but Dart state is lost. The system automatically recovers:

```dart
// This happens automatically in Palettes.init()
await PaletteHost.instance.recover();
```

The recovery process:
1. Native sends snapshot of all window states
2. Dart syncs controller state (visibility, position)
3. Orphan windows (no controller) are destroyed

### Manual Recovery

```dart
// If you create controllers manually, call recover after registration
final controller = host.palette<void>('my-palette');
await host.recover();
```

## Testing

### MockNativeBridge

```dart
import 'package:floating_palette/src/testing/testing.dart';

final mock = MockNativeBridge();

// Setup stubs
mock.stubDefaults();  // Common stubs (protocol version, capabilities)
mock.stubResponse('window', 'create', 'window-123');

// Simulate events
mock.simulateShown('my-palette');
mock.simulateHidden('my-palette');
mock.simulateEvent(NativeEvent(
  service: 'message',
  event: 'received',
  windowId: 'my-palette',
  data: {'type': 'custom', 'data': {'key': 'value'}},
));

// Verify commands
expect(mock.wasCalled('visibility', 'show'), isTrue);
expect(mock.wasCalledFor('visibility', 'show', 'my-palette'), isTrue);
expect(mock.callCount('visibility', 'show'), equals(1));

// Get command details
final cmd = mock.lastCommand('visibility');
expect(cmd?.windowId, equals('my-palette'));
```

### PaletteTestHost

Simplified test setup:

```dart
import 'package:floating_palette/src/testing/testing.dart';

late PaletteTestHost testHost;

setUp(() async {
  testHost = await PaletteTestHost.create();
});

tearDown(() async {
  await testHost.dispose();
});

test('shows palette', () async {
  final controller = testHost.createController('test');

  await controller.show();

  testHost.verifyCommand('visibility', 'show', windowId: 'test');
});

test('handles events', () async {
  final controller = testHost.createController<void>('test');
  final events = <bool>[];

  controller.visibility.listen(events.add);
  testHost.simulateShown('test');

  await Future.delayed(Duration.zero);
  expect(events, contains(true));
});
```

## FFI (Synchronous Operations)

For performance-critical code that can't await, use FFI:

```dart
import 'package:floating_palette/floating_palette_advanced.dart';

// Get cursor position synchronously
final position = PaletteFFI.getCursorPosition();
print('Cursor at: ${position.x}, ${position.y}');

// Get screen bounds synchronously
final bounds = PaletteFFI.getMainScreenBounds();
print('Screen: ${bounds.width}x${bounds.height}');
```

## Protocol Versioning

The Dart and native sides negotiate protocol version at startup:

```dart
// Native reports its version
final version = await bridge.send<Map>(NativeCommand(
  service: 'host',
  command: 'getProtocolVersion',
));

print('Protocol: ${version['version']}');
print('Supports Dart: ${version['minDartVersion']}-${version['maxDartVersion']}');
```

Version mismatch throws `ProtocolVersionMismatch` with upgrade instructions.

## Creating Custom Services

If you need to extend native functionality:

### 1. Add Swift Service

```swift
// macos/Classes/services/MyCustomService.swift
class MyCustomService {
    private var eventSink: ((String, String, String?, [String: Any]) -> Void)?

    func setEventSink(_ sink: @escaping (String, String, String?, [String: Any]) -> Void) {
        self.eventSink = sink
    }

    func handle(_ command: String, windowId: String?, params: [String: Any], result: @escaping FlutterResult) {
        switch command {
        case "myCommand":
            // Handle command
            result(["success": true])
        default:
            result(FlutterError(code: "UNKNOWN", message: "Unknown command", details: nil))
        }
    }
}
```

### 2. Register in Plugin

```swift
// FloatingPalettePlugin.swift
private var myCustomService: MyCustomService?

// In initializeServices:
myCustomService = MyCustomService()
myCustomService?.setEventSink(eventSink)

// In handle:
case "mycustom":
    myCustomService?.handle(command, windowId: windowId, params: params, result: result)
```

### 3. Create Dart Client

```dart
class MyCustomClient extends ServiceClient {
  MyCustomClient(super.bridge);

  @override
  String get serviceName => 'mycustom';

  Future<bool> myCommand(String windowId, {required String data}) async {
    final result = await sendCommand<Map<String, dynamic>>(
      'myCommand',
      windowId: windowId,
      params: {'data': data},
    );
    return result?['success'] == true;
  }
}
```

### 4. Use the Client

```dart
final client = MyCustomClient(PaletteHost.instance.bridge);
await client.myCommand('my-palette', data: 'hello');
```
