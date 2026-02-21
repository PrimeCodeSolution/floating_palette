#include "host_service.h"

#include "../core/logger.h"

namespace floating_palette {

void HostService::Handle(
    const std::string& command,
    const std::string* window_id,
    const flutter::EncodableMap& params,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (command == "getProtocolVersion") {
    GetProtocolVersion(std::move(result));
  } else if (command == "getCapabilities") {
    GetCapabilities(std::move(result));
  } else if (command == "getServiceVersion") {
    GetServiceVersion(params, std::move(result));
  } else if (command == "getSnapshot") {
    GetSnapshot(std::move(result));
  } else if (command == "ping") {
    Ping(std::move(result));
  } else {
    result->Error("UNKNOWN_COMMAND", "Unknown host command: " + command);
  }
}

void HostService::GetProtocolVersion(
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  result->Success(flutter::EncodableValue(flutter::EncodableMap{
      {flutter::EncodableValue("version"),
       flutter::EncodableValue(kProtocolVersion)},
      {flutter::EncodableValue("minDartVersion"),
       flutter::EncodableValue(kMinDartVersion)},
      {flutter::EncodableValue("maxDartVersion"),
       flutter::EncodableValue(kMaxDartVersion)},
  }));
}

void HostService::GetCapabilities(
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  result->Success(flutter::EncodableValue(flutter::EncodableMap{
      {flutter::EncodableValue("blur"), flutter::EncodableValue(false)},
      {flutter::EncodableValue("transform"), flutter::EncodableValue(false)},
      {flutter::EncodableValue("globalHotkeys"),
       flutter::EncodableValue(false)},
      {flutter::EncodableValue("glassEffect"),
       flutter::EncodableValue(false)},
      {flutter::EncodableValue("multiMonitor"),
       flutter::EncodableValue(true)},
      {flutter::EncodableValue("contentSizing"),
       flutter::EncodableValue(true)},
      {flutter::EncodableValue("platform"),
       flutter::EncodableValue("windows")},
  }));
}

void HostService::GetServiceVersion(
    const flutter::EncodableMap& params,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  auto it = params.find(flutter::EncodableValue("service"));
  if (it == params.end() || !std::holds_alternative<std::string>(it->second)) {
    result->Error("INVALID_PARAMS", "Missing 'service' parameter");
    return;
  }
  const auto& service = std::get<std::string>(it->second);
  result->Success(flutter::EncodableValue(flutter::EncodableMap{
      {flutter::EncodableValue("service"),
       flutter::EncodableValue(service)},
      {flutter::EncodableValue("version"), flutter::EncodableValue(1)},
  }));
}

void HostService::GetSnapshot(
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  // TODO: Return snapshot of all palette windows for hot restart recovery
  result->Success(flutter::EncodableValue(flutter::EncodableList{}));
}

void HostService::Ping(
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  result->Success(flutter::EncodableValue(true));
}

}  // namespace floating_palette
