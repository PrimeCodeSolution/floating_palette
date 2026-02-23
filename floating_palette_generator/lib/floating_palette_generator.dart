import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

import 'src/palette_generator.dart';

/// Builder factory for floating_palette code generation.
/// Uses SharedPartBuilder to work alongside other generators (freezed, json_serializable, etc.)
Builder paletteBuilder(BuilderOptions options) => SharedPartBuilder(
      [PaletteGenerator()],
      'floating_palette',
    );
