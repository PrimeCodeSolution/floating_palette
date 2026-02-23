#include "window_channel_router.h"

#include "../coordinators/drag_coordinator.h"
#include "../core/logger.h"
#include "../core/palette_binary_messenger.h"
#include "../core/param_helpers.h"
#include "background_capture_service.h"
#include "frame_service.h"
#include "snap_service.h"

namespace floating_palette {

void WindowChannelRouter::SetupChannels(
    PaletteWindow* window,
    FlutterDesktopMessengerRef messenger,
    EventSink event_sink,
    FrameService* frame_service,
    SnapService* snap_service,
    DragCoordinator* drag_coordinator,
    BackgroundCaptureService* capture_service) {

  // Create binary messenger wrapper (stored on PaletteWindow for lifetime)
  window->binary_messenger =
      std::make_unique<PaletteBinaryMessenger>(messenger);
  auto* messenger_ptr = window->binary_messenger.get();

  const std::string& window_id = window->id;

  // ── Entry Channel ──────────────────────────────────────────────────────
  window->entry_channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          messenger_ptr, "floating_palette/entry",
          &flutter::StandardMethodCodec::GetInstance());

  window->entry_channel->SetMethodCallHandler(
      [window_id](
          const flutter::MethodCall<flutter::EncodableValue>& call,
          std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        if (call.method_name() == "getPaletteId") {
          result->Success(flutter::EncodableValue(window_id));
        } else {
          result->NotImplemented();
        }
      });

  // ── Messenger Channel ──────────────────────────────────────────────────
  window->messenger_channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          messenger_ptr, "floating_palette/messenger",
          &flutter::StandardMethodCodec::GetInstance());

  window->messenger_channel->SetMethodCallHandler(
      [window_id, event_sink, snap_service](
          const flutter::MethodCall<flutter::EncodableValue>& call,
          std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        const auto& method = call.method_name();
        const auto* args =
            std::get_if<flutter::EncodableMap>(call.arguments());
        flutter::EncodableMap params = args ? *args : flutter::EncodableMap{};

        if (method == "send") {
          if (event_sink) {
            event_sink("message", "received", &window_id, params);
          }
          result->Success(flutter::EncodableValue());

        } else if (method == "snap") {
          if (snap_service) {
            snap_service->Handle("snap", &window_id, params, std::move(result));
          } else {
            result->Success(flutter::EncodableValue());
          }

        } else if (method == "detachSnap") {
          if (snap_service) {
            snap_service->Handle("detach", &window_id, params,
                                 std::move(result));
          } else {
            result->Success(flutter::EncodableValue());
          }

        } else if (method == "setAutoSnapConfig") {
          if (snap_service) {
            snap_service->Handle("setAutoSnapConfig", &window_id, params,
                                 std::move(result));
          } else {
            result->Success(flutter::EncodableValue());
          }

        } else if (method == "notify") {
          if (event_sink) {
            event_sink("palette", "notify", &window_id, params);
          }
          result->Success(flutter::EncodableValue());

        } else if (method == "requestHide") {
          if (event_sink) {
            flutter::EncodableMap data;
            event_sink("visibility", "requestHide", &window_id, data);
          }
          result->Success(flutter::EncodableValue());

        } else {
          result->NotImplemented();
        }
      });

  // ── Self Channel ───────────────────────────────────────────────────────
  window->self_channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          messenger_ptr, "floating_palette/self",
          &flutter::StandardMethodCodec::GetInstance());

  window->self_channel->SetMethodCallHandler(
      [window_id, event_sink, drag_coordinator, capture_service](
          const flutter::MethodCall<flutter::EncodableValue>& call,
          std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        const auto& method = call.method_name();
        auto* w = WindowStore::Instance().Get(window_id);

        if (!w || !w->hwnd) {
          result->Error("NOT_FOUND", "Window not found");
          return;
        }

        if (method == "getBounds") {
          RECT rect;
          GetWindowRect(w->hwnd, &rect);
          result->Success(flutter::EncodableValue(flutter::EncodableMap{
              {flutter::EncodableValue("x"),
               flutter::EncodableValue(static_cast<double>(rect.left))},
              {flutter::EncodableValue("y"),
               flutter::EncodableValue(static_cast<double>(rect.top))},
              {flutter::EncodableValue("width"),
               flutter::EncodableValue(
                   static_cast<double>(rect.right - rect.left))},
              {flutter::EncodableValue("height"),
               flutter::EncodableValue(
                   static_cast<double>(rect.bottom - rect.top))},
          }));

        } else if (method == "getPosition") {
          RECT rect;
          GetWindowRect(w->hwnd, &rect);
          result->Success(flutter::EncodableValue(flutter::EncodableMap{
              {flutter::EncodableValue("x"),
               flutter::EncodableValue(static_cast<double>(rect.left))},
              {flutter::EncodableValue("y"),
               flutter::EncodableValue(static_cast<double>(rect.top))},
          }));

        } else if (method == "getSize") {
          RECT rect;
          GetWindowRect(w->hwnd, &rect);
          result->Success(flutter::EncodableValue(flutter::EncodableMap{
              {flutter::EncodableValue("width"),
               flutter::EncodableValue(
                   static_cast<double>(rect.right - rect.left))},
              {flutter::EncodableValue("height"),
               flutter::EncodableValue(
                   static_cast<double>(rect.bottom - rect.top))},
          }));

        } else if (method == "getSizeConfig") {
          result->Success(flutter::EncodableValue(flutter::EncodableMap{
              {flutter::EncodableValue("width"),
               flutter::EncodableValue(w->width)},
              {flutter::EncodableValue("minWidth"),
               flutter::EncodableValue(w->min_width)},
              {flutter::EncodableValue("minHeight"),
               flutter::EncodableValue(w->min_height)},
              {flutter::EncodableValue("maxWidth"),
               flutter::EncodableValue(w->max_width)},
              {flutter::EncodableValue("maxHeight"),
               flutter::EncodableValue(w->max_height)},
          }));

        } else if (method == "startDrag") {
          if (drag_coordinator && w->draggable) {
            drag_coordinator->StartDrag(window_id, w);
          }
          result->Success(flutter::EncodableValue());

        } else if (method == "setSize") {
          const auto* args =
              std::get_if<flutter::EncodableMap>(call.arguments());
          if (args) {
            double new_w = GetDouble(*args, "width", w->width);
            double new_h = GetDouble(*args, "height", w->height);
            int iw = static_cast<int>(new_w);
            int ih = static_cast<int>(new_h);
            SetWindowPos(w->hwnd, NULL, 0, 0, iw, ih,
                         SWP_NOMOVE | SWP_NOZORDER | SWP_NOACTIVATE);
            HWND child = GetWindow(w->hwnd, GW_CHILD);
            if (child) {
              SetWindowPos(child, NULL, 0, 0, iw, ih,
                           SWP_NOMOVE | SWP_NOZORDER | SWP_NOACTIVATE);
            }
            w->width = new_w;
            w->height = new_h;
          }
          result->Success(flutter::EncodableValue());

        } else if (method == "hide") {
          ShowWindow(w->hwnd, SW_HIDE);
          LONG_PTR ex = GetWindowLongPtr(w->hwnd, GWL_EXSTYLE);
          SetWindowLongPtr(w->hwnd, GWL_EXSTYLE, ex | WS_EX_NOACTIVATE);
          if (event_sink) {
            flutter::EncodableMap data;
            event_sink("visibility", "hidden", &window_id, data);
          }
          result->Success(flutter::EncodableValue());

        } else if (method == "backgroundCapture.checkPermission") {
          result->Success(flutter::EncodableValue("granted"));

        } else if (method == "backgroundCapture.requestPermission") {
          result->Success(flutter::EncodableValue("granted"));

        } else if (method == "backgroundCapture.start") {
          // TODO: Start background capture for this palette
          result->Success(flutter::EncodableValue());

        } else if (method == "backgroundCapture.stop") {
          // TODO: Stop background capture for this palette
          result->Success(flutter::EncodableValue());

        } else if (method == "backgroundCapture.getTextureId") {
          result->Success(flutter::EncodableValue(-1));

        } else {
          result->NotImplemented();
        }
      });

  FP_LOG("Plugin", "SetupChannels for " + window_id);
}

}  // namespace floating_palette
