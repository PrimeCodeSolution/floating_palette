#include "window_channel_router.h"

#include "../core/logger.h"

namespace floating_palette {

void WindowChannelRouter::SetupChannels(
    flutter::PluginRegistrarWindows* registrar,
    const std::string& window_id) {
  // TODO: Set up per-palette channels once palette engines are implemented:
  //   - floating_palette/entry     (forceResize, entry point config)
  //   - floating_palette/messenger (host ↔ palette messaging)
  //   - floating_palette/self      (palette → host self-commands)
  FP_LOG("Plugin", "SetupChannels stub for " + window_id);
}

}  // namespace floating_palette
