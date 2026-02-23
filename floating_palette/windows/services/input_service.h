#pragma once

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <string>
#include <unordered_map>
#include <unordered_set>

#include "../core/window_store.h"

namespace floating_palette {

class InputService {
 public:
  InputService();
  ~InputService();

  void SetEventSink(EventSink sink) { event_sink_ = std::move(sink); }
  void Handle(const std::string& command,
              const std::string* window_id,
              const flutter::EncodableMap& params,
              std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  // Called during window cleanup
  void CleanupForWindow(const std::string& window_id);

 private:
  EventSink event_sink_;

  // Tracking which windows have keyboard/pointer capture
  std::unordered_set<std::string> keyboard_captures_;
  std::unordered_set<std::string> pointer_captures_;

  // Global hooks
  static HHOOK keyboard_hook_;
  static HHOOK mouse_hook_;
  static InputService* instance_;

  static LRESULT CALLBACK KeyboardHookProc(int code, WPARAM wparam,
                                           LPARAM lparam);
  static LRESULT CALLBACK MouseHookProc(int code, WPARAM wparam,
                                        LPARAM lparam);

  void InstallKeyboardHook();
  void RemoveKeyboardHook();
  void InstallMouseHook();
  void RemoveMouseHook();

  void CaptureKeyboard(const std::string* window_id,
                       std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void ReleaseKeyboard(const std::string* window_id,
                       std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void CapturePointer(const std::string* window_id,
                      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void ReleasePointer(const std::string* window_id,
                      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void SetCursor(const std::string* window_id,
                 const flutter::EncodableMap& params,
                 std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void SetPassthrough(const std::string* window_id,
                      const flutter::EncodableMap& params,
                      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
};

}  // namespace floating_palette
