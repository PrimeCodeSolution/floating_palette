#include "text_selection_service.h"

#include <combaseapi.h>
#include <oleauto.h>
#include <psapi.h>

#include <algorithm>
#include <string>

#include "../core/dpi_helper.h"
#include "../core/logger.h"

namespace floating_palette {

// ─── Inner COM handler: text selection changed ───────────────────────────────

class TextSelectionService::SelectionHandler
    : public IUIAutomationEventHandler {
 public:
  explicit SelectionHandler(TextSelectionService* service)
      : service_(service), ref_count_(1) {}

  ULONG STDMETHODCALLTYPE AddRef() override {
    return InterlockedIncrement(&ref_count_);
  }
  ULONG STDMETHODCALLTYPE Release() override {
    ULONG count = InterlockedDecrement(&ref_count_);
    if (count == 0) delete this;
    return count;
  }
  HRESULT STDMETHODCALLTYPE QueryInterface(REFIID riid, void** ppv) override {
    if (riid == __uuidof(IUnknown) ||
        riid == __uuidof(IUIAutomationEventHandler)) {
      *ppv = static_cast<IUIAutomationEventHandler*>(this);
      AddRef();
      return S_OK;
    }
    *ppv = nullptr;
    return E_NOINTERFACE;
  }

  HRESULT STDMETHODCALLTYPE HandleAutomationEvent(
      IUIAutomationElement* sender, EVENTID /*eventId*/) override {
    if (!service_ || !sender) return S_OK;

    TextSelectionEvent evt;
    if (service_->ReadSelectionFromElement(sender, evt)) {
      std::lock_guard<std::mutex> lock(service_->queue_mutex_);
      service_->event_queue_.push_back(std::move(evt));
    } else {
      // Could not read selection — treat as cleared
      TextSelectionEvent empty;
      std::lock_guard<std::mutex> lock(service_->queue_mutex_);
      service_->event_queue_.push_back(std::move(empty));
    }
    return S_OK;
  }

 private:
  TextSelectionService* service_;
  ULONG ref_count_;
};

// ─── Inner COM handler: focus changed ────────────────────────────────────────

class TextSelectionService::FocusHandler
    : public IUIAutomationFocusChangedEventHandler {
 public:
  explicit FocusHandler(TextSelectionService* service)
      : service_(service), ref_count_(1) {}

  ULONG STDMETHODCALLTYPE AddRef() override {
    return InterlockedIncrement(&ref_count_);
  }
  ULONG STDMETHODCALLTYPE Release() override {
    ULONG count = InterlockedDecrement(&ref_count_);
    if (count == 0) delete this;
    return count;
  }
  HRESULT STDMETHODCALLTYPE QueryInterface(REFIID riid, void** ppv) override {
    if (riid == __uuidof(IUnknown) ||
        riid == __uuidof(IUIAutomationFocusChangedEventHandler)) {
      *ppv = static_cast<IUIAutomationFocusChangedEventHandler*>(this);
      AddRef();
      return S_OK;
    }
    *ppv = nullptr;
    return E_NOINTERFACE;
  }

  HRESULT STDMETHODCALLTYPE HandleFocusChangedEvent(
      IUIAutomationElement* /*sender*/) override {
    if (!service_) return S_OK;

    TextSelectionEvent evt;
    evt.is_focus_change = true;
    {
      std::lock_guard<std::mutex> lock(service_->queue_mutex_);
      service_->event_queue_.push_back(std::move(evt));
    }
    return S_OK;
  }

 private:
  TextSelectionService* service_;
  ULONG ref_count_;
};

// ─── Static instance ────────────────────────────────────────────────────────

TextSelectionService* TextSelectionService::instance_ = nullptr;

// ─── Constructor / Destructor ────────────────────────────────────────────────

TextSelectionService::TextSelectionService() { instance_ = this; }

TextSelectionService::~TextSelectionService() {
  StopMonitoring(nullptr);
  ReleaseUIAutomation();
  if (instance_ == this) instance_ = nullptr;
}

// ─── Command routing ─────────────────────────────────────────────────────────

void TextSelectionService::Handle(
    const std::string& command,
    const std::string* /*window_id*/,
    const flutter::EncodableMap& /*params*/,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (command == "checkPermission") {
    CheckPermission(std::move(result));
  } else if (command == "requestPermission") {
    RequestPermission(std::move(result));
  } else if (command == "getSelection") {
    GetSelection(std::move(result));
  } else if (command == "startMonitoring") {
    StartMonitoring(std::move(result));
  } else if (command == "stopMonitoring") {
    StopMonitoring(std::move(result));
  } else {
    result->Error("UNKNOWN_COMMAND",
                  "Unknown textSelection command: " + command);
  }
}

// ─── COM lifecycle ───────────────────────────────────────────────────────────

bool TextSelectionService::EnsureUIAutomation() {
  if (automation_) return true;

  // Join Flutter's existing STA (S_FALSE = already initialized, that's fine)
  HRESULT hr = CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
  if (FAILED(hr) && hr != RPC_E_CHANGED_MODE) {
    FP_LOG("TextSel", "CoInitializeEx failed");
    return false;
  }
  com_initialized_ = (hr == S_OK);

  hr = CoCreateInstance(CLSID_CUIAutomation, nullptr, CLSCTX_INPROC_SERVER,
                        __uuidof(IUIAutomation),
                        reinterpret_cast<void**>(&automation_));
  if (FAILED(hr) || !automation_) {
    FP_LOG("TextSel", "CoCreateInstance(CUIAutomation) failed");
    if (com_initialized_) CoUninitialize();
    com_initialized_ = false;
    return false;
  }

  hr = automation_->GetRootElement(&root_element_);
  if (FAILED(hr) || !root_element_) {
    FP_LOG("TextSel", "GetRootElement failed");
    automation_->Release();
    automation_ = nullptr;
    if (com_initialized_) CoUninitialize();
    com_initialized_ = false;
    return false;
  }

  return true;
}

void TextSelectionService::ReleaseUIAutomation() {
  if (root_element_) {
    root_element_->Release();
    root_element_ = nullptr;
  }
  if (automation_) {
    automation_->Release();
    automation_ = nullptr;
  }
  if (com_initialized_) {
    CoUninitialize();
    com_initialized_ = false;
  }
}

// ─── Timer callbacks ─────────────────────────────────────────────────────────

void CALLBACK TextSelectionService::PollTimerProc(HWND, UINT, UINT_PTR,
                                                  DWORD) {
  if (instance_) {
    instance_->ProcessPendingEvents();
  }
}

void CALLBACK TextSelectionService::ClearTimerProc(HWND, UINT, UINT_PTR id,
                                                   DWORD) {
  if (instance_) {
    KillTimer(NULL, id);
    instance_->clear_timer_id_ = 0;
    instance_->EmitSelectionCleared();
  }
}

// ─── Commands ────────────────────────────────────────────────────────────────

void TextSelectionService::CheckPermission(
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  bool granted = EnsureUIAutomation();
  flutter::EncodableMap data;
  data[flutter::EncodableValue("granted")] = flutter::EncodableValue(granted);
  result->Success(flutter::EncodableValue(data));
}

void TextSelectionService::RequestPermission(
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  // No-op on Windows — UIA doesn't require user consent for same-privilege
  result->Success(flutter::EncodableValue());
}

void TextSelectionService::GetSelection(
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (!EnsureUIAutomation()) {
    result->Success(flutter::EncodableValue());  // null
    return;
  }

  IUIAutomationElement* focused = nullptr;
  HRESULT hr = automation_->GetFocusedElement(&focused);
  if (FAILED(hr) || !focused) {
    result->Success(flutter::EncodableValue());
    return;
  }

  TextSelectionEvent evt;
  if (!ReadSelectionFromElement(focused, evt) || evt.text.empty()) {
    focused->Release();
    result->Success(flutter::EncodableValue());
    return;
  }

  // Build result map
  flutter::EncodableMap data;
  data[flutter::EncodableValue("text")] = flutter::EncodableValue(evt.text);

  std::string app_bundle_id, app_name;
  GetAppInfo(app_bundle_id, app_name);
  data[flutter::EncodableValue("appBundleId")] =
      flutter::EncodableValue(app_bundle_id);
  data[flutter::EncodableValue("appName")] =
      flutter::EncodableValue(app_name);

  if (evt.has_bounds) {
    POINT pt = {static_cast<LONG>(evt.x), static_cast<LONG>(evt.y)};
    double scale = GetScaleFactorForPoint(pt);
    data[flutter::EncodableValue("x")] =
        flutter::EncodableValue(PhysicalToLogical(evt.x, scale));
    data[flutter::EncodableValue("y")] =
        flutter::EncodableValue(PhysicalToLogical(evt.y, scale));
    data[flutter::EncodableValue("width")] =
        flutter::EncodableValue(PhysicalToLogical(evt.width, scale));
    data[flutter::EncodableValue("height")] =
        flutter::EncodableValue(PhysicalToLogical(evt.height, scale));
  }

  focused->Release();
  result->Success(flutter::EncodableValue(data));
}

void TextSelectionService::StartMonitoring(
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (monitoring_) {
    if (result) result->Success(flutter::EncodableValue());
    return;
  }

  if (!EnsureUIAutomation()) {
    if (result) result->Error("UIA_INIT_FAILED", "Could not initialize UIA");
    return;
  }

  // Create handlers
  selection_handler_ = new SelectionHandler(this);
  focus_handler_ = new FocusHandler(this);

  // Subscribe to text selection changed on entire desktop
  HRESULT hr = automation_->AddAutomationEventHandler(
      UIA_Text_TextSelectionChangedEventId, root_element_, TreeScope_Subtree,
      nullptr, selection_handler_);
  if (FAILED(hr)) {
    FP_LOG("TextSel", "AddAutomationEventHandler failed");
    selection_handler_->Release();
    selection_handler_ = nullptr;
    focus_handler_->Release();
    focus_handler_ = nullptr;
    if (result) result->Error("UIA_SUBSCRIBE_FAILED",
                              "Could not subscribe to selection events");
    return;
  }

  // Subscribe to focus changes
  hr = automation_->AddFocusChangedEventHandler(nullptr, focus_handler_);
  if (FAILED(hr)) {
    FP_LOG("TextSel", "AddFocusChangedEventHandler failed");
    automation_->RemoveAutomationEventHandler(
        UIA_Text_TextSelectionChangedEventId, root_element_,
        selection_handler_);
    selection_handler_->Release();
    selection_handler_ = nullptr;
    focus_handler_->Release();
    focus_handler_ = nullptr;
    if (result) result->Error("UIA_SUBSCRIBE_FAILED",
                              "Could not subscribe to focus events");
    return;
  }

  // Start poll timer (50ms — marshals BG events to UI thread)
  poll_timer_id_ = SetTimer(NULL, 0, 50, PollTimerProc);
  monitoring_ = true;

  FP_LOG("TextSel", "Monitoring started");
  if (result) result->Success(flutter::EncodableValue());
}

void TextSelectionService::StopMonitoring(
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (!monitoring_) {
    if (result) result->Success(flutter::EncodableValue());
    return;
  }

  // Kill timers
  if (poll_timer_id_ != 0) {
    KillTimer(NULL, poll_timer_id_);
    poll_timer_id_ = 0;
  }
  CancelClear();

  // Unsubscribe UIA handlers
  if (automation_ && selection_handler_) {
    automation_->RemoveAutomationEventHandler(
        UIA_Text_TextSelectionChangedEventId, root_element_,
        selection_handler_);
  }
  if (automation_ && focus_handler_) {
    automation_->RemoveFocusChangedEventHandler(focus_handler_);
  }

  // Release handler COM objects
  if (selection_handler_) {
    selection_handler_->Release();
    selection_handler_ = nullptr;
  }
  if (focus_handler_) {
    focus_handler_->Release();
    focus_handler_ = nullptr;
  }

  // Clear queue and dedup state
  {
    std::lock_guard<std::mutex> lock(queue_mutex_);
    event_queue_.clear();
  }
  last_text_.clear();
  last_x_ = last_y_ = last_width_ = last_height_ = 0;

  monitoring_ = false;
  FP_LOG("TextSel", "Monitoring stopped");
  if (result) result->Success(flutter::EncodableValue());
}

// ─── Event processing ────────────────────────────────────────────────────────

void TextSelectionService::ProcessPendingEvents() {
  std::vector<TextSelectionEvent> events;
  {
    std::lock_guard<std::mutex> lock(queue_mutex_);
    events.swap(event_queue_);
  }

  for (auto& evt : events) {
    if (evt.is_focus_change || evt.text.empty()) {
      ScheduleClear();
      continue;
    }

    // Has text — cancel any pending clear
    CancelClear();

    // Dedup: skip if text and bounds match previous emission
    if (evt.text == last_text_ && evt.has_bounds &&
        evt.x == last_x_ && evt.y == last_y_ &&
        evt.width == last_width_ && evt.height == last_height_) {
      continue;
    }

    EmitSelectionChanged(evt);
  }
}

void TextSelectionService::EmitSelectionChanged(
    const TextSelectionEvent& evt) {
  // Update dedup state
  last_text_ = evt.text;
  last_x_ = evt.x;
  last_y_ = evt.y;
  last_width_ = evt.width;
  last_height_ = evt.height;

  flutter::EncodableMap data;
  data[flutter::EncodableValue("text")] = flutter::EncodableValue(evt.text);

  std::string app_bundle_id, app_name;
  GetAppInfo(app_bundle_id, app_name);
  data[flutter::EncodableValue("appBundleId")] =
      flutter::EncodableValue(app_bundle_id);
  data[flutter::EncodableValue("appName")] =
      flutter::EncodableValue(app_name);

  if (evt.has_bounds) {
    POINT pt = {static_cast<LONG>(evt.x), static_cast<LONG>(evt.y)};
    double scale = GetScaleFactorForPoint(pt);
    data[flutter::EncodableValue("x")] =
        flutter::EncodableValue(PhysicalToLogical(evt.x, scale));
    data[flutter::EncodableValue("y")] =
        flutter::EncodableValue(PhysicalToLogical(evt.y, scale));
    data[flutter::EncodableValue("width")] =
        flutter::EncodableValue(PhysicalToLogical(evt.width, scale));
    data[flutter::EncodableValue("height")] =
        flutter::EncodableValue(PhysicalToLogical(evt.height, scale));
  }

  if (event_sink_) {
    event_sink_("textSelection", "selectionChanged", nullptr, data);
  }
}

void TextSelectionService::EmitSelectionCleared() {
  last_text_.clear();
  last_x_ = last_y_ = last_width_ = last_height_ = 0;

  if (event_sink_) {
    flutter::EncodableMap data;
    event_sink_("textSelection", "selectionCleared", nullptr, data);
  }
}

void TextSelectionService::ScheduleClear() {
  CancelClear();
  clear_timer_id_ = SetTimer(NULL, 0, 200, ClearTimerProc);
}

void TextSelectionService::CancelClear() {
  if (clear_timer_id_ != 0) {
    KillTimer(NULL, clear_timer_id_);
    clear_timer_id_ = 0;
  }
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

bool TextSelectionService::ReadSelectionFromElement(
    IUIAutomationElement* element, TextSelectionEvent& out) {
  if (!element) return false;

  IUIAutomationTextPattern* text_pattern = nullptr;
  HRESULT hr = element->GetCurrentPatternAs(
      UIA_TextPatternId, __uuidof(IUIAutomationTextPattern),
      reinterpret_cast<void**>(&text_pattern));
  if (FAILED(hr) || !text_pattern) return false;

  IUIAutomationTextRangeArray* ranges = nullptr;
  hr = text_pattern->GetSelection(&ranges);
  if (FAILED(hr) || !ranges) {
    text_pattern->Release();
    return false;
  }

  int count = 0;
  ranges->get_Length(&count);
  if (count == 0) {
    ranges->Release();
    text_pattern->Release();
    return false;
  }

  IUIAutomationTextRange* range = nullptr;
  ranges->GetElement(0, &range);
  if (!range) {
    ranges->Release();
    text_pattern->Release();
    return false;
  }

  // Read text
  BSTR bstr_text = nullptr;
  hr = range->GetText(-1, &bstr_text);
  if (SUCCEEDED(hr) && bstr_text) {
    int len = WideCharToMultiByte(CP_UTF8, 0, bstr_text, -1, nullptr, 0,
                                  nullptr, nullptr);
    if (len > 1) {
      out.text.resize(len - 1);
      WideCharToMultiByte(CP_UTF8, 0, bstr_text, -1, out.text.data(), len,
                          nullptr, nullptr);
    }
    SysFreeString(bstr_text);
  }

  // Read bounding rectangles (each rect = 4 doubles: x, y, w, h)
  SAFEARRAY* rects = nullptr;
  hr = range->GetBoundingRectangles(&rects);
  if (SUCCEEDED(hr) && rects) {
    LONG lb = 0, ub = 0;
    SafeArrayGetLBound(rects, 1, &lb);
    SafeArrayGetUBound(rects, 1, &ub);
    LONG num_values = ub - lb + 1;

    if (num_values >= 4) {
      double* data = nullptr;
      if (SUCCEEDED(SafeArrayAccessData(rects,
                                        reinterpret_cast<void**>(&data)))) {
        // Union all line rects into a single bounding rect
        double min_x = data[0];
        double min_y = data[1];
        double max_x = data[0] + data[2];
        double max_y = data[1] + data[3];

        for (LONG i = 4; i + 3 < num_values; i += 4) {
          min_x = (std::min)(min_x, data[i]);
          min_y = (std::min)(min_y, data[i + 1]);
          max_x = (std::max)(max_x, data[i] + data[i + 2]);
          max_y = (std::max)(max_y, data[i + 1] + data[i + 3]);
        }

        SafeArrayUnaccessData(rects);

        out.x = min_x;
        out.y = min_y;
        out.width = max_x - min_x;
        out.height = max_y - min_y;
        out.has_bounds = (out.width > 0 || out.height > 0);
      }
    }
    SafeArrayDestroy(rects);
  }

  range->Release();
  ranges->Release();
  text_pattern->Release();
  return true;
}

void TextSelectionService::GetAppInfo(std::string& app_bundle_id,
                                      std::string& app_name) {
  HWND fg = GetForegroundWindow();
  if (!fg) return;

  // Window title → appName
  wchar_t title[256] = {};
  GetWindowTextW(fg, title, 256);
  int len = WideCharToMultiByte(CP_UTF8, 0, title, -1, nullptr, 0, nullptr,
                                nullptr);
  if (len > 1) {
    app_name.resize(len - 1);
    WideCharToMultiByte(CP_UTF8, 0, title, -1, app_name.data(), len, nullptr,
                        nullptr);
  }

  // Exe filename → appBundleId
  DWORD pid = 0;
  GetWindowThreadProcessId(fg, &pid);
  if (pid == 0) return;

  HANDLE proc = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, pid);
  if (!proc) return;

  wchar_t exe_path[MAX_PATH] = {};
  DWORD size = MAX_PATH;
  if (QueryFullProcessImageNameW(proc, 0, exe_path, &size)) {
    std::wstring path(exe_path, size);
    auto pos = path.find_last_of(L"\\/");
    std::wstring filename =
        (pos != std::wstring::npos) ? path.substr(pos + 1) : path;
    int len2 = WideCharToMultiByte(CP_UTF8, 0, filename.c_str(), -1, nullptr,
                                   0, nullptr, nullptr);
    if (len2 > 1) {
      app_bundle_id.resize(len2 - 1);
      WideCharToMultiByte(CP_UTF8, 0, filename.c_str(), -1,
                          app_bundle_id.data(), len2, nullptr, nullptr);
    }
  }
  CloseHandle(proc);
}

}  // namespace floating_palette
