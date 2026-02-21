#include "drag_coordinator.h"

#include "../core/logger.h"

namespace floating_palette {

void DragCoordinator::SetDelegate(DragCoordinatorDelegate* delegate) {
  delegate_ = delegate;
}

void DragCoordinator::StartDrag(const std::string& id,
                                PaletteWindow* window) {
  // TODO: Implement Win32 drag handling
  FP_LOG("Frame", "startDrag stub called for " + id);
}

bool DragCoordinator::IsDragging(const std::string& id) const {
  return is_dragging_ && active_drag_id_ == id;
}

}  // namespace floating_palette
