#pragma once

#include <windows.h>
#include <commctrl.h>

#include <string>

namespace floating_palette {

struct PaletteWindow;

/// Delegate that receives drag lifecycle callbacks.
class DragCoordinatorDelegate {
 public:
  virtual ~DragCoordinatorDelegate() = default;
  virtual void DragBegan(const std::string& id) = 0;
  virtual void DragMoved(const std::string& id, const RECT& frame) = 0;
  virtual void DragEnded(const std::string& id, const RECT& frame) = 0;
};

/// Owns the entire drag lifecycle for palette windows.
/// Uses SetCapture for mouse tracking during drag.
class DragCoordinator {
 public:
  void SetDelegate(DragCoordinatorDelegate* delegate);
  void StartDrag(const std::string& id, PaletteWindow* window);
  bool IsDragging(const std::string& id) const;

 private:
  DragCoordinatorDelegate* delegate_ = nullptr;
  std::string active_drag_id_;
  bool is_dragging_ = false;

  // Drag start state
  POINT drag_start_mouse_ = {};
  POINT drag_start_window_ = {};
  HWND drag_hwnd_ = nullptr;

  static LRESULT CALLBACK DragSubclassProc(HWND hwnd, UINT msg,
                                           WPARAM wparam, LPARAM lparam,
                                           UINT_PTR id, DWORD_PTR ref);
  void OnMouseMove(HWND hwnd, LPARAM lparam);
  void OnMouseUp(HWND hwnd);
};

}  // namespace floating_palette
