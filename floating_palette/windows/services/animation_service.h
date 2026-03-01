#pragma once

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <string>
#include <unordered_map>

#include "../core/window_store.h"

namespace floating_palette {

struct ActiveAnimation {
  std::string window_id;
  std::string property;  // "x", "y", "width", "height", "opacity"
  double from_value;
  double to_value;
  double duration_ms;
  std::string easing;  // "linear", "easeIn", "easeOut", "easeInOut"
  ULONGLONG start_time;
};

class AnimationService {
 public:
  AnimationService();
  ~AnimationService();

  void SetEventSink(EventSink sink) { event_sink_ = std::move(sink); }
  void Handle(const std::string& command,
              const std::string* window_id,
              const flutter::EncodableMap& params,
              std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

 private:
  EventSink event_sink_;

  // Key: "windowId:property"
  std::unordered_map<std::string, ActiveAnimation> animations_;
  UINT_PTR timer_id_ = 0;

  static AnimationService* instance_;
  static void CALLBACK TimerProc(HWND, UINT, UINT_PTR, DWORD);

  void StartTimer();
  void StopTimer();
  void Tick();
  double ApplyEasing(double t, const std::string& easing);
  void ApplyValue(const std::string& window_id, const std::string& property,
                  double value);

  void Animate(const std::string* window_id,
               const flutter::EncodableMap& params,
               std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void AnimateMultiple(const std::string* window_id,
                       const flutter::EncodableMap& params,
                       std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void Stop(const std::string* window_id,
            std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void StopAll(std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void IsAnimating(const std::string* window_id,
                   std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
};

}  // namespace floating_palette
