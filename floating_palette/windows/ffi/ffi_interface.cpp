#include "ffi_interface.h"

#include <psapi.h>

#include "../core/logger.h"
#include "../core/monitor_helper.h"
#include "../core/window_store.h"

using namespace floating_palette;

// Static pointer to VisibilityService for reveal callback.
// Set by VisibilityService on construction.
namespace floating_palette {
class VisibilityService;
extern VisibilityService* g_visibility_service;
}  // namespace floating_palette

// Forward declaration - defined in visibility_service.cpp
namespace floating_palette {
void VisibilityService_Reveal(const std::string& window_id);
}

// ═══════════════════════════════════════════════════════════════════════════
// WINDOW SIZING
// ═══════════════════════════════════════════════════════════════════════════

// Custom message for deferred resize (avoids re-entrant layout during performLayout)
#define WM_FP_DEFERRED_RESIZE (WM_USER + 200)
#define WM_FP_DEFERRED_REVEAL (WM_USER + 201)

void FloatingPalette_ResizeWindow(const char* window_id, double width,
                                  double height) {
  if (!window_id) return;
  std::string id(window_id);

  FP_LOG("FFI", "ResizeWindow [" + id + "] " +
                     std::to_string(static_cast<int>(width)) + "x" +
                     std::to_string(static_cast<int>(height)));

  auto* window = WindowStore::Instance().Get(id);
  if (!window || !window->hwnd) {
    FP_LOG("FFI", "ResizeWindow NOT_FOUND: " + id);
    return;
  }

  // Store desired size immediately
  window->width = width;
  window->height = height;

  // Defer the actual native resize to avoid re-entrant layout.
  // On Windows, SetWindowPos sends WM_SIZE synchronously, which triggers
  // _updateWindowMetrics -> markNeedsLayout while still inside performLayout.
  // PostMessage defers to the next message loop iteration.
  int w = static_cast<int>(width);
  int h = static_cast<int>(height);
  PostMessage(window->hwnd, WM_FP_DEFERRED_RESIZE, static_cast<WPARAM>(w),
              static_cast<LPARAM>(h));

  // Trigger the reveal pattern (also deferred)
  if (window->is_pending_reveal) {
    FP_LOG("FFI", "ResizeWindow posting DEFERRED_REVEAL: " + id);
    PostMessage(window->hwnd, WM_FP_DEFERRED_REVEAL, 0, 0);
  }
}

bool FloatingPalette_GetWindowFrame(const char* window_id, double* out_x,
                                    double* out_y, double* out_width,
                                    double* out_height) {
  if (!window_id) return false;

  auto* window = WindowStore::Instance().Get(std::string(window_id));
  if (!window || !window->hwnd) {
    if (out_x) *out_x = 0;
    if (out_y) *out_y = 0;
    if (out_width) *out_width = 0;
    if (out_height) *out_height = 0;
    return false;
  }

  RECT rect;
  if (!GetWindowRect(window->hwnd, &rect)) return false;

  if (out_x) *out_x = static_cast<double>(rect.left);
  if (out_y) *out_y = static_cast<double>(rect.top);
  if (out_width) *out_width = static_cast<double>(rect.right - rect.left);
  if (out_height) *out_height = static_cast<double>(rect.bottom - rect.top);
  return true;
}

bool FloatingPalette_IsWindowVisible(const char* window_id) {
  if (!window_id) return false;

  auto* window = WindowStore::Instance().Get(std::string(window_id));
  if (!window || !window->hwnd) return false;

  return ::IsWindowVisible(window->hwnd) != FALSE;
}

// ═══════════════════════════════════════════════════════════════════════════
// CURSOR POSITION
// ═══════════════════════════════════════════════════════════════════════════

void FloatingPalette_GetCursorPosition(double* out_x, double* out_y) {
  POINT pt;
  if (GetCursorPos(&pt)) {
    if (out_x) *out_x = static_cast<double>(pt.x);
    if (out_y) *out_y = static_cast<double>(pt.y);
  } else {
    if (out_x) *out_x = 0;
    if (out_y) *out_y = 0;
  }
}

int32_t FloatingPalette_GetCursorScreen(void) {
  POINT pt;
  if (!GetCursorPos(&pt)) return -1;

  HMONITOR monitor = MonitorFromPoint(pt, MONITOR_DEFAULTTONULL);
  if (!monitor) return -1;

  return MonitorHelper::MonitorToIndex(monitor);
}

// ═══════════════════════════════════════════════════════════════════════════
// SCREEN INFO
// ═══════════════════════════════════════════════════════════════════════════

int32_t FloatingPalette_GetScreenCount(void) {
  return MonitorHelper::GetMonitorCount();
}

bool FloatingPalette_GetScreenBounds(int32_t screen_index, double* out_x,
                                     double* out_y, double* out_width,
                                     double* out_height) {
  MonitorInfo info;
  if (!MonitorHelper::GetMonitorByIndex(screen_index, info)) {
    if (out_x) *out_x = 0;
    if (out_y) *out_y = 0;
    if (out_width) *out_width = 0;
    if (out_height) *out_height = 0;
    return false;
  }

  if (out_x) *out_x = static_cast<double>(info.bounds.left);
  if (out_y) *out_y = static_cast<double>(info.bounds.top);
  if (out_width)
    *out_width = static_cast<double>(info.bounds.right - info.bounds.left);
  if (out_height)
    *out_height = static_cast<double>(info.bounds.bottom - info.bounds.top);
  return true;
}

bool FloatingPalette_GetScreenVisibleBounds(int32_t screen_index,
                                            double* out_x, double* out_y,
                                            double* out_width,
                                            double* out_height) {
  MonitorInfo info;
  if (!MonitorHelper::GetMonitorByIndex(screen_index, info)) {
    if (out_x) *out_x = 0;
    if (out_y) *out_y = 0;
    if (out_width) *out_width = 0;
    if (out_height) *out_height = 0;
    return false;
  }

  if (out_x) *out_x = static_cast<double>(info.work_area.left);
  if (out_y) *out_y = static_cast<double>(info.work_area.top);
  if (out_width)
    *out_width =
        static_cast<double>(info.work_area.right - info.work_area.left);
  if (out_height)
    *out_height =
        static_cast<double>(info.work_area.bottom - info.work_area.top);
  return true;
}

double FloatingPalette_GetScreenScaleFactor(int32_t screen_index) {
  MonitorInfo info;
  if (!MonitorHelper::GetMonitorByIndex(screen_index, info)) return 1.0;
  return info.scale_factor;
}

// ═══════════════════════════════════════════════════════════════════════════
// ACTIVE APPLICATION
// ═══════════════════════════════════════════════════════════════════════════

bool FloatingPalette_GetActiveAppBounds(double* out_x, double* out_y,
                                        double* out_width,
                                        double* out_height) {
  HWND fg = GetForegroundWindow();
  if (!fg) return false;

  RECT rect;
  if (!GetWindowRect(fg, &rect)) return false;

  if (out_x) *out_x = static_cast<double>(rect.left);
  if (out_y) *out_y = static_cast<double>(rect.top);
  if (out_width) *out_width = static_cast<double>(rect.right - rect.left);
  if (out_height) *out_height = static_cast<double>(rect.bottom - rect.top);
  return true;
}

int32_t FloatingPalette_GetActiveAppIdentifier(char* out_buffer,
                                               int32_t buffer_size) {
  if (!out_buffer || buffer_size <= 0) return 0;
  out_buffer[0] = '\0';

  HWND fg = GetForegroundWindow();
  if (!fg) return 0;

  DWORD pid = 0;
  GetWindowThreadProcessId(fg, &pid);
  if (pid == 0) return 0;

  HANDLE process =
      OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, pid);
  if (!process) return 0;

  char path[MAX_PATH] = {};
  DWORD path_size = MAX_PATH;
  BOOL ok = QueryFullProcessImageNameA(process, 0, path, &path_size);
  CloseHandle(process);

  if (!ok || path_size == 0) return 0;

  int len = static_cast<int>(path_size);
  if (len >= buffer_size) len = buffer_size - 1;
  memcpy(out_buffer, path, len);
  out_buffer[len] = '\0';
  return len;
}

// ═══════════════════════════════════════════════════════════════════════════
// GLASS MASK EFFECT (no-op stubs — macOS-only feature)
// ═══════════════════════════════════════════════════════════════════════════

void* FloatingPalette_CreateGlassPathBuffer(const char* window_id) {
  return nullptr;
}

void FloatingPalette_DestroyGlassPathBuffer(const char* window_id) {}

void FloatingPalette_SetGlassEnabled(const char* window_id, bool enabled) {}

void FloatingPalette_SetGlassMaterial(const char* window_id,
                                      int32_t material) {}

void FloatingPalette_SetGlassDark(const char* window_id, bool is_dark) {}

void FloatingPalette_SetGlassTintOpacity(const char* window_id, float opacity,
                                         float corner_radius) {}

// ═══════════════════════════════════════════════════════════════════════════
// GLASS ANIMATION (no-op stubs — macOS-only feature)
// ═══════════════════════════════════════════════════════════════════════════

double FloatingPalette_GetCurrentTime(void) {
  // High-resolution timer (equivalent to CACurrentMediaTime on macOS)
  LARGE_INTEGER freq, counter;
  QueryPerformanceFrequency(&freq);
  QueryPerformanceCounter(&counter);
  return static_cast<double>(counter.QuadPart) /
         static_cast<double>(freq.QuadPart);
}

void* FloatingPalette_CreateAnimationBuffer(const char* window_id,
                                            int32_t layer_id) {
  return nullptr;
}

void FloatingPalette_DestroyAnimationBuffer(const char* window_id,
                                            int32_t layer_id) {}
