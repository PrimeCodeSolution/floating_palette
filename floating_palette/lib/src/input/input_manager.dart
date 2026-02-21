import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart';

import '../bridge/native_bridge.dart';
import '../config/palette_behavior.dart' show FocusRestoreMode;
import '../services/services.dart';
import 'click_outside_behavior.dart';
import 'click_outside_handler.dart';
import 'dismiss_coordinator.dart';
import 'input_behavior.dart';
import 'palette_group.dart';
import 'show_guard.dart';

/// Represents the entity that currently has keyboard focus.
sealed class FocusedEntity {
  const FocusedEntity();
}

/// The host application has focus.
class HostFocused extends FocusedEntity {
  const HostFocused();

  @override
  bool operator ==(Object other) => other is HostFocused;

  @override
  int get hashCode => runtimeType.hashCode;
}

/// A specific palette has focus.
class PaletteFocused extends FocusedEntity {
  final String paletteId;

  const PaletteFocused(this.paletteId);

  @override
  bool operator ==(Object other) =>
      other is PaletteFocused && other.paletteId == paletteId;

  @override
  int get hashCode => paletteId.hashCode;
}

/// Tracks a visible palette and its input configuration.
class _VisiblePalette {
  final String id;
  final InputBehavior behavior;
  final PaletteGroup? group;

  _VisiblePalette(this.id, this.behavior, {this.group});
}

/// Orchestrates keyboard input routing between host app and palettes.
///
/// InputManager is the central coordinator that:
/// - Tracks which entity (host or palette) has keyboard focus
/// - Routes captured keys to focused palette AND any unfocused palettes that want them
/// - Handles click-outside behavior
///
/// Example:
/// ```dart
/// // Get the InputManager from PaletteHost
/// final inputManager = PaletteHost.instance.inputManager;
///
/// // Palette shows and takes focus
/// inputManager.registerPalette('slash-menu', InputBehavior.menu());
/// inputManager.setFocus(PaletteFocused('slash-menu'));
///
/// // Later, palette hides
/// inputManager.unregisterPalette('slash-menu');
/// inputManager.setFocus(HostFocused());
/// ```
class InputManager {
  /// The native bridge for communicating with the platform.
  final NativeBridge _bridge;

  // Service clients created with injected bridge
  late final InputClient _inputClient;
  late final FocusClient _focusClient;

  // Extracted helpers
  final ShowGuard _showGuard;
  final DismissCoordinator _dismissCoordinator;
  late final ClickOutsideHandler _clickOutsideHandler;

  /// Create an InputManager with the given bridge.
  ///
  /// In most cases, you should use [PaletteHost.inputManager] instead of
  /// creating your own instance.
  InputManager(this._bridge) : _showGuard = ShowGuard(), _dismissCoordinator = DismissCoordinator() {
    _inputClient = InputClient(_bridge);
    _focusClient = FocusClient(_bridge);
    _clickOutsideHandler = ClickOutsideHandler(
      showGuard: _showGuard,
      dismissCoordinator: _dismissCoordinator,
      setFocus: (entity) => setFocus(entity),
    );
  }

  FocusedEntity _focusedEntity = const HostFocused();
  final Map<String, _VisiblePalette> _visiblePalettes = {};

  final _focusController = StreamController<FocusedEntity>.broadcast();
  final _keyEventController =
      StreamController<(String, LogicalKeyboardKey, Set<LogicalKeyboardKey>)>
          .broadcast();

  /// Stream of focus changes.
  Stream<FocusedEntity> get focusStream => _focusController.stream;

  /// Stream of key events: (paletteId, key, modifiers).
  Stream<(String, LogicalKeyboardKey, Set<LogicalKeyboardKey>)>
      get keyEventStream => _keyEventController.stream;

  /// Current focused entity.
  FocusedEntity get focusedEntity => _focusedEntity;

  /// Whether a palette currently has focus.
  bool get isPaletteFocused => _focusedEntity is PaletteFocused;

  /// ID of the focused palette, or null if host is focused.
  String? get focusedPaletteId {
    final entity = _focusedEntity;
    return entity is PaletteFocused ? entity.paletteId : null;
  }

  // ════════════════════════════════════════════════════════════════════════════
  // Palette Registration
  // ════════════════════════════════════════════════════════════════════════════

  /// Register a visible palette with its input behavior.
  ///
  /// Called when a palette becomes visible via `.show()`.
  ///
  /// If the palette belongs to an exclusive [PaletteGroup], any other
  /// visible palettes in that group will be hidden first.
  ///
  /// Returns `false` if registration was blocked by the show guard.
  Future<bool> registerPalette(String id, InputBehavior behavior) async {
    // Check show guard - prevent re-show during dismiss cycle
    if (_showGuard.isBlocked(id)) {
      debugPrint('[InputManager] registerPalette($id): BLOCKED by show guard');
      return false;
    }

    debugPrint('[InputManager] registerPalette($id): focus=${behavior.focus}, group=${behavior.group}, keys=${behavior.keys?.map((k) => '0x${k.keyId.toRadixString(16)}').toList()}');

    // Handle exclusive groups - hide others in same group first
    final group = behavior.group;
    if (group != null) {
      await _enforceExclusiveGroup(group, excludingId: id);
    }

    _visiblePalettes[id] = _VisiblePalette(id, behavior, group: group);

    // Set up key capture for this palette
    // ONLY capture keys that are explicitly requested
    // Do NOT capture all keys just because focus=true - that breaks TextFields!
    final keys = behavior.keys;
    if (keys != null && keys.isNotEmpty) {
      debugPrint('[InputManager] Capturing specific keys for $id: ${keys.map((k) => '0x${k.keyId.toRadixString(16)}').toList()}');
      await _inputClient.captureKeyboard(id, keys: keys);
    } else {
      // Don't capture any keys - let normal Flutter input handling work
      debugPrint('[InputManager] NOT capturing any keys for $id (keys not specified)');
    }

    // Set up click outside handling
    if (behavior.clickOutside != ClickOutsideBehavior.passthrough) {
      await _inputClient.capturePointer(id);
      _inputClient.onClickOutside(id, (position) {
        _clickOutsideHandler.handleClickOutside(id, behavior.clickOutside, position);
      });
    }

    // Set up key event forwarding
    _inputClient.onKeyDown(id, (key, modifiers) {
      _routeKeyEvent(id, key, modifiers);
    });

    return true;
  }

  /// Enforce exclusive group by hiding other palettes in the same group.
  Future<void> _enforceExclusiveGroup(
    PaletteGroup group, {
    required String excludingId,
  }) async {
    final toHide = _visiblePalettes.values
        .where((p) => p.group == group && p.id != excludingId)
        .map((p) => p.id)
        .toList();

    for (final id in toHide) {
      debugPrint('[InputManager] Hiding $id due to exclusive group ${group.name}');
      // Request dismiss via callback (same mechanism as click-outside)
      // Don't activate show guard - this is programmatic, not click-based
      _dismissCoordinator.requestDismiss(id);
    }
  }

  /// Unregister a palette when it becomes hidden.
  Future<void> unregisterPalette(String id) async {
    _visiblePalettes.remove(id);

    await _inputClient.releaseKeyboard(id);
    await _inputClient.releasePointer(id);

    // If this was the focused palette, return focus to host
    if (_focusedEntity case PaletteFocused(paletteId: final focusedId)) {
      if (focusedId == id) {
        await setFocus(const HostFocused());
      }
    }
  }

  // ════════════════════════════════════════════════════════════════════════════
  // Focus Management
  // ════════════════════════════════════════════════════════════════════════════

  /// Set which entity has keyboard focus.
  ///
  /// When [entity] is [HostFocused], [focusRestoreMode] controls what happens:
  /// - [FocusRestoreMode.none] - Don't change focus
  /// - [FocusRestoreMode.mainWindow] - Activate main app window (default)
  /// - [FocusRestoreMode.previousApp] - Hide app, return to previous app
  Future<void> setFocus(
    FocusedEntity entity, {
    FocusRestoreMode focusRestoreMode = FocusRestoreMode.mainWindow,
  }) async {
    if (_focusedEntity == entity) return;

    _focusedEntity = entity;
    _focusController.add(entity);

    // Update native focus
    switch (entity) {
      case HostFocused():
        // Unfocus all palettes
        for (final palette in _visiblePalettes.values) {
          await _focusClient.unfocus(palette.id);
        }
        // Restore focus based on mode
        await _focusClient.restoreFocus(focusRestoreMode);
      case PaletteFocused(:final paletteId):
        // Focus the specific palette
        await _focusClient.focus(paletteId);
    }
  }

  // ════════════════════════════════════════════════════════════════════════════
  // Key Event Routing
  // ════════════════════════════════════════════════════════════════════════════

  /// Route a key event to appropriate palettes.
  void _routeKeyEvent(
    String sourceId,
    LogicalKeyboardKey key,
    Set<LogicalKeyboardKey> modifiers,
  ) {
    // Always send to the source palette
    _keyEventController.add((sourceId, key, modifiers));

    // Also route to other visible palettes that want this key
    for (final palette in _visiblePalettes.values) {
      if (palette.id == sourceId) continue;

      final wantedKeys = palette.behavior.keys;
      if (wantedKeys != null && wantedKeys.contains(key)) {
        _keyEventController.add((palette.id, key, modifiers));
      }
    }
  }

  // ════════════════════════════════════════════════════════════════════════════
  // Dismiss API (delegates to DismissCoordinator)
  // ════════════════════════════════════════════════════════════════════════════

  /// Set callback for when a palette requests dismissal.
  ///
  /// This is the legacy API. Prefer using [registerDismissCallback] for
  /// per-palette callbacks, which are called automatically by the package.
  void onDismissRequested(void Function(String paletteId) callback) {
    _dismissCoordinator.onDismissRequested(callback);
  }

  /// Register a dismiss callback for a specific palette.
  ///
  /// Called automatically by [PaletteController.show] when hideOnClickOutside is true.
  /// The callback is removed when [unregisterDismissCallback] is called.
  void registerDismissCallback(String paletteId, void Function() callback) {
    _dismissCoordinator.registerDismissCallback(paletteId, callback);
  }

  /// Unregister a dismiss callback for a specific palette.
  ///
  /// Called automatically by [PaletteController.hide].
  void unregisterDismissCallback(String paletteId) {
    _dismissCoordinator.unregisterDismissCallback(paletteId);
  }

  // ════════════════════════════════════════════════════════════════════════════
  // Query APIs
  // ════════════════════════════════════════════════════════════════════════════

  /// Get all currently visible palette IDs.
  Set<String> get visiblePaletteIds => _visiblePalettes.keys.toSet();

  /// Check if a palette is currently registered as visible.
  bool isPaletteVisible(String id) => _visiblePalettes.containsKey(id);

  /// Get the input behavior for a visible palette.
  InputBehavior? getBehavior(String id) => _visiblePalettes[id]?.behavior;

  /// Update the input behavior for a visible palette.
  Future<void> updateBehavior(String id, InputBehavior behavior) async {
    if (!_visiblePalettes.containsKey(id)) return;

    // Re-register with new behavior
    await unregisterPalette(id);
    await registerPalette(id, behavior);
  }

  // ════════════════════════════════════════════════════════════════════════════
  // Show Guard API
  // ════════════════════════════════════════════════════════════════════════════

  /// Check if showing a palette is currently blocked by the show guard.
  ///
  /// The show guard prevents re-showing a palette immediately after it was
  /// dismissed via click-outside, which would cause a show/dismiss loop.
  bool isShowBlocked(String paletteId) => _showGuard.isBlocked(paletteId);

  /// Explicitly clear the show guard for a palette.
  ///
  /// Use this when you intentionally want to allow re-showing immediately,
  /// e.g., after a deliberate user action like clicking a toggle button.
  void clearShowGuard(String paletteId) => _showGuard.clear(paletteId);

  // ════════════════════════════════════════════════════════════════════════════
  // Group API
  // ════════════════════════════════════════════════════════════════════════════

  /// Get all visible palettes in a specific exclusive group.
  Set<String> getVisibleInGroup(PaletteGroup group) {
    return _visiblePalettes.values
        .where((p) => p.group == group)
        .map((p) => p.id)
        .toSet();
  }

  /// Hide all palettes in an exclusive group.
  ///
  /// Useful for programmatically dismissing all menus, popups, etc.
  Future<void> hideGroup(PaletteGroup group) async {
    final ids = getVisibleInGroup(group).toList();
    for (final id in ids) {
      _dismissCoordinator.requestDismiss(id);
    }
  }

  /// Dispose resources.
  void dispose() {
    _focusController.close();
    _keyEventController.close();
    _visiblePalettes.clear();
    _inputClient.dispose();
    _focusClient.dispose();
  }
}
