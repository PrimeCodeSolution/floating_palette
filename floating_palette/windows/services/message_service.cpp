#include "message_service.h"

#include "../core/logger.h"
#include "../core/param_helpers.h"

namespace floating_palette {

void MessageService::Handle(
    const std::string& command,
    const std::string* window_id,
    const flutter::EncodableMap& params,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (command == "send") {
    Send(window_id, params, std::move(result));
  } else {
    result->Error("UNKNOWN_COMMAND", "Unknown message command: " + command);
  }
}

void MessageService::Send(
    const std::string* window_id,
    const flutter::EncodableMap& params,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (!window_id) {
    result->Error("MISSING_ID", "windowId required");
    return;
  }

  auto* window = WindowStore::Instance().Get(*window_id);
  if (!window) {
    result->Error("NOT_FOUND", "Window not found: " + *window_id);
    return;
  }

  // Forward message to the palette's messenger channel
  if (window->messenger_channel) {
    window->messenger_channel->InvokeMethod(
        "receive",
        std::make_unique<flutter::EncodableValue>(
            flutter::EncodableValue(params)));
  }

  result->Success(flutter::EncodableValue());
}

}  // namespace floating_palette
