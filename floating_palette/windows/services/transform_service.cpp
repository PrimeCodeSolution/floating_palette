#include "transform_service.h"

#include "../core/logger.h"
#include "../core/param_helpers.h"

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
  if (!window_id) {
    result->Error("MISSING_ID", "windowId required");
    return;
  }

  auto* window = WindowStore::Instance().Get(*window_id);
  if (!window) {
    result->Error("NOT_FOUND", "Window not found");
    return;
  }

  // Software state tracking only (no native transforms on Windows)
  window->scale_x = GetDouble(params, "x", GetDouble(params, "scale", 1.0));
  window->scale_y = GetDouble(params, "y", GetDouble(params, "scale", 1.0));

  result->Success(flutter::EncodableValue());
}

void TransformService::SetRotation(
    const std::string* window_id,
    const flutter::EncodableMap& params,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (!window_id) {
    result->Error("MISSING_ID", "windowId required");
    return;
  }

  auto* window = WindowStore::Instance().Get(*window_id);
  if (!window) {
    result->Error("NOT_FOUND", "Window not found");
    return;
  }

  window->rotation = GetDouble(params, "angle", 0.0);

  result->Success(flutter::EncodableValue());
}

void TransformService::SetFlip(
    const std::string* window_id,
    const flutter::EncodableMap& params,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (!window_id) {
    result->Error("MISSING_ID", "windowId required");
    return;
  }

  auto* window = WindowStore::Instance().Get(*window_id);
  if (!window) {
    result->Error("NOT_FOUND", "Window not found");
    return;
  }

  window->flip_horizontal = GetBool(params, "horizontal", false);
  window->flip_vertical = GetBool(params, "vertical", false);

  result->Success(flutter::EncodableValue());
}

void TransformService::Reset(
    const std::string* window_id,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (!window_id) {
    result->Error("MISSING_ID", "windowId required");
    return;
  }

  auto* window = WindowStore::Instance().Get(*window_id);
  if (!window) {
    result->Error("NOT_FOUND", "Window not found");
    return;
  }

  window->scale_x = 1.0;
  window->scale_y = 1.0;
  window->rotation = 0.0;
  window->flip_horizontal = false;
  window->flip_vertical = false;

  result->Success(flutter::EncodableValue());
}

void TransformService::GetScale(
    const std::string* window_id,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (!window_id) {
    result->Success(flutter::EncodableValue(1.0));
    return;
  }

  auto* window = WindowStore::Instance().Get(*window_id);
  if (!window) {
    result->Success(flutter::EncodableValue(1.0));
    return;
  }

  result->Success(flutter::EncodableValue(flutter::EncodableMap{
      {flutter::EncodableValue("x"), flutter::EncodableValue(window->scale_x)},
      {flutter::EncodableValue("y"), flutter::EncodableValue(window->scale_y)},
  }));
}

void TransformService::GetRotation(
    const std::string* window_id,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (!window_id) {
    result->Success(flutter::EncodableValue(0.0));
    return;
  }

  auto* window = WindowStore::Instance().Get(*window_id);
  if (!window) {
    result->Success(flutter::EncodableValue(0.0));
    return;
  }

  result->Success(flutter::EncodableValue(window->rotation));
}

}  // namespace floating_palette
