#include "screen_service.h"

#include "../core/logger.h"

namespace floating_palette {

void ScreenService::Handle(
    const std::string& command,
    const std::string* window_id,
    const flutter::EncodableMap& params,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (command == "getScreens") {
    GetScreens(std::move(result));
  } else if (command == "getCurrentScreen") {
    GetCurrentScreen(std::move(result));
  } else if (command == "getWindowScreen") {
    GetWindowScreen(window_id, std::move(result));
  } else if (command == "moveToScreen") {
    MoveToScreen(window_id, params, std::move(result));
  } else if (command == "getCursorPosition") {
    GetCursorPosition(std::move(result));
  } else if (command == "getActiveAppBounds") {
    GetActiveAppBounds(std::move(result));
  } else {
    result->Error("UNKNOWN_COMMAND", "Unknown screen command: " + command);
  }
}

void ScreenService::GetScreens(
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  // TODO: Enumerate monitors via EnumDisplayMonitors
  result->Success(flutter::EncodableValue(flutter::EncodableList{}));
}

void ScreenService::GetCurrentScreen(
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  // TODO: Get primary monitor info
  result->Success(flutter::EncodableValue());
}

void ScreenService::GetWindowScreen(
    const std::string* window_id,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  // TODO: Get monitor containing the window
  result->Success(flutter::EncodableValue());
}

void ScreenService::MoveToScreen(
    const std::string* window_id,
    const flutter::EncodableMap& params,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  FP_LOG("Screen", "moveToScreen stub");
  result->Success(flutter::EncodableValue());
}

void ScreenService::GetCursorPosition(
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  // TODO: GetCursorPos
  result->Success(flutter::EncodableValue(flutter::EncodableMap{
      {flutter::EncodableValue("x"), flutter::EncodableValue(0.0)},
      {flutter::EncodableValue("y"), flutter::EncodableValue(0.0)},
  }));
}

void ScreenService::GetActiveAppBounds(
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  // TODO: GetForegroundWindow + GetWindowRect
  result->Success(flutter::EncodableValue(flutter::EncodableMap{
      {flutter::EncodableValue("x"), flutter::EncodableValue(0.0)},
      {flutter::EncodableValue("y"), flutter::EncodableValue(0.0)},
      {flutter::EncodableValue("width"), flutter::EncodableValue(0.0)},
      {flutter::EncodableValue("height"), flutter::EncodableValue(0.0)},
  }));
}

}  // namespace floating_palette
