import 'dart:ui';

/// Information about text selected in any macOS application.
class SelectedText {
  /// The selected text string.
  final String text;

  /// Screen-coordinate bounds of the selection (x, y, width, height).
  ///
  /// May be [Rect.zero] if the application doesn't support bounds reporting.
  final Rect bounds;

  /// Bundle identifier of the application (e.g. "com.google.Chrome").
  final String appBundleId;

  /// Display name of the application (e.g. "Google Chrome").
  final String appName;

  /// If bounds are unavailable, the reason from the native AX layer.
  ///
  /// Null when bounds were successfully retrieved.
  final String? boundsError;

  const SelectedText({
    required this.text,
    required this.bounds,
    required this.appBundleId,
    required this.appName,
    this.boundsError,
  });

  factory SelectedText.fromMap(Map<String, dynamic> map) {
    return SelectedText(
      text: map['text'] as String? ?? '',
      bounds: Rect.fromLTWH(
        (map['x'] as num?)?.toDouble() ?? 0,
        (map['y'] as num?)?.toDouble() ?? 0,
        (map['width'] as num?)?.toDouble() ?? 0,
        (map['height'] as num?)?.toDouble() ?? 0,
      ),
      appBundleId: map['appBundleId'] as String? ?? '',
      appName: map['appName'] as String? ?? '',
      boundsError: map['boundsError'] as String?,
    );
  }

  @override
  String toString() => 'SelectedText('
      'text: "${text.length > 50 ? '${text.substring(0, 50)}...' : text}", '
      'bounds: $bounds, '
      'app: $appName)';
}

/// Accessibility permission status.
enum AccessibilityPermission { granted, denied }
