#pragma once

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <string>

#include "../core/window_store.h"

namespace floating_palette {

class SnapService;

class VisibilityService {
 public:
  void SetEventSink(EventSink sink) { event_sink_ = std::move(sink); }
  void Handle(const std::string& command,
              const std::string* window_id,
              const flutter::EncodableMap& params,
              std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  void SetSnapService(SnapService* service) { snap_service_ = service; }

  void Reveal(const std::string& window_id);

 private:
  EventSink event_sink_;
  SnapService* snap_service_ = nullptr;

  void Show(const std::string* window_id,
            const flutter::EncodableMap& params,
            std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void Hide(const std::string* window_id,
            const flutter::EncodableMap& params,
            std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void SetOpacity(const std::string* window_id,
                  const flutter::EncodableMap& params,
                  std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void GetOpacity(const std::string* window_id,
                  std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void DoReveal(const std::string* window_id,
                std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
};

}  // namespace floating_palette
