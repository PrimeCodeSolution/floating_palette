#pragma once

#include <flutter/encodable_value.h>

#include <string>
#include <variant>

namespace floating_palette {

inline double GetDouble(const flutter::EncodableMap& map, const char* key,
                        double default_value = 0.0) {
  auto it = map.find(flutter::EncodableValue(key));
  if (it == map.end()) return default_value;
  if (std::holds_alternative<double>(it->second))
    return std::get<double>(it->second);
  if (std::holds_alternative<int32_t>(it->second))
    return static_cast<double>(std::get<int32_t>(it->second));
  if (std::holds_alternative<int64_t>(it->second))
    return static_cast<double>(std::get<int64_t>(it->second));
  return default_value;
}

inline int GetInt(const flutter::EncodableMap& map, const char* key,
                  int default_value = 0) {
  auto it = map.find(flutter::EncodableValue(key));
  if (it == map.end()) return default_value;
  if (std::holds_alternative<int32_t>(it->second))
    return std::get<int32_t>(it->second);
  if (std::holds_alternative<int64_t>(it->second))
    return static_cast<int>(std::get<int64_t>(it->second));
  if (std::holds_alternative<double>(it->second))
    return static_cast<int>(std::get<double>(it->second));
  return default_value;
}

inline bool GetBool(const flutter::EncodableMap& map, const char* key,
                    bool default_value = false) {
  auto it = map.find(flutter::EncodableValue(key));
  if (it == map.end()) return default_value;
  if (std::holds_alternative<bool>(it->second))
    return std::get<bool>(it->second);
  return default_value;
}

inline std::string GetString(const flutter::EncodableMap& map, const char* key,
                             const std::string& default_value = "") {
  auto it = map.find(flutter::EncodableValue(key));
  if (it == map.end()) return default_value;
  if (std::holds_alternative<std::string>(it->second))
    return std::get<std::string>(it->second);
  return default_value;
}

}  // namespace floating_palette
