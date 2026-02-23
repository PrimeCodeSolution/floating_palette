#pragma once

#include <flutter/binary_messenger.h>
#include <flutter_messenger.h>

#include <map>
#include <memory>
#include <string>

namespace floating_palette {

/// Minimal BinaryMessenger implementation wrapping FlutterDesktopMessengerRef.
/// Used to create per-palette method channels on secondary Flutter engines.
class PaletteBinaryMessenger : public flutter::BinaryMessenger {
 public:
  explicit PaletteBinaryMessenger(FlutterDesktopMessengerRef messenger)
      : messenger_(messenger) {}

  ~PaletteBinaryMessenger() override = default;

  // Non-copyable
  PaletteBinaryMessenger(const PaletteBinaryMessenger&) = delete;
  PaletteBinaryMessenger& operator=(const PaletteBinaryMessenger&) = delete;

  void Send(const std::string& channel,
            const uint8_t* message,
            size_t message_size,
            flutter::BinaryReply reply) const override {
    if (!reply) {
      FlutterDesktopMessengerSend(messenger_, channel.c_str(), message,
                                  message_size);
      return;
    }

    struct Captures {
      flutter::BinaryReply reply;
    };
    auto captures = new Captures();
    captures->reply = std::move(reply);

    auto callback = [](const uint8_t* data, size_t data_size,
                       void* user_data) {
      auto* c = reinterpret_cast<Captures*>(user_data);
      c->reply(data, data_size);
      delete c;
    };

    bool result = FlutterDesktopMessengerSendWithReply(
        messenger_, channel.c_str(), message, message_size, callback, captures);
    if (!result) {
      delete captures;
    }
  }

  void SetMessageHandler(const std::string& channel,
                         flutter::BinaryMessageHandler handler) override {
    if (!handler) {
      handlers_.erase(channel);
      FlutterDesktopMessengerSetCallback(messenger_, channel.c_str(), nullptr,
                                         nullptr);
      return;
    }
    handlers_[channel] = std::move(handler);
    flutter::BinaryMessageHandler* handler_ptr = &handlers_[channel];
    FlutterDesktopMessengerSetCallback(messenger_, channel.c_str(),
                                       ForwardToHandler, handler_ptr);
  }

 private:
  static void ForwardToHandler(FlutterDesktopMessengerRef messenger,
                                const FlutterDesktopMessage* message,
                                void* user_data) {
    auto* response_handle = message->response_handle;
    auto messenger_ptr = std::shared_ptr<FlutterDesktopMessenger>(
        FlutterDesktopMessengerAddRef(messenger),
        &FlutterDesktopMessengerRelease);

    flutter::BinaryReply reply_handler =
        [messenger_ptr, response_handle](
            const uint8_t* reply, size_t reply_size) mutable {
          auto lock = std::unique_ptr<FlutterDesktopMessenger,
                                      decltype(&FlutterDesktopMessengerUnlock)>(
              FlutterDesktopMessengerLock(messenger_ptr.get()),
              &FlutterDesktopMessengerUnlock);
          if (!FlutterDesktopMessengerIsAvailable(messenger_ptr.get())) {
            return;
          }
          if (!response_handle) {
            return;
          }
          FlutterDesktopMessengerSendResponse(messenger_ptr.get(),
                                               response_handle, reply,
                                               reply_size);
          response_handle = nullptr;
        };

    const auto& message_handler =
        *static_cast<flutter::BinaryMessageHandler*>(user_data);
    message_handler(message->message, message->message_size,
                    std::move(reply_handler));
  }

  FlutterDesktopMessengerRef messenger_;
  std::map<std::string, flutter::BinaryMessageHandler> handlers_;
};

}  // namespace floating_palette
