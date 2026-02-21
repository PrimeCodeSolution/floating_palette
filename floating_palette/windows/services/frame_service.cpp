#include "frame_service.h"

#include "../core/logger.h"

namespace floating_palette {

void FrameService::Handle(
    const std::string& command,
    const std::string* window_id,
    const flutter::EncodableMap& params,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (command == "setPosition") {
    SetPosition(window_id, params, std::move(result));
  } else if (command == "setSize") {
    SetSize(window_id, params, std::move(result));
  } else if (command == "setBounds") {
    SetBounds(window_id, params, std::move(result));
  } else if (command == "getPosition") {
    GetPosition(window_id, std::move(result));
  } else if (command == "getSize") {
    GetSize(window_id, std::move(result));
  } else if (command == "getBounds") {
    GetBounds(window_id, std::move(result));
  } else if (command == "startDrag") {
    StartDrag(window_id, std::move(result));
  } else if (command == "setDraggable") {
    SetDraggable(window_id, params, std::move(result));
  } else {
    result->Error("UNKNOWN_COMMAND", "Unknown frame command: " + command);
  }
}

void FrameService::SetPosition(
    const std::string* window_id,
    const flutter::EncodableMap& params,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  FP_LOG("Frame", "setPosition stub");
  result->Success(flutter::EncodableValue());
}

void FrameService::SetSize(
    const std::string* window_id,
    const flutter::EncodableMap& params,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  FP_LOG("Frame", "setSize stub");
  result->Success(flutter::EncodableValue());
}

void FrameService::SetBounds(
    const std::string* window_id,
    const flutter::EncodableMap& params,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  FP_LOG("Frame", "setBounds stub");
  result->Success(flutter::EncodableValue());
}

void FrameService::GetPosition(
    const std::string* window_id,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  result->Success(flutter::EncodableValue(flutter::EncodableMap{
      {flutter::EncodableValue("x"), flutter::EncodableValue(0.0)},
      {flutter::EncodableValue("y"), flutter::EncodableValue(0.0)},
  }));
}

void FrameService::GetSize(
    const std::string* window_id,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  result->Success(flutter::EncodableValue(flutter::EncodableMap{
      {flutter::EncodableValue("width"), flutter::EncodableValue(0.0)},
      {flutter::EncodableValue("height"), flutter::EncodableValue(0.0)},
  }));
}

void FrameService::GetBounds(
    const std::string* window_id,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  result->Success(flutter::EncodableValue(flutter::EncodableMap{
      {flutter::EncodableValue("x"), flutter::EncodableValue(0.0)},
      {flutter::EncodableValue("y"), flutter::EncodableValue(0.0)},
      {flutter::EncodableValue("width"), flutter::EncodableValue(0.0)},
      {flutter::EncodableValue("height"), flutter::EncodableValue(0.0)},
  }));
}

void FrameService::StartDrag(
    const std::string* window_id,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  FP_LOG("Frame", "startDrag stub");
  result->Success(flutter::EncodableValue());
}

void FrameService::SetDraggable(
    const std::string* window_id,
    const flutter::EncodableMap& params,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  FP_LOG("Frame", "setDraggable stub");
  result->Success(flutter::EncodableValue());
}

}  // namespace floating_palette
