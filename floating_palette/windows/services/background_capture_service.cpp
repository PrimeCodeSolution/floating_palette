#include "background_capture_service.h"

#include "../core/logger.h"

namespace floating_palette {

BackgroundCaptureService::BackgroundCaptureService(
    flutter::PluginRegistrarWindows* registrar)
    : registrar_(registrar) {}

void BackgroundCaptureService::Handle(
    const std::string& command,
    const std::string* window_id,
    const flutter::EncodableMap& params,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (command == "checkPermission") {
    CheckPermission(std::move(result));
  } else if (command == "requestPermission") {
    RequestPermission(std::move(result));
  } else if (command == "start") {
    Start(window_id, params, std::move(result));
  } else if (command == "stop") {
    Stop(window_id, std::move(result));
  } else if (command == "getTextureId") {
    GetTextureId(window_id, std::move(result));
  } else {
    result->Error("UNKNOWN_COMMAND",
                  "Unknown backgroundCapture command: " + command);
  }
}

void BackgroundCaptureService::CheckPermission(
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  // Windows doesn't require screen capture permissions like macOS
  result->Success(flutter::EncodableValue("granted"));
}

void BackgroundCaptureService::RequestPermission(
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  // No-op on Windows
  result->Success(flutter::EncodableValue("granted"));
}

void BackgroundCaptureService::Start(
    const std::string* window_id,
    const flutter::EncodableMap& params,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  FP_LOG("Capture", "start stub");
  result->Success(flutter::EncodableValue());
}

void BackgroundCaptureService::Stop(
    const std::string* window_id,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  FP_LOG("Capture", "stop stub");
  result->Success(flutter::EncodableValue());
}

void BackgroundCaptureService::GetTextureId(
    const std::string* window_id,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  // TODO: Return texture ID from Flutter texture registry
  result->Success(flutter::EncodableValue(-1));
}

}  // namespace floating_palette
