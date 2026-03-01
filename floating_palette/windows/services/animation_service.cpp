#include "animation_service.h"

#include <flutter/method_result_functions.h>

#include "../core/dpi_helper.h"
#include "../core/logger.h"
#include "../core/param_helpers.h"

namespace floating_palette {

AnimationService* AnimationService::instance_ = nullptr;

AnimationService::AnimationService() {
  instance_ = this;
}

AnimationService::~AnimationService() {
  StopTimer();
  if (instance_ == this) instance_ = nullptr;
}

void AnimationService::Handle(
    const std::string& command,
    const std::string* window_id,
    const flutter::EncodableMap& params,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (command == "animate") {
    Animate(window_id, params, std::move(result));
  } else if (command == "animateMultiple") {
    AnimateMultiple(window_id, params, std::move(result));
  } else if (command == "stop") {
    Stop(window_id, std::move(result));
  } else if (command == "stopAll") {
    StopAll(std::move(result));
  } else if (command == "isAnimating") {
    IsAnimating(window_id, std::move(result));
  } else {
    result->Error("UNKNOWN_COMMAND", "Unknown animation command: " + command);
  }
}

void CALLBACK AnimationService::TimerProc(HWND, UINT, UINT_PTR, DWORD) {
  if (instance_) {
    instance_->Tick();
  }
}

void AnimationService::StartTimer() {
  if (timer_id_ != 0) return;
  timer_id_ = SetTimer(NULL, 0, 16, TimerProc);  // ~60fps
}

void AnimationService::StopTimer() {
  if (timer_id_ != 0) {
    KillTimer(NULL, timer_id_);
    timer_id_ = 0;
  }
}

double AnimationService::ApplyEasing(double t, const std::string& easing) {
  if (t <= 0.0) return 0.0;
  if (t >= 1.0) return 1.0;

  if (easing == "easeIn") {
    return t * t;
  } else if (easing == "easeOut") {
    return 1.0 - (1.0 - t) * (1.0 - t);
  } else if (easing == "easeInOut") {
    if (t < 0.5) {
      return 4.0 * t * t * t;
    } else {
      double f = (2.0 * t - 2.0);
      return 0.5 * f * f * f + 1.0;
    }
  }
  // linear
  return t;
}

void AnimationService::ApplyValue(const std::string& window_id,
                                  const std::string& property,
                                  double value) {
  auto* window = WindowStore::Instance().Get(window_id);
  if (!window || !window->hwnd) return;

  if (property == "opacity") {
    window->opacity = value;
    BYTE alpha = static_cast<BYTE>(value * 255.0);
    SetLayeredWindowAttributes(window->hwnd, RGB(1, 0, 1), alpha, LWA_COLORKEY | LWA_ALPHA);
  } else {
    // value is in logical pixels; convert to physical for SetWindowPos
    double scale = GetScaleFactorForHwnd(window->hwnd);

    RECT rect;
    GetWindowRect(window->hwnd, &rect);

    // Current position/size are already physical
    int x = rect.left;
    int y = rect.top;
    int w = rect.right - rect.left;
    int h = rect.bottom - rect.top;

    // Convert the animated logical value to physical
    if (property == "x") x = LogicalToPhysical(value, scale);
    else if (property == "y") y = LogicalToPhysical(value, scale);
    else if (property == "width") w = LogicalToPhysical(value, scale);
    else if (property == "height") h = LogicalToPhysical(value, scale);

    UINT flags = SWP_NOZORDER | SWP_NOACTIVATE;
    if (property == "x" || property == "y") flags |= SWP_NOSIZE;
    else flags |= SWP_NOMOVE;

    SetWindowPos(window->hwnd, NULL, x, y, w, h, flags);

    // Resize Flutter child if size changed
    if (property == "width" || property == "height") {
      HWND child = GetWindow(window->hwnd, GW_CHILD);
      if (child) {
        SetWindowPos(child, NULL, 0, 0, w, h,
                     SWP_NOMOVE | SWP_NOZORDER | SWP_NOACTIVATE);
      }
    }
  }
}

void AnimationService::Tick() {
  ULONGLONG now = GetTickCount64();
  std::vector<std::string> completed;

  for (auto& [key, anim] : animations_) {
    double elapsed = static_cast<double>(now - anim.start_time);
    double t = elapsed / anim.duration_ms;

    if (t >= 1.0) {
      ApplyValue(anim.window_id, anim.property, anim.to_value);
      completed.push_back(key);
    } else {
      double eased = ApplyEasing(t, anim.easing);
      double value = anim.from_value + (anim.to_value - anim.from_value) * eased;
      ApplyValue(anim.window_id, anim.property, value);
    }
  }

  for (const auto& key : completed) {
    auto it = animations_.find(key);
    if (it != animations_.end()) {
      std::string window_id = it->second.window_id;
      std::string property = it->second.property;
      animations_.erase(it);

      if (event_sink_) {
        flutter::EncodableMap data{
            {flutter::EncodableValue("property"),
             flutter::EncodableValue(property)},
        };
        event_sink_("animation", "complete", &window_id, data);
      }
    }
  }

  if (animations_.empty()) {
    StopTimer();
  }
}

void AnimationService::Animate(
    const std::string* window_id,
    const flutter::EncodableMap& params,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (!window_id) {
    result->Error("MISSING_ID", "windowId required");
    return;
  }

  auto* window = WindowStore::Instance().Get(*window_id);
  if (!window || !window->hwnd) {
    result->Error("NOT_FOUND", "Window not found");
    return;
  }

  std::string property = GetString(params, "property", "");
  double to_value = GetDouble(params, "to", 0);
  double duration = GetDouble(params, "duration", 300);
  std::string easing = GetString(params, "easing", "easeInOut");

  // Get current value as "from" (convert physical to logical for Dart consistency)
  double from_value = 0;
  RECT rect;
  GetWindowRect(window->hwnd, &rect);
  double scale = GetScaleFactorForHwnd(window->hwnd);

  if (property == "x") from_value = PhysicalToLogical(rect.left, scale);
  else if (property == "y") from_value = PhysicalToLogical(rect.top, scale);
  else if (property == "width") from_value = PhysicalToLogical(rect.right - rect.left, scale);
  else if (property == "height") from_value = PhysicalToLogical(rect.bottom - rect.top, scale);
  else if (property == "opacity") from_value = window->opacity;

  // Allow explicit "from" override
  from_value = GetDouble(params, "from", from_value);

  ActiveAnimation anim;
  anim.window_id = *window_id;
  anim.property = property;
  anim.from_value = from_value;
  anim.to_value = to_value;
  anim.duration_ms = duration;
  anim.easing = easing;
  anim.start_time = GetTickCount64();

  std::string key = *window_id + ":" + property;
  animations_[key] = anim;

  StartTimer();
  result->Success(flutter::EncodableValue());
}

void AnimationService::AnimateMultiple(
    const std::string* window_id,
    const flutter::EncodableMap& params,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (!window_id) {
    result->Error("MISSING_ID", "windowId required");
    return;
  }

  auto anims_it = params.find(flutter::EncodableValue("animations"));
  if (anims_it == params.end() ||
      !std::holds_alternative<flutter::EncodableList>(anims_it->second)) {
    result->Error("INVALID_PARAMS", "Missing 'animations' list");
    return;
  }

  const auto& anims_list = std::get<flutter::EncodableList>(anims_it->second);
  for (const auto& item : anims_list) {
    if (std::holds_alternative<flutter::EncodableMap>(item)) {
      const auto& anim_params = std::get<flutter::EncodableMap>(item);
      // Reuse Animate with a discarded result
      Animate(window_id, anim_params,
              std::make_unique<flutter::MethodResultFunctions<flutter::EncodableValue>>(
                  nullptr, nullptr, nullptr));
    }
  }

  result->Success(flutter::EncodableValue());
}

void AnimationService::Stop(
    const std::string* window_id,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (!window_id) {
    result->Error("MISSING_ID", "windowId required");
    return;
  }

  // Remove all animations for this window
  for (auto it = animations_.begin(); it != animations_.end();) {
    if (it->second.window_id == *window_id) {
      it = animations_.erase(it);
    } else {
      ++it;
    }
  }

  if (animations_.empty()) StopTimer();

  result->Success(flutter::EncodableValue());
}

void AnimationService::StopAll(
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  animations_.clear();
  StopTimer();
  result->Success(flutter::EncodableValue());
}

void AnimationService::IsAnimating(
    const std::string* window_id,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (!window_id) {
    result->Success(flutter::EncodableValue(false));
    return;
  }

  for (const auto& [key, anim] : animations_) {
    if (anim.window_id == *window_id) {
      result->Success(flutter::EncodableValue(true));
      return;
    }
  }

  result->Success(flutter::EncodableValue(false));
}

}  // namespace floating_palette
