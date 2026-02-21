#include "window_service.h"

#include "../core/logger.h"

namespace floating_palette {

WindowService::WindowService(flutter::PluginRegistrarWindows* registrar)
    : registrar_(registrar) {}

void WindowService::Handle(
    const std::string& command,
    const std::string* window_id,
    const flutter::EncodableMap& params,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (command == "create") {
    Create(window_id, params, std::move(result));
  } else if (command == "destroy") {
    Destroy(window_id, params, std::move(result));
  } else if (command == "exists") {
    Exists(window_id, std::move(result));
  } else if (command == "setEntryPoint") {
    SetEntryPoint(window_id, params, std::move(result));
  } else {
    result->Error("UNKNOWN_COMMAND", "Unknown window command: " + command);
  }
}

void WindowService::Create(
    const std::string* window_id,
    const flutter::EncodableMap& params,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (!window_id) {
    result->Error("MISSING_ID", "windowId required");
    return;
  }
  if (WindowStore::Instance().Exists(*window_id)) {
    result->Error("ALREADY_EXISTS", "Window already exists: " + *window_id);
    return;
  }
  // TODO: Create HWND, Flutter engine, register channels
  FP_LOG("Window", "create stub: " + *window_id);
  result->Success(flutter::EncodableValue());
}

void WindowService::Destroy(
    const std::string* window_id,
    const flutter::EncodableMap& params,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (!window_id) {
    result->Error("MISSING_ID", "windowId required");
    return;
  }
  // TODO: Destroy window, engine, channels
  FP_LOG("Window", "destroy stub: " + *window_id);
  result->Success(flutter::EncodableValue());
}

void WindowService::Exists(
    const std::string* window_id,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (!window_id) {
    result->Success(flutter::EncodableValue(false));
    return;
  }
  bool exists = WindowStore::Instance().Exists(*window_id);
  result->Success(flutter::EncodableValue(exists));
}

void WindowService::SetEntryPoint(
    const std::string* window_id,
    const flutter::EncodableMap& params,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  // TODO: Configure entry point for palette Flutter engine
  FP_LOG("Window", "setEntryPoint stub");
  result->Success(flutter::EncodableValue());
}

}  // namespace floating_palette
