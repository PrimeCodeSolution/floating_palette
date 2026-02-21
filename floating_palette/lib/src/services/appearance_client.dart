import 'dart:ui';

import '../bridge/service_client.dart';
import '../config/palette_appearance.dart';

/// Client for AppearanceService.
///
/// Handles window chrome, shadow, background.
class AppearanceClient extends ServiceClient {
  AppearanceClient(super.bridge);

  @override
  String get serviceName => 'appearance';

  /// Set corner radius.
  Future<void> setCornerRadius(String id, double radius) async {
    await send<void>('setCornerRadius', windowId: id, params: {
      'radius': radius,
    });
  }

  /// Set shadow style.
  Future<void> setShadow(String id, PaletteShadow shadow) async {
    await send<void>('setShadow', windowId: id, params: {
      'shadow': shadow.name,
    });
  }

  /// Set background color.
  Future<void> setBackgroundColor(String id, Color? color) async {
    await send<void>('setBackgroundColor', windowId: id, params: {
      if (color != null) 'color': color.toARGB32() else 'color': null,
    });
  }

  /// Set transparency.
  Future<void> setTransparent(String id, bool transparent) async {
    await send<void>('setTransparent', windowId: id, params: {
      'transparent': transparent,
    });
  }

  /// Enable or disable system blur effect.
  ///
  /// On macOS: Uses NSVisualEffectView for vibrancy.
  /// On Windows 11: Uses Acrylic backdrop (DWM).
  ///
  /// [material] - macOS blur material (default: 'hudWindow').
  /// Available materials: titlebar, selection, menu, popover, sidebar,
  /// headerView, sheet, windowBackground, hudWindow, fullScreenUI,
  /// toolTip, contentBackground, underWindowBackground, underPageBackground.
  ///
  /// Note: Window must have transparency enabled for blur to be visible.
  Future<void> setBlur(String id, {bool enabled = true, String material = 'hudWindow'}) async {
    await send<void>('setBlur', windowId: id, params: {
      'enabled': enabled,
      'material': material,
    });
  }

  /// Apply full appearance config.
  Future<void> applyAppearance(String id, PaletteAppearance appearance) async {
    await send<void>('applyAppearance', windowId: id, params: {
      'cornerRadius': appearance.cornerRadius,
      'shadow': appearance.shadow.name,
      'transparent': appearance.transparent,
      if (appearance.backgroundColor != null)
        'backgroundColor': appearance.backgroundColor!.toARGB32(),
    });
  }
}
