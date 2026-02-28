#pragma once

#include <windows.h>
#include <shellscalingapi.h>

#include <cmath>

namespace floating_palette {

/// Get the DPI scale factor for the monitor containing the given HWND.
/// Returns 1.0 on failure or if DPI cannot be determined.
inline double GetScaleFactorForHwnd(HWND hwnd) {
  HMONITOR monitor = MonitorFromWindow(hwnd, MONITOR_DEFAULTTOPRIMARY);
  if (!monitor) return 1.0;

  UINT dpi_x = 96, dpi_y = 96;
  if (SUCCEEDED(GetDpiForMonitor(monitor, MDT_EFFECTIVE_DPI, &dpi_x, &dpi_y))) {
    return static_cast<double>(dpi_x) / 96.0;
  }
  return 1.0;
}

/// Get the DPI scale factor for the monitor containing the given point.
/// Returns 1.0 on failure.
inline double GetScaleFactorForPoint(POINT pt) {
  HMONITOR monitor = MonitorFromPoint(pt, MONITOR_DEFAULTTOPRIMARY);
  if (!monitor) return 1.0;

  UINT dpi_x = 96, dpi_y = 96;
  if (SUCCEEDED(GetDpiForMonitor(monitor, MDT_EFFECTIVE_DPI, &dpi_x, &dpi_y))) {
    return static_cast<double>(dpi_x) / 96.0;
  }
  return 1.0;
}

/// Get the DPI scale factor for the primary monitor.
/// Useful when no HWND exists yet (e.g., during window creation).
inline double GetPrimaryScaleFactor() {
  POINT origin = {0, 0};
  return GetScaleFactorForPoint(origin);
}

/// Convert a logical pixel value (from Dart) to physical pixels (for Win32).
inline int LogicalToPhysical(double logical, double scale) {
  return static_cast<int>(std::round(logical * scale));
}

/// Convert a physical pixel value (from Win32) to logical pixels (for Dart).
inline double PhysicalToLogical(long physical, double scale) {
  if (scale <= 0.0) return static_cast<double>(physical);
  return static_cast<double>(physical) / scale;
}

/// Convert a physical pixel value (int variant) to logical pixels (for Dart).
inline double PhysicalToLogical(int physical, double scale) {
  return PhysicalToLogical(static_cast<long>(physical), scale);
}

/// Convert a physical double value (from Win32) to logical pixels (for Dart).
inline double PhysicalToLogical(double physical, double scale) {
  if (scale <= 0.0) return physical;
  return physical / scale;
}

}  // namespace floating_palette
