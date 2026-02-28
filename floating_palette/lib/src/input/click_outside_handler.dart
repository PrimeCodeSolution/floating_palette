import 'dart:ui';

import 'package:flutter/foundation.dart' show debugPrint;

import 'click_outside_behavior.dart';
import 'dismiss_coordinator.dart';
import 'input_manager.dart';
import 'show_guard.dart';

/// Handles click-outside events with deduplication.
///
/// Native code may fire clickOutside events for each captured window when
/// a single physical click occurs. This handler deduplicates those events
/// using timestamp + position matching.
class ClickOutsideHandler {
  final ShowGuard _showGuard;
  final DismissCoordinator _dismissCoordinator;
  final void Function(FocusedEntity) _setFocus;

  /// Tracks the last click event for deduplication.
  _ClickEvent? _lastClickEvent;

  /// Tracks which palettes have been notified for the current click.
  final Set<String> _palettesNotifiedForCurrentClick = {};

  ClickOutsideHandler({
    required ShowGuard showGuard,
    required DismissCoordinator dismissCoordinator,
    required void Function(FocusedEntity) setFocus,
  })  : _showGuard = showGuard,
        _dismissCoordinator = dismissCoordinator,
        _setFocus = setFocus;

  /// Handle a click-outside event for a palette.
  ///
  /// [clickedPaletteId] is the ID of the sibling palette that was clicked,
  /// or null if the click was not on any palette window.
  void handleClickOutside(
    String paletteId,
    ClickOutsideBehavior behavior,
    ClickOutsideScope scope,
    Offset position,
    String? clickedPaletteId,
  ) {
    // If scope is nonPalette and click was on a sibling palette, skip
    if (scope == ClickOutsideScope.nonPalette && clickedPaletteId != null) {
      debugPrint('[InputManager] Skipping clickOutside for $paletteId '
          '(scope=nonPalette, clicked on $clickedPaletteId)');
      return;
    }

    // ════════════════════════════════════════════════════════════════════════
    // Deduplication Logic
    // ════════════════════════════════════════════════════════════════════════

    final currentClick = _ClickEvent(position);

    // Check if this is the same physical click as before
    if (_lastClickEvent != null && currentClick.isSameClick(_lastClickEvent!)) {
      // Same physical click - check if we've already handled this palette
      if (_palettesNotifiedForCurrentClick.contains(paletteId)) {
        debugPrint('[InputManager] Dedup: skipping $paletteId (already processed for this click)');
        return;
      }
    } else {
      // New physical click - reset tracking
      _lastClickEvent = currentClick;
      _palettesNotifiedForCurrentClick.clear();
    }

    // Mark this palette as processed for current click
    _palettesNotifiedForCurrentClick.add(paletteId);

    debugPrint('[InputManager] _handleClickOutside($paletteId): behavior=$behavior');

    // ════════════════════════════════════════════════════════════════════════
    // Behavior Handling
    // ════════════════════════════════════════════════════════════════════════

    switch (behavior) {
      case ClickOutsideBehavior.dismiss:
        // Activate show guard BEFORE dismissing to prevent re-show loop
        _showGuard.markDismissed(paletteId);

        // Palette should hide - emit event for controller to handle
        _dismissCoordinator.requestDismiss(paletteId);

      case ClickOutsideBehavior.unfocus:
        _setFocus(const HostFocused());

      case ClickOutsideBehavior.block:
        // Do nothing, click is consumed
        break;

      case ClickOutsideBehavior.passthrough:
        // Should not reach here, passthrough doesn't capture pointer
        break;
    }
  }
}

/// Represents a physical click event with timing for deduplication.
///
/// Multiple windows may report clickOutside for the same physical click.
/// We use timestamp + position to identify the same click.
class _ClickEvent {
  /// Maximum time window (ms) to consider two events as the same physical click.
  static const int _dedupTimeWindowMs = 50;

  /// Maximum position drift (px) to consider two events as the same physical click.
  static const double _dedupPositionThreshold = 5.0;

  final Offset position;
  final DateTime timestamp;

  _ClickEvent(this.position) : timestamp = DateTime.now();

  /// Whether this click is likely the same as another.
  ///
  /// Uses a small time window and position tolerance
  /// to coalesce events from the same physical click.
  bool isSameClick(_ClickEvent other) {
    final timeDelta = timestamp.difference(other.timestamp).abs();
    final positionDelta = (position - other.position).distance;
    return timeDelta.inMilliseconds < _dedupTimeWindowMs &&
        positionDelta < _dedupPositionThreshold;
  }
}
