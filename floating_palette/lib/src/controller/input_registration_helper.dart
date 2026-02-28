import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart' show LogicalKeyboardKey;

import '../config/palette_behavior.dart';
import '../config/palette_keyboard.dart';
import '../input/click_outside_behavior.dart';
import '../input/input_behavior.dart';
import '../input/input_manager.dart';
import '../input/palette_group.dart';

/// Result of input registration.
class InputRegistrationResult {
  final bool registered;
  final Set<LogicalKeyboardKey>? effectiveKeys;
  final bool hideOnEscape;

  const InputRegistrationResult({
    required this.registered,
    this.effectiveKeys,
    this.hideOnEscape = false,
  });
}

/// Helper for palette input registration with InputManager.
///
/// Handles the complex logic of:
/// - Resolving effective focus/keys/clickOutside from config and overrides
/// - Registering with InputManager
/// - Setting up dismiss callbacks
/// - Managing focus state
class InputRegistrationHelper {
  final String paletteId;
  final InputManager _inputManager;

  const InputRegistrationHelper(this.paletteId, this._inputManager);

  /// Register palette with InputManager for input routing.
  ///
  /// Returns registration result with effective keys and whether escape handling is needed.
  Future<InputRegistrationResult> register({
    required PaletteBehavior behavior,
    required PaletteKeyboard keyboard,
    bool? focusOverride,
    Set<LogicalKeyboardKey>? keysOverride,
    ClickOutsideBehavior? clickOutsideOverride,
    PaletteGroup? groupOverride,
    required Future<void> Function() onDismiss,
  }) async {
    // Resolve defaults from config
    final effectiveFocus = focusOverride ?? behavior.shouldFocus;
    final effectiveClickOutside = clickOutsideOverride ?? behavior.clickOutsideBehavior;
    final effectiveClickOutsideScope = behavior.clickOutsideScope;
    final effectiveGroup = groupOverride ?? behavior.group;

    // Resolve keys: passed parameter > config.keyboard.alwaysIntercept > null
    var effectiveKeys = keysOverride ??
        (keyboard.alwaysIntercept.isNotEmpty ? keyboard.alwaysIntercept : null);

    // Add Escape key to captured keys if hideOnEscape is enabled
    final hideOnEscape = behavior.hideOnEscape;
    if (hideOnEscape) {
      effectiveKeys = {...?effectiveKeys, LogicalKeyboardKey.escape};
    }

    // Debug logging
    debugPrint(
        '[InputRegistrationHelper] register($paletteId): focus=$effectiveFocus, '
        'group=$effectiveGroup, hideOnEscape=$hideOnEscape, '
        'keys=${effectiveKeys?.map((k) => '0x${k.keyId.toRadixString(16)}').toList()}');

    // Register with InputManager
    final inputBehavior = InputBehavior(
      focus: effectiveFocus,
      keys: effectiveKeys,
      clickOutside: effectiveClickOutside,
      clickOutsideScope: effectiveClickOutsideScope,
      group: effectiveGroup,
    );
    final registered =
        await _inputManager.registerPalette(paletteId, inputBehavior);

    if (!registered) {
      debugPrint('[InputRegistrationHelper] register($paletteId): blocked');
      return const InputRegistrationResult(registered: false);
    }

    // Register dismiss callback for hideOnClickOutside
    if (effectiveClickOutside == ClickOutsideBehavior.dismiss) {
      _inputManager.registerDismissCallback(paletteId, onDismiss);
    }

    // Set focus if requested
    if (effectiveFocus) {
      await _inputManager.setFocus(PaletteFocused(paletteId));
    }

    return InputRegistrationResult(
      registered: true,
      effectiveKeys: effectiveKeys,
      hideOnEscape: hideOnEscape,
    );
  }

  /// Unregister palette from InputManager.
  Future<void> unregister() async {
    _inputManager.unregisterDismissCallback(paletteId);
    await _inputManager.unregisterPalette(paletteId);
  }
}
