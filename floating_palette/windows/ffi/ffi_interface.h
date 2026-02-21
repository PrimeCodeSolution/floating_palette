#pragma once

/// FFI Interface for synchronous Dart-to-native calls.
///
/// These functions are exposed via extern "C" for direct FFI access from Dart.
/// They provide synchronous operations critical for flicker-free UX:
/// - Window resizing (SizeReporter)
/// - Cursor position queries
/// - Screen bounds queries
/// - Active app bounds queries
/// - Glass mask effect (no-op stubs on Windows)
///
/// IMPORTANT: Keep function signatures in sync with src/ffi_interface.h

#include <windows.h>

#include <stdbool.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// ═══════════════════════════════════════════════════════════════════════════
// WINDOW SIZING
// ═══════════════════════════════════════════════════════════════════════════

__declspec(dllexport) void FloatingPalette_ResizeWindow(
    const char* window_id,
    double width,
    double height);

__declspec(dllexport) bool FloatingPalette_GetWindowFrame(
    const char* window_id,
    double* out_x,
    double* out_y,
    double* out_width,
    double* out_height);

__declspec(dllexport) bool FloatingPalette_IsWindowVisible(
    const char* window_id);

// ═══════════════════════════════════════════════════════════════════════════
// CURSOR POSITION
// ═══════════════════════════════════════════════════════════════════════════

__declspec(dllexport) void FloatingPalette_GetCursorPosition(
    double* out_x,
    double* out_y);

__declspec(dllexport) int32_t FloatingPalette_GetCursorScreen(void);

// ═══════════════════════════════════════════════════════════════════════════
// SCREEN INFO
// ═══════════════════════════════════════════════════════════════════════════

__declspec(dllexport) int32_t FloatingPalette_GetScreenCount(void);

__declspec(dllexport) bool FloatingPalette_GetScreenBounds(
    int32_t screen_index,
    double* out_x,
    double* out_y,
    double* out_width,
    double* out_height);

__declspec(dllexport) bool FloatingPalette_GetScreenVisibleBounds(
    int32_t screen_index,
    double* out_x,
    double* out_y,
    double* out_width,
    double* out_height);

__declspec(dllexport) double FloatingPalette_GetScreenScaleFactor(
    int32_t screen_index);

// ═══════════════════════════════════════════════════════════════════════════
// ACTIVE APPLICATION
// ═══════════════════════════════════════════════════════════════════════════

__declspec(dllexport) bool FloatingPalette_GetActiveAppBounds(
    double* out_x,
    double* out_y,
    double* out_width,
    double* out_height);

__declspec(dllexport) int32_t FloatingPalette_GetActiveAppIdentifier(
    char* out_buffer,
    int32_t buffer_size);

// ═══════════════════════════════════════════════════════════════════════════
// GLASS MASK EFFECT (no-op stubs — macOS-only feature)
// ═══════════════════════════════════════════════════════════════════════════

__declspec(dllexport) void* FloatingPalette_CreateGlassPathBuffer(
    const char* window_id);

__declspec(dllexport) void FloatingPalette_DestroyGlassPathBuffer(
    const char* window_id);

__declspec(dllexport) void FloatingPalette_SetGlassEnabled(
    const char* window_id,
    bool enabled);

__declspec(dllexport) void FloatingPalette_SetGlassMaterial(
    const char* window_id,
    int32_t material);

__declspec(dllexport) void FloatingPalette_SetGlassDark(
    const char* window_id,
    bool is_dark);

__declspec(dllexport) void FloatingPalette_SetGlassTintOpacity(
    const char* window_id,
    float opacity,
    float corner_radius);

// ═══════════════════════════════════════════════════════════════════════════
// GLASS ANIMATION (no-op stubs — macOS-only feature)
// ═══════════════════════════════════════════════════════════════════════════

__declspec(dllexport) double FloatingPalette_GetCurrentTime(void);

__declspec(dllexport) void* FloatingPalette_CreateAnimationBuffer(
    const char* window_id,
    int32_t layer_id);

__declspec(dllexport) void FloatingPalette_DestroyAnimationBuffer(
    const char* window_id,
    int32_t layer_id);

#ifdef __cplusplus
}
#endif
