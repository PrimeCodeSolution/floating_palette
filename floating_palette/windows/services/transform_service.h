#pragma once

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <string>

#include "../core/window_store.h"

namespace floating_palette {

class TransformService {
 public:
  void SetEventSink(EventSink sink) { event_sink_ = std::move(sink); }
  void Handle(const std::string& command,
              const std::string* window_id,
              const flutter::EncodableMap& params,
              std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

 private:
  EventSink event_sink_;

  void SetScale(const std::string* window_id,
                const flutter::EncodableMap& params,
                std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void SetRotation(const std::string* window_id,
                   const flutter::EncodableMap& params,
                   std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void SetFlip(const std::string* window_id,
               const flutter::EncodableMap& params,
               std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void Reset(const std::string* window_id,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void GetScale(const std::string* window_id,
                std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void GetRotation(const std::string* window_id,
                   std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
};

}  // namespace floating_palette
