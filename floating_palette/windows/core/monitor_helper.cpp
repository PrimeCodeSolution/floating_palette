#include "monitor_helper.h"

#include <algorithm>

namespace floating_palette {

namespace {

struct EnumContext {
  std::vector<MonitorInfo> monitors;
};

BOOL CALLBACK MonitorEnumProc(HMONITOR monitor, HDC, LPRECT, LPARAM data) {
  auto* ctx = reinterpret_cast<EnumContext*>(data);

  MONITORINFO mi = {};
  mi.cbSize = sizeof(MONITORINFO);
  if (!GetMonitorInfo(monitor, &mi)) return TRUE;

  MonitorInfo info = {};
  info.handle = monitor;
  info.bounds = mi.rcMonitor;
  info.work_area = mi.rcWork;
  info.is_primary = (mi.dwFlags & MONITORINFOF_PRIMARY) != 0;

  // Get DPI scale factor
  UINT dpi_x = 96, dpi_y = 96;
  if (SUCCEEDED(GetDpiForMonitor(monitor, MDT_EFFECTIVE_DPI, &dpi_x, &dpi_y))) {
    info.scale_factor = static_cast<double>(dpi_x) / 96.0;
  } else {
    info.scale_factor = 1.0;
  }

  ctx->monitors.push_back(info);
  return TRUE;
}

}  // namespace

std::vector<MonitorInfo> MonitorHelper::GetAllMonitors() {
  EnumContext ctx;
  EnumDisplayMonitors(NULL, NULL, MonitorEnumProc, reinterpret_cast<LPARAM>(&ctx));

  // Sort: primary first, then by x position (left to right)
  std::sort(ctx.monitors.begin(), ctx.monitors.end(),
            [](const MonitorInfo& a, const MonitorInfo& b) {
              if (a.is_primary != b.is_primary) return a.is_primary;
              return a.bounds.left < b.bounds.left;
            });

  return ctx.monitors;
}

bool MonitorHelper::GetMonitorByIndex(int index, MonitorInfo& out) {
  auto monitors = GetAllMonitors();
  if (index < 0 || index >= static_cast<int>(monitors.size())) return false;
  out = monitors[index];
  return true;
}

int MonitorHelper::MonitorToIndex(HMONITOR monitor) {
  auto monitors = GetAllMonitors();
  for (int i = 0; i < static_cast<int>(monitors.size()); i++) {
    if (monitors[i].handle == monitor) return i;
  }
  return -1;
}

int MonitorHelper::GetMonitorCount() {
  return GetSystemMetrics(SM_CMONITORS);
}

}  // namespace floating_palette
