#include "message_service.h"

#include "../core/logger.h"

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
  // TODO: Route message to palette's messenger channel
  FP_LOG("Message", "send stub");
  result->Success(flutter::EncodableValue());
}

}  // namespace floating_palette
