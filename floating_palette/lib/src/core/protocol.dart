import '../bridge/command.dart';
import '../bridge/native_bridge.dart';

/// Protocol version mismatch error.
///
/// Thrown when the Dart package version doesn't match the native plugin version.
class ProtocolMismatchError extends Error {
  final String message;
  final int dartVersion;
  final int nativeVersion;

  ProtocolMismatchError(
    this.message, {
    required this.dartVersion,
    required this.nativeVersion,
  });

  @override
  String toString() => 'ProtocolMismatchError: $message';
}

/// Protocol versioning and compatibility checking.
///
/// Ensures the Dart package and native plugin are compatible.
/// Called automatically during [PaletteHost.initialize].
abstract final class Protocol {
  /// Current Dart protocol version.
  ///
  /// Increment when:
  /// - Adding new commands (minor version bump is OK)
  /// - Changing command parameters (requires version bump)
  /// - Removing commands (requires major version bump)
  /// - Changing event payloads (requires version bump)
  static const version = 1;

  /// Minimum native protocol version this Dart package supports.
  static const minNativeVersion = 1;

  /// Maximum native protocol version this Dart package supports.
  static const maxNativeVersion = 1;

  /// Perform protocol handshake with native.
  ///
  /// Verifies that the native plugin version is compatible with this
  /// Dart package. Throws [ProtocolMismatchError] if versions are incompatible.
  ///
  /// Called automatically during [PaletteHost.initialize].
  static Future<void> handshake(NativeBridge bridge) async {
    final result = await bridge.sendForMap(const NativeCommand(
      service: 'host',
      command: 'getProtocolVersion',
      params: {},
    ));

    // If native doesn't support version check, assume compatible (legacy)
    if (result == null) {
      return;
    }

    final nativeVersion = result['version'] as int?;
    if (nativeVersion == null) {
      return;
    }

    // Check compatibility
    if (nativeVersion < minNativeVersion) {
      throw ProtocolMismatchError(
        'Native plugin is too old. '
        'Dart protocol v$version requires native v$minNativeVersion-$maxNativeVersion, '
        'but native is v$nativeVersion. Please update the native plugin.',
        dartVersion: version,
        nativeVersion: nativeVersion,
      );
    }

    if (nativeVersion > maxNativeVersion) {
      throw ProtocolMismatchError(
        'Native plugin is too new. '
        'Dart protocol v$version supports native v$minNativeVersion-$maxNativeVersion, '
        'but native is v$nativeVersion. Please update the Dart package.',
        dartVersion: version,
        nativeVersion: nativeVersion,
      );
    }
  }

}
