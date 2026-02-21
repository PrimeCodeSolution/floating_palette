#include "include/floating_palette/floating_palette_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "floating_palette_plugin.h"

void FloatingPalettePluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  floating_palette::FloatingPalettePlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
