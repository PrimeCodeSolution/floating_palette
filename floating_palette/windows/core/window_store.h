#pragma once

#include <windows.h>

#include <flutter/encodable_value.h>

#include <functional>
#include <memory>
#include <mutex>
#include <string>
#include <unordered_map>

namespace floating_palette {

// Shared event sink type used by all services.
// Parameters: service, event, windowId (nullptr if none), data.
using EventSink = std::function<void(
    const std::string& service,
    const std::string& event,
    const std::string* window_id,
    const flutter::EncodableMap& data)>;

/// Represents a palette window with its native handle.
struct PaletteWindow {
  std::string id;
  HWND hwnd = nullptr;
  // Future: FlutterDesktopEngineRef, FlutterDesktopViewRef
  bool is_pending_reveal = false;
  bool should_focus = true;
  bool draggable = true;
  bool keep_alive = false;
};

/// Stores and tracks all palette windows.
/// Single source of truth for window handles. Thread-safe.
class WindowStore {
 public:
  static WindowStore& Instance() {
    static WindowStore store;
    return store;
  }

  PaletteWindow* Get(const std::string& id) {
    std::lock_guard<std::mutex> lock(mutex_);
    auto it = windows_.find(id);
    return it != windows_.end() ? it->second.get() : nullptr;
  }

  bool Exists(const std::string& id) {
    std::lock_guard<std::mutex> lock(mutex_);
    return windows_.count(id) > 0;
  }

  void Store(const std::string& id, std::unique_ptr<PaletteWindow> window) {
    std::lock_guard<std::mutex> lock(mutex_);
    windows_[id] = std::move(window);
  }

  std::unique_ptr<PaletteWindow> Remove(const std::string& id) {
    std::lock_guard<std::mutex> lock(mutex_);
    auto it = windows_.find(id);
    if (it == windows_.end()) return nullptr;
    auto window = std::move(it->second);
    windows_.erase(it);
    return window;
  }

  void Clear() {
    std::lock_guard<std::mutex> lock(mutex_);
    windows_.clear();
  }

  // Returns snapshot of all windows (raw pointers, caller must not store).
  std::unordered_map<std::string, PaletteWindow*> All() {
    std::lock_guard<std::mutex> lock(mutex_);
    std::unordered_map<std::string, PaletteWindow*> result;
    for (auto& [id, window] : windows_) {
      result[id] = window.get();
    }
    return result;
  }

 private:
  WindowStore() = default;
  std::mutex mutex_;
  std::unordered_map<std::string, std::unique_ptr<PaletteWindow>> windows_;
};

}  // namespace floating_palette
