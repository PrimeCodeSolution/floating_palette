#pragma once

/// Debug-only logging via OutputDebugStringA.
///
/// Usage:
///   FP_LOG("Window", "create id=" + id);
///
/// Viewing logs:
///   Use DebugView (Sysinternals) or Visual Studio Output window.
///   Filter by "[floating_palette:" prefix.

#ifdef _DEBUG

#include <windows.h>

#include <sstream>
#include <string>

namespace floating_palette {

inline void LogMessage(const char* category, const char* message) {
  std::ostringstream oss;
  oss << "[floating_palette:" << category << "] " << message << "\n";
  OutputDebugStringA(oss.str().c_str());
}

inline void LogMessage(const char* category, const std::string& message) {
  LogMessage(category, message.c_str());
}

}  // namespace floating_palette

#define FP_LOG(category, message) \
  ::floating_palette::LogMessage(category, message)

#else

#define FP_LOG(category, message) ((void)0)

#endif
