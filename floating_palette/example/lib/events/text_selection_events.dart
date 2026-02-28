import 'package:floating_palette/floating_palette.dart';
import 'package:floating_palette_annotations/floating_palette_annotations.dart';

/// Sent from host to palette with the currently selected text.
@PaletteEventType('text-selection.text_update')
class TextUpdateEvent extends PaletteEvent {
  static const id = 'text-selection.text_update';

  @override
  String get eventId => id;

  final String text;
  final String appName;

  const TextUpdateEvent({required this.text, required this.appName});

  @override
  Map<String, dynamic> toMap() => {'text': text, 'appName': appName};

  static TextUpdateEvent fromMap(Map<String, dynamic> m) => TextUpdateEvent(
        text: m['text'] as String? ?? '',
        appName: m['appName'] as String? ?? '',
      );
}
