#include "floating_palette_plugin.h"

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <string>
#include <variant>

#include "coordinators/drag_coordinator.h"
#include "core/logger.h"
#include "services/animation_service.h"
#include "services/appearance_service.h"
#include "services/background_capture_service.h"
#include "services/focus_service.h"
#include "services/frame_service.h"
#include "services/host_service.h"
#include "services/input_service.h"
#include "services/message_service.h"
#include "services/screen_service.h"
#include "services/snap_service.h"
#include "services/transform_service.h"
#include "services/visibility_service.h"
#include "services/window_service.h"
#include "services/zorder_service.h"

namespace floating_palette {

// static
void FloatingPalettePlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows* registrar) {
  auto channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      registrar->messenger(), "floating_palette",
      &flutter::StandardMethodCodec::GetInstance());

  auto plugin = std::make_unique<FloatingPalettePlugin>(
      registrar, std::move(channel));

  plugin->channel_->SetMethodCallHandler(
      [plugin_ptr = plugin.get()](const auto& call, auto result) {
        plugin_ptr->HandleMethodCall(call, std::move(result));
      });

  registrar->AddPlugin(std::move(plugin));
}

FloatingPalettePlugin::FloatingPalettePlugin(
    flutter::PluginRegistrarWindows* registrar,
    std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel)
    : registrar_(registrar), channel_(std::move(channel)) {
  InitializeServices();
}

FloatingPalettePlugin::~FloatingPalettePlugin() = default;

void FloatingPalettePlugin::InitializeServices() {
  // Create event sink
  EventSink event_sink = [this](const std::string& service,
                                const std::string& event,
                                const std::string* window_id,
                                const flutter::EncodableMap& data) {
    SendEvent(service, event, window_id, data);
  };

  // Initialize all services
  window_service_ = std::make_unique<WindowService>(registrar_);
  window_service_->SetEventSink(event_sink);

  visibility_service_ = std::make_unique<VisibilityService>();
  visibility_service_->SetEventSink(event_sink);

  frame_service_ = std::make_unique<FrameService>();
  frame_service_->SetEventSink(event_sink);

  transform_service_ = std::make_unique<TransformService>();
  transform_service_->SetEventSink(event_sink);

  animation_service_ = std::make_unique<AnimationService>();
  animation_service_->SetEventSink(event_sink);

  input_service_ = std::make_unique<InputService>();
  input_service_->SetEventSink(event_sink);

  focus_service_ = std::make_unique<FocusService>();
  focus_service_->SetEventSink(event_sink);
  focus_service_->SetMainHwnd(registrar_->GetView()->GetNativeWindow());

  zorder_service_ = std::make_unique<ZOrderService>();
  zorder_service_->SetEventSink(event_sink);

  appearance_service_ = std::make_unique<AppearanceService>();
  appearance_service_->SetEventSink(event_sink);

  screen_service_ = std::make_unique<ScreenService>();
  screen_service_->SetEventSink(event_sink);
  screen_service_->SetMainHwnd(registrar_->GetView()->GetNativeWindow());

  background_capture_service_ =
      std::make_unique<BackgroundCaptureService>(registrar_);
  background_capture_service_->SetEventSink(event_sink);

  message_service_ = std::make_unique<MessageService>();
  message_service_->SetEventSink(event_sink);

  host_service_ = std::make_unique<HostService>();
  host_service_->SetEventSink(event_sink);

  snap_service_ = std::make_unique<SnapService>();
  snap_service_->SetEventSink(event_sink);

  // Create DragCoordinator and wire it up
  drag_coordinator_ = std::make_unique<DragCoordinator>();
  drag_coordinator_->SetDelegate(snap_service_.get());

  // Wire cross-service references
  window_service_->SetBackgroundCaptureService(
      background_capture_service_.get());
  window_service_->SetFrameService(frame_service_.get());
  window_service_->SetSnapService(snap_service_.get());
  window_service_->SetDragCoordinator(drag_coordinator_.get());
  window_service_->SetInputService(input_service_.get());
  window_service_->SetVisibilityService(visibility_service_.get());

  frame_service_->SetSnapService(snap_service_.get());
  frame_service_->SetDragCoordinator(drag_coordinator_.get());

  visibility_service_->SetSnapService(snap_service_.get());
}

void FloatingPalettePlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (method_call.method_name() != "command") {
    result->NotImplemented();
    return;
  }

  const auto* args =
      std::get_if<flutter::EncodableMap>(method_call.arguments());
  if (!args) {
    result->NotImplemented();
    return;
  }

  // Extract service name
  auto service_it = args->find(flutter::EncodableValue("service"));
  if (service_it == args->end() ||
      !std::holds_alternative<std::string>(service_it->second)) {
    result->NotImplemented();
    return;
  }
  const auto& service = std::get<std::string>(service_it->second);

  // Extract command name
  auto command_it = args->find(flutter::EncodableValue("command"));
  if (command_it == args->end() ||
      !std::holds_alternative<std::string>(command_it->second)) {
    result->NotImplemented();
    return;
  }
  const auto& command = std::get<std::string>(command_it->second);

  // Extract optional windowId
  const std::string* window_id = nullptr;
  auto window_id_it = args->find(flutter::EncodableValue("windowId"));
  if (window_id_it != args->end() &&
      std::holds_alternative<std::string>(window_id_it->second)) {
    window_id = &std::get<std::string>(window_id_it->second);
  }

  // Extract params (default to empty map)
  flutter::EncodableMap params;
  auto params_it = args->find(flutter::EncodableValue("params"));
  if (params_it != args->end() &&
      std::holds_alternative<flutter::EncodableMap>(params_it->second)) {
    params = std::get<flutter::EncodableMap>(params_it->second);
  }

  FP_LOG("CMD", service + "." + command +
                    (window_id ? " [" + *window_id + "]" : " [no-id]"));

  // Route to appropriate service
  if (service == "window") {
    window_service_->Handle(command, window_id, params, std::move(result));
  } else if (service == "visibility") {
    visibility_service_->Handle(command, window_id, params, std::move(result));
  } else if (service == "frame") {
    frame_service_->Handle(command, window_id, params, std::move(result));
  } else if (service == "transform") {
    transform_service_->Handle(command, window_id, params, std::move(result));
  } else if (service == "animation") {
    animation_service_->Handle(command, window_id, params, std::move(result));
  } else if (service == "input") {
    input_service_->Handle(command, window_id, params, std::move(result));
  } else if (service == "focus") {
    focus_service_->Handle(command, window_id, params, std::move(result));
  } else if (service == "zorder") {
    zorder_service_->Handle(command, window_id, params, std::move(result));
  } else if (service == "appearance") {
    appearance_service_->Handle(command, window_id, params, std::move(result));
  } else if (service == "screen") {
    screen_service_->Handle(command, window_id, params, std::move(result));
  } else if (service == "backgroundCapture") {
    background_capture_service_->Handle(command, window_id, params,
                                        std::move(result));
  } else if (service == "message") {
    message_service_->Handle(command, window_id, params, std::move(result));
  } else if (service == "host") {
    host_service_->Handle(command, window_id, params, std::move(result));
  } else if (service == "snap") {
    snap_service_->Handle(command, window_id, params, std::move(result));
  } else {
    result->Error("UNKNOWN_SERVICE", "Unknown service: " + service);
  }
}

void FloatingPalettePlugin::SendEvent(const std::string& service,
                                      const std::string& event,
                                      const std::string* window_id,
                                      const flutter::EncodableMap& data) {
  FP_LOG("EVT", service + "." + event +
                    (window_id ? " [" + *window_id + "]" : " [no-id]"));
  flutter::EncodableMap args;
  args[flutter::EncodableValue("service")] = flutter::EncodableValue(service);
  args[flutter::EncodableValue("event")] = flutter::EncodableValue(event);
  if (window_id) {
    args[flutter::EncodableValue("windowId")] =
        flutter::EncodableValue(*window_id);
  } else {
    args[flutter::EncodableValue("windowId")] = flutter::EncodableValue();
  }
  args[flutter::EncodableValue("data")] = flutter::EncodableValue(data);

  channel_->InvokeMethod("event",
                         std::make_unique<flutter::EncodableValue>(args));
}

}  // namespace floating_palette
