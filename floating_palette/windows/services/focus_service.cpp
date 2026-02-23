#include "focus_service.h"

#include "../core/logger.h"
#include "../core/param_helpers.h"

namespace floating_palette {

void FocusService::Handle(
    const std::string& command,
    const std::string* window_id,
    const flutter::EncodableMap& params,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (command == "focus") {
    Focus(window_id, std::move(result));
  } else if (command == "unfocus") {
    Unfocus(window_id, std::move(result));
  } else if (command == "setPolicy") {
    SetPolicy(window_id, params, std::move(result));
  } else if (command == "isFocused") {
    IsFocused(window_id, std::move(result));
  } else if (command == "focusMainWindow") {
    FocusMainWindow(std::move(result));
  } else if (command == "hideApp") {
    HideApp(std::move(result));
  } else {
    result->Error("UNKNOWN_COMMAND", "Unknown focus command: " + command);
  }
}

void FocusService::Focus(
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

  // Remove WS_EX_NOACTIVATE to allow focus
  LONG_PTR ex = GetWindowLongPtr(window->hwnd, GWL_EXSTYLE);
  SetWindowLongPtr(window->hwnd, GWL_EXSTYLE, ex & ~WS_EX_NOACTIVATE);

  SetForegroundWindow(window->hwnd);
  SetFocus(window->hwnd);

  if (event_sink_) {
    flutter::EncodableMap data;
    event_sink_("focus", "focused", window_id, data);
  }

  result->Success(flutter::EncodableValue());
}

void FocusService::Unfocus(
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

  // Re-add WS_EX_NOACTIVATE
  LONG_PTR ex = GetWindowLongPtr(window->hwnd, GWL_EXSTYLE);
  SetWindowLongPtr(window->hwnd, GWL_EXSTYLE, ex | WS_EX_NOACTIVATE);

  // Return focus to main window
  if (main_hwnd_) {
    SetForegroundWindow(main_hwnd_);
  }

  if (event_sink_) {
    flutter::EncodableMap data;
    event_sink_("focus", "unfocused", window_id, data);
  }

  result->Success(flutter::EncodableValue());
}

void FocusService::SetPolicy(
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

  std::string policy = GetString(params, "policy", "onClick");
  window->focus_policy = policy;

  LONG_PTR ex = GetWindowLongPtr(window->hwnd, GWL_EXSTYLE);
  if (policy == "never") {
    SetWindowLongPtr(window->hwnd, GWL_EXSTYLE, ex | WS_EX_NOACTIVATE);
  } else if (policy == "always") {
    SetWindowLongPtr(window->hwnd, GWL_EXSTYLE, ex & ~WS_EX_NOACTIVATE);
  }
  // "onClick" - handled by WM_MOUSEACTIVATE in WndProc

  result->Success(flutter::EncodableValue());
}

void FocusService::IsFocused(
    const std::string* window_id,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (!window_id) {
    result->Success(flutter::EncodableValue(false));
    return;
  }

  auto* window = WindowStore::Instance().Get(*window_id);
  if (!window || !window->hwnd) {
    result->Success(flutter::EncodableValue(false));
    return;
  }

  HWND fg = GetForegroundWindow();
  bool focused = (fg == window->hwnd);
  result->Success(flutter::EncodableValue(focused));
}

void FocusService::FocusMainWindow(
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (main_hwnd_) {
    SetForegroundWindow(main_hwnd_);
    SetFocus(main_hwnd_);
  }
  result->Success(flutter::EncodableValue());
}

void FocusService::HideApp(
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (main_hwnd_) {
    ShowWindow(main_hwnd_, SW_MINIMIZE);
  }
  result->Success(flutter::EncodableValue());
}

}  // namespace floating_palette
