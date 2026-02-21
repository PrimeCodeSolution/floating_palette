#include "transform_service.h"

#include "../core/logger.h"

namespace floating_palette {

void TransformService::Handle(
    const std::string& command,
    const std::string* window_id,
    const flutter::EncodableMap& params,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (command == "setScale") {
    SetScale(window_id, params, std::move(result));
  } else if (command == "setRotation") {
    SetRotation(window_id, params, std::move(result));
  } else if (command == "setFlip") {
    SetFlip(window_id, params, std::move(result));
  } else if (command == "reset") {
    Reset(window_id, std::move(result));
  } else if (command == "getScale") {
    GetScale(window_id, std::move(result));
  } else if (command == "getRotation") {
    GetRotation(window_id, std::move(result));
  } else {
    result->Error("UNKNOWN_COMMAND", "Unknown transform command: " + command);
  }
}

void TransformService::SetScale(
    const std::string* window_id,
    const flutter::EncodableMap& params,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  FP_LOG("Transform", "setScale stub");
  result->Success(flutter::EncodableValue());
}

void TransformService::SetRotation(
    const std::string* window_id,
    const flutter::EncodableMap& params,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  FP_LOG("Transform", "setRotation stub");
  result->Success(flutter::EncodableValue());
}

void TransformService::SetFlip(
    const std::string* window_id,
    const flutter::EncodableMap& params,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  FP_LOG("Transform", "setFlip stub");
  result->Success(flutter::EncodableValue());
}

void TransformService::Reset(
    const std::string* window_id,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  FP_LOG("Transform", "reset stub");
  result->Success(flutter::EncodableValue());
}

void TransformService::GetScale(
    const std::string* window_id,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  result->Success(flutter::EncodableValue(1.0));
}

void TransformService::GetRotation(
    const std::string* window_id,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  result->Success(flutter::EncodableValue(0.0));
}

}  // namespace floating_palette
