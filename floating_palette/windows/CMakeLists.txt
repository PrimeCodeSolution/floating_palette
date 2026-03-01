# The Flutter tooling requires that developers have a version of Visual Studio
# installed that includes CMake 3.14 or later. You should not increase this
# version, as doing so will cause the plugin to fail to compile for some
# customers of the plugin.
cmake_minimum_required(VERSION 3.14)

# Project-level configuration.
set(PROJECT_NAME "floating_palette")
project(${PROJECT_NAME} LANGUAGES CXX)

# Explicitly opt in to modern CMake behaviors to avoid warnings with recent
# versions of CMake.
cmake_policy(VERSION 3.14...3.25)

# This value is used when generating builds using this plugin, so it must
# not be changed
set(PLUGIN_NAME "floating_palette_plugin")

# Any new source files that you add to the plugin should be added here.
list(APPEND PLUGIN_SOURCES
  # Root level files
  "floating_palette_plugin.cpp"
  "floating_palette_plugin.h"
  "floating_palette_plugin_c_api.cpp"
  "include/floating_palette/floating_palette_plugin_c_api.h"
  # Core
  "core/logger.h"
  "core/window_store.h"
  "core/param_helpers.h"
  "core/palette_binary_messenger.h"
  "core/monitor_helper.h"
  "core/monitor_helper.cpp"
  # Coordinators
  "coordinators/drag_coordinator.h"
  "coordinators/drag_coordinator.cpp"
  # FFI
  "ffi/ffi_interface.h"
  "ffi/ffi_interface.cpp"
  # Services
  "services/window_service.h"
  "services/window_service.cpp"
  "services/visibility_service.h"
  "services/visibility_service.cpp"
  "services/frame_service.h"
  "services/frame_service.cpp"
  "services/transform_service.h"
  "services/transform_service.cpp"
  "services/animation_service.h"
  "services/animation_service.cpp"
  "services/input_service.h"
  "services/input_service.cpp"
  "services/focus_service.h"
  "services/focus_service.cpp"
  "services/zorder_service.h"
  "services/zorder_service.cpp"
  "services/appearance_service.h"
  "services/appearance_service.cpp"
  "services/screen_service.h"
  "services/screen_service.cpp"
  "services/background_capture_service.h"
  "services/background_capture_service.cpp"
  "services/message_service.h"
  "services/message_service.cpp"
  "services/host_service.h"
  "services/host_service.cpp"
  "services/snap_service.h"
  "services/snap_service.cpp"
  "services/window_channel_router.h"
  "services/window_channel_router.cpp"
)

# Define the plugin library target. Its name must not be changed (see comment
# on PLUGIN_NAME above).
add_library(${PLUGIN_NAME} SHARED
  ${PLUGIN_SOURCES}
)

# Apply a standard set of build settings that are configured in the
# application-level CMakeLists.txt. This can be removed for plugins that want
# full control over build settings.
apply_standard_settings(${PLUGIN_NAME})

# Symbols are hidden by default to reduce the chance of accidental conflicts
# between plugins. This should not be removed; any symbols that should be
# exported should be explicitly exported with the FLUTTER_PLUGIN_EXPORT macro.
set_target_properties(${PLUGIN_NAME} PROPERTIES
  CXX_VISIBILITY_PRESET hidden)
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)

# Source include directories and library dependencies. Add any plugin-specific
# dependencies here.
target_include_directories(${PLUGIN_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}/include")
target_link_libraries(${PLUGIN_NAME} PRIVATE flutter flutter_wrapper_plugin dwmapi Shcore comctl32)

# List of absolute paths to libraries that should be bundled with the plugin.
# This list could contain prebuilt libraries, or libraries created by an
# external build triggered from this build file.
set(floating_palette_bundled_libraries
  ""
  PARENT_SCOPE
)

# === IDE support ===
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

# === C++ Standard ===
target_compile_features(${PLUGIN_NAME} PRIVATE cxx_std_17)
