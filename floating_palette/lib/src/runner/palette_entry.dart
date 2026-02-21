import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'palette_runner.dart';

/// Method channel for palette entry point communication.
const _channel = MethodChannel('floating_palette/entry');

/// Package-provided entry point for all palettes.
///
/// This is called by native when creating a palette window.
/// Native passes the palette ID via method channel, and we route
/// to the correct registered palette.
///
/// Users don't need to create entry points - just register palettes:
/// ```dart
/// PaletteRegistry.register('myPalette', (ctx) => MyPaletteWidget());
/// ```
@pragma('vm:entry-point')
void floatingPaletteMain() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Get palette ID from native
  final paletteId = await _channel.invokeMethod<String>('getPaletteId');

  if (paletteId == null) {
    runApp(const _ErrorWidget('No palette ID received from native'));
    return;
  }

  runPalette(paletteId);
}

class _ErrorWidget extends StatelessWidget {
  final String message;

  const _ErrorWidget(this.message);

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
        color: const Color(0xFFFF0000),
        child: Center(
          child: Text(
            message,
            style: const TextStyle(color: Color(0xFFFFFFFF)),
          ),
        ),
      ),
    );
  }
}
