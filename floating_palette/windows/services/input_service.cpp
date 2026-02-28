#include "input_service.h"

#include "../core/dpi_helper.h"
#include "../core/logger.h"
#include "../core/param_helpers.h"

namespace floating_palette {

// Convert Win32 VK code to Flutter LogicalKeyboardKey ID.
// Flutter uses specific planes: 0x0 for printable, 0x100000000 for non-printable,
// 0x200000000 for modifiers.
static int64_t VkToLogicalKey(DWORD vk_code) {
  switch (vk_code) {
    // Printable characters
    case VK_SPACE: return 0x00000020;
    // Digits
    case '0': return 0x00000030;
    case '1': return 0x00000031;
    case '2': return 0x00000032;
    case '3': return 0x00000033;
    case '4': return 0x00000034;
    case '5': return 0x00000035;
    case '6': return 0x00000036;
    case '7': return 0x00000037;
    case '8': return 0x00000038;
    case '9': return 0x00000039;
    // Letters (lowercase code points)
    case 'A': return 0x00000061;
    case 'B': return 0x00000062;
    case 'C': return 0x00000063;
    case 'D': return 0x00000064;
    case 'E': return 0x00000065;
    case 'F': return 0x00000066;
    case 'G': return 0x00000067;
    case 'H': return 0x00000068;
    case 'I': return 0x00000069;
    case 'J': return 0x0000006a;
    case 'K': return 0x0000006b;
    case 'L': return 0x0000006c;
    case 'M': return 0x0000006d;
    case 'N': return 0x0000006e;
    case 'O': return 0x0000006f;
    case 'P': return 0x00000070;
    case 'Q': return 0x00000071;
    case 'R': return 0x00000072;
    case 'S': return 0x00000073;
    case 'T': return 0x00000074;
    case 'U': return 0x00000075;
    case 'V': return 0x00000076;
    case 'W': return 0x00000077;
    case 'X': return 0x00000078;
    case 'Y': return 0x00000079;
    case 'Z': return 0x0000007a;
    // Non-printable keys
    case VK_BACK:   return 0x100000008;
    case VK_TAB:    return 0x100000009;
    case VK_RETURN: return 0x10000000d;
    case VK_ESCAPE: return 0x10000001b;
    case VK_DELETE: return 0x10000007f;
    // Arrow keys
    case VK_LEFT:  return 0x100000302;
    case VK_UP:    return 0x100000304;
    case VK_RIGHT: return 0x100000303;
    case VK_DOWN:  return 0x100000301;
    // Home/End/PageUp/PageDown
    case VK_HOME:   return 0x100000306;
    case VK_END:    return 0x100000305;
    case VK_PRIOR:  return 0x100000308;  // PageUp
    case VK_NEXT:   return 0x100000307;  // PageDown
    // Function keys
    case VK_F1:  return 0x100000801;
    case VK_F2:  return 0x100000802;
    case VK_F3:  return 0x100000803;
    case VK_F4:  return 0x100000804;
    case VK_F5:  return 0x100000805;
    case VK_F6:  return 0x100000806;
    case VK_F7:  return 0x100000807;
    case VK_F8:  return 0x100000808;
    case VK_F9:  return 0x100000809;
    case VK_F10: return 0x10000080a;
    case VK_F11: return 0x10000080b;
    case VK_F12: return 0x10000080c;
    // Modifier keys
    case VK_LSHIFT:   return 0x200000102;
    case VK_RSHIFT:   return 0x200000103;
    case VK_LCONTROL: return 0x200000104;
    case VK_RCONTROL: return 0x200000105;
    case VK_LMENU:    return 0x200000106;  // Left Alt
    case VK_RMENU:    return 0x200000107;  // Right Alt
    case VK_LWIN:     return 0x200000108;
    case VK_RWIN:     return 0x200000109;
    // Generic modifiers (when L/R not distinguished)
    case VK_SHIFT:   return 0x200000102;
    case VK_CONTROL: return 0x200000104;
    case VK_MENU:    return 0x200000106;
    // Punctuation
    case VK_OEM_1:      return 0x0000003b;  // ;
    case VK_OEM_PLUS:   return 0x0000003d;  // =
    case VK_OEM_COMMA:  return 0x0000002c;  // ,
    case VK_OEM_MINUS:  return 0x0000002d;  // -
    case VK_OEM_PERIOD: return 0x0000002e;  // .
    case VK_OEM_2:      return 0x0000002f;  // /
    case VK_OEM_3:      return 0x00000060;  // `
    case VK_OEM_4:      return 0x0000005b;  // [
    case VK_OEM_5:      return 0x0000005c;  // backslash
    case VK_OEM_6:      return 0x0000005d;  // ]
    case VK_OEM_7:      return 0x00000027;  // '
    default: {
      // Fallback: try MapVirtualKey for character, else use VK plane
      UINT ch = MapVirtualKeyW(vk_code, MAPVK_VK_TO_CHAR);
      if (ch >= 0x20 && ch <= 0x7E) {
        return static_cast<int64_t>(tolower(ch));
      }
      return 0x100000000LL | static_cast<int64_t>(vk_code);
    }
  }
}

// Static members
HHOOK InputService::keyboard_hook_ = nullptr;
HHOOK InputService::mouse_hook_ = nullptr;
InputService* InputService::instance_ = nullptr;

InputService::InputService() {
  instance_ = this;
}

InputService::~InputService() {
  RemoveKeyboardHook();
  RemoveMouseHook();
  if (instance_ == this) instance_ = nullptr;
}

void InputService::Handle(
    const std::string& command,
    const std::string* window_id,
    const flutter::EncodableMap& params,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (command == "captureKeyboard") {
    CaptureKeyboard(window_id, params, std::move(result));
  } else if (command == "releaseKeyboard") {
    ReleaseKeyboard(window_id, std::move(result));
  } else if (command == "capturePointer") {
    CapturePointer(window_id, std::move(result));
  } else if (command == "releasePointer") {
    ReleasePointer(window_id, std::move(result));
  } else if (command == "setCursor") {
    SetCursor(window_id, params, std::move(result));
  } else if (command == "setPassthrough") {
    SetPassthrough(window_id, params, std::move(result));
  } else {
    result->Error("UNKNOWN_COMMAND", "Unknown input command: " + command);
  }
}

void InputService::CleanupForWindow(const std::string& window_id) {
  keyboard_captures_.erase(window_id);
  captured_keys_.erase(window_id);
  capture_all_keys_.erase(window_id);
  pointer_captures_.erase(window_id);
  if (keyboard_captures_.empty()) RemoveKeyboardHook();
  if (pointer_captures_.empty()) RemoveMouseHook();
}

LRESULT CALLBACK InputService::KeyboardHookProc(int code, WPARAM wparam,
                                                 LPARAM lparam) {
  if (code >= 0 && instance_ && instance_->event_sink_) {
    KBDLLHOOKSTRUCT* kb = reinterpret_cast<KBDLLHOOKSTRUCT*>(lparam);
    bool is_key_down =
        (wparam == WM_KEYDOWN || wparam == WM_SYSKEYDOWN);
    std::string event_type = is_key_down ? "keyDown" : "keyUp";

    // Convert VK code to Flutter LogicalKeyboardKey ID
    int64_t key_id = VkToLogicalKey(kb->vkCode);

    // Build active modifier list
    flutter::EncodableList modifiers;
    if (GetKeyState(VK_SHIFT) & 0x8000) {
      modifiers.push_back(flutter::EncodableValue(
          static_cast<int64_t>(0x200000102)));  // shiftLeft
    }
    if (GetKeyState(VK_CONTROL) & 0x8000) {
      modifiers.push_back(flutter::EncodableValue(
          static_cast<int64_t>(0x200000104)));  // controlLeft
    }
    if (GetKeyState(VK_MENU) & 0x8000) {
      modifiers.push_back(flutter::EncodableValue(
          static_cast<int64_t>(0x200000106)));  // altLeft
    }
    if (GetKeyState(VK_LWIN) & 0x8000 || GetKeyState(VK_RWIN) & 0x8000) {
      modifiers.push_back(flutter::EncodableValue(
          static_cast<int64_t>(0x200000108)));  // metaLeft
    }

    flutter::EncodableMap data{
        {flutter::EncodableValue("keyId"),
         flutter::EncodableValue(key_id)},
        {flutter::EncodableValue("modifiers"),
         flutter::EncodableValue(modifiers)},
    };

    // Gap 1: Per-window key filtering (match macOS behavior)
    bool should_consume = false;

    for (const auto& id : instance_->keyboard_captures_) {
      bool wants_all =
          instance_->capture_all_keys_.count(id)
              ? instance_->capture_all_keys_[id]
              : false;
      bool wants_this_key = wants_all;
      if (!wants_this_key) {
        auto keys_it = instance_->captured_keys_.find(id);
        if (keys_it != instance_->captured_keys_.end()) {
          wants_this_key = keys_it->second.count(key_id) > 0;
        }
      }

      if (wants_this_key) {
        // Emit via event sink (existing path)
        instance_->event_sink_("input", event_type, &id, data);

        // Gap 2: Forward via entry channel (match macOS dual-path delivery)
        auto* window = WindowStore::Instance().Get(id);
        if (window && window->entry_channel) {
          if (is_key_down) {
            flutter::EncodableMap args{
                {flutter::EncodableValue("keyId"),
                 flutter::EncodableValue(key_id)},
                {flutter::EncodableValue("modifiers"),
                 flutter::EncodableValue(modifiers)},
            };
            window->entry_channel->InvokeMethod(
                "keyDown",
                std::make_unique<flutter::EncodableValue>(
                    flutter::EncodableValue(args)));
          } else {
            flutter::EncodableMap args{
                {flutter::EncodableValue("keyId"),
                 flutter::EncodableValue(key_id)},
            };
            window->entry_channel->InvokeMethod(
                "keyUp",
                std::make_unique<flutter::EncodableValue>(
                    flutter::EncodableValue(args)));
          }
        }

        should_consume = true;
      }
    }

    // Gap 3: Pass-through tracking for keyUp consistency
    if (is_key_down) {
      if (should_consume) {
        instance_->passed_through_vk_codes_.erase(kb->vkCode);
      } else {
        instance_->passed_through_vk_codes_.insert(kb->vkCode);
      }
    } else {
      // keyUp: if matching keyDown was passed through, force pass-through
      if (instance_->passed_through_vk_codes_.count(kb->vkCode)) {
        instance_->passed_through_vk_codes_.erase(kb->vkCode);
        return CallNextHookEx(keyboard_hook_, code, wparam, lparam);
      }
    }

    if (should_consume) {
      return 1;  // Eat the key event
    }
  }
  return CallNextHookEx(keyboard_hook_, code, wparam, lparam);
}

LRESULT CALLBACK InputService::MouseHookProc(int code, WPARAM wparam,
                                              LPARAM lparam) {
  if (code >= 0 && instance_ && instance_->event_sink_) {
    MSLLHOOKSTRUCT* ms = reinterpret_cast<MSLLHOOKSTRUCT*>(lparam);

    if (wparam == WM_LBUTTONDOWN || wparam == WM_RBUTTONDOWN ||
        wparam == WM_MBUTTONDOWN) {
      POINT pt = ms->pt;
      double pt_scale = GetScaleFactorForPoint(pt);

      // Check if click is outside any capturing palette window
      for (const auto& id : instance_->pointer_captures_) {
        auto* window = WindowStore::Instance().Get(id);
        if (!window || !window->hwnd) continue;

        RECT rect;
        GetWindowRect(window->hwnd, &rect);
        // PtInRect check stays in physical space (both pt and rect are physical)
        if (!PtInRect(&rect, pt)) {
          flutter::EncodableMap data{
              {flutter::EncodableValue("x"),
               flutter::EncodableValue(PhysicalToLogical(pt.x, pt_scale))},
              {flutter::EncodableValue("y"),
               flutter::EncodableValue(PhysicalToLogical(pt.y, pt_scale))},
          };
          instance_->event_sink_("input", "clickOutside", &id, data);
        }
      }
    }

    if (wparam == WM_MOUSEMOVE) {
      POINT pt = ms->pt;
      double pt_scale = GetScaleFactorForPoint(pt);
      for (const auto& id : instance_->pointer_captures_) {
        auto* window = WindowStore::Instance().Get(id);
        if (!window || !window->hwnd) continue;

        RECT rect;
        GetWindowRect(window->hwnd, &rect);
        // PtInRect check stays in physical space
        bool inside = PtInRect(&rect, pt) != FALSE;

        // We emit enter/exit on every move; Dart side deduplicates
        std::string event = inside ? "pointerEnter" : "pointerExit";
        flutter::EncodableMap data{
            {flutter::EncodableValue("x"),
             flutter::EncodableValue(PhysicalToLogical(pt.x, pt_scale))},
            {flutter::EncodableValue("y"),
             flutter::EncodableValue(PhysicalToLogical(pt.y, pt_scale))},
        };
        instance_->event_sink_("input", event, &id, data);
      }
    }
  }
  return CallNextHookEx(mouse_hook_, code, wparam, lparam);
}

void InputService::InstallKeyboardHook() {
  if (keyboard_hook_) return;
  keyboard_hook_ = SetWindowsHookEx(WH_KEYBOARD_LL, KeyboardHookProc,
                                    GetModuleHandle(nullptr), 0);
}

void InputService::RemoveKeyboardHook() {
  if (keyboard_hook_) {
    UnhookWindowsHookEx(keyboard_hook_);
    keyboard_hook_ = nullptr;
  }
}

void InputService::InstallMouseHook() {
  if (mouse_hook_) return;
  mouse_hook_ = SetWindowsHookEx(WH_MOUSE_LL, MouseHookProc,
                                 GetModuleHandle(nullptr), 0);
}

void InputService::RemoveMouseHook() {
  if (mouse_hook_) {
    UnhookWindowsHookEx(mouse_hook_);
    mouse_hook_ = nullptr;
  }
}

void InputService::CaptureKeyboard(
    const std::string* window_id,
    const flutter::EncodableMap& params,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (!window_id) {
    result->Error("MISSING_ID", "windowId required");
    return;
  }

  // Parse allKeys flag
  bool all_keys = GetBool(params, "allKeys", false);
  capture_all_keys_[*window_id] = all_keys;

  // Parse keys list (Flutter logical key IDs)
  std::unordered_set<int64_t> key_ids;
  auto keys_it = params.find(flutter::EncodableValue("keys"));
  if (keys_it != params.end()) {
    if (auto* list =
            std::get_if<flutter::EncodableList>(&keys_it->second)) {
      for (const auto& val : *list) {
        if (auto* i32 = std::get_if<int32_t>(&val))
          key_ids.insert(static_cast<int64_t>(*i32));
        else if (auto* i64 = std::get_if<int64_t>(&val))
          key_ids.insert(*i64);
      }
    }
  }
  captured_keys_[*window_id] = std::move(key_ids);

  keyboard_captures_.insert(*window_id);
  InstallKeyboardHook();

  result->Success(flutter::EncodableValue());
}

void InputService::ReleaseKeyboard(
    const std::string* window_id,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (!window_id) {
    result->Error("MISSING_ID", "windowId required");
    return;
  }

  keyboard_captures_.erase(*window_id);
  captured_keys_.erase(*window_id);
  capture_all_keys_.erase(*window_id);
  if (keyboard_captures_.empty()) {
    RemoveKeyboardHook();
  }

  result->Success(flutter::EncodableValue());
}

void InputService::CapturePointer(
    const std::string* window_id,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (!window_id) {
    result->Error("MISSING_ID", "windowId required");
    return;
  }

  pointer_captures_.insert(*window_id);
  InstallMouseHook();

  result->Success(flutter::EncodableValue());
}

void InputService::ReleasePointer(
    const std::string* window_id,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (!window_id) {
    result->Error("MISSING_ID", "windowId required");
    return;
  }

  pointer_captures_.erase(*window_id);
  if (pointer_captures_.empty()) {
    RemoveMouseHook();
  }

  result->Success(flutter::EncodableValue());
}

void InputService::SetCursor(
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

  std::string cursor_name = GetString(params, "cursor", "arrow");

  LPCWSTR cursor_id = IDC_ARROW;
  if (cursor_name == "arrow") cursor_id = IDC_ARROW;
  else if (cursor_name == "ibeam" || cursor_name == "text") cursor_id = IDC_IBEAM;
  else if (cursor_name == "crosshair") cursor_id = IDC_CROSS;
  else if (cursor_name == "hand" || cursor_name == "pointingHand") cursor_id = IDC_HAND;
  else if (cursor_name == "resizeLeftRight" || cursor_name == "horizontalResize") cursor_id = IDC_SIZEWE;
  else if (cursor_name == "resizeUpDown" || cursor_name == "verticalResize") cursor_id = IDC_SIZENS;
  else if (cursor_name == "resizeAll" || cursor_name == "move") cursor_id = IDC_SIZEALL;
  else if (cursor_name == "wait") cursor_id = IDC_WAIT;
  else if (cursor_name == "help") cursor_id = IDC_HELP;
  else if (cursor_name == "no" || cursor_name == "forbidden") cursor_id = IDC_NO;

  HCURSOR hcursor = LoadCursor(nullptr, cursor_id);
  if (hcursor) {
    ::SetCursor(hcursor);
    SetClassLongPtr(window->hwnd, GCLP_HCURSOR,
                    reinterpret_cast<LONG_PTR>(hcursor));
  }

  result->Success(flutter::EncodableValue());
}

void InputService::SetPassthrough(
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

  bool passthrough = GetBool(params, "passthrough", false);

  LONG_PTR ex = GetWindowLongPtr(window->hwnd, GWL_EXSTYLE);
  if (passthrough) {
    SetWindowLongPtr(window->hwnd, GWL_EXSTYLE, ex | WS_EX_TRANSPARENT);
  } else {
    SetWindowLongPtr(window->hwnd, GWL_EXSTYLE, ex & ~WS_EX_TRANSPARENT);
  }

  result->Success(flutter::EncodableValue());
}

}  // namespace floating_palette
