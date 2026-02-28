#include "snap_service.h"

#include "../core/dpi_helper.h"
#include "../core/logger.h"
#include "../core/param_helpers.h"

#include <cmath>

namespace floating_palette {

void SnapService::Handle(
    const std::string& command,
    const std::string* window_id,
    const flutter::EncodableMap& params,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  // All commands read IDs from params (matching macOS / Dart SnapClient API).
  // The envelope window_id is ignored for snap commands.
  if (command == "snap") {
    Snap(params, std::move(result));
  } else if (command == "detach") {
    Detach(params, std::move(result));
  } else if (command == "reSnap") {
    ReSnap(params, std::move(result));
  } else if (command == "getSnapDistance") {
    GetSnapDistance(params, std::move(result));
  } else if (command == "setAutoSnapConfig") {
    SetAutoSnapConfig(params, std::move(result));
  } else {
    result->Error("UNKNOWN_COMMAND", "Unknown snap command: " + command);
  }
}

void SnapService::OnWindowShown(const std::string& id) {
  // Reposition any followers snapped to this window
  for (auto& [follower_id, binding] : bindings_) {
    if (binding.target_id == id) {
      PositionFollower(binding);
    }
  }
}

void SnapService::OnWindowMoved(const std::string& id) {
  // Reposition any followers snapped to this window
  for (auto& [follower_id, binding] : bindings_) {
    if (binding.target_id == id) {
      PositionFollower(binding);
    }
  }
}

void SnapService::OnWindowHidden(const std::string& id) {
  // Nothing to do -- followers stay in place
  FP_LOG("Snap", "onWindowHidden: " + id);
}

void SnapService::OnWindowDestroyed(const std::string& id) {
  // Remove bindings where this window is follower
  bindings_.erase(id);

  // Remove bindings where this window is target
  for (auto it = bindings_.begin(); it != bindings_.end();) {
    if (it->second.target_id == id) {
      it = bindings_.erase(it);
    } else {
      ++it;
    }
  }

  auto_snap_configs_.erase(id);

  // Clear proximity state if it involves this window
  if (proximity_state_ &&
      (proximity_state_->dragged_id == id || proximity_state_->target_id == id)) {
    proximity_state_.reset();
  }
}

// DragCoordinatorDelegate

void SnapService::DragBegan(const std::string& id) {
  // Detach from snap when drag starts
  auto it = bindings_.find(id);
  if (it != bindings_.end()) {
    auto* window = WindowStore::Instance().Get(id);
    if (window && window->hwnd) {
      SetParent(window->hwnd, NULL);
    }
    bindings_.erase(it);
    if (event_sink_) {
      flutter::EncodableMap data;
      event_sink_("snap", "detached", &id, data);
    }
  }

  // Clear stale proximity state from previous drag
  if (proximity_state_ && proximity_state_->dragged_id == id) {
    proximity_state_.reset();
  }
}

void SnapService::DragMoved(const std::string& id, const RECT& frame) {
  // Reposition any followers snapped to the dragged window (target following)
  for (auto& [follower_id, binding] : bindings_) {
    if (binding.target_id == id) {
      PositionFollower(binding);
    }
  }

  // Check proximity for auto-snap (unsnapped window being dragged)
  if (bindings_.find(id) == bindings_.end()) {
    CheckProximity(id, frame);
  }
}

void SnapService::DragEnded(const std::string& id, const RECT& frame) {
  // Auto-snap if in proximity at drag end
  if (proximity_state_ && proximity_state_->dragged_id == id) {
    auto& prox = *proximity_state_;

    SnapBinding binding;
    binding.follower_id = id;
    binding.target_id = prox.target_id;
    binding.follower_edge = prox.dragged_edge;
    binding.target_edge = prox.target_edge;
    binding.alignment = "center";
    binding.gap = 4;

    bindings_[id] = binding;
    PositionFollower(binding);

    if (event_sink_) {
      flutter::EncodableMap data{
          {flutter::EncodableValue("targetId"),
           flutter::EncodableValue(prox.target_id)},
      };
      event_sink_("snap", "snapped", &id, data);
    }
    proximity_state_.reset();
  }
}

SnapService::SnapPosition SnapService::CalculateSnapPosition(
    const SnapBinding& binding) {
  auto* follower = WindowStore::Instance().Get(binding.follower_id);
  auto* target = WindowStore::Instance().Get(binding.target_id);
  if (!follower || !follower->hwnd || !target || !target->hwnd) return {0, 0};

  RECT target_rect;
  GetWindowRect(target->hwnd, &target_rect);

  RECT follower_rect;
  GetWindowRect(follower->hwnd, &follower_rect);
  int fw = follower_rect.right - follower_rect.left;
  int fh = follower_rect.bottom - follower_rect.top;

  int tw = target_rect.right - target_rect.left;
  int th = target_rect.bottom - target_rect.top;

  // Gap comes from Dart (logical pixels) — convert to physical
  double scale = GetScaleFactorForHwnd(target->hwnd);
  int gap = LogicalToPhysical(binding.gap, scale);
  int new_x = 0, new_y = 0;

  // Calculate position based on edge pair (matching macOS calculateSnapPosition).
  // Note: Windows Y is top-down (0 = top of screen), macOS Y is bottom-up.
  const auto& fe = binding.follower_edge;
  const auto& te = binding.target_edge;

  if (fe == "top" && te == "bottom") {
    // Follower's top meets target's bottom -> follower goes below target
    new_y = target_rect.bottom + gap;
  } else if (fe == "bottom" && te == "top") {
    // Follower's bottom meets target's top -> follower goes above target
    new_y = target_rect.top - fh - gap;
  } else if (fe == "left" && te == "right") {
    // Follower's left meets target's right -> follower goes to right of target
    new_x = target_rect.right + gap;
  } else if (fe == "right" && te == "left") {
    // Follower's right meets target's left -> follower goes to left of target
    new_x = target_rect.left - fw - gap;
  }

  // Calculate alignment along the perpendicular axis
  bool is_vertical_snap = (fe == "top" || fe == "bottom");
  if (is_vertical_snap) {
    // Align along X axis
    if (binding.alignment == "leading") {
      new_x = target_rect.left;
    } else if (binding.alignment == "trailing") {
      new_x = target_rect.right - fw;
    } else {
      // center (default)
      new_x = target_rect.left + (tw - fw) / 2;
    }
  } else {
    // Align along Y axis
    if (binding.alignment == "leading") {
      new_y = target_rect.top;
    } else if (binding.alignment == "trailing") {
      new_y = target_rect.bottom - fh;
    } else {
      // center (default)
      new_y = target_rect.top + (th - fh) / 2;
    }
  }

  return {new_x, new_y};
}

void SnapService::PositionFollower(const SnapBinding& binding) {
  auto* follower = WindowStore::Instance().Get(binding.follower_id);
  if (!follower || !follower->hwnd) return;

  auto pos = CalculateSnapPosition(binding);
  SetWindowPos(follower->hwnd, NULL, pos.x, pos.y, 0, 0,
               SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE);
}

// Proximity Detection

bool SnapService::AreCompatibleEdges(const std::string& drag_edge,
                                     const std::string& target_edge) {
  return (drag_edge == "top" && target_edge == "bottom") ||
         (drag_edge == "bottom" && target_edge == "top") ||
         (drag_edge == "left" && target_edge == "right") ||
         (drag_edge == "right" && target_edge == "left");
}

double SnapService::CalculateEdgeDistance(
    const RECT& dragged, const std::string& dragged_edge,
    const RECT& target, const std::string& target_edge) {
  // Check perpendicular overlap (edges must be in range to snap)
  bool is_vertical = (dragged_edge == "top" || dragged_edge == "bottom");
  if (is_vertical) {
    // Horizontal overlap required
    long overlap = (std::min)(dragged.right, target.right) -
                   (std::max)(dragged.left, target.left);
    if (overlap <= 0) return 1e9;
  } else {
    // Vertical overlap required
    long overlap = (std::min)(dragged.bottom, target.bottom) -
                   (std::max)(dragged.top, target.top);
    if (overlap <= 0) return 1e9;
  }

  // Calculate edge-to-edge distance
  if (dragged_edge == "top" && target_edge == "bottom")
    return std::abs(static_cast<double>(dragged.top - target.bottom));
  if (dragged_edge == "bottom" && target_edge == "top")
    return std::abs(static_cast<double>(dragged.bottom - target.top));
  if (dragged_edge == "left" && target_edge == "right")
    return std::abs(static_cast<double>(dragged.left - target.right));
  if (dragged_edge == "right" && target_edge == "left")
    return std::abs(static_cast<double>(dragged.right - target.left));
  return 1e9;
}

void SnapService::CheckProximity(const std::string& dragged_id,
                                 const RECT& frame) {
  auto drag_config_it = auto_snap_configs_.find(dragged_id);
  if (drag_config_it == auto_snap_configs_.end() ||
      drag_config_it->second.can_snap_from.empty()) {
    // Clear proximity if no longer configured
    if (proximity_state_ && proximity_state_->dragged_id == dragged_id) {
      if (event_sink_) {
        flutter::EncodableMap data{
            {flutter::EncodableValue("targetId"),
             flutter::EncodableValue(proximity_state_->target_id)},
        };
        event_sink_("snap", "proximityExited", &dragged_id, data);
      }
      proximity_state_.reset();
    }
    return;
  }
  const auto& drag_config = drag_config_it->second;

  struct BestMatch {
    std::string target_id;
    std::string dragged_edge;
    std::string target_edge;
    double distance;
  };
  std::optional<BestMatch> best;

  for (auto& [target_id, target_config] : auto_snap_configs_) {
    if (target_id == dragged_id) continue;
    if (target_config.accepts_snap_on.empty()) continue;

    // Check target_ids filter
    if (!drag_config.target_ids.empty() &&
        drag_config.target_ids.find(target_id) == drag_config.target_ids.end()) {
      continue;
    }

    // Skip if target already follows the dragged window (avoid reverse)
    auto existing = bindings_.find(target_id);
    if (existing != bindings_.end() && existing->second.target_id == dragged_id) {
      continue;
    }

    auto* target_window = WindowStore::Instance().Get(target_id);
    if (!target_window || !target_window->hwnd) continue;
    if (!::IsWindowVisible(target_window->hwnd)) continue;

    RECT target_rect;
    GetWindowRect(target_window->hwnd, &target_rect);

    // Scale proximity threshold from logical (Dart) to physical (Win32)
    double prox_scale = GetScaleFactorForHwnd(target_window->hwnd);
    double physical_threshold = drag_config.proximity_threshold * prox_scale;

    // Check each edge combination
    for (const auto& drag_edge : drag_config.can_snap_from) {
      for (const auto& target_edge : target_config.accepts_snap_on) {
        if (!AreCompatibleEdges(drag_edge, target_edge)) continue;

        double dist = CalculateEdgeDistance(frame, drag_edge,
                                            target_rect, target_edge);
        if (dist < physical_threshold) {
          if (!best || dist < best->distance) {
            best = {target_id, drag_edge, target_edge, dist};
          }
        }
      }
    }
  }

  // Update proximity state and emit events
  if (best) {
    if (!proximity_state_ ||
        proximity_state_->target_id != best->target_id ||
        proximity_state_->dragged_edge != best->dragged_edge ||
        proximity_state_->target_edge != best->target_edge) {
      // New proximity or edge change
      if (proximity_state_ && event_sink_) {
        flutter::EncodableMap data{
            {flutter::EncodableValue("targetId"),
             flutter::EncodableValue(proximity_state_->target_id)},
        };
        event_sink_("snap", "proximityExited", &dragged_id, data);
      }
      proximity_state_ = ProximityState{
          dragged_id, best->target_id, best->dragged_edge, best->target_edge};
      if (event_sink_) {
        flutter::EncodableMap data{
            {flutter::EncodableValue("targetId"),
             flutter::EncodableValue(best->target_id)},
            {flutter::EncodableValue("draggedEdge"),
             flutter::EncodableValue(best->dragged_edge)},
            {flutter::EncodableValue("targetEdge"),
             flutter::EncodableValue(best->target_edge)},
            {flutter::EncodableValue("distance"),
             flutter::EncodableValue(best->distance)},
        };
        event_sink_("snap", "proximityEntered", &dragged_id, data);
      }
    } else {
      // Same proximity, update distance
      if (event_sink_) {
        flutter::EncodableMap data{
            {flutter::EncodableValue("targetId"),
             flutter::EncodableValue(best->target_id)},
            {flutter::EncodableValue("distance"),
             flutter::EncodableValue(best->distance)},
        };
        event_sink_("snap", "proximityUpdated", &dragged_id, data);
      }
    }
  } else if (proximity_state_ && proximity_state_->dragged_id == dragged_id) {
    // Exited proximity
    if (event_sink_) {
      flutter::EncodableMap data{
          {flutter::EncodableValue("targetId"),
           flutter::EncodableValue(proximity_state_->target_id)},
      };
      event_sink_("snap", "proximityExited", &dragged_id, data);
    }
    proximity_state_.reset();
  }
}

// Commands

void SnapService::Snap(
    const flutter::EncodableMap& params,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  std::string follower_id = GetString(params, "followerId", "");
  std::string target_id = GetString(params, "targetId", "");
  if (follower_id.empty() || target_id.empty()) {
    result->Error("INVALID_PARAMS", "followerId and targetId required");
    return;
  }

  std::string follower_edge = GetString(params, "followerEdge", "top");
  std::string target_edge = GetString(params, "targetEdge", "bottom");
  std::string alignment = GetString(params, "alignment", "center");
  double gap = GetDouble(params, "gap", 0);

  // Read config sub-map for onTargetHidden / onTargetDestroyed
  std::string on_target_hidden = "hideFollower";
  std::string on_target_destroyed = "hideAndDetach";
  auto config_it = params.find(flutter::EncodableValue("config"));
  if (config_it != params.end() &&
      std::holds_alternative<flutter::EncodableMap>(config_it->second)) {
    const auto& config = std::get<flutter::EncodableMap>(config_it->second);
    on_target_hidden = GetString(config, "onTargetHidden", "hideFollower");
    on_target_destroyed = GetString(config, "onTargetDestroyed", "hideAndDetach");
  }

  SnapBinding binding;
  binding.follower_id = follower_id;
  binding.target_id = target_id;
  binding.follower_edge = follower_edge;
  binding.target_edge = target_edge;
  binding.alignment = alignment;
  binding.gap = gap;
  binding.on_target_hidden = on_target_hidden;
  binding.on_target_destroyed = on_target_destroyed;

  bindings_[follower_id] = binding;
  PositionFollower(binding);

  if (event_sink_) {
    flutter::EncodableMap data{
        {flutter::EncodableValue("targetId"),
         flutter::EncodableValue(target_id)},
    };
    event_sink_("snap", "snapped", &follower_id, data);
  }

  result->Success(flutter::EncodableValue());
}

void SnapService::Detach(
    const flutter::EncodableMap& params,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  std::string follower_id = GetString(params, "followerId", "");
  if (follower_id.empty()) {
    result->Error("INVALID_PARAMS", "followerId required");
    return;
  }

  auto it = bindings_.find(follower_id);
  if (it != bindings_.end()) {
    auto* window = WindowStore::Instance().Get(follower_id);
    if (window && window->hwnd) {
      SetParent(window->hwnd, NULL);
    }
    bindings_.erase(it);

    if (event_sink_) {
      flutter::EncodableMap data;
      event_sink_("snap", "detached", &follower_id, data);
    }
  }

  result->Success(flutter::EncodableValue());
}

void SnapService::ReSnap(
    const flutter::EncodableMap& params,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  std::string follower_id = GetString(params, "followerId", "");
  if (follower_id.empty()) {
    result->Error("INVALID_PARAMS", "followerId required");
    return;
  }

  auto it = bindings_.find(follower_id);
  if (it == bindings_.end()) {
    result->Error("NOT_FOUND", "No binding for follower");
    return;
  }

  PositionFollower(it->second);

  if (event_sink_) {
    flutter::EncodableMap data{
        {flutter::EncodableValue("targetId"),
         flutter::EncodableValue(it->second.target_id)},
    };
    event_sink_("snap", "snapped", &follower_id, data);
  }

  result->Success(flutter::EncodableValue());
}

void SnapService::GetSnapDistance(
    const flutter::EncodableMap& params,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  std::string follower_id = GetString(params, "followerId", "");
  if (follower_id.empty()) {
    result->Success(flutter::EncodableValue(0.0));
    return;
  }

  auto it = bindings_.find(follower_id);
  if (it == bindings_.end()) {
    result->Success(flutter::EncodableValue(0.0));
    return;
  }

  auto* follower = WindowStore::Instance().Get(it->second.follower_id);
  if (!follower || !follower->hwnd) {
    result->Success(flutter::EncodableValue(0.0));
    return;
  }

  RECT fr;
  GetWindowRect(follower->hwnd, &fr);

  auto snap_pos = CalculateSnapPosition(it->second);
  double physical_dist = std::hypot(
      static_cast<double>(snap_pos.x - fr.left),
      static_cast<double>(snap_pos.y - fr.top));

  // Convert physical distance to logical for Dart
  double scale = GetScaleFactorForHwnd(follower->hwnd);
  double dist = PhysicalToLogical(physical_dist, scale);

  result->Success(flutter::EncodableValue(dist));
}

void SnapService::SetAutoSnapConfig(
    const flutter::EncodableMap& params,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  std::string palette_id = GetString(params, "paletteId", "");
  if (palette_id.empty()) {
    result->Error("INVALID_PARAMS", "paletteId required");
    return;
  }

  // Helper to read a string list from an EncodableMap into a set
  auto read_string_set = [](const flutter::EncodableMap& map, const char* key)
      -> std::unordered_set<std::string> {
    std::unordered_set<std::string> result;
    auto it = map.find(flutter::EncodableValue(key));
    if (it != map.end() &&
        std::holds_alternative<flutter::EncodableList>(it->second)) {
      for (const auto& item : std::get<flutter::EncodableList>(it->second)) {
        if (std::holds_alternative<std::string>(item)) {
          result.insert(std::get<std::string>(item));
        }
      }
    }
    return result;
  };

  // Read the config sub-map (Dart sends { paletteId, config: { ... } })
  auto config_it = params.find(flutter::EncodableValue("config"));
  if (config_it != params.end() &&
      std::holds_alternative<flutter::EncodableMap>(config_it->second)) {
    const auto& config_map = std::get<flutter::EncodableMap>(config_it->second);

    auto can_snap_from = read_string_set(config_map, "canSnapFrom");
    auto accepts_snap_on = read_string_set(config_map, "acceptsSnapOn");

    // If config is effectively disabled, remove it
    if (can_snap_from.empty() && accepts_snap_on.empty()) {
      auto_snap_configs_.erase(palette_id);
    } else {
      AutoSnapConfig config;
      config.can_snap_from = std::move(can_snap_from);
      config.accepts_snap_on = std::move(accepts_snap_on);
      config.target_ids = read_string_set(config_map, "targetIds");
      config.proximity_threshold = GetDouble(config_map, "proximityThreshold", 50.0);
      config.show_feedback = GetBool(config_map, "showFeedback", true);
      auto_snap_configs_[palette_id] = std::move(config);
    }
  }

  result->Success(flutter::EncodableValue());
}

}  // namespace floating_palette
