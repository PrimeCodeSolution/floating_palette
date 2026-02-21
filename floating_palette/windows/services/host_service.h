#pragma once

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <string>

#include "../core/window_store.h"

namespace floating_palette {

class HostService {
 public:
  void SetEventSink(EventSink sink) { event_sink_ = std::move(sink); }
  void Handle(const std::string& command,
              const std::string* window_id,
              const flutter::EncodableMap& params,
              std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

 private:
  EventSink event_sink_;

  static constexpr int kProtocolVersion = 1;
  static constexpr int kMinDartVersion = 1;
  static constexpr int kMaxDartVersion = 1;

  void GetProtocolVersion(std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void GetCapabilities(std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void GetServiceVersion(const flutter::EncodableMap& params,
                         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void GetSnapshot(std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void Ping(std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
};

}  // namespace floating_palette
