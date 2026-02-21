#include "ffi_interface.h"

#include "../core/logger.h"
#include "../core/window_store.h"

// ═══════════════════════════════════════════════════════════════════════════
// WINDOW SIZING
// ═══════════════════════════════════════════════════════════════════════════

void FloatingPalette_ResizeWindow(const char* window_id, double width,
                                  double height) {
  // TODO: Resize HWND via SetWindowPos
  FP_LOG("FFI", "ResizeWindow stub");
}

bool FloatingPalette_GetWindowFrame(const char* window_id, double* out_x,
                                    double* out_y, double* out_width,
                                    double* out_height) {
  // TODO: GetWindowRect
  if (out_x) *out_x = 0;
  if (out_y) *out_y = 0;
  if (out_width) *out_width = 0;
  if (out_height) *out_height = 0;
  return false;
}

bool FloatingPalette_IsWindowVisible(const char* window_id) {
  // TODO: IsWindowVisible(hwnd)
  return false;
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

  // TODO: Map HMONITOR to screen index
  return 0;
}

// ═══════════════════════════════════════════════════════════════════════════
// SCREEN INFO
// ═══════════════════════════════════════════════════════════════════════════

int32_t FloatingPalette_GetScreenCount(void) {
  return GetSystemMetrics(SM_CMONITORS);
}

bool FloatingPalette_GetScreenBounds(int32_t screen_index, double* out_x,
                                     double* out_y, double* out_width,
                                     double* out_height) {
  // TODO: Enumerate monitors and return bounds for given index
  if (out_x) *out_x = 0;
  if (out_y) *out_y = 0;
  if (out_width) *out_width = 0;
  if (out_height) *out_height = 0;
  return false;
}

bool FloatingPalette_GetScreenVisibleBounds(int32_t screen_index,
                                            double* out_x, double* out_y,
                                            double* out_width,
                                            double* out_height) {
  // TODO: SystemParametersInfo(SPI_GETWORKAREA, ...) for given monitor
  if (out_x) *out_x = 0;
  if (out_y) *out_y = 0;
  if (out_width) *out_width = 0;
  if (out_height) *out_height = 0;
  return false;
}

double FloatingPalette_GetScreenScaleFactor(int32_t screen_index) {
  // TODO: GetDpiForMonitor for given monitor
  return 1.0;
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
  // TODO: GetForegroundWindow → GetWindowThreadProcessId → process name
  if (out_buffer && buffer_size > 0) {
    out_buffer[0] = '\0';
  }
  return 0;
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
