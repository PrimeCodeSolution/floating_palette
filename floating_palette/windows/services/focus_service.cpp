#include "focus_service.h"

#include "../core/logger.h"

namespace floating_palette {

void FocusService::Handle(
    const std::string& command,
    const std::string* window_id,
    const flutter::EncodableMap& params,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (command == "focus") {
    Focus(window_id, std::move(result));
  } else if (command == "unfocus") {
    Unfocus(window_id, std::move(result));
  } else if (command == "setPolicy") {
    SetPolicy(window_id, params, std::move(result));
  } else if (command == "isFocused") {
    IsFocused(window_id, std::move(result));
  } else if (command == "focusMainWindow") {
    FocusMainWindow(std::move(result));
  } else if (command == "hideApp") {
    HideApp(std::move(result));
  } else {
    result->Error("UNKNOWN_COMMAND", "Unknown focus command: " + command);
  }
}

void FocusService::Focus(
    const std::string* window_id,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  FP_LOG("Focus", "focus stub");
  result->Success(flutter::EncodableValue());
}

void FocusService::Unfocus(
    const std::string* window_id,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  FP_LOG("Focus", "unfocus stub");
  result->Success(flutter::EncodableValue());
}

void FocusService::SetPolicy(
    const std::string* window_id,
    const flutter::EncodableMap& params,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  FP_LOG("Focus", "setPolicy stub");
  result->Success(flutter::EncodableValue());
}

void FocusService::IsFocused(
    const std::string* window_id,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  result->Success(flutter::EncodableValue(false));
}

void FocusService::FocusMainWindow(
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  FP_LOG("Focus", "focusMainWindow stub");
  result->Success(flutter::EncodableValue());
}

void FocusService::HideApp(
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  FP_LOG("Focus", "hideApp stub");
  result->Success(flutter::EncodableValue());
}

}  // namespace floating_palette
