/**
 * Floating Palette FFI Interface
 *
 * This header defines the synchronous FFI functions for time-critical operations.
 * It serves as the single source of truth for:
 *   - Dart FFI bindings (generated via ffigen)
 *   - macOS Swift implementation (@_cdecl functions)
 *   - Windows C++ implementation (extern "C" functions)
 *
 * All functions use C calling convention for cross-platform compatibility.
 *
 * IMPORTANT: After modifying this file, regenerate Dart bindings:
 *   dart run ffigen
 */

#ifndef FLOATING_PALETTE_FFI_INTERFACE_H
#define FLOATING_PALETTE_FFI_INTERFACE_H

#include <stdbool.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// ═══════════════════════════════════════════════════════════════════════════
// WINDOW SIZING
// Critical for SizeReporter - must resize window in same frame as measurement
// ═══════════════════════════════════════════════════════════════════════════

/**
 * Resize a palette window synchronously.
 * Called by SizeReporter when content size changes.
 *
 * @param window_id  The palette window identifier
 * @param width      New width in logical pixels
 * @param height     New height in logical pixels
 */
void FloatingPalette_ResizeWindow(
    const char* window_id,
    double width,
    double height
);

/**
 * Get the current frame (position and size) of a palette window.
 *
 * @param window_id  The palette window identifier
 * @param out_x      Output: X position (screen coordinates)
 * @param out_y      Output: Y position (screen coordinates)
 * @param out_width  Output: Window width
 * @param out_height Output: Window height
 * @return           true if window exists, false otherwise
 */
bool FloatingPalette_GetWindowFrame(
    const char* window_id,
    double* out_x,
    double* out_y,
    double* out_width,
    double* out_height
);

/**
 * Check if a palette window is currently visible.
 *
 * @param window_id  The palette window identifier
 * @return           true if window exists and is visible, false otherwise
 */
bool FloatingPalette_IsWindowVisible(const char* window_id);

// ═══════════════════════════════════════════════════════════════════════════
// CURSOR POSITION
// Critical for .nearCursor() positioning - need exact position at show moment
// ═══════════════════════════════════════════════════════════════════════════

/**
 * Get the current cursor (mouse) position in screen coordinates.
 *
 * @param out_x  Output: Cursor X position
 * @param out_y  Output: Cursor Y position
 */
void FloatingPalette_GetCursorPosition(
    double* out_x,
    double* out_y
);

/**
 * Get the screen index where the cursor is currently located.
 *
 * @return  Screen index (0-based), or -1 if unable to determine
 */
int32_t FloatingPalette_GetCursorScreen(void);

// ═══════════════════════════════════════════════════════════════════════════
// SCREEN INFO
// Critical for .constrain() and edge avoidance calculations
// ═══════════════════════════════════════════════════════════════════════════

/**
 * Get the number of connected screens/monitors.
 *
 * @return  Number of screens
 */
int32_t FloatingPalette_GetScreenCount(void);

/**
 * Get the full bounds of a screen (including menu bar, dock areas).
 *
 * @param screen_index  Screen index (0-based)
 * @param out_x         Output: Screen origin X
 * @param out_y         Output: Screen origin Y
 * @param out_width     Output: Screen width
 * @param out_height    Output: Screen height
 * @return              true if screen exists, false otherwise
 */
bool FloatingPalette_GetScreenBounds(
    int32_t screen_index,
    double* out_x,
    double* out_y,
    double* out_width,
    double* out_height
);

/**
 * Get the visible bounds of a screen (excluding menu bar, dock, taskbar).
 * Use this for constraining palette positions.
 *
 * @param screen_index  Screen index (0-based)
 * @param out_x         Output: Visible area origin X
 * @param out_y         Output: Visible area origin Y
 * @param out_width     Output: Visible area width
 * @param out_height    Output: Visible area height
 * @return              true if screen exists, false otherwise
 */
bool FloatingPalette_GetScreenVisibleBounds(
    int32_t screen_index,
    double* out_x,
    double* out_y,
    double* out_width,
    double* out_height
);

/**
 * Get the scale factor (DPI scaling) of a screen.
 *
 * @param screen_index  Screen index (0-based)
 * @return              Scale factor (1.0 = standard, 2.0 = Retina/HiDPI)
 */
double FloatingPalette_GetScreenScaleFactor(int32_t screen_index);

// ═══════════════════════════════════════════════════════════════════════════
// ACTIVE APPLICATION
// Critical for .atWidget() relative positioning to host app
// ═══════════════════════════════════════════════════════════════════════════

/**
 * Get the bounds of the frontmost/active application window.
 * Useful for positioning palettes relative to the host application.
 *
 * @param out_x       Output: Window origin X
 * @param out_y       Output: Window origin Y
 * @param out_width   Output: Window width
 * @param out_height  Output: Window height
 * @return            true if active window found, false otherwise
 */
bool FloatingPalette_GetActiveAppBounds(
    double* out_x,
    double* out_y,
    double* out_width,
    double* out_height
);

/**
 * Get the bundle identifier or process name of the active application.
 *
 * @param out_buffer      Buffer to write the identifier/name
 * @param buffer_size     Size of the buffer
 * @return                Length of the identifier, or 0 if not found
 */
int32_t FloatingPalette_GetActiveAppIdentifier(
    char* out_buffer,
    int32_t buffer_size
);

// ═══════════════════════════════════════════════════════════════════════════
// GLASS MASK EFFECT
// Native NSVisualEffectView blur masked to arbitrary path from Flutter
// ═══════════════════════════════════════════════════════════════════════════

/**
 * Path commands for glass mask (matches Flutter's path operations).
 */
typedef enum {
    GlassPath_MoveTo = 0,    // 1 point (x, y)
    GlassPath_LineTo = 1,    // 1 point (x, y)
    GlassPath_QuadTo = 2,    // 2 points (cx, cy, x, y)
    GlassPath_CubicTo = 3,   // 3 points (c1x, c1y, c2x, c2y, x, y)
    GlassPath_Close = 4,     // 0 points
} GlassPathCommand;

/**
 * Shared memory buffer for glass mask path data.
 * Flutter writes path commands/points, native reads and applies as CAShapeLayer mask.
 *
 * Thread safety:
 *   - Flutter writes frameIdPost FIRST (signals write in progress)
 *   - Flutter writes all data
 *   - Flutter writes frameId LAST (signals write complete)
 *   - Native reads frameId, copies data, reads frameIdPost
 *   - If frameId != frameIdPost, native skips frame (torn read)
 */
typedef struct {
    _Atomic uint64_t frameId;       // Incremented AFTER write complete

    uint32_t commandCount;          // Number of path commands
    uint8_t commands[256];          // Command types (GlassPathCommand enum)

    uint32_t pointCount;            // Number of points (x,y pairs)
    float points[1024];             // [x0,y0, x1,y1, ...] max 512 points

    float windowHeight;             // For Y-flip (Flutter Y=0 top, macOS Y=0 bottom)

    uint64_t frameIdPost;           // Copy of frameId for tear detection
} GlassPathBuffer;

/**
 * Create a shared path buffer for a palette window.
 * Returns a pointer that Flutter can write path data to.
 *
 * @param window_id  The palette window identifier
 * @return           Pointer to GlassPathBuffer, or NULL on failure
 */
void* FloatingPalette_CreateGlassPathBuffer(const char* window_id);

/**
 * Destroy the shared path buffer for a palette window.
 *
 * @param window_id  The palette window identifier
 */
void FloatingPalette_DestroyGlassPathBuffer(const char* window_id);

/**
 * Enable or disable the glass effect for a palette window.
 * When enabled, creates NSVisualEffectView and starts CVDisplayLink polling.
 *
 * @param window_id  The palette window identifier
 * @param enabled    true to enable glass effect, false to disable
 */
void FloatingPalette_SetGlassEnabled(const char* window_id, bool enabled);

/**
 * Set the blur material for the glass effect.
 *
 * @param window_id  The palette window identifier
 * @param material   Material index: 0=hudWindow, 1=sidebar, 2=popover, 3=menu, 4=sheet
 */
void FloatingPalette_SetGlassMaterial(const char* window_id, int32_t material);

/**
 * Set dark mode for the glass effect.
 *
 * @param window_id  The palette window identifier
 * @param is_dark    false = clear glass, true = dark/regular glass
 */
void FloatingPalette_SetGlassDark(const char* window_id, bool is_dark);

/**
 * Set tint opacity for the glass effect.
 * A dark tint layer is added behind the glass to reduce transparency.
 *
 * @param window_id     The palette window identifier
 * @param opacity       0.0 = fully transparent (default), 1.0 = fully opaque black
 * @param corner_radius Corner radius for the tint layer (default 16)
 */
void FloatingPalette_SetGlassTintOpacity(const char* window_id, float opacity, float corner_radius);

// ═══════════════════════════════════════════════════════════════════════════
// GLASS ANIMATION (Native-driven)
// Eliminates per-frame FFI calls during animations by moving interpolation
// to native side at display refresh rate (60-120Hz)
// ═══════════════════════════════════════════════════════════════════════════

/**
 * Animation curve types for native glass interpolation.
 * Must match Dart GlassAnimationCurve enum.
 */
typedef enum {
    GlassAnimation_Linear = 0,       // t
    GlassAnimation_EaseOut = 1,      // 1 - (1-t)^2
    GlassAnimation_EaseOutCubic = 2, // 1 - (1-t)^3 (default)
    GlassAnimation_EaseInOut = 3,    // t < 0.5 ? 2t^2 : 1 - (-2t+2)^2/2
} GlassAnimationCurve;

/**
 * Shared memory buffer for glass animation parameters.
 * Flutter writes animation params ONCE at start, native interpolates at display rate.
 *
 * Thread safety (same as GlassPathBuffer):
 *   - Flutter writes animationIdPost FIRST (signals write in progress)
 *   - Flutter writes all data
 *   - Flutter writes animationId LAST (signals write complete)
 *   - Native reads animationId, copies data, reads animationIdPost
 *   - If animationId != animationIdPost, native skips (torn read)
 */
typedef struct __attribute__((packed)) {
    uint64_t animationId;       // Incremented on each animation start

    uint8_t isAnimating;        // 1 = active animation, 0 = static bounds
    uint8_t curveType;          // GlassAnimationCurve enum value
    uint8_t _padding[2];        // Alignment padding

    // Start bounds (animation begins here)
    float startX;
    float startY;
    float startWidth;
    float startHeight;

    // Target bounds (animation ends here)
    float targetX;
    float targetY;
    float targetWidth;
    float targetHeight;

    float cornerRadius;         // Corner radius for RRect

    double startTime;           // CACurrentMediaTime at animation start
    double duration;            // Animation duration in seconds

    float windowHeight;         // For Y-flip if needed
    uint8_t _padding2[4];       // Alignment padding

    uint64_t animationIdPost;   // Copy of animationId for tear detection
} GlassAnimationBuffer;

/**
 * Get current time (CACurrentMediaTime) for clock synchronization.
 * Used by Dart to write animation start time in sync with native.
 *
 * @return  Current time in seconds (high precision)
 */
double FloatingPalette_GetCurrentTime(void);

/**
 * Create an animation buffer for a palette window and layer.
 * Returns a pointer that Flutter can write animation parameters to.
 *
 * @param window_id  The palette window identifier
 * @param layer_id   Layer ID (0 for default layer)
 * @return           Pointer to GlassAnimationBuffer, or NULL on failure
 */
void* FloatingPalette_CreateAnimationBuffer(
    const char* window_id,
    int32_t layer_id
);

/**
 * Destroy the animation buffer for a palette window and layer.
 *
 * @param window_id  The palette window identifier
 * @param layer_id   Layer ID (0 for default layer)
 */
void FloatingPalette_DestroyAnimationBuffer(
    const char* window_id,
    int32_t layer_id
);

#ifdef __cplusplus
}
#endif

#endif // FLOATING_PALETTE_FFI_INTERFACE_H
