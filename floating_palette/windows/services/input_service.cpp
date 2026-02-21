#include "input_service.h"

#include "../core/logger.h"

namespace floating_palette {

void InputService::Handle(
    const std::string& command,
    const std::string* window_id,
    const flutter::EncodableMap& params,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (command == "captureKeyboard") {
    CaptureKeyboard(window_id, std::move(result));
  } else if (command == "releaseKeyboard") {
    ReleaseKeyboard(window_id, std::move(result));
  } else if (command == "capturePointer") {
    CapturePointer(window_id, std::move(result));
  } else if (command == "releasePointer") {
    ReleasePointer(window_id, std::move(result));
  } else if (command == "setCursor") {
    SetCursor(window_id, params, std::move(result));
  } else if (command == "setPassthrough") {
    SetPassthrough(window_id, params, std::move(result));
  } else {
    result->Error("UNKNOWN_COMMAND", "Unknown input command: " + command);
  }
}

void InputService::CaptureKeyboard(
    const std::string* window_id,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  FP_LOG("Input", "captureKeyboard stub");
  result->Success(flutter::EncodableValue());
}

void InputService::ReleaseKeyboard(
    const std::string* window_id,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  FP_LOG("Input", "releaseKeyboard stub");
  result->Success(flutter::EncodableValue());
}

void InputService::CapturePointer(
    const std::string* window_id,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  FP_LOG("Input", "capturePointer stub");
  result->Success(flutter::EncodableValue());
}

void InputService::ReleasePointer(
    const std::string* window_id,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  FP_LOG("Input", "releasePointer stub");
  result->Success(flutter::EncodableValue());
}

void InputService::SetCursor(
    const std::string* window_id,
    const flutter::EncodableMap& params,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  FP_LOG("Input", "setCursor stub");
  result->Success(flutter::EncodableValue());
}

void InputService::SetPassthrough(
    const std::string* window_id,
    const flutter::EncodableMap& params,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  FP_LOG("Input", "setPassthrough stub");
  result->Success(flutter::EncodableValue());
}

}  // namespace floating_palette
