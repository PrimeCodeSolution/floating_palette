#pragma once

#include <UIAutomation.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <mutex>
#include <string>
#include <vector>

#include "../core/window_store.h"

namespace floating_palette {

struct TextSelectionEvent {
  std::string text;
  double x = 0;
  double y = 0;
  double width = 0;
  double height = 0;
  bool has_bounds = false;
  bool is_focus_change = false;
};

class TextSelectionService {
 public:
  TextSelectionService();
  ~TextSelectionService();

  void SetEventSink(EventSink sink) { event_sink_ = std::move(sink); }
  void Handle(const std::string& command,
              const std::string* window_id,
              const flutter::EncodableMap& params,
              std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

 private:
  class SelectionHandler;
  class FocusHandler;

  EventSink event_sink_;

  // COM / UIA
  IUIAutomation* automation_ = nullptr;
  IUIAutomationElement* root_element_ = nullptr;
  SelectionHandler* selection_handler_ = nullptr;
  FocusHandler* focus_handler_ = nullptr;
  bool com_initialized_ = false;
  bool monitoring_ = false;

  // Thread-safe event queue (BG → UI)
  std::mutex queue_mutex_;
  std::vector<TextSelectionEvent> event_queue_;

  // Timers (UI thread only)
  UINT_PTR poll_timer_id_ = 0;
  UINT_PTR clear_timer_id_ = 0;

  // Dedup state (UI thread only)
  std::string last_text_;
  double last_x_ = 0;
  double last_y_ = 0;
  double last_width_ = 0;
  double last_height_ = 0;

  // Static instance for timer callbacks
  static TextSelectionService* instance_;
  static void CALLBACK PollTimerProc(HWND, UINT, UINT_PTR, DWORD);
  static void CALLBACK ClearTimerProc(HWND, UINT, UINT_PTR, DWORD);

  // COM lifecycle
  bool EnsureUIAutomation();
  void ReleaseUIAutomation();

  // Event processing (UI thread)
  void ProcessPendingEvents();
  void EmitSelectionChanged(const TextSelectionEvent& evt);
  void EmitSelectionCleared();
  void ScheduleClear();
  void CancelClear();

  // Helpers
  bool ReadSelectionFromElement(IUIAutomationElement* element,
                                TextSelectionEvent& out);
  void GetAppInfo(std::string& app_bundle_id, std::string& app_name);

  // Commands
  void CheckPermission(
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void RequestPermission(
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void GetSelection(
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void StartMonitoring(
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void StopMonitoring(
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
};

}  // namespace floating_palette
