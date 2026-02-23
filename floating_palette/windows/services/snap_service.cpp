#include "snap_service.h"

#include "../core/logger.h"
#include "../core/param_helpers.h"

#include <cmath>

namespace floating_palette {

void SnapService::Handle(
    const std::string& command,
    const std::string* window_id,
    const flutter::EncodableMap& params,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (command == "snap") {
    Snap(window_id, params, std::move(result));
  } else if (command == "detach") {
    Detach(window_id, std::move(result));
  } else if (command == "reSnap") {
    ReSnap(window_id, std::move(result));
  } else if (command == "getSnapDistance") {
    GetSnapDistance(window_id, std::move(result));
  } else if (command == "setAutoSnapConfig") {
    SetAutoSnapConfig(window_id, params, std::move(result));
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
}

// DragCoordinatorDelegate

void SnapService::DragBegan(const std::string& id) {
  // Detach from snap when drag starts
  auto it = bindings_.find(id);
  if (it != bindings_.end()) {
    auto* window = WindowStore::Instance().Get(id);
    if (window && window->hwnd) {
      // Restore as top-level window
      SetParent(window->hwnd, NULL);
    }
    bindings_.erase(it);
    if (event_sink_) {
      flutter::EncodableMap data;
      event_sink_("snap", "detached", &id, data);
    }
  }
}

void SnapService::DragMoved(const std::string& id, const RECT& frame) {
  // Check for auto-snap proximity
  auto config_it = auto_snap_configs_.find(id);
  if (config_it == auto_snap_configs_.end() || !config_it->second.enabled) {
    return;
  }

  // Auto-snap proximity detection during drag is handled here
  // The Dart side handles the visual feedback
}

void SnapService::DragEnded(const std::string& id, const RECT& frame) {
  // Check for auto-snap at drag end
  auto config_it = auto_snap_configs_.find(id);
  if (config_it == auto_snap_configs_.end() || !config_it->second.enabled) {
    return;
  }

  const auto& config = config_it->second;
  double proximity = config.proximity;

  // Check proximity to all other visible palette windows
  auto all = WindowStore::Instance().All();
  for (auto& [target_id, target] : all) {
    if (target_id == id || !target->hwnd) continue;
    if (!::IsWindowVisible(target->hwnd)) continue;

    RECT target_rect;
    GetWindowRect(target->hwnd, &target_rect);

    // Check distance between edges
    double dist_right =
        std::abs(frame.right - target_rect.left);  // snap to left of target
    double dist_left =
        std::abs(frame.left - target_rect.right);  // snap to right of target
    double dist_bottom =
        std::abs(frame.bottom - target_rect.top);  // snap above target
    double dist_top =
        std::abs(frame.top - target_rect.bottom);  // snap below target

    double min_dist =
        (std::min)({dist_right, dist_left, dist_bottom, dist_top});
    if (min_dist <= proximity) {
      // Auto-snap to closest edge
      SnapBinding binding;
      binding.follower_id = id;
      binding.target_id = target_id;

      if (min_dist == dist_right) binding.edge = "right";
      else if (min_dist == dist_left) binding.edge = "left";
      else if (min_dist == dist_bottom) binding.edge = "bottom";
      else binding.edge = "top";

      bindings_[id] = binding;
      PositionFollower(binding);

      if (event_sink_) {
        flutter::EncodableMap data{
            {flutter::EncodableValue("targetId"),
             flutter::EncodableValue(target_id)},
            {flutter::EncodableValue("edge"),
             flutter::EncodableValue(binding.edge)},
        };
        event_sink_("snap", "snapped", &id, data);
      }
      break;
    }
  }
}

void SnapService::PositionFollower(const SnapBinding& binding) {
  auto* follower = WindowStore::Instance().Get(binding.follower_id);
  auto* target = WindowStore::Instance().Get(binding.target_id);
  if (!follower || !follower->hwnd || !target || !target->hwnd) return;

  RECT target_rect;
  GetWindowRect(target->hwnd, &target_rect);

  RECT follower_rect;
  GetWindowRect(follower->hwnd, &follower_rect);
  int fw = follower_rect.right - follower_rect.left;
  int fh = follower_rect.bottom - follower_rect.top;

  int new_x = 0, new_y = 0;

  if (binding.edge == "right") {
    new_x = target_rect.right;
    new_y = target_rect.top;
  } else if (binding.edge == "left") {
    new_x = target_rect.left - fw;
    new_y = target_rect.top;
  } else if (binding.edge == "bottom") {
    new_x = target_rect.left;
    new_y = target_rect.bottom;
  } else if (binding.edge == "top") {
    new_x = target_rect.left;
    new_y = target_rect.top - fh;
  }

  new_x += static_cast<int>(binding.offset_x);
  new_y += static_cast<int>(binding.offset_y);

  SetWindowPos(follower->hwnd, NULL, new_x, new_y, 0, 0,
               SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE);
}

// Commands

void SnapService::Snap(
    const std::string* window_id,
    const flutter::EncodableMap& params,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (!window_id) {
    result->Error("MISSING_ID", "windowId required");
    return;
  }

  std::string target_id = GetString(params, "targetId", "");
  if (target_id.empty()) {
    result->Error("MISSING_TARGET", "targetId required");
    return;
  }

  SnapBinding binding;
  binding.follower_id = *window_id;
  binding.target_id = target_id;
  binding.edge = GetString(params, "edge", "right");
  binding.offset_x = GetDouble(params, "offsetX", 0);
  binding.offset_y = GetDouble(params, "offsetY", 0);

  bindings_[*window_id] = binding;
  PositionFollower(binding);

  if (event_sink_) {
    flutter::EncodableMap data{
        {flutter::EncodableValue("targetId"),
         flutter::EncodableValue(target_id)},
        {flutter::EncodableValue("edge"),
         flutter::EncodableValue(binding.edge)},
    };
    event_sink_("snap", "snapped", window_id, data);
  }

  result->Success(flutter::EncodableValue());
}

void SnapService::Detach(
    const std::string* window_id,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (!window_id) {
    result->Error("MISSING_ID", "windowId required");
    return;
  }

  auto it = bindings_.find(*window_id);
  if (it != bindings_.end()) {
    auto* window = WindowStore::Instance().Get(*window_id);
    if (window && window->hwnd) {
      SetParent(window->hwnd, NULL);
    }
    bindings_.erase(it);

    if (event_sink_) {
      flutter::EncodableMap data;
      event_sink_("snap", "detached", window_id, data);
    }
  }

  result->Success(flutter::EncodableValue());
}

void SnapService::ReSnap(
    const std::string* window_id,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (!window_id) {
    result->Success(flutter::EncodableValue());
    return;
  }

  // Reposition followers of this window
  for (auto& [follower_id, binding] : bindings_) {
    if (binding.target_id == *window_id) {
      PositionFollower(binding);
    }
  }

  // Also reposition this window if it's a follower
  auto it = bindings_.find(*window_id);
  if (it != bindings_.end()) {
    PositionFollower(it->second);
  }

  result->Success(flutter::EncodableValue());
}

void SnapService::GetSnapDistance(
    const std::string* window_id,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (!window_id) {
    result->Success(flutter::EncodableValue(0.0));
    return;
  }

  auto it = bindings_.find(*window_id);
  if (it == bindings_.end()) {
    result->Success(flutter::EncodableValue(0.0));
    return;
  }

  // Return the distance between follower and target edges
  auto* follower = WindowStore::Instance().Get(it->second.follower_id);
  auto* target = WindowStore::Instance().Get(it->second.target_id);
  if (!follower || !follower->hwnd || !target || !target->hwnd) {
    result->Success(flutter::EncodableValue(0.0));
    return;
  }

  RECT fr, tr;
  GetWindowRect(follower->hwnd, &fr);
  GetWindowRect(target->hwnd, &tr);

  double dist = 0;
  if (it->second.edge == "right") dist = std::abs(fr.left - tr.right);
  else if (it->second.edge == "left") dist = std::abs(fr.right - tr.left);
  else if (it->second.edge == "bottom") dist = std::abs(fr.top - tr.bottom);
  else if (it->second.edge == "top") dist = std::abs(fr.bottom - tr.top);

  result->Success(flutter::EncodableValue(dist));
}

void SnapService::SetAutoSnapConfig(
    const std::string* window_id,
    const flutter::EncodableMap& params,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (!window_id) {
    result->Error("MISSING_ID", "windowId required");
    return;
  }

  AutoSnapConfig config;
  config.proximity = GetDouble(params, "proximity", 20.0);
  config.enabled = GetBool(params, "enabled", true);
  config.preferred_edge = GetString(params, "preferredEdge", "right");

  auto_snap_configs_[*window_id] = config;

  result->Success(flutter::EncodableValue());
}

}  // namespace floating_palette
