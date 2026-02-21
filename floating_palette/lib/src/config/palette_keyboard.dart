import 'package:flutter/services.dart';

/// Keyboard handling configuration for a palette.
class PaletteKeyboard {
  /// Whether to intercept keyboard events before they reach the host app.
  final bool interceptKeys;

  /// Keys to always pass through to the host app (even if intercepting).
  final Set<LogicalKeyboardKey> passthrough;

  /// Keys to always intercept (even if not generally intercepting).
  final Set<LogicalKeyboardKey> alwaysIntercept;

  const PaletteKeyboard({
    this.interceptKeys = true,
    this.passthrough = const {},
    this.alwaysIntercept = const {},
  });

  /// Intercept all keyboard events.
  const PaletteKeyboard.interceptAll()
      : interceptKeys = true,
        passthrough = const {},
        alwaysIntercept = const {};

  /// Don't intercept any keyboard events.
  const PaletteKeyboard.passthroughAll()
      : interceptKeys = false,
        passthrough = const {},
        alwaysIntercept = const {};

  /// Standard palette: intercepts most, passes Tab through.
  PaletteKeyboard.standard()
      : interceptKeys = true,
        passthrough = {LogicalKeyboardKey.tab},
        alwaysIntercept = const {};

  PaletteKeyboard copyWith({
    bool? interceptKeys,
    Set<LogicalKeyboardKey>? passthrough,
    Set<LogicalKeyboardKey>? alwaysIntercept,
  }) {
    return PaletteKeyboard(
      interceptKeys: interceptKeys ?? this.interceptKeys,
      passthrough: passthrough ?? this.passthrough,
      alwaysIntercept: alwaysIntercept ?? this.alwaysIntercept,
    );
  }

  Map<String, dynamic> toMap() => {
        'interceptKeys': interceptKeys,
        'passthrough': passthrough.map((k) => k.keyId).toList(),
        'alwaysIntercept': alwaysIntercept.map((k) => k.keyId).toList(),
      };
}
