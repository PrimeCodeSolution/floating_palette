#pragma once

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <memory>

namespace floating_palette {

class AnimationService;
class AppearanceService;
class BackgroundCaptureService;
class DragCoordinator;
class FocusService;
class FrameService;
class HostService;
class InputService;
class MessageService;
class ScreenService;
class SnapService;
class TextSelectionService;
class TransformService;
class VisibilityService;
class WindowService;
class ZOrderService;

/// Floating Palette Plugin
///
/// Architecture:
/// - Dart orchestrates (all business logic)
/// - Native executes (stateless service primitives)
///
/// Commands come in via method channel, get routed to services.
/// Events go back via method channel.
class FloatingPalettePlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(
      flutter::PluginRegistrarWindows* registrar);

  FloatingPalettePlugin(flutter::PluginRegistrarWindows* registrar,
                        std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel);
  ~FloatingPalettePlugin();

 private:
  flutter::PluginRegistrarWindows* registrar_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;

  // Services
  std::unique_ptr<WindowService> window_service_;
  std::unique_ptr<VisibilityService> visibility_service_;
  std::unique_ptr<FrameService> frame_service_;
  std::unique_ptr<TransformService> transform_service_;
  std::unique_ptr<AnimationService> animation_service_;
  std::unique_ptr<InputService> input_service_;
  std::unique_ptr<FocusService> focus_service_;
  std::unique_ptr<ZOrderService> zorder_service_;
  std::unique_ptr<AppearanceService> appearance_service_;
  std::unique_ptr<ScreenService> screen_service_;
  std::unique_ptr<BackgroundCaptureService> background_capture_service_;
  std::unique_ptr<MessageService> message_service_;
  std::unique_ptr<HostService> host_service_;
  std::unique_ptr<SnapService> snap_service_;
  std::unique_ptr<TextSelectionService> text_selection_service_;
  std::unique_ptr<DragCoordinator> drag_coordinator_;

  void InitializeServices();
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void SendEvent(const std::string& service,
                 const std::string& event,
                 const std::string* window_id,
                 const flutter::EncodableMap& data);
};

}  // namespace floating_palette
