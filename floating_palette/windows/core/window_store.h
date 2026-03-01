#pragma once

#include <windows.h>

#include <flutter/binary_messenger.h>
#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <flutter_windows.h>

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

/// Represents a palette window with its native handle and Flutter engine.
struct PaletteWindow {
  std::string id;
  HWND hwnd = nullptr;

  // Flutter engine
  FlutterDesktopEngineRef engine = nullptr;
  FlutterDesktopViewControllerRef view_controller = nullptr;

  // Per-palette binary messenger (must outlive channels)
  std::unique_ptr<flutter::BinaryMessenger> binary_messenger;

  // Per-palette method channels (owned by this struct)
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      entry_channel;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      messenger_channel;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      self_channel;

  // Visibility / reveal
  bool is_pending_reveal = false;
  bool should_focus = true;
  UINT_PTR reveal_timer_id = 0;

  // Opacity
  double opacity = 1.0;

  // Focus
  std::string focus_policy = "onClick";

  // Size config
  double width = 300;
  double height = 200;
  double min_width = 0;
  double min_height = 0;
  double max_width = 0;
  double max_height = 0;
  bool resizable = true;

  // Drag
  bool draggable = true;

  // Entry point
  std::string entry_point;

  // Z-order state
  std::string level = "floating";  // "floating", "normal"
  bool is_pinned = false;

  // Appearance state
  double corner_radius = 0;
  bool has_shadow = false;
  int32_t background_color = 0;  // ARGB
  bool is_transparent = true;
  std::string blur_type = "none";

  // Transform state (software tracking only)
  double scale_x = 1.0;
  double scale_y = 1.0;
  double rotation = 0.0;
  bool flip_horizontal = false;
  bool flip_vertical = false;

  // Lifecycle
  bool is_destroyed = false;
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

  // Find a palette window by its HWND.
  PaletteWindow* FindByHwnd(HWND hwnd) {
    std::lock_guard<std::mutex> lock(mutex_);
    for (auto& [id, window] : windows_) {
      if (window->hwnd == hwnd) return window.get();
    }
    return nullptr;
  }

 private:
  WindowStore() = default;
  std::mutex mutex_;
  std::unordered_map<std::string, std::unique_ptr<PaletteWindow>> windows_;
};

}  // namespace floating_palette
