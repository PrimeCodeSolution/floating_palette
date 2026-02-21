/// Testing utilities for floating palette.
///
/// Import this library to write unit tests for palette code:
///
/// ```dart
/// import 'package:floating_palette/floating_palette.dart';
/// import 'package:floating_palette/src/testing/testing.dart';
///
/// void main() {
///   late PaletteTestHost testHost;
///
///   setUp(() async {
///     testHost = await PaletteTestHost.create();
///   });
///
///   tearDown(() async {
///     await testHost.dispose();
///   });
///
///   test('shows palette', () async {
///     final controller = testHost.createController('test');
///     await controller.show();
///     testHost.verifyCommand('visibility', 'show');
///   });
/// }
/// ```
library;

export 'mock_native_bridge.dart';
export 'palette_test_host.dart';
