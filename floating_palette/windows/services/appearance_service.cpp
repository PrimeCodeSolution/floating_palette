#include "appearance_service.h"

#include "../core/logger.h"

namespace floating_palette {

void AppearanceService::Handle(
    const std::string& command,
    const std::string* window_id,
    const flutter::EncodableMap& params,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (command == "setCornerRadius") {
    SetCornerRadius(window_id, params, std::move(result));
  } else if (command == "setShadow") {
    SetShadow(window_id, params, std::move(result));
  } else if (command == "setBackgroundColor") {
    SetBackgroundColor(window_id, params, std::move(result));
  } else if (command == "setTransparent") {
    SetTransparent(window_id, params, std::move(result));
  } else if (command == "setBlur") {
    SetBlur(window_id, params, std::move(result));
  } else if (command == "applyAppearance") {
    ApplyAppearance(window_id, params, std::move(result));
  } else {
    result->Error("UNKNOWN_COMMAND",
                  "Unknown appearance command: " + command);
  }
}

void AppearanceService::SetCornerRadius(
    const std::string* window_id,
    const flutter::EncodableMap& params,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  FP_LOG("Appearance", "setCornerRadius stub");
  result->Success(flutter::EncodableValue());
}

void AppearanceService::SetShadow(
    const std::string* window_id,
    const flutter::EncodableMap& params,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  FP_LOG("Appearance", "setShadow stub");
  result->Success(flutter::EncodableValue());
}

void AppearanceService::SetBackgroundColor(
    const std::string* window_id,
    const flutter::EncodableMap& params,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  FP_LOG("Appearance", "setBackgroundColor stub");
  result->Success(flutter::EncodableValue());
}

void AppearanceService::SetTransparent(
    const std::string* window_id,
    const flutter::EncodableMap& params,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  FP_LOG("Appearance", "setTransparent stub");
  result->Success(flutter::EncodableValue());
}

void AppearanceService::SetBlur(
    const std::string* window_id,
    const flutter::EncodableMap& params,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  FP_LOG("Appearance", "setBlur stub");
  result->Success(flutter::EncodableValue());
}

void AppearanceService::ApplyAppearance(
    const std::string* window_id,
    const flutter::EncodableMap& params,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  FP_LOG("Appearance", "applyAppearance stub");
  result->Success(flutter::EncodableValue());
}

}  // namespace floating_palette
