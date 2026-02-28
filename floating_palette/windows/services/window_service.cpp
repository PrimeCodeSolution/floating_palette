#include "window_service.h"

#include <flutter_windows.h>

#include "../core/dpi_helper.h"
#include "../core/logger.h"
#include "../core/param_helpers.h"
#include "input_service.h"
#include "snap_service.h"
#include "visibility_service.h"
#include "window_channel_router.h"

// Custom messages shared with ffi_interface.cpp
#define WM_FP_DEFERRED_RESIZE (WM_USER + 200)
#define WM_FP_DEFERRED_REVEAL (WM_USER + 201)

// Timer ID for deferred engine creation (uses WM_TIMER, lowest priority)
#define TIMER_ENGINE_SETUP 1

namespace floating_palette {

// Apply rounded-corner window region to clip black corners.
// w, h are physical pixel dimensions; corner_radius is in logical pixels.
static void ApplyWindowRegion(HWND hwnd, int w, int h, double corner_radius, double scale) {
  if (corner_radius > 0) {
    int r = LogicalToPhysical(corner_radius * 2.0, scale);
    HRGN rgn = CreateRoundRectRgn(0, 0, w + 1, h + 1, r, r);
    SetWindowRgn(hwnd, rgn, TRUE);  // OS takes ownership of rgn
  } else {
    SetWindowRgn(hwnd, NULL, TRUE);  // Remove region (rectangular)
  }
}

// Forward declaration for deferred reveal
extern VisibilityService* g_visibility_service;
void VisibilityService_Reveal(const std::string& window_id);

bool WindowService::wndclass_registered_ = false;
WindowService* WindowService::instance_ = nullptr;

WindowService::WindowService(flutter::PluginRegistrarWindows* registrar)
    : registrar_(registrar) {
  instance_ = this;
}

void WindowService::EnsureWndClassRegistered() {
  if (wndclass_registered_) return;

  WNDCLASSEXW wc = {};
  wc.cbSize = sizeof(WNDCLASSEXW);
  wc.style = CS_HREDRAW | CS_VREDRAW;
  wc.lpfnWndProc = PaletteWndProc;
  wc.hInstance = GetModuleHandle(nullptr);
  wc.hCursor = LoadCursor(nullptr, IDC_ARROW);
  wc.hbrBackground = nullptr;  // No background brush (transparent)
  wc.lpszClassName = L"FLOATING_PALETTE_WND";
  RegisterClassExW(&wc);

  wndclass_registered_ = true;
}

LRESULT CALLBACK WindowService::PaletteWndProc(HWND hwnd, UINT msg,
                                                WPARAM wparam,
                                                LPARAM lparam) {
  switch (msg) {
    case WM_SIZE: {
      // Resize Flutter child HWND to match palette window
      HWND child = GetWindow(hwnd, GW_CHILD);
      if (child) {
        RECT rect;
        GetClientRect(hwnd, &rect);
        SetWindowPos(child, NULL, 0, 0, rect.right - rect.left,
                     rect.bottom - rect.top,
                     SWP_NOMOVE | SWP_NOZORDER | SWP_NOACTIVATE);
      }
      // Reapply rounded-corner region after resize
      auto* pw = WindowStore::Instance().FindByHwnd(hwnd);
      if (pw && pw->corner_radius > 0) {
        RECT wr;
        GetWindowRect(hwnd, &wr);
        int rw = wr.right - wr.left;
        int rh = wr.bottom - wr.top;
        double scale = GetScaleFactorForHwnd(hwnd);
        ApplyWindowRegion(hwnd, rw, rh, pw->corner_radius, scale);
      }
      return 0;
    }

    case WM_MOUSEACTIVATE: {
      // Check if WS_EX_NOACTIVATE is set - if so, prevent activation
      LONG_PTR ex_style = GetWindowLongPtr(hwnd, GWL_EXSTYLE);
      if (ex_style & WS_EX_NOACTIVATE) {
        return MA_NOACTIVATE;
      }
      break;
    }

    case WM_CLOSE: {
      // Hide instead of destroy - Dart controls lifecycle
      ShowWindow(hwnd, SW_HIDE);
      return 0;
    }

    case WM_ERASEBKGND: {
      // Return 1 for transparent background
      return 1;
    }

    case WM_NCHITTEST: {
      // Allow the default hit-testing
      LRESULT hit = DefWindowProc(hwnd, msg, wparam, lparam);
      if (hit == HTCLIENT) return HTCLIENT;
      return hit;
    }

    case WM_FP_DEFERRED_RESIZE: {
      // Deferred resize from FFI ResizeWindow (avoids re-entrant layout)
      int w = static_cast<int>(wparam);
      int h = static_cast<int>(lparam);
      {
        auto* pw = WindowStore::Instance().FindByHwnd(hwnd);
        FP_LOG("WndProc", "WM_FP_DEFERRED_RESIZE " +
                               std::to_string(w) + "x" + std::to_string(h) +
                               (pw ? " [" + pw->id + "]" : " [?]"));
      }
      SetWindowPos(hwnd, NULL, 0, 0, w, h,
                   SWP_NOMOVE | SWP_NOZORDER | SWP_NOACTIVATE);
      // WM_SIZE handler will resize the Flutter child
      return 0;
    }

    case WM_FP_DEFERRED_REVEAL: {
      // Deferred reveal from FFI ResizeWindow
      auto* pw = WindowStore::Instance().FindByHwnd(hwnd);
      FP_LOG("WndProc", "WM_FP_DEFERRED_REVEAL" +
                             (pw ? " [" + pw->id + "]" : " [?]"));
      if (pw) {
        VisibilityService_Reveal(pw->id);
      }
      return 0;
    }

    case WM_TIMER: {
      if (wparam == TIMER_ENGINE_SETUP) {
        KillTimer(hwnd, TIMER_ENGINE_SETUP);
        // Deferred engine creation (lowest-priority message ensures all
        // pending method calls are processed before we block the pump)
        auto* pw = WindowStore::Instance().FindByHwnd(hwnd);
        FP_LOG("WndProc", "WM_TIMER ENGINE_SETUP" +
                               (pw ? " [" + pw->id + "]" : " [?]"));
        if (pw && instance_) {
          instance_->SetupEngine(pw->id);
        }
        return 0;
      }
      break;
    }
  }

  return DefWindowProc(hwnd, msg, wparam, lparam);
}

void WindowService::Handle(
    const std::string& command,
    const std::string* window_id,
    const flutter::EncodableMap& params,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (command == "create") {
    Create(window_id, params, std::move(result));
  } else if (command == "destroy") {
    Destroy(window_id, params, std::move(result));
  } else if (command == "exists") {
    Exists(window_id, std::move(result));
  } else if (command == "setEntryPoint") {
    SetEntryPoint(window_id, params, std::move(result));
  } else {
    result->Error("UNKNOWN_COMMAND", "Unknown window command: " + command);
  }
}

void WindowService::Create(
    const std::string* window_id,
    const flutter::EncodableMap& params,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (!window_id) {
    result->Error("MISSING_ID", "windowId required");
    return;
  }
  if (WindowStore::Instance().Exists(*window_id)) {
    result->Error("ALREADY_EXISTS", "Window already exists: " + *window_id);
    return;
  }

  FP_LOG("Window", "Create start: " + *window_id);

  EnsureWndClassRegistered();

  // Parse parameters
  double width = GetDouble(params, "width", 400);
  double height = GetDouble(params, "height", 200);
  double min_width = GetDouble(params, "minWidth", 200);
  double min_height = GetDouble(params, "minHeight", 100);
  double max_width = GetDouble(params, "maxWidth", 0);
  double max_height = GetDouble(params, "maxHeight", 600);
  double corner_radius = GetDouble(params, "cornerRadius", 12);
  bool transparent = GetBool(params, "transparent", true);
  bool resizable = GetBool(params, "resizable", false);
  bool keep_alive = GetBool(params, "keepAlive", false);
  int bg_color = GetInt(params, "backgroundColor", 0);

  // Scale to physical pixels for window creation (no HWND yet, use primary)
  double create_scale = GetPrimaryScaleFactor();
  int w = LogicalToPhysical(width, create_scale);
  int h = LogicalToPhysical(height, create_scale);

  // Create the palette HWND (off-screen initially, hidden)
  HWND hwnd = CreateWindowExW(
      WS_EX_TOOLWINDOW | WS_EX_LAYERED | WS_EX_NOACTIVATE,
      L"FLOATING_PALETTE_WND",
      L"",           // No title
      WS_POPUP,      // Borderless popup
      -10000, -10000, // Off-screen initially
      w, h,
      nullptr,       // No parent
      nullptr,       // No menu
      GetModuleHandle(nullptr),
      nullptr);

  if (!hwnd) {
    FP_LOG("Window", "Create HWND FAILED: " + *window_id);
    result->Error("CREATE_FAILED", "CreateWindowExW failed");
    return;
  }

  FP_LOG("Window", "Create HWND ok: " + *window_id +
                        " hwnd=0x" + std::to_string(reinterpret_cast<uintptr_t>(hwnd)) +
                        " size=" + std::to_string(w) + "x" + std::to_string(h));

  // Make fully transparent initially for reveal pattern.
  // LWA_COLORKEY makes RGB(1,0,1) pixels transparent (overflow padding area).
  SetLayeredWindowAttributes(hwnd, RGB(1, 0, 1), 0, LWA_COLORKEY | LWA_ALPHA);

  // Apply rounded-corner region to clip black corners
  ApplyWindowRegion(hwnd, w, h, corner_radius, create_scale);

  // Create palette window record (no engine yet — deferred)
  auto palette = std::make_unique<PaletteWindow>();
  palette->id = *window_id;
  palette->hwnd = hwnd;
  palette->width = width;
  palette->height = height;
  palette->min_width = min_width;
  palette->min_height = min_height;
  palette->max_width = max_width;
  palette->max_height = max_height;
  palette->corner_radius = corner_radius;
  palette->is_transparent = transparent;
  palette->resizable = resizable;
  palette->keep_alive = keep_alive;
  palette->background_color = bg_color;

  // Set entry point
  std::string entry_point = GetString(params, "entryPoint", "paletteMain");
  palette->entry_point = entry_point;

  FP_LOG("Window", "Create stored: " + *window_id + " entry=" + entry_point);

  // Store the window
  WindowStore::Instance().Store(*window_id, std::move(palette));

  // Return success immediately so Dart doesn't time out.
  // Engine creation is deferred to the next message loop iteration.
  result->Success(flutter::EncodableValue());

  // Defer engine creation via WM_TIMER (lowest-priority message).
  // This ensures ALL pending method calls from Dart (setSize, setPosition,
  // show, etc.) are processed before engine creation blocks the message pump.
  FP_LOG("Window", "Create timer set: " + *window_id);
  SetTimer(hwnd, TIMER_ENGINE_SETUP, 1, NULL);
}

void WindowService::SetupEngine(const std::string& window_id) {
  FP_LOG("Window", "SetupEngine start: " + window_id);
  auto* palette = WindowStore::Instance().Get(window_id);
  if (!palette || palette->is_destroyed) {
    FP_LOG("Window", "SetupEngine ABORT (not found or destroyed): " + window_id);
    return;
  }
  if (palette->engine) {
    FP_LOG("Window", "SetupEngine SKIP (already set up): " + window_id);
    return;  // Already set up
  }

  HWND hwnd = palette->hwnd;
  double engine_scale = GetScaleFactorForHwnd(hwnd);
  int w = LogicalToPhysical(palette->width, engine_scale);
  int h = LogicalToPhysical(palette->height, engine_scale);

  // Get paths from the host engine's executable directory
  wchar_t exe_path[MAX_PATH] = {};
  GetModuleFileNameW(nullptr, exe_path, MAX_PATH);
  std::wstring exe_dir(exe_path);
  exe_dir = exe_dir.substr(0, exe_dir.find_last_of(L'\\'));

  std::wstring assets_path = exe_dir + L"\\data\\flutter_assets";
  std::wstring icu_path = exe_dir + L"\\data\\icudtl.dat";
  std::wstring aot_path = exe_dir + L"\\data\\app.so";

  // Create Flutter engine properties
  FlutterDesktopEngineProperties engine_props = {};
  engine_props.assets_path = assets_path.c_str();
  engine_props.icu_data_path = icu_path.c_str();

  // Check for AOT library
  DWORD aot_attr = GetFileAttributesW(aot_path.c_str());
  if (aot_attr != INVALID_FILE_ATTRIBUTES) {
    engine_props.aot_library_path = aot_path.c_str();
  }

  engine_props.dart_entrypoint_argc = 0;
  engine_props.dart_entrypoint_argv = nullptr;

  // Create the Flutter engine
  FP_LOG("Window", "SetupEngine creating engine: " + window_id);
  FlutterDesktopEngineRef engine = FlutterDesktopEngineCreate(&engine_props);
  if (!engine) {
    FP_LOG("Window", "SetupEngine ENGINE CREATE FAILED: " + window_id);
    return;
  }

  // Run the engine with the palette's entry point
  const char* ep = palette->entry_point.c_str();
  FP_LOG("Window", "SetupEngine running entry=" + std::string(ep) + ": " + window_id);
  if (!FlutterDesktopEngineRun(engine, ep)) {
    FP_LOG("Window", "SetupEngine ENGINE RUN FAILED: " + window_id);
    FlutterDesktopEngineDestroy(engine);
    return;
  }
  palette->engine = engine;

  // Create view controller (this creates a Flutter HWND)
  FP_LOG("Window", "SetupEngine creating view controller: " + window_id);
  FlutterDesktopViewControllerRef controller =
      FlutterDesktopViewControllerCreate(w, h, engine);
  if (!controller) {
    FP_LOG("Window", "SetupEngine VIEW CONTROLLER FAILED: " + window_id);
    FlutterDesktopEngineDestroy(engine);
    palette->engine = nullptr;
    return;
  }
  palette->view_controller = controller;

  // Reparent the Flutter view HWND into our palette window
  HWND flutter_hwnd = FlutterDesktopViewGetHWND(
      FlutterDesktopViewControllerGetView(controller));
  FP_LOG("Window", "SetupEngine reparenting flutter_hwnd=0x" +
                        std::to_string(reinterpret_cast<uintptr_t>(flutter_hwnd)) +
                        " into hwnd=0x" +
                        std::to_string(reinterpret_cast<uintptr_t>(hwnd)) +
                        ": " + window_id);
  if (flutter_hwnd) {
    SetWindowLongPtr(flutter_hwnd, GWL_STYLE, WS_CHILD | WS_VISIBLE);
    SetWindowLongPtr(flutter_hwnd, GWL_EXSTYLE, 0);
    SetParent(flutter_hwnd, hwnd);
    SetWindowPos(flutter_hwnd, NULL, 0, 0, w, h,
                 SWP_NOZORDER | SWP_NOACTIVATE | SWP_FRAMECHANGED);
  }

  // Set up per-palette method channels
  FP_LOG("Window", "SetupEngine setting up channels: " + window_id);
  FlutterDesktopMessengerRef messenger =
      FlutterDesktopEngineGetMessenger(engine);
  WindowChannelRouter::SetupChannels(palette, messenger,
                                     event_sink_, frame_service_,
                                     snap_service_, drag_coordinator_,
                                     background_capture_service_);

  FP_LOG("Window", "SetupEngine COMPLETE: " + window_id);

  // Emit "created" event now that engine is ready
  if (event_sink_) {
    flutter::EncodableMap data;
    event_sink_("window", "created", &window_id, data);
  }
}

void WindowService::Destroy(
    const std::string* window_id,
    const flutter::EncodableMap& params,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (!window_id) {
    result->Error("MISSING_ID", "windowId required");
    return;
  }

  FP_LOG("Window", "Destroy start: " + *window_id);

  auto* window = WindowStore::Instance().Get(*window_id);
  if (!window) {
    FP_LOG("Window", "Destroy NOT_FOUND: " + *window_id);
    result->Error("NOT_FOUND", "Window not found: " + *window_id);
    return;
  }

  window->is_destroyed = true;

  // Notify dependent services
  if (input_service_) {
    input_service_->CleanupForWindow(*window_id);
  }
  if (snap_service_) {
    snap_service_->OnWindowDestroyed(*window_id);
  }

  // Clean up channels (must happen before binary messenger)
  window->entry_channel.reset();
  window->messenger_channel.reset();
  window->self_channel.reset();
  window->binary_messenger.reset();

  // Cancel engine setup timer if pending
  if (window->hwnd) {
    KillTimer(window->hwnd, TIMER_ENGINE_SETUP);
  }

  // Cancel reveal timer if active
  if (window->reveal_timer_id != 0) {
    KillTimer(NULL, window->reveal_timer_id);
    window->reveal_timer_id = 0;
  }

  // Destroy view controller (shuts down engine)
  if (window->view_controller) {
    FlutterDesktopViewControllerDestroy(window->view_controller);
    window->view_controller = nullptr;
    window->engine = nullptr;  // Engine is owned by view controller
  }

  // Destroy the native window
  HWND hwnd = window->hwnd;

  // Remove from store
  WindowStore::Instance().Remove(*window_id);

  // Destroy HWND after removing from store
  if (hwnd) {
    DestroyWindow(hwnd);
  }

  FP_LOG("Window", "destroyed: " + *window_id);

  // Emit "destroyed" event
  if (event_sink_) {
    flutter::EncodableMap data;
    event_sink_("window", "destroyed", window_id, data);
  }

  result->Success(flutter::EncodableValue());
}

void WindowService::Exists(
    const std::string* window_id,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (!window_id) {
    result->Success(flutter::EncodableValue(false));
    return;
  }
  bool exists = WindowStore::Instance().Exists(*window_id);
  result->Success(flutter::EncodableValue(exists));
}

void WindowService::SetEntryPoint(
    const std::string* window_id,
    const flutter::EncodableMap& params,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (!window_id) {
    result->Error("MISSING_ID", "windowId required");
    return;
  }
  auto* window = WindowStore::Instance().Get(*window_id);
  if (window) {
    window->entry_point = GetString(params, "entryPoint", "paletteMain");
  }
  result->Success(flutter::EncodableValue());
}

}  // namespace floating_palette
