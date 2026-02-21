#include "visibility_service.h"

#include "../core/logger.h"

namespace floating_palette {

void VisibilityService::Handle(
    const std::string& command,
    const std::string* window_id,
    const flutter::EncodableMap& params,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (command == "show") {
    Show(window_id, params, std::move(result));
  } else if (command == "hide") {
    Hide(window_id, params, std::move(result));
  } else if (command == "setOpacity") {
    SetOpacity(window_id, params, std::move(result));
  } else if (command == "getOpacity") {
    GetOpacity(window_id, std::move(result));
  } else if (command == "reveal") {
    DoReveal(window_id, std::move(result));
  } else {
    result->Error("UNKNOWN_COMMAND",
                  "Unknown visibility command: " + command);
  }
}

void VisibilityService::Reveal(const std::string& window_id) {
  // TODO: Implement show-after-sized reveal pattern
  FP_LOG("Visibility", "reveal stub: " + window_id);
}

void VisibilityService::Show(
    const std::string* window_id,
    const flutter::EncodableMap& params,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  // TODO: Show window with ShowWindow/SetWindowPos
  FP_LOG("Visibility", "show stub");
  result->Success(flutter::EncodableValue());
}

void VisibilityService::Hide(
    const std::string* window_id,
    const flutter::EncodableMap& params,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  // TODO: Hide window
  FP_LOG("Visibility", "hide stub");
  result->Success(flutter::EncodableValue());
}

void VisibilityService::SetOpacity(
    const std::string* window_id,
    const flutter::EncodableMap& params,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  // TODO: Set window opacity via SetLayeredWindowAttributes
  FP_LOG("Visibility", "setOpacity stub");
  result->Success(flutter::EncodableValue());
}

void VisibilityService::GetOpacity(
    const std::string* window_id,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  // TODO: Get window opacity
  result->Success(flutter::EncodableValue(1.0));
}

void VisibilityService::DoReveal(
    const std::string* window_id,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (window_id) {
    Reveal(*window_id);
  }
  result->Success(flutter::EncodableValue());
}

}  // namespace floating_palette
