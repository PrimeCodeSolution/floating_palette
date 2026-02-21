#pragma once

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <string>

#include "../core/window_store.h"

namespace floating_palette {

class BackgroundCaptureService;
class DragCoordinator;
class FrameService;
class InputService;
class SnapService;

class WindowService {
 public:
  explicit WindowService(flutter::PluginRegistrarWindows* registrar);

  void SetEventSink(EventSink sink) { event_sink_ = std::move(sink); }
  void Handle(const std::string& command,
              const std::string* window_id,
              const flutter::EncodableMap& params,
              std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  void SetBackgroundCaptureService(BackgroundCaptureService* service) {
    background_capture_service_ = service;
  }
  void SetFrameService(FrameService* service) { frame_service_ = service; }
  void SetSnapService(SnapService* service) { snap_service_ = service; }
  void SetDragCoordinator(DragCoordinator* coordinator) {
    drag_coordinator_ = coordinator;
  }
  void SetInputService(InputService* service) { input_service_ = service; }

 private:
  flutter::PluginRegistrarWindows* registrar_;
  EventSink event_sink_;
  BackgroundCaptureService* background_capture_service_ = nullptr;
  FrameService* frame_service_ = nullptr;
  SnapService* snap_service_ = nullptr;
  DragCoordinator* drag_coordinator_ = nullptr;
  InputService* input_service_ = nullptr;

  void Create(const std::string* window_id,
              const flutter::EncodableMap& params,
              std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void Destroy(const std::string* window_id,
               const flutter::EncodableMap& params,
               std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void Exists(const std::string* window_id,
              std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void SetEntryPoint(const std::string* window_id,
                     const flutter::EncodableMap& params,
                     std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
};

}  // namespace floating_palette
