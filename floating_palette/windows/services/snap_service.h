#pragma once

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <string>
#include <unordered_map>

#include "../coordinators/drag_coordinator.h"
#include "../core/window_store.h"

namespace floating_palette {

struct SnapBinding {
  std::string follower_id;
  std::string target_id;
  std::string edge;       // "top", "bottom", "left", "right"
  double offset_x = 0;
  double offset_y = 0;
};

struct AutoSnapConfig {
  double proximity = 20.0;
  bool enabled = false;
  std::string preferred_edge = "right";
};

class SnapService : public DragCoordinatorDelegate {
 public:
  void SetEventSink(EventSink sink) { event_sink_ = std::move(sink); }
  void Handle(const std::string& command,
              const std::string* window_id,
              const flutter::EncodableMap& params,
              std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  // Called by VisibilityService when windows show/hide
  void OnWindowShown(const std::string& id);
  void OnWindowHidden(const std::string& id);
  void OnWindowDestroyed(const std::string& id);

  // DragCoordinatorDelegate
  void DragBegan(const std::string& id) override;
  void DragMoved(const std::string& id, const RECT& frame) override;
  void DragEnded(const std::string& id, const RECT& frame) override;

 private:
  EventSink event_sink_;

  std::unordered_map<std::string, SnapBinding> bindings_;
  std::unordered_map<std::string, AutoSnapConfig> auto_snap_configs_;

  void PositionFollower(const SnapBinding& binding);

  void Snap(const std::string* window_id,
            const flutter::EncodableMap& params,
            std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void Detach(const std::string* window_id,
              std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void ReSnap(const std::string* window_id,
              std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void GetSnapDistance(const std::string* window_id,
                       std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void SetAutoSnapConfig(const std::string* window_id,
                         const flutter::EncodableMap& params,
                         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
};

}  // namespace floating_palette
