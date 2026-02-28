import 'package:floating_palette/floating_palette.dart';
import 'package:flutter/material.dart';

import '../events/text_selection_events.dart';

/// Palette that displays the currently selected text.
///
/// Receives [TextUpdateEvent] from the host and shows the text
/// in a styled container. Uses [PaletteScaffold] with [SizeReporter]
/// so the native window fits the content.
class TextSelectionPalette extends StatefulWidget {
  const TextSelectionPalette({super.key});

  @override
  State<TextSelectionPalette> createState() => _TextSelectionPaletteState();
}

class _TextSelectionPaletteState extends State<TextSelectionPalette> {
  String _text = '';
  String _appName = '';

  @override
  void initState() {
    super.initState();
    if (PaletteContext.isInPalette) {
      PaletteContext.current.on<TextUpdateEvent>(_onTextUpdate);
    }
  }

  void _onTextUpdate(TextUpdateEvent event) {
    setState(() {
      _text = event.text;
      _appName = event.appName;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: PaletteScaffold(
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E2E),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: const Color(0xFF3A3A4A),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: SizedBox(
          width: 320,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_appName.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      _appName,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF888899),
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                Text(
                  _text.isEmpty ? '...' : _text,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFFE0E0F0),
                    height: 1.4,
                  ),
                  maxLines: 6,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
