#pragma once

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <string>

#include "../core/window_store.h"

namespace floating_palette {

class FocusService {
 public:
  void SetEventSink(EventSink sink) { event_sink_ = std::move(sink); }
  void Handle(const std::string& command,
              const std::string* window_id,
              const flutter::EncodableMap& params,
              std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  void SetMainHwnd(HWND hwnd) { main_hwnd_ = hwnd; }

 private:
  EventSink event_sink_;
  HWND main_hwnd_ = nullptr;

  void Focus(const std::string* window_id,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void Unfocus(const std::string* window_id,
               std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void SetPolicy(const std::string* window_id,
                 const flutter::EncodableMap& params,
                 std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void IsFocused(const std::string* window_id,
                 std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void FocusMainWindow(std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void HideApp(std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
};

}  // namespace floating_palette
