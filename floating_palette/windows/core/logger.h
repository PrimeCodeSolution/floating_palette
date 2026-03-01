#pragma once

/// Dual-output logging: stderr (visible in `flutter run`) + OutputDebugStringA.
///
/// Usage:
///   FP_LOG("Window", "create id=" + id);
///
/// Viewing logs:
///   - `flutter run -d windows` console (stderr)
///   - DebugView (Sysinternals) or Visual Studio Output window
///   Filter by "[FP:" prefix.

// NOTE: _DEBUG guard removed temporarily for diagnostics.
// Restore once the secondary-palette show bug is fixed.

#include <windows.h>

#include <cstdio>
#include <sstream>
#include <string>

namespace floating_palette {

inline void LogMessage(const char* category, const char* message) {
  std::ostringstream oss;
  oss << "[FP:" << category << "] " << message << "\n";
  const std::string& s = oss.str();
  OutputDebugStringA(s.c_str());
  fprintf(stderr, "%s", s.c_str());
  fflush(stderr);
}

inline void LogMessage(const char* category, const std::string& message) {
  LogMessage(category, message.c_str());
}

}  // namespace floating_palette

#define FP_LOG(category, message) \
  ::floating_palette::LogMessage(category, message)
