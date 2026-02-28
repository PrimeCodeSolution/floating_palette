#include "visibility_service.h"

#include "../core/logger.h"
#include "../core/param_helpers.h"
#include "snap_service.h"

namespace floating_palette {

// Global for FFI access
VisibilityService* g_visibility_service = nullptr;

void VisibilityService_Reveal(const std::string& window_id) {
  if (g_visibility_service) {
    g_visibility_service->Reveal(window_id);
  }
}

// Timer callback for safety reveal timeout
static void CALLBACK RevealTimerProc(HWND, UINT, UINT_PTR timer_id,
                                     DWORD) {
  FP_LOG("Visibility", "RevealTimerProc fired timer_id=" + std::to_string(timer_id));
  // Find the window associated with this timer
  auto all = WindowStore::Instance().All();
  for (auto& [id, window] : all) {
    if (window->reveal_timer_id == timer_id) {
      KillTimer(NULL, timer_id);
      window->reveal_timer_id = 0;
      FP_LOG("Visibility", "RevealTimerProc matched [" + id + "] pending=" +
                                (window->is_pending_reveal ? "yes" : "no"));
      if (window->is_pending_reveal) {
        VisibilityService_Reveal(id);
      }
      break;
    }
  }
}

VisibilityService::VisibilityService() {
  g_visibility_service = this;
}

VisibilityService::~VisibilityService() {
  if (g_visibility_service == this) {
    g_visibility_service = nullptr;
  }
}

void VisibilityService::Handle(
    const std::string& command,
    const std::string* window_id,
    const flutter::EncodableMap& params,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (command == "show") {
    Show(window_id, params, std::move(result));
  } else if (command == "hide") {
    Hide(window_id, params, std::move(result));
  } else if (command == "setOpacity") {
    SetOpacity(window_id, params, std::move(result));
  } else if (command == "getOpacity") {
    GetOpacity(window_id, std::move(result));
  } else if (command == "reveal") {
    DoReveal(window_id, std::move(result));
  } else {
    result->Error("UNKNOWN_COMMAND",
                  "Unknown visibility command: " + command);
  }
}

void VisibilityService::Reveal(const std::string& window_id) {
  FP_LOG("Visibility", "Reveal start: " + window_id);
  auto* window = WindowStore::Instance().Get(window_id);
  if (!window || !window->hwnd) {
    FP_LOG("Visibility", "Reveal ABORT (not found): " + window_id);
    return;
  }
  if (!window->is_pending_reveal) {
    FP_LOG("Visibility", "Reveal SKIP (not pending): " + window_id);
    return;
  }

  window->is_pending_reveal = false;

  // Cancel safety timer
  if (window->reveal_timer_id != 0) {
    KillTimer(NULL, window->reveal_timer_id);
    window->reveal_timer_id = 0;
  }

  // Set opacity to the configured level
  BYTE alpha = static_cast<BYTE>(window->opacity * 255.0);
  FP_LOG("Visibility", "Reveal alpha=" + std::to_string(alpha) + ": " + window_id);
  SetLayeredWindowAttributes(window->hwnd, RGB(1, 0, 1), alpha, LWA_COLORKEY | LWA_ALPHA);

  // Handle focus if needed
  if (window->should_focus && window->focus_policy != "never") {
    LONG_PTR ex = GetWindowLongPtr(window->hwnd, GWL_EXSTYLE);
    SetWindowLongPtr(window->hwnd, GWL_EXSTYLE, ex & ~WS_EX_NOACTIVATE);
    SetForegroundWindow(window->hwnd);
    SetFocus(window->hwnd);
  }

  // Notify snap service
  if (snap_service_) {
    snap_service_->OnWindowShown(window_id);
  }

  // Emit "shown" event
  if (event_sink_) {
    flutter::EncodableMap data;
    event_sink_("visibility", "shown", &window_id, data);
  }

  FP_LOG("Visibility", "revealed: " + window_id);
}

void VisibilityService::Show(
    const std::string* window_id,
    const flutter::EncodableMap& params,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (!window_id) {
    result->Error("MISSING_ID", "windowId required");
    return;
  }

  auto* window = WindowStore::Instance().Get(*window_id);
  if (!window || !window->hwnd) {
    FP_LOG("Visibility", "Show NOT_FOUND: " + *window_id);
    result->Error("NOT_FOUND", "Window not found: " + *window_id);
    return;
  }

  FP_LOG("Visibility", "Show window found: " + *window_id +
                            " hwnd=0x" + std::to_string(reinterpret_cast<uintptr_t>(window->hwnd)) +
                            " engine=" + (window->engine ? "yes" : "NO") +
                            " entry_channel=" + (window->entry_channel ? "yes" : "NO"));

  // Parse show parameters
  window->should_focus = GetBool(params, "focus", true);

  // Set pending reveal (wait for Dart SizeReporter to call ResizeWindow)
  window->is_pending_reveal = true;

  // Make window fully transparent initially
  SetLayeredWindowAttributes(window->hwnd, RGB(1, 0, 1), 0, LWA_COLORKEY | LWA_ALPHA);

  // Show the window (but it's transparent, so invisible)
  ShowWindow(window->hwnd, SW_SHOWNOACTIVATE);

  // Invoke forceResize on the palette's entry channel to trigger SizeReporter
  if (window->entry_channel) {
    FP_LOG("Visibility", "Show invoking forceResize: " + *window_id);
    window->entry_channel->InvokeMethod(
        "forceResize",
        std::make_unique<flutter::EncodableValue>(flutter::EncodableValue()));
  } else {
    FP_LOG("Visibility", "Show NO entry_channel, skipping forceResize: " + *window_id);
  }

  // Start safety timer (100ms) in case SizeReporter doesn't fire
  window->reveal_timer_id = SetTimer(NULL, 0, 100, RevealTimerProc);
  FP_LOG("Visibility", "Show safety timer started, pending reveal: " + *window_id);
  result->Success(flutter::EncodableValue());
}

void VisibilityService::Hide(
    const std::string* window_id,
    const flutter::EncodableMap& params,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (!window_id) {
    result->Error("MISSING_ID", "windowId required");
    return;
  }

  FP_LOG("Visibility", "Hide start: " + *window_id);

  auto* window = WindowStore::Instance().Get(*window_id);
  if (!window || !window->hwnd) {
    FP_LOG("Visibility", "Hide NOT_FOUND: " + *window_id);
    result->Error("NOT_FOUND", "Window not found: " + *window_id);
    return;
  }

  // Cancel pending reveal
  window->is_pending_reveal = false;
  if (window->reveal_timer_id != 0) {
    KillTimer(NULL, window->reveal_timer_id);
    window->reveal_timer_id = 0;
  }

  ShowWindow(window->hwnd, SW_HIDE);

  // Re-add WS_EX_NOACTIVATE for next show
  LONG_PTR ex = GetWindowLongPtr(window->hwnd, GWL_EXSTYLE);
  SetWindowLongPtr(window->hwnd, GWL_EXSTYLE, ex | WS_EX_NOACTIVATE);

  // Notify snap service
  if (snap_service_) {
    snap_service_->OnWindowHidden(*window_id);
  }

  // Emit "hidden" event
  if (event_sink_) {
    flutter::EncodableMap data;
    event_sink_("visibility", "hidden", window_id, data);
  }

  FP_LOG("Visibility", "hidden: " + *window_id);
  result->Success(flutter::EncodableValue());
}

void VisibilityService::SetOpacity(
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

  double opacity = GetDouble(params, "opacity", 1.0);
  if (opacity < 0.0) opacity = 0.0;
  if (opacity > 1.0) opacity = 1.0;
  window->opacity = opacity;

  BYTE alpha = static_cast<BYTE>(opacity * 255.0);
  SetLayeredWindowAttributes(window->hwnd, RGB(1, 0, 1), alpha, LWA_COLORKEY | LWA_ALPHA);

  result->Success(flutter::EncodableValue());
}

void VisibilityService::GetOpacity(
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

  result->Success(flutter::EncodableValue(window->opacity));
}

void VisibilityService::DoReveal(
    const std::string* window_id,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (window_id) {
    Reveal(*window_id);
  }
  result->Success(flutter::EncodableValue());
}

}  // namespace floating_palette
