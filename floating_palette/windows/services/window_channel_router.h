#pragma once

#include <flutter/plugin_registrar_windows.h>

#include <string>

namespace floating_palette {

/// Routes per-palette method channels (entry, messenger, self).
///
/// Each palette window gets 3 channels:
///   - floating_palette/entry     (host → palette commands)
///   - floating_palette/messenger (host ↔ palette messaging)
///   - floating_palette/self      (palette → host self-commands)
///
/// Not yet implemented — palette engines are not created on Windows.
class WindowChannelRouter {
 public:
  static void SetupChannels(flutter::PluginRegistrarWindows* registrar,
                            const std::string& window_id);
};

}  // namespace floating_palette
