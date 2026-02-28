#include "frame_service.h"

#include "../coordinators/drag_coordinator.h"
#include "../core/logger.h"
#include "../core/param_helpers.h"
#include "snap_service.h"

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
  if (!window_id) {
    result->Error("MISSING_ID", "windowId required");
    return;
  }

  auto* window = WindowStore::Instance().Get(*window_id);
  if (!window || !window->hwnd) {
    result->Error("NOT_FOUND", "Window not found");
    return;
  }

  double x = GetDouble(params, "x", 0);
  double y = GetDouble(params, "y", 0);
  std::string anchor = GetString(params, "anchor", "topLeft");

  FP_LOG("Frame", "SetPosition [" + *window_id + "] x=" +
                       std::to_string(static_cast<int>(x)) + " y=" +
                       std::to_string(static_cast<int>(y)) +
                       " anchor=" + anchor);

  // Get current window size for anchor calculation
  RECT rect;
  GetWindowRect(window->hwnd, &rect);
  int w = rect.right - rect.left;
  int h = rect.bottom - rect.top;

  int ix = static_cast<int>(x);
  int iy = static_cast<int>(y);

  // Adjust for anchor point
  if (anchor == "center") {
    ix -= w / 2;
    iy -= h / 2;
  } else if (anchor == "topCenter") {
    ix -= w / 2;
  } else if (anchor == "bottomLeft") {
    iy -= h;
  } else if (anchor == "bottomCenter") {
    ix -= w / 2;
    iy -= h;
  } else if (anchor == "bottomRight") {
    ix -= w;
    iy -= h;
  } else if (anchor == "topRight") {
    ix -= w;
  } else if (anchor == "centerLeft") {
    iy -= h / 2;
  } else if (anchor == "centerRight") {
    ix -= w;
    iy -= h / 2;
  }
  // "topLeft" is default, no adjustment needed

  SetWindowPos(window->hwnd, NULL, ix, iy, 0, 0,
               SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE);

  // Notify snap service of position change — reposition followers
  if (snap_service_) {
    snap_service_->OnWindowMoved(*window_id);
  }

  result->Success(flutter::EncodableValue());
}

void FrameService::SetSize(
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

  double w = GetDouble(params, "width", window->width);
  double h = GetDouble(params, "height", window->height);
  int iw = static_cast<int>(w);
  int ih = static_cast<int>(h);

  FP_LOG("Frame", "SetSize [" + *window_id + "] " +
                       std::to_string(iw) + "x" + std::to_string(ih));

  SetWindowPos(window->hwnd, NULL, 0, 0, iw, ih,
               SWP_NOMOVE | SWP_NOZORDER | SWP_NOACTIVATE);

  // Resize Flutter child
  HWND child = GetWindow(window->hwnd, GW_CHILD);
  if (child) {
    SetWindowPos(child, NULL, 0, 0, iw, ih,
                 SWP_NOMOVE | SWP_NOZORDER | SWP_NOACTIVATE);
  }

  window->width = w;
  window->height = h;

  result->Success(flutter::EncodableValue());
}

void FrameService::SetBounds(
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

  double x = GetDouble(params, "x", 0);
  double y = GetDouble(params, "y", 0);
  double w = GetDouble(params, "width", window->width);
  double h = GetDouble(params, "height", window->height);
  int ix = static_cast<int>(x);
  int iy = static_cast<int>(y);
  int iw = static_cast<int>(w);
  int ih = static_cast<int>(h);

  SetWindowPos(window->hwnd, NULL, ix, iy, iw, ih,
               SWP_NOZORDER | SWP_NOACTIVATE);

  // Resize Flutter child
  HWND child = GetWindow(window->hwnd, GW_CHILD);
  if (child) {
    SetWindowPos(child, NULL, 0, 0, iw, ih,
                 SWP_NOMOVE | SWP_NOZORDER | SWP_NOACTIVATE);
  }

  window->width = w;
  window->height = h;

  result->Success(flutter::EncodableValue());
}

void FrameService::GetPosition(
    const std::string* window_id,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (!window_id) {
    result->Success(flutter::EncodableValue(flutter::EncodableMap{
        {flutter::EncodableValue("x"), flutter::EncodableValue(0.0)},
        {flutter::EncodableValue("y"), flutter::EncodableValue(0.0)},
    }));
    return;
  }

  auto* window = WindowStore::Instance().Get(*window_id);
  if (!window || !window->hwnd) {
    result->Success(flutter::EncodableValue(flutter::EncodableMap{
        {flutter::EncodableValue("x"), flutter::EncodableValue(0.0)},
        {flutter::EncodableValue("y"), flutter::EncodableValue(0.0)},
    }));
    return;
  }

  RECT rect;
  GetWindowRect(window->hwnd, &rect);
  result->Success(flutter::EncodableValue(flutter::EncodableMap{
      {flutter::EncodableValue("x"),
       flutter::EncodableValue(static_cast<double>(rect.left))},
      {flutter::EncodableValue("y"),
       flutter::EncodableValue(static_cast<double>(rect.top))},
  }));
}

void FrameService::GetSize(
    const std::string* window_id,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (!window_id) {
    result->Success(flutter::EncodableValue(flutter::EncodableMap{
        {flutter::EncodableValue("width"), flutter::EncodableValue(0.0)},
        {flutter::EncodableValue("height"), flutter::EncodableValue(0.0)},
    }));
    return;
  }

  auto* window = WindowStore::Instance().Get(*window_id);
  if (!window || !window->hwnd) {
    result->Success(flutter::EncodableValue(flutter::EncodableMap{
        {flutter::EncodableValue("width"), flutter::EncodableValue(0.0)},
        {flutter::EncodableValue("height"), flutter::EncodableValue(0.0)},
    }));
    return;
  }

  RECT rect;
  GetWindowRect(window->hwnd, &rect);
  result->Success(flutter::EncodableValue(flutter::EncodableMap{
      {flutter::EncodableValue("width"),
       flutter::EncodableValue(static_cast<double>(rect.right - rect.left))},
      {flutter::EncodableValue("height"),
       flutter::EncodableValue(static_cast<double>(rect.bottom - rect.top))},
  }));
}

void FrameService::GetBounds(
    const std::string* window_id,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (!window_id) {
    result->Success(flutter::EncodableValue(flutter::EncodableMap{
        {flutter::EncodableValue("x"), flutter::EncodableValue(0.0)},
        {flutter::EncodableValue("y"), flutter::EncodableValue(0.0)},
        {flutter::EncodableValue("width"), flutter::EncodableValue(0.0)},
        {flutter::EncodableValue("height"), flutter::EncodableValue(0.0)},
    }));
    return;
  }

  auto* window = WindowStore::Instance().Get(*window_id);
  if (!window || !window->hwnd) {
    result->Success(flutter::EncodableValue(flutter::EncodableMap{
        {flutter::EncodableValue("x"), flutter::EncodableValue(0.0)},
        {flutter::EncodableValue("y"), flutter::EncodableValue(0.0)},
        {flutter::EncodableValue("width"), flutter::EncodableValue(0.0)},
        {flutter::EncodableValue("height"), flutter::EncodableValue(0.0)},
    }));
    return;
  }

  RECT rect;
  GetWindowRect(window->hwnd, &rect);
  result->Success(flutter::EncodableValue(flutter::EncodableMap{
      {flutter::EncodableValue("x"),
       flutter::EncodableValue(static_cast<double>(rect.left))},
      {flutter::EncodableValue("y"),
       flutter::EncodableValue(static_cast<double>(rect.top))},
      {flutter::EncodableValue("width"),
       flutter::EncodableValue(static_cast<double>(rect.right - rect.left))},
      {flutter::EncodableValue("height"),
       flutter::EncodableValue(static_cast<double>(rect.bottom - rect.top))},
  }));
}

void FrameService::StartDrag(
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

  if (!window->draggable) {
    result->Success(flutter::EncodableValue());
    return;
  }

  if (drag_coordinator_) {
    drag_coordinator_->StartDrag(*window_id, window);
  }

  result->Success(flutter::EncodableValue());
}

void FrameService::SetDraggable(
    const std::string* window_id,
    const flutter::EncodableMap& params,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (!window_id) {
    result->Error("MISSING_ID", "windowId required");
    return;
  }

  auto* window = WindowStore::Instance().Get(*window_id);
  if (window) {
    window->draggable = GetBool(params, "draggable", true);
  }

  result->Success(flutter::EncodableValue());
}

}  // namespace floating_palette
