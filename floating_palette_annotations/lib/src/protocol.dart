/// Marks a class as a service schema for code generation.
///
/// Service schemas define the contract between Dart and native code.
/// The generator produces typed client classes from these schemas.
///
/// ```dart
/// @PaletteService('window', version: 1)
/// abstract class WindowSchema {
///   @PaletteCommand('create', returnsValue: true)
///   Future<String?> create(CreateWindowParams params);
///
///   @PaletteNativeEvent('created')
///   void onCreated(String windowId);
/// }
/// ```
class PaletteService {
  /// The service name (must match native side).
  final String name;

  /// The service version for compatibility checks.
  final int version;

  const PaletteService(this.name, {this.version = 1});
}

/// Marks a method as a command in a service schema.
///
/// Commands are sent from Dart to native and may return values.
///
/// ```dart
/// @PaletteCommand('create', returnsValue: true)
/// Future<String?> create(CreateWindowParams params);
/// ```
class PaletteCommand {
  /// The command name (sent to native).
  final String name;

  /// Whether this command returns a value.
  final bool returnsValue;

  /// Whether this command is fire-and-forget (no await).
  final bool fireAndForget;

  const PaletteCommand(
    this.name, {
    this.returnsValue = false,
    this.fireAndForget = false,
  });
}

/// Marks a method as a native event handler in a service schema.
///
/// Native events are sent from native to Dart when something happens.
///
/// ```dart
/// @PaletteNativeEvent('created')
/// void onCreated(String windowId);
/// ```
class PaletteNativeEvent {
  /// The event name (received from native).
  final String name;

  const PaletteNativeEvent(this.name);
}

/// Marks a class as a palette event type for code generation.
///
/// Palette events are messages sent between host app and palette windows.
/// Using explicit IDs ensures stability under code obfuscation.
///
/// ```dart
/// @PaletteEventType('menu.item_selected')
/// class MenuItemSelected extends PaletteEvent {
///   final String itemId;
///   final int index;
///   // ...
/// }
/// ```
class PaletteEventType {
  /// Explicit event ID (stable across obfuscation).
  final String id;

  const PaletteEventType(this.id);
}

/// Marks a class as command/event parameters for code generation.
///
/// Parameter classes are serialized to JSON when sent to native.
///
/// ```dart
/// @PaletteParams()
/// class CreateWindowParams {
///   final String id;
///   final double width;
///   final double height;
///   // ...
/// }
/// ```
class PaletteParams {
  const PaletteParams();
}
