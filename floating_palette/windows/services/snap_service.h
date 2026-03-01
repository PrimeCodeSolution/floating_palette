#pragma once

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <optional>
#include <string>
#include <unordered_map>
#include <unordered_set>

#include "../coordinators/drag_coordinator.h"
#include "../core/window_store.h"

namespace floating_palette {

struct SnapBinding {
  std::string follower_id;
  std::string target_id;
  std::string follower_edge;  // "top", "bottom", "left", "right"
  std::string target_edge;    // "top", "bottom", "left", "right"
  std::string alignment;      // "leading", "center", "trailing"
  double gap = 0;
  std::string on_target_hidden;     // from config
  std::string on_target_destroyed;  // from config
};

struct AutoSnapConfig {
  std::unordered_set<std::string> can_snap_from;   // edges this palette can snap from
  std::unordered_set<std::string> accepts_snap_on;  // edges that accept incoming snaps
  std::unordered_set<std::string> target_ids;       // empty = all palettes
  double proximity_threshold = 50.0;
  bool show_feedback = true;
};

struct ProximityState {
  std::string dragged_id;
  std::string target_id;
  std::string dragged_edge;
  std::string target_edge;
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

  // Called by FrameService / DragCoordinator when a window moves.
  // Repositions any followers snapped to this window.
  void OnWindowMoved(const std::string& id);

  // DragCoordinatorDelegate
  void DragBegan(const std::string& id) override;
  void DragMoved(const std::string& id, const RECT& frame) override;
  void DragEnded(const std::string& id, const RECT& frame) override;

 private:
  EventSink event_sink_;

  std::unordered_map<std::string, SnapBinding> bindings_;
  std::unordered_map<std::string, AutoSnapConfig> auto_snap_configs_;
  std::optional<ProximityState> proximity_state_;

  struct SnapPosition { int x; int y; };
  SnapPosition CalculateSnapPosition(const SnapBinding& binding);
  void PositionFollower(const SnapBinding& binding);

  void CheckProximity(const std::string& dragged_id, const RECT& frame);
  static bool AreCompatibleEdges(const std::string& drag_edge,
                                 const std::string& target_edge);
  static double CalculateEdgeDistance(const RECT& dragged, const std::string& dragged_edge,
                                     const RECT& target, const std::string& target_edge);

  void Snap(const flutter::EncodableMap& params,
            std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void Detach(const flutter::EncodableMap& params,
              std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void ReSnap(const flutter::EncodableMap& params,
              std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void GetSnapDistance(const flutter::EncodableMap& params,
                       std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void SetAutoSnapConfig(const flutter::EncodableMap& params,
                         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
};

}  // namespace floating_palette
