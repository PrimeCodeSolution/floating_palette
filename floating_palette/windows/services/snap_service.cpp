#include "snap_service.h"

#include "../core/logger.h"

namespace floating_palette {

void SnapService::Handle(
    const std::string& command,
    const std::string* window_id,
    const flutter::EncodableMap& params,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (command == "snap") {
    Snap(window_id, params, std::move(result));
  } else if (command == "detach") {
    Detach(window_id, std::move(result));
  } else if (command == "reSnap") {
    ReSnap(window_id, std::move(result));
  } else if (command == "getSnapDistance") {
    GetSnapDistance(window_id, std::move(result));
  } else if (command == "setAutoSnapConfig") {
    SetAutoSnapConfig(window_id, params, std::move(result));
  } else {
    result->Error("UNKNOWN_COMMAND", "Unknown snap command: " + command);
  }
}

void SnapService::OnWindowShown(const std::string& id) {
  FP_LOG("Snap", "onWindowShown stub: " + id);
}

void SnapService::OnWindowHidden(const std::string& id) {
  FP_LOG("Snap", "onWindowHidden stub: " + id);
}

// DragCoordinatorDelegate

void SnapService::DragBegan(const std::string& id) {
  FP_LOG("Snap", "dragBegan stub: " + id);
}

void SnapService::DragMoved(const std::string& id, const RECT& frame) {
  FP_LOG("Snap", "dragMoved stub: " + id);
}

void SnapService::DragEnded(const std::string& id, const RECT& frame) {
  FP_LOG("Snap", "dragEnded stub: " + id);
}

// Commands

void SnapService::Snap(
    const std::string* window_id,
    const flutter::EncodableMap& params,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  FP_LOG("Snap", "snap stub");
  result->Success(flutter::EncodableValue());
}

void SnapService::Detach(
    const std::string* window_id,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  FP_LOG("Snap", "detach stub");
  result->Success(flutter::EncodableValue());
}

void SnapService::ReSnap(
    const std::string* window_id,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  FP_LOG("Snap", "reSnap stub");
  result->Success(flutter::EncodableValue());
}

void SnapService::GetSnapDistance(
    const std::string* window_id,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  result->Success(flutter::EncodableValue(0.0));
}

void SnapService::SetAutoSnapConfig(
    const std::string* window_id,
    const flutter::EncodableMap& params,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  FP_LOG("Snap", "setAutoSnapConfig stub");
  result->Success(flutter::EncodableValue());
}

}  // namespace floating_palette
