#pragma once

#include <windows.h>
#include <shellscalingapi.h>

#include <vector>

namespace floating_palette {

struct MonitorInfo {
  HMONITOR handle;
  RECT bounds;       // Full monitor bounds
  RECT work_area;    // Usable area (excludes taskbar)
  double scale_factor;
  bool is_primary;
};

/// Enumerates monitors in a consistent order: primary first, then left-to-right.
/// Shared by FFI interface and ScreenService.
class MonitorHelper {
 public:
  /// Get all monitors, primary first, then sorted by x position.
  static std::vector<MonitorInfo> GetAllMonitors();

  /// Get monitor info by index (0 = primary).
  static bool GetMonitorByIndex(int index, MonitorInfo& out);

  /// Map an HMONITOR handle to its index in the sorted list.
  static int MonitorToIndex(HMONITOR monitor);

  /// Get the number of monitors.
  static int GetMonitorCount();
};

}  // namespace floating_palette
