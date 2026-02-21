import 'package:floating_palette/floating_palette.dart';
import 'package:floating_palette_annotations/floating_palette_annotations.dart';

/// Emitted when a key is pressed on the virtual keyboard.
///
/// Event ID follows the generated format: `${paletteId}.${snake_case(className)}`
/// Since this is registered with the 'virtual-keyboard' palette, the ID is
/// 'virtual-keyboard.keyboard_key_pressed'.
@PaletteEventType('virtual-keyboard.keyboard_key_pressed')
class KeyboardKeyPressed extends PaletteEvent {
  static const id = 'virtual-keyboard.keyboard_key_pressed';

  @override
  String get eventId => id;

  final String key;

  const KeyboardKeyPressed(this.key);

  @override
  Map<String, dynamic> toMap() => {'key': key};

  static KeyboardKeyPressed fromMap(Map<String, dynamic> m) =>
      KeyboardKeyPressed(m['key'] as String);
}

/// Emitted to toggle keyboard visibility.
///
/// Event ID follows the generated format: `${paletteId}.${snake_case(className)}`
/// Since this is registered with the 'editor' palette, the ID is
/// 'editor.toggle_keyboard'.
@PaletteEventType('editor.toggle_keyboard')
class ToggleKeyboard extends PaletteEvent {
  static const id = 'editor.toggle_keyboard';

  @override
  String get eventId => id;

  const ToggleKeyboard();

  @override
  Map<String, dynamic> toMap() => {};

  static ToggleKeyboard fromMap(Map<String, dynamic> _) => const ToggleKeyboard();
}
