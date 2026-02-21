#pragma once

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <string>

#include "../core/window_store.h"

namespace floating_palette {

class ScreenService {
 public:
  void SetEventSink(EventSink sink) { event_sink_ = std::move(sink); }
  void Handle(const std::string& command,
              const std::string* window_id,
              const flutter::EncodableMap& params,
              std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

 private:
  EventSink event_sink_;

  void GetScreens(std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void GetCurrentScreen(std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void GetWindowScreen(const std::string* window_id,
                       std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void MoveToScreen(const std::string* window_id,
                    const flutter::EncodableMap& params,
                    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void GetCursorPosition(std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void GetActiveAppBounds(std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
};

}  // namespace floating_palette
