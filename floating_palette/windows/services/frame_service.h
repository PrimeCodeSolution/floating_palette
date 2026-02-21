#pragma once

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <string>

#include "../core/window_store.h"

namespace floating_palette {

class DragCoordinator;
class SnapService;

class FrameService {
 public:
  void SetEventSink(EventSink sink) { event_sink_ = std::move(sink); }
  void Handle(const std::string& command,
              const std::string* window_id,
              const flutter::EncodableMap& params,
              std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  void SetSnapService(SnapService* service) { snap_service_ = service; }
  void SetDragCoordinator(DragCoordinator* coordinator) {
    drag_coordinator_ = coordinator;
  }

 private:
  EventSink event_sink_;
  SnapService* snap_service_ = nullptr;
  DragCoordinator* drag_coordinator_ = nullptr;

  void SetPosition(const std::string* window_id,
                   const flutter::EncodableMap& params,
                   std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void SetSize(const std::string* window_id,
               const flutter::EncodableMap& params,
               std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void SetBounds(const std::string* window_id,
                 const flutter::EncodableMap& params,
                 std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void GetPosition(const std::string* window_id,
                   std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void GetSize(const std::string* window_id,
               std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void GetBounds(const std::string* window_id,
                 std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void StartDrag(const std::string* window_id,
                 std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void SetDraggable(const std::string* window_id,
                    const flutter::EncodableMap& params,
                    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
};

}  // namespace floating_palette
