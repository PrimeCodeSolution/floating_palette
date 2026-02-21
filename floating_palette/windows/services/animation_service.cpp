#include "animation_service.h"

#include "../core/logger.h"

namespace floating_palette {

void AnimationService::Handle(
    const std::string& command,
    const std::string* window_id,
    const flutter::EncodableMap& params,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (command == "animate") {
    Animate(window_id, params, std::move(result));
  } else if (command == "animateMultiple") {
    AnimateMultiple(window_id, params, std::move(result));
  } else if (command == "stop") {
    Stop(window_id, std::move(result));
  } else if (command == "stopAll") {
    StopAll(std::move(result));
  } else if (command == "isAnimating") {
    IsAnimating(window_id, std::move(result));
  } else {
    result->Error("UNKNOWN_COMMAND", "Unknown animation command: " + command);
  }
}

void AnimationService::Animate(
    const std::string* window_id,
    const flutter::EncodableMap& params,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  FP_LOG("Animation", "animate stub");
  result->Success(flutter::EncodableValue());
}

void AnimationService::AnimateMultiple(
    const std::string* window_id,
    const flutter::EncodableMap& params,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  FP_LOG("Animation", "animateMultiple stub");
  result->Success(flutter::EncodableValue());
}

void AnimationService::Stop(
    const std::string* window_id,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  FP_LOG("Animation", "stop stub");
  result->Success(flutter::EncodableValue());
}

void AnimationService::StopAll(
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  FP_LOG("Animation", "stopAll stub");
  result->Success(flutter::EncodableValue());
}

void AnimationService::IsAnimating(
    const std::string* window_id,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  result->Success(flutter::EncodableValue(false));
}

}  // namespace floating_palette
