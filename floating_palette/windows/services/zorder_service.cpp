#include "zorder_service.h"

#include "../core/logger.h"

namespace floating_palette {

void ZOrderService::Handle(
    const std::string& command,
    const std::string* window_id,
    const flutter::EncodableMap& params,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (command == "bringToFront") {
    BringToFront(window_id, std::move(result));
  } else if (command == "sendToBack") {
    SendToBack(window_id, std::move(result));
  } else if (command == "moveAbove") {
    MoveAbove(window_id, params, std::move(result));
  } else if (command == "moveBelow") {
    MoveBelow(window_id, params, std::move(result));
  } else if (command == "setZIndex") {
    SetZIndex(window_id, params, std::move(result));
  } else if (command == "setLevel") {
    SetLevel(window_id, params, std::move(result));
  } else if (command == "pin") {
    Pin(window_id, std::move(result));
  } else if (command == "unpin") {
    Unpin(window_id, std::move(result));
  } else {
    result->Error("UNKNOWN_COMMAND", "Unknown zorder command: " + command);
  }
}

void ZOrderService::BringToFront(
    const std::string* window_id,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  FP_LOG("ZOrder", "bringToFront stub");
  result->Success(flutter::EncodableValue());
}

void ZOrderService::SendToBack(
    const std::string* window_id,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  FP_LOG("ZOrder", "sendToBack stub");
  result->Success(flutter::EncodableValue());
}

void ZOrderService::MoveAbove(
    const std::string* window_id,
    const flutter::EncodableMap& params,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  FP_LOG("ZOrder", "moveAbove stub");
  result->Success(flutter::EncodableValue());
}

void ZOrderService::MoveBelow(
    const std::string* window_id,
    const flutter::EncodableMap& params,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  FP_LOG("ZOrder", "moveBelow stub");
  result->Success(flutter::EncodableValue());
}

void ZOrderService::SetZIndex(
    const std::string* window_id,
    const flutter::EncodableMap& params,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  FP_LOG("ZOrder", "setZIndex stub");
  result->Success(flutter::EncodableValue());
}

void ZOrderService::SetLevel(
    const std::string* window_id,
    const flutter::EncodableMap& params,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  FP_LOG("ZOrder", "setLevel stub");
  result->Success(flutter::EncodableValue());
}

void ZOrderService::Pin(
    const std::string* window_id,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  FP_LOG("ZOrder", "pin stub");
  result->Success(flutter::EncodableValue());
}

void ZOrderService::Unpin(
    const std::string* window_id,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  FP_LOG("ZOrder", "unpin stub");
  result->Success(flutter::EncodableValue());
}

}  // namespace floating_palette
