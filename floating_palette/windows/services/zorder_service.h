#pragma once

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <string>

#include "../core/window_store.h"

namespace floating_palette {

class ZOrderService {
 public:
  void SetEventSink(EventSink sink) { event_sink_ = std::move(sink); }
  void Handle(const std::string& command,
              const std::string* window_id,
              const flutter::EncodableMap& params,
              std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

 private:
  EventSink event_sink_;

  void BringToFront(const std::string* window_id,
                    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void SendToBack(const std::string* window_id,
                  std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void MoveAbove(const std::string* window_id,
                 const flutter::EncodableMap& params,
                 std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void MoveBelow(const std::string* window_id,
                 const flutter::EncodableMap& params,
                 std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void SetZIndex(const std::string* window_id,
                 const flutter::EncodableMap& params,
                 std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void SetLevel(const std::string* window_id,
                const flutter::EncodableMap& params,
                std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void Pin(const std::string* window_id,
           std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void Unpin(const std::string* window_id,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
};

}  // namespace floating_palette
