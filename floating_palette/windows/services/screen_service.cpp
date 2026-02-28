#include "screen_service.h"

#include "../core/dpi_helper.h"
#include "../core/logger.h"
#include "../core/monitor_helper.h"
#include "../core/param_helpers.h"

namespace floating_palette {

void ScreenService::Handle(
    const std::string& command,
    const std::string* window_id,
    const flutter::EncodableMap& params,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (command == "getScreens") {
    GetScreens(std::move(result));
  } else if (command == "getCurrentScreen") {
    GetCurrentScreen(std::move(result));
  } else if (command == "getWindowScreen") {
    GetWindowScreen(window_id, std::move(result));
  } else if (command == "moveToScreen") {
    MoveToScreen(window_id, params, std::move(result));
  } else if (command == "getCursorPosition") {
    GetCursorPosition(std::move(result));
  } else if (command == "getActiveAppBounds") {
    GetActiveAppBounds(std::move(result));
  } else {
    result->Error("UNKNOWN_COMMAND", "Unknown screen command: " + command);
  }
}

void ScreenService::GetScreens(
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  auto monitors = MonitorHelper::GetAllMonitors();
  flutter::EncodableList screens;

  for (int i = 0; i < static_cast<int>(monitors.size()); i++) {
    const auto& m = monitors[i];
    double sf = m.scale_factor;
    flutter::EncodableMap frame{
        {flutter::EncodableValue("x"),
         flutter::EncodableValue(PhysicalToLogical(m.bounds.left, sf))},
        {flutter::EncodableValue("y"),
         flutter::EncodableValue(PhysicalToLogical(m.bounds.top, sf))},
        {flutter::EncodableValue("width"),
         flutter::EncodableValue(
             PhysicalToLogical(m.bounds.right - m.bounds.left, sf))},
        {flutter::EncodableValue("height"),
         flutter::EncodableValue(
             PhysicalToLogical(m.bounds.bottom - m.bounds.top, sf))},
    };
    flutter::EncodableMap visible_frame{
        {flutter::EncodableValue("x"),
         flutter::EncodableValue(PhysicalToLogical(m.work_area.left, sf))},
        {flutter::EncodableValue("y"),
         flutter::EncodableValue(PhysicalToLogical(m.work_area.top, sf))},
        {flutter::EncodableValue("width"),
         flutter::EncodableValue(
             PhysicalToLogical(m.work_area.right - m.work_area.left, sf))},
        {flutter::EncodableValue("height"),
         flutter::EncodableValue(
             PhysicalToLogical(m.work_area.bottom - m.work_area.top, sf))},
    };
    flutter::EncodableMap screen{
        {flutter::EncodableValue("id"), flutter::EncodableValue(i)},
        {flutter::EncodableValue("frame"),
         flutter::EncodableValue(frame)},
        {flutter::EncodableValue("visibleFrame"),
         flutter::EncodableValue(visible_frame)},
        {flutter::EncodableValue("scaleFactor"),
         flutter::EncodableValue(m.scale_factor)},
        {flutter::EncodableValue("isPrimary"),
         flutter::EncodableValue(m.is_primary)},
    };
    screens.push_back(flutter::EncodableValue(screen));
  }

  result->Success(flutter::EncodableValue(screens));
}

void ScreenService::GetCurrentScreen(
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (!main_hwnd_) {
    result->Success(flutter::EncodableValue(0));
    return;
  }

  HMONITOR monitor = MonitorFromWindow(main_hwnd_, MONITOR_DEFAULTTOPRIMARY);
  int index = MonitorHelper::MonitorToIndex(monitor);
  result->Success(flutter::EncodableValue(index));
}

void ScreenService::GetWindowScreen(
    const std::string* window_id,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (!window_id) {
    result->Success(flutter::EncodableValue(0));
    return;
  }

  auto* window = WindowStore::Instance().Get(*window_id);
  if (!window || !window->hwnd) {
    result->Success(flutter::EncodableValue(0));
    return;
  }

  HMONITOR monitor =
      MonitorFromWindow(window->hwnd, MONITOR_DEFAULTTOPRIMARY);
  int index = MonitorHelper::MonitorToIndex(monitor);
  result->Success(flutter::EncodableValue(index));
}

void ScreenService::MoveToScreen(
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

  int target_index = GetInt(params, "screenIndex", 0);
  MonitorInfo target;
  if (!MonitorHelper::GetMonitorByIndex(target_index, target)) {
    result->Error("INVALID_SCREEN", "Invalid screen index");
    return;
  }

  // Get current window rect
  RECT rect;
  GetWindowRect(window->hwnd, &rect);
  int w = rect.right - rect.left;
  int h = rect.bottom - rect.top;

  // Position at center of target monitor's work area
  int cx = target.work_area.left +
           (target.work_area.right - target.work_area.left - w) / 2;
  int cy = target.work_area.top +
           (target.work_area.bottom - target.work_area.top - h) / 2;

  SetWindowPos(window->hwnd, NULL, cx, cy, 0, 0,
               SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE);

  result->Success(flutter::EncodableValue());
}

void ScreenService::GetCursorPosition(
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  POINT pt;
  if (GetCursorPos(&pt)) {
    double scale = GetScaleFactorForPoint(pt);
    result->Success(flutter::EncodableValue(flutter::EncodableMap{
        {flutter::EncodableValue("x"),
         flutter::EncodableValue(PhysicalToLogical(pt.x, scale))},
        {flutter::EncodableValue("y"),
         flutter::EncodableValue(PhysicalToLogical(pt.y, scale))},
    }));
  } else {
    result->Success(flutter::EncodableValue(flutter::EncodableMap{
        {flutter::EncodableValue("x"), flutter::EncodableValue(0.0)},
        {flutter::EncodableValue("y"), flutter::EncodableValue(0.0)},
    }));
  }
}

void ScreenService::GetActiveAppBounds(
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  HWND fg = GetForegroundWindow();
  if (!fg) {
    result->Success(flutter::EncodableValue(flutter::EncodableMap{
        {flutter::EncodableValue("x"), flutter::EncodableValue(0.0)},
        {flutter::EncodableValue("y"), flutter::EncodableValue(0.0)},
        {flutter::EncodableValue("width"), flutter::EncodableValue(0.0)},
        {flutter::EncodableValue("height"), flutter::EncodableValue(0.0)},
    }));
    return;
  }

  RECT rect;
  if (!GetWindowRect(fg, &rect)) {
    result->Success(flutter::EncodableValue(flutter::EncodableMap{
        {flutter::EncodableValue("x"), flutter::EncodableValue(0.0)},
        {flutter::EncodableValue("y"), flutter::EncodableValue(0.0)},
        {flutter::EncodableValue("width"), flutter::EncodableValue(0.0)},
        {flutter::EncodableValue("height"), flutter::EncodableValue(0.0)},
    }));
    return;
  }

  double scale = GetScaleFactorForHwnd(fg);
  result->Success(flutter::EncodableValue(flutter::EncodableMap{
      {flutter::EncodableValue("x"),
       flutter::EncodableValue(PhysicalToLogical(rect.left, scale))},
      {flutter::EncodableValue("y"),
       flutter::EncodableValue(PhysicalToLogical(rect.top, scale))},
      {flutter::EncodableValue("width"),
       flutter::EncodableValue(PhysicalToLogical(rect.right - rect.left, scale))},
      {flutter::EncodableValue("height"),
       flutter::EncodableValue(
           PhysicalToLogical(rect.bottom - rect.top, scale))},
  }));
}

}  // namespace floating_palette
