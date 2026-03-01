#include "drag_coordinator.h"

#include "../core/logger.h"
#include "../core/window_store.h"

namespace floating_palette {

static const UINT_PTR kDragSubclassId = 1001;

void DragCoordinator::SetDelegate(DragCoordinatorDelegate* delegate) {
  delegate_ = delegate;
}

void DragCoordinator::StartDrag(const std::string& id,
                                PaletteWindow* window) {
  if (!window || !window->hwnd) return;
  if (is_dragging_) return;

  // Record initial positions
  GetCursorPos(&drag_start_mouse_);

  RECT rect;
  GetWindowRect(window->hwnd, &rect);
  drag_start_window_ = {rect.left, rect.top};

  active_drag_id_ = id;
  is_dragging_ = true;
  drag_hwnd_ = window->hwnd;

  // Capture mouse on the palette HWND
  SetCapture(window->hwnd);

  // Install window subclass for WM_MOUSEMOVE / WM_LBUTTONUP
  SetWindowSubclass(window->hwnd, DragSubclassProc, kDragSubclassId,
                    reinterpret_cast<DWORD_PTR>(this));

  if (delegate_) {
    delegate_->DragBegan(id);
  }

  FP_LOG("Drag", "started: " + id);
}

bool DragCoordinator::IsDragging(const std::string& id) const {
  return is_dragging_ && active_drag_id_ == id;
}

LRESULT CALLBACK DragCoordinator::DragSubclassProc(
    HWND hwnd, UINT msg, WPARAM wparam, LPARAM lparam,
    UINT_PTR id, DWORD_PTR ref) {
  auto* self = reinterpret_cast<DragCoordinator*>(ref);

  switch (msg) {
    case WM_MOUSEMOVE:
      self->OnMouseMove(hwnd, lparam);
      return 0;

    case WM_LBUTTONUP:
      self->OnMouseUp(hwnd);
      return 0;

    case WM_CAPTURECHANGED:
      // Capture was taken away; end drag
      if (self->is_dragging_) {
        self->OnMouseUp(hwnd);
      }
      break;
  }

  return DefSubclassProc(hwnd, msg, wparam, lparam);
}

void DragCoordinator::OnMouseMove(HWND hwnd, LPARAM lparam) {
  if (!is_dragging_) return;

  POINT current;
  GetCursorPos(&current);

  int dx = current.x - drag_start_mouse_.x;
  int dy = current.y - drag_start_mouse_.y;

  int new_x = drag_start_window_.x + dx;
  int new_y = drag_start_window_.y + dy;

  SetWindowPos(hwnd, NULL, new_x, new_y, 0, 0,
               SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE);

  if (delegate_) {
    RECT frame;
    GetWindowRect(hwnd, &frame);
    delegate_->DragMoved(active_drag_id_, frame);
  }
}

void DragCoordinator::OnMouseUp(HWND hwnd) {
  if (!is_dragging_) return;

  ReleaseCapture();
  RemoveWindowSubclass(hwnd, DragSubclassProc, kDragSubclassId);

  is_dragging_ = false;

  if (delegate_) {
    RECT frame;
    GetWindowRect(hwnd, &frame);
    delegate_->DragEnded(active_drag_id_, frame);
  }

  FP_LOG("Drag", "ended: " + active_drag_id_);
  drag_hwnd_ = nullptr;
}

}  // namespace floating_palette
