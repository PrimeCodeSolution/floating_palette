#include "appearance_service.h"

#include <dwmapi.h>
#include <flutter/method_result_functions.h>

#include "../core/logger.h"
#include "../core/param_helpers.h"

// DWM constants for Win11 features (not in older SDK headers)
#ifndef DWMWA_WINDOW_CORNER_PREFERENCE
#define DWMWA_WINDOW_CORNER_PREFERENCE 33
#endif
#ifndef DWMWA_SYSTEMBACKDROP_TYPE
#define DWMWA_SYSTEMBACKDROP_TYPE 38
#endif

// DWM_WINDOW_CORNER_PREFERENCE values
#define DWMWCP_DEFAULT 0
#define DWMWCP_DONOTROUND 1
#define DWMWCP_ROUND 2
#define DWMWCP_ROUNDSMALL 3

// DWM_SYSTEMBACKDROP_TYPE values
#define DWMSBT_AUTO 0
#define DWMSBT_NONE 1
#define DWMSBT_MAINWINDOW 2   // Mica
#define DWMSBT_TRANSIENTWINDOW 3  // Acrylic
#define DWMSBT_TABBEDWINDOW 4  // Mica Alt

namespace floating_palette {

void AppearanceService::Handle(
    const std::string& command,
    const std::string* window_id,
    const flutter::EncodableMap& params,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (command == "setCornerRadius") {
    SetCornerRadius(window_id, params, std::move(result));
  } else if (command == "setShadow") {
    SetShadow(window_id, params, std::move(result));
  } else if (command == "setBackgroundColor") {
    SetBackgroundColor(window_id, params, std::move(result));
  } else if (command == "setTransparent") {
    SetTransparent(window_id, params, std::move(result));
  } else if (command == "setBlur") {
    SetBlur(window_id, params, std::move(result));
  } else if (command == "applyAppearance") {
    ApplyAppearance(window_id, params, std::move(result));
  } else {
    result->Error("UNKNOWN_COMMAND",
                  "Unknown appearance command: " + command);
  }
}

void AppearanceService::SetCornerRadius(
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

  double radius = GetDouble(params, "radius", 0);
  window->corner_radius = radius;

  // Try Win11 DWM API first
  int corner_pref = (radius > 0) ? DWMWCP_ROUND : DWMWCP_DONOTROUND;
  HRESULT hr = DwmSetWindowAttribute(window->hwnd,
                                      DWMWA_WINDOW_CORNER_PREFERENCE,
                                      &corner_pref, sizeof(corner_pref));

  if (FAILED(hr) && radius > 0) {
    // Fallback for Win10: use SetWindowRgn with rounded rect
    RECT rect;
    GetWindowRect(window->hwnd, &rect);
    int w = rect.right - rect.left;
    int h = rect.bottom - rect.top;
    int r = static_cast<int>(radius * 2);
    HRGN rgn = CreateRoundRectRgn(0, 0, w + 1, h + 1, r, r);
    SetWindowRgn(window->hwnd, rgn, TRUE);
    // Note: SetWindowRgn takes ownership of the region handle
  }

  result->Success(flutter::EncodableValue());
}

void AppearanceService::SetShadow(
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

  bool enabled = GetBool(params, "enabled", true);
  window->has_shadow = enabled;

  if (enabled) {
    // Extend frame slightly to enable DWM shadow
    MARGINS margins = {0, 0, 0, 1};
    DwmExtendFrameIntoClientArea(window->hwnd, &margins);
  } else {
    MARGINS margins = {0, 0, 0, 0};
    DwmExtendFrameIntoClientArea(window->hwnd, &margins);
  }

  result->Success(flutter::EncodableValue());
}

void AppearanceService::SetBackgroundColor(
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

  // Store for reference; actual rendering handled by Flutter
  window->background_color = GetInt(params, "color", 0);

  result->Success(flutter::EncodableValue());
}

void AppearanceService::SetTransparent(
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

  bool transparent = GetBool(params, "transparent", true);
  window->is_transparent = transparent;

  LONG_PTR ex = GetWindowLongPtr(window->hwnd, GWL_EXSTYLE);
  if (transparent) {
    SetWindowLongPtr(window->hwnd, GWL_EXSTYLE, ex | WS_EX_LAYERED);
  } else {
    SetWindowLongPtr(window->hwnd, GWL_EXSTYLE, ex & ~WS_EX_LAYERED);
  }

  result->Success(flutter::EncodableValue());
}

void AppearanceService::SetBlur(
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

  std::string type = GetString(params, "type", "none");
  window->blur_type = type;

  if (type == "none") {
    int backdrop = DWMSBT_NONE;
    DwmSetWindowAttribute(window->hwnd, DWMWA_SYSTEMBACKDROP_TYPE,
                          &backdrop, sizeof(backdrop));
  } else if (type == "acrylic") {
    int backdrop = DWMSBT_TRANSIENTWINDOW;
    HRESULT hr = DwmSetWindowAttribute(window->hwnd,
                                        DWMWA_SYSTEMBACKDROP_TYPE,
                                        &backdrop, sizeof(backdrop));
    if (FAILED(hr)) {
      // Win10 fallback: use undocumented SetWindowCompositionAttribute
      // This requires runtime linking and is best-effort
      FP_LOG("Appearance", "Acrylic blur not supported on this Windows version");
    }
  } else if (type == "mica") {
    int backdrop = DWMSBT_MAINWINDOW;
    DwmSetWindowAttribute(window->hwnd, DWMWA_SYSTEMBACKDROP_TYPE,
                          &backdrop, sizeof(backdrop));
  } else if (type == "micaAlt") {
    int backdrop = DWMSBT_TABBEDWINDOW;
    DwmSetWindowAttribute(window->hwnd, DWMWA_SYSTEMBACKDROP_TYPE,
                          &backdrop, sizeof(backdrop));
  }

  result->Success(flutter::EncodableValue());
}

void AppearanceService::ApplyAppearance(
    const std::string* window_id,
    const flutter::EncodableMap& params,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (!window_id) {
    result->Error("MISSING_ID", "windowId required");
    return;
  }

  // Helper to create a no-op result for sub-calls
  auto noop = []() {
    return std::make_unique<flutter::MethodResultFunctions<flutter::EncodableValue>>(
        nullptr, nullptr, nullptr);
  };

  // Apply all appearance properties in bulk
  auto corner_it = params.find(flutter::EncodableValue("cornerRadius"));
  if (corner_it != params.end()) {
    flutter::EncodableMap cr_params{
        {flutter::EncodableValue("radius"), corner_it->second}};
    SetCornerRadius(window_id, cr_params, noop());
  }

  auto shadow_it = params.find(flutter::EncodableValue("shadow"));
  if (shadow_it != params.end()) {
    flutter::EncodableMap s_params{
        {flutter::EncodableValue("enabled"), shadow_it->second}};
    SetShadow(window_id, s_params, noop());
  }

  auto bg_it = params.find(flutter::EncodableValue("backgroundColor"));
  if (bg_it != params.end()) {
    flutter::EncodableMap bg_params{
        {flutter::EncodableValue("color"), bg_it->second}};
    SetBackgroundColor(window_id, bg_params, noop());
  }

  auto trans_it = params.find(flutter::EncodableValue("transparent"));
  if (trans_it != params.end()) {
    flutter::EncodableMap t_params{
        {flutter::EncodableValue("transparent"), trans_it->second}};
    SetTransparent(window_id, t_params, noop());
  }

  auto blur_it = params.find(flutter::EncodableValue("blur"));
  if (blur_it != params.end()) {
    flutter::EncodableMap b_params{
        {flutter::EncodableValue("type"), blur_it->second}};
    SetBlur(window_id, b_params, noop());
  }

  result->Success(flutter::EncodableValue());
}

}  // namespace floating_palette
