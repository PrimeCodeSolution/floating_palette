#pragma once

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <flutter_windows.h>

#include <string>

#include "../core/window_store.h"

namespace floating_palette {

class BackgroundCaptureService;
class DragCoordinator;
class FrameService;
class SnapService;

/// Routes per-palette method channels (entry, messenger, self).
///
/// Each palette window gets 3 channels on its own engine messenger:
///   - floating_palette/entry     (host → palette: getPaletteId)
///   - floating_palette/messenger (palette → host: send, snap, notify, etc.)
///   - floating_palette/self      (palette → host: getBounds, startDrag, etc.)
class WindowChannelRouter {
 public:
  static void SetupChannels(PaletteWindow* window,
                            FlutterDesktopMessengerRef messenger,
                            EventSink event_sink,
                            FrameService* frame_service,
                            SnapService* snap_service,
                            DragCoordinator* drag_coordinator,
                            BackgroundCaptureService* capture_service);
};

}  // namespace floating_palette
