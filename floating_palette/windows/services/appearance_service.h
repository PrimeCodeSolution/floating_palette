#pragma once

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <string>

#include "../core/window_store.h"

namespace floating_palette {

class AppearanceService {
 public:
  void SetEventSink(EventSink sink) { event_sink_ = std::move(sink); }
  void Handle(const std::string& command,
              const std::string* window_id,
              const flutter::EncodableMap& params,
              std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

 private:
  EventSink event_sink_;

  void SetCornerRadius(const std::string* window_id,
                       const flutter::EncodableMap& params,
                       std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void SetShadow(const std::string* window_id,
                 const flutter::EncodableMap& params,
                 std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void SetBackgroundColor(const std::string* window_id,
                          const flutter::EncodableMap& params,
                          std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void SetTransparent(const std::string* window_id,
                      const flutter::EncodableMap& params,
                      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void SetBlur(const std::string* window_id,
               const flutter::EncodableMap& params,
               std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void ApplyAppearance(const std::string* window_id,
                       const flutter::EncodableMap& params,
                       std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
};

}  // namespace floating_palette
