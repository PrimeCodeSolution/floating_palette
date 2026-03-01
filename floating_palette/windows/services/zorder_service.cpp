#include "zorder_service.h"

#include "../core/logger.h"
#include "../core/param_helpers.h"

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
  if (!window_id) {
    result->Error("MISSING_ID", "windowId required");
    return;
  }

  auto* window = WindowStore::Instance().Get(*window_id);
  if (!window || !window->hwnd) {
    result->Error("NOT_FOUND", "Window not found");
    return;
  }

  SetWindowPos(window->hwnd, HWND_TOP, 0, 0, 0, 0,
               SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE);

  result->Success(flutter::EncodableValue());
}

void ZOrderService::SendToBack(
    const std::string* window_id,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (!window_id) {
    result->Error("MISSING_ID", "windowId required");
    return;
  }

  auto* window = WindowStore::Instance().Get(*window_id);
  if (!window || !window->hwnd) {
    result->Error("NOT_FOUND", "Window not found");
    return;
  }

  SetWindowPos(window->hwnd, HWND_BOTTOM, 0, 0, 0, 0,
               SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE);

  result->Success(flutter::EncodableValue());
}

void ZOrderService::MoveAbove(
    const std::string* window_id,
    const flutter::EncodableMap& params,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (!window_id) {
    result->Error("MISSING_ID", "windowId required");
    return;
  }

  auto* window = WindowStore::Instance().Get(*window_id);
  if (!window || !window->hwnd) {
    result->Error("NOT_FOUND", "Window not found");
    return;
  }

  std::string target_id = GetString(params, "targetId", "");
  auto* target = WindowStore::Instance().Get(target_id);
  if (!target || !target->hwnd) {
    result->Error("TARGET_NOT_FOUND", "Target window not found");
    return;
  }

  // Insert after target (which places us above it in z-order)
  SetWindowPos(window->hwnd, target->hwnd, 0, 0, 0, 0,
               SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE);

  result->Success(flutter::EncodableValue());
}

void ZOrderService::MoveBelow(
    const std::string* window_id,
    const flutter::EncodableMap& params,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (!window_id) {
    result->Error("MISSING_ID", "windowId required");
    return;
  }

  auto* window = WindowStore::Instance().Get(*window_id);
  if (!window || !window->hwnd) {
    result->Error("NOT_FOUND", "Window not found");
    return;
  }

  std::string target_id = GetString(params, "targetId", "");
  auto* target = WindowStore::Instance().Get(target_id);
  if (!target || !target->hwnd) {
    result->Error("TARGET_NOT_FOUND", "Target window not found");
    return;
  }

  // Insert after the window below target
  HWND insert_after = GetWindow(target->hwnd, GW_HWNDNEXT);
  if (!insert_after) insert_after = HWND_BOTTOM;

  SetWindowPos(window->hwnd, insert_after, 0, 0, 0, 0,
               SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE);

  result->Success(flutter::EncodableValue());
}

void ZOrderService::SetZIndex(
    const std::string* window_id,
    const flutter::EncodableMap& params,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  // On Windows, z-index is relative; treat as bring-to-front
  BringToFront(window_id, std::move(result));
}

void ZOrderService::SetLevel(
    const std::string* window_id,
    const flutter::EncodableMap& params,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (!window_id) {
    result->Error("MISSING_ID", "windowId required");
    return;
  }

  auto* window = WindowStore::Instance().Get(*window_id);
  if (!window || !window->hwnd) {
    result->Error("NOT_FOUND", "Window not found");
    return;
  }

  std::string level = GetString(params, "level", "floating");
  window->level = level;

  HWND insert_after =
      (level == "floating") ? HWND_TOPMOST : HWND_NOTOPMOST;

  SetWindowPos(window->hwnd, insert_after, 0, 0, 0, 0,
               SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE);

  result->Success(flutter::EncodableValue());
}

void ZOrderService::Pin(
    const std::string* window_id,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (!window_id) {
    result->Error("MISSING_ID", "windowId required");
    return;
  }

  auto* window = WindowStore::Instance().Get(*window_id);
  if (!window || !window->hwnd) {
    result->Error("NOT_FOUND", "Window not found");
    return;
  }

  window->is_pinned = true;
  SetWindowPos(window->hwnd, HWND_TOPMOST, 0, 0, 0, 0,
               SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE);

  if (event_sink_) {
    flutter::EncodableMap data;
    event_sink_("zorder", "pinned", window_id, data);
  }

  result->Success(flutter::EncodableValue());
}

void ZOrderService::Unpin(
    const std::string* window_id,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (!window_id) {
    result->Error("MISSING_ID", "windowId required");
    return;
  }

  auto* window = WindowStore::Instance().Get(*window_id);
  if (!window || !window->hwnd) {
    result->Error("NOT_FOUND", "Window not found");
    return;
  }

  window->is_pinned = false;
  SetWindowPos(window->hwnd, HWND_NOTOPMOST, 0, 0, 0, 0,
               SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE);

  if (event_sink_) {
    flutter::EncodableMap data;
    event_sink_("zorder", "unpinned", window_id, data);
  }

  result->Success(flutter::EncodableValue());
}

}  // namespace floating_palette
