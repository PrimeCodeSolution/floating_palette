import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/painting.dart' show Alignment, Axis;
import 'package:flutter/scheduler.dart' show Priority, SchedulerBinding;
import 'package:flutter/services.dart' show LogicalKeyboardKey;

import '../config/config.dart';
import '../core/capability_guard.dart';
import '../core/palette_host.dart';
import '../events/palette_event.dart';
import '../input/input.dart';
import '../positioning/positioning.dart';
import '../services/services.dart';
import '../snap/snap_events.dart';
import '../snap/snap_types.dart';
import 'effects_helper.dart';
import 'input_registration_helper.dart';
import 'palette_messaging.dart';
import 'position_resolver.dart';
import 'transform_helper.dart';

// Re-export for backward compatibility
export 'effects_helper.dart' show ShakeDirection, ShakeDecay;

/// Callback types for palette events.
typedef PaletteVoidCallback = void Function();
typedef PaletteMessageCallback<T> = void Function(T message);

/// Controller for a single palette window.
///
/// Provides imperative control over visibility, position, transforms, and effects.
class PaletteController<TArgs> implements PaletteIdentifiable {
  /// The palette ID this controller manages.
  final String id;

  /// The host that owns this controller.
  final PaletteHost _host;

  /// Current configuration (starts from annotation defaults).
  PaletteConfig _config;

  /// The default configuration from annotations.
  final PaletteConfig _defaultConfig;

  /// Current args (set on show, cleared on hide).
  TArgs? _currentArgs;

  /// Whether the palette is currently visible.
  bool _isVisible = false;

  /// Whether the window has been created.
  bool _isWarm = false;

  /// Whether the palette is frozen (interaction disabled).
  bool _isFrozen = false;

  /// Whether this palette is currently snapped to another palette.
  bool _isSnapped = false;

  // ════════════════════════════════════════════════════════════════════════════
  // Service Clients (created with injected bridge)
  // ════════════════════════════════════════════════════════════════════════════

  late final WindowClient _window;
  late final VisibilityClient _visibility;
  late final FrameClient _frame;
  late final TransformClient _transform;
  late final AnimationClient _animation;
  late final InputClient _input;
  late final FocusClient _focus;
  late final ZOrderClient _zorder;
  late final AppearanceClient _appearance;
  late final ScreenClient _screen;
  late final MessageClient _messageClient;

  // Helpers
  late final EffectsHelper _effects;
  late final PositionResolver _positionResolver;
  late final InputRegistrationHelper _inputRegistration;
  late final PaletteMessaging _messaging;
  late final TransformHelper _transformHelper;
  late final CapabilityGuard _guard;

  // Escape key handler subscription
  StreamSubscription<(String, LogicalKeyboardKey, Set<LogicalKeyboardKey>)>?
      _escapeSubscription;

  // Operation serializer to prevent concurrent show/hide interleaving
  Future<void>? _pendingOperation;

  // ════════════════════════════════════════════════════════════════════════════
  // Callbacks
  // ════════════════════════════════════════════════════════════════════════════

  final List<PaletteVoidCallback> _onShowCallbacks = [];
  final List<PaletteVoidCallback> _onHideCallbacks = [];
  final List<PaletteVoidCallback> _onDisposeCallbacks = [];
  final Map<Type, List<_TypedCallbackBase>> _messageCallbacks = {};

  /// Stream controller for visibility changes.
  final _visibilityController = StreamController<bool>.broadcast();

  PaletteController({
    required this.id,
    required PaletteHost host,
    PaletteConfig? config,
  })  : _host = host,
        _config = config ?? const PaletteConfig(),
        _defaultConfig = config ?? const PaletteConfig() {
    _initializeClients();
    _setupEventListeners();
  }

  void _initializeClients() {
    final bridge = _host.bridge;
    _window = WindowClient(bridge);
    _visibility = VisibilityClient(bridge);
    _frame = FrameClient(bridge);
    _transform = TransformClient(bridge);
    _animation = AnimationClient(bridge);
    _input = InputClient(bridge);
    _focus = FocusClient(bridge);
    _zorder = ZOrderClient(bridge);
    _appearance = AppearanceClient(bridge);
    _screen = ScreenClient(bridge);
    _messageClient = MessageClient(bridge);

    // Initialize helpers
    _effects = EffectsHelper(_animation);
    _positionResolver = PositionResolver(_screen);
    _inputRegistration = InputRegistrationHelper(id, _host.inputManager);
    _messaging = PaletteMessaging(id, _messageClient);
    _transformHelper = TransformHelper(_transform);
    _guard = CapabilityGuard(
      _host.capabilities,
      behavior: _config.unsupportedBehavior,
    );
  }

  void _setupEventListeners() {
    _visibility.onShown(id, () => _setVisible(true));
    _visibility.onHidden(id, () => _setVisible(false));
    _window.onContentReady(id, () => _isWarm = true);
  }

  // ════════════════════════════════════════════════════════════════════════════
  // State Queries
  // ════════════════════════════════════════════════════════════════════════════

  bool get isVisible => _isVisible;
  bool get isWarm => _isWarm;
  bool get isFrozen => _isFrozen;
  bool get isSnapped => _isSnapped;
  TArgs? get currentArgs => _currentArgs;
  PaletteConfig get config => _config;

  // ════════════════════════════════════════════════════════════════════════════
  // Capability Checks
  // ════════════════════════════════════════════════════════════════════════════

  /// Whether blur effects are supported on this platform.
  bool get supportsBlur => _host.capabilities.blur;

  /// Whether 3D transforms are supported on this platform.
  bool get supportsTransform => _host.capabilities.transform;

  /// Whether global hotkeys are supported on this platform.
  bool get supportsGlobalHotkeys => _host.capabilities.globalHotkeys;

  /// Whether native glass effect is supported on this platform.
  bool get supportsGlassEffect => _host.capabilities.glassEffect;

  /// The current platform name.
  String get platform => _host.capabilities.platform;
  Stream<bool> get visibilityStream => _visibilityController.stream;

  Future<Offset> get position => _frame.getPosition(id);
  Future<Size> get size => _frame.getSize(id);
  Future<Rect> get bounds => _frame.getBounds(id);
  Future<double> get currentScale => _transform.getScale(id);
  Future<double> get rotation => _transform.getRotation(id);
  Future<int> get zIndex => _zorder.getZIndex(id);
  Future<bool> get hasFocus => _focus.hasFocus(id);

  /// Get bounds as [ScreenRect] for anchor point calculations.
  Future<ScreenRect> get screenRect async {
    final b = await bounds;
    return ScreenRect.fromBounds(b);
  }

  /// Get screen position of a specific anchor point.
  Future<Offset> getAnchorPoint(Anchor anchor) async {
    final rect = await screenRect;
    return rect.anchorPoint(anchor);
  }

  // ════════════════════════════════════════════════════════════════════════════
  // Lifecycle
  // ════════════════════════════════════════════════════════════════════════════

  /// Pre-create the window without showing.
  Future<void> warmUp() async {
    if (_isWarm) return;
    try {
      await _window.create(
        id,
        appearance: _config.appearance,
        size: _config.size,
        keepAlive: _config.behavior.keepAlive,
      );
    } catch (e) {
      // Window may already exist after hot restart - that's fine
      debugPrint('[PaletteController] warmUp($id): $e (window may already exist)');
    }
    _isWarm = true;
  }

  /// Schedule warmup during idle time. If [autoShowOnReady], shows after warmup.
  void scheduleWarmUp({
    Priority priority = Priority.idle,
    bool autoShowOnReady = false,
    PalettePosition? position,
  }) {
    if (_isWarm) {
      if (autoShowOnReady) show(position: position);
      return;
    }
    SchedulerBinding.instance.scheduleTask(() async {
      await warmUp();
      if (autoShowOnReady) show(position: position);
    }, priority);
  }

  /// Schedule warmup for multiple palettes during idle time.
  static void scheduleWarmUpAll(
    List<PaletteController> palettes, {
    Priority priority = Priority.idle,
  }) {
    for (final palette in palettes) {
      palette.scheduleWarmUp(priority: priority);
    }
  }

  /// Destroy the window to free resources.
  Future<void> coolDown() async {
    if (!_isWarm) return;
    await _window.destroy(id);
    _isWarm = false;
  }

  /// Recreate the window content.
  Future<void> reload() async {
    final wasVisible = _isVisible;
    if (wasVisible) await hide();
    await coolDown();
    await warmUp();
    if (wasVisible) await show();
  }

  // ════════════════════════════════════════════════════════════════════════════
  // Show / Hide
  // ════════════════════════════════════════════════════════════════════════════

  /// Serialize async operations to prevent concurrent show/hide interleaving.
  Future<void> _serialized(Future<void> Function() operation) async {
    while (_pendingOperation != null) {
      await _pendingOperation;
    }
    final completer = Completer<void>();
    _pendingOperation = completer.future;
    try {
      await operation();
    } finally {
      _pendingOperation = null;
      completer.complete();
    }
  }

  /// Show the palette with optional overrides for position, size, focus, and input behavior.
  Future<void> show({
    TArgs? args,
    PalettePosition? position,
    PaletteSize? size,
    bool? focus,
    Set<LogicalKeyboardKey>? keys,
    ClickOutsideBehavior? clickOutside,
    PaletteGroup? group,
    Duration? delay,
    Duration? autoHideAfter,
    bool animate = true,
  }) async {
    // Check show guard - prevent re-show during dismiss cycle
    if (_host.inputManager.isShowBlocked(id)) {
      debugPrint('[PaletteController] show($id): BLOCKED by show guard');
      return;
    }

    // Delay outside the serialized block so the lock isn't held during sleep
    if (delay != null) await Future<void>.delayed(delay);

    await _serialized(() async {
      _currentArgs = args;

      // Ensure window exists
      if (!_isWarm) await warmUp();

      // Apply size and position
      final sz = size ?? _config.size;
      if (sz.resizable) {
        await _frame.setSize(id, Size(sz.width, sz.minHeight));
      }
      final pos = position ?? _config.position;
      await _frame.setPosition(id, await _resolvePosition(pos), anchor: pos.anchor.name);

      // Show window
      final effectiveFocus = focus ?? _config.behavior.shouldFocus;
      await _visibility.show(id, animate: animate, focus: effectiveFocus);

      // Auto-pin above all windows if configured
      if (_config.behavior.alwaysOnTop) {
        await pin(level: PinLevel.aboveAll);
      }

      // Register input handling
      final result = await _inputRegistration.register(
        behavior: _config.behavior,
        keyboard: _config.keyboard,
        focusOverride: focus,
        keysOverride: keys,
        clickOutsideOverride: clickOutside,
        groupOverride: group,
        onDismiss: hide,
      );

      if (!result.registered) {
        debugPrint('[PaletteController] show($id): registration blocked, hiding');
        await _visibility.hide(id, animate: false);
        return;
      }

      if (result.hideOnEscape) _setupEscapeHandler();
      if (autoHideAfter != null) Future<void>.delayed(autoHideAfter, hide);
    });
  }

  /// Hide the palette.
  Future<void> hide({
    Duration? delay,
    bool animate = true,
  }) async {
    if (!_isVisible) return;

    // Delay outside the serialized block so the lock isn't held during sleep
    if (delay != null) await Future<void>.delayed(delay);

    await _serialized(() async {
      // Re-check after acquiring the lock — may have been hidden by a concurrent operation
      if (!_isVisible) return;

      _currentArgs = null;
      _cleanupEscapeHandler();
      await _inputRegistration.unregister();

      await _visibility.hide(id, animate: animate);
    });
  }

  /// Toggle visibility.
  Future<void> toggle({TArgs? args}) async {
    if (_isVisible) {
      await hide();
    } else {
      await show(args: args);
    }
  }

  /// Show positioned relative to another palette's anchor point.
  Future<void> showRelativeTo(
    PaletteController other, {
    required Anchor theirAnchor,
    Anchor myAnchor = Anchor.topLeft,
    Offset offset = Offset.zero,
    TArgs? args,
    bool? focus,
    Set<LogicalKeyboardKey>? keys,
    ClickOutsideBehavior? clickOutside,
    bool animate = true,
  }) async {
    // Get the other palette's screen rect
    final otherRect = await other.screenRect;

    // Calculate target position
    final targetPoint = otherRect.anchorPoint(theirAnchor) + offset;

    // Show at that position with the specified anchor
    await show(
      args: args,
      position: PalettePosition(
        target: Target.custom,
        customPosition: targetPoint,
        anchor: myAnchor,
      ),
      focus: focus,
      keys: keys,
      clickOutside: clickOutside,
      animate: animate,
    );
  }

  /// Show at a specific screen position.
  Future<void> showAtPosition(
    Offset screenPosition, {
    Anchor anchor = Anchor.topLeft,
    Offset offset = Offset.zero,
    TArgs? args,
    bool? focus,
    Set<LogicalKeyboardKey>? keys,
    ClickOutsideBehavior? clickOutside,
    bool animate = true,
  }) async {
    await show(
      args: args,
      position: PalettePosition(
        target: Target.custom,
        customPosition: screenPosition + offset,
        anchor: anchor,
      ),
      focus: focus,
      keys: keys,
      clickOutside: clickOutside,
      animate: animate,
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // Position
  // ════════════════════════════════════════════════════════════════════════════

  /// Move to a position.
  Future<void> move({
    Offset? to,
    Offset? by,
    bool animate = false,
    Duration? duration,
    String curve = 'easeOut',
  }) async {
    if (!_isVisible) return;

    Offset target;
    if (to != null) {
      target = to;
    } else if (by != null) {
      final current = await _frame.getPosition(id);
      target = current + by;
    } else {
      return;
    }

    await _frame.setPosition(
      id,
      target,
      animate: animate,
      durationMs: duration?.inMilliseconds,
      curve: curve,
    );
  }

  /// Resolve a PalettePosition to screen coordinates.
  ///
  /// Delegates to [PositionResolver] which handles platform-specific
  /// coordinate systems automatically.
  Future<Offset> _resolvePosition(PalettePosition position) =>
      _positionResolver.resolve(position);

  // ════════════════════════════════════════════════════════════════════════════
  // Size
  // ════════════════════════════════════════════════════════════════════════════

  /// Resize the palette.
  Future<void> resize({
    Size? to,
    double? width,
    double? height,
    bool animate = false,
    Duration? duration,
    String curve = 'easeOut',
  }) async {
    if (!_isVisible) return;

    final current = await _frame.getSize(id);
    final target = Size(
      to?.width ?? width ?? current.width,
      to?.height ?? height ?? current.height,
    );

    await _frame.setSize(
      id,
      target,
      animate: animate,
      durationMs: duration?.inMilliseconds,
      curve: curve,
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // Snap (palette-to-palette snapping)
  // ════════════════════════════════════════════════════════════════════════════

  /// Snap this palette to another palette.
  ///
  /// [mode] determines the relationship:
  /// - [SnapMode.follower] (default): One-way. This palette follows target.
  /// - [SnapMode.bidirectional]: Two-way. Drag either, both move together.
  ///
  /// Example - Follower mode (keyboard follows editor):
  /// ```dart
  /// keyboard.snapTo(editor, myEdge: SnapEdge.top, targetEdge: SnapEdge.bottom);
  /// ```
  ///
  /// Example - Bidirectional mode (blocks move together):
  /// ```dart
  /// blockA.snapTo(
  ///   blockB,
  ///   myEdge: SnapEdge.top,
  ///   targetEdge: SnapEdge.bottom,
  ///   mode: SnapMode.bidirectional,
  /// );
  /// // Now dragging A moves B, and dragging B moves A
  /// ```
  Future<void> snapTo(
    PaletteController target, {
    required SnapEdge myEdge,
    required SnapEdge targetEdge,
    SnapAlignment alignment = SnapAlignment.center,
    double gap = 0,
    SnapConfig config = const SnapConfig(),
    SnapMode mode = SnapMode.follower,
  }) async {
    // Create forward binding: this → target
    await _host.snapClient.snap(
      followerId: id,
      targetId: target.id,
      followerEdge: myEdge,
      targetEdge: targetEdge,
      alignment: alignment,
      gap: gap,
      config: config,
    );
    _isSnapped = true;

    // For bidirectional mode, create reverse binding: target → this
    if (mode == SnapMode.bidirectional) {
      await _host.snapClient.snap(
        followerId: target.id,
        targetId: id,
        followerEdge: targetEdge,
        targetEdge: myEdge,
        alignment: alignment,
        gap: gap,
        config: config,
      );
      target._isSnapped = true;
    }
  }

  /// Detach this palette from its snap target.
  ///
  /// After detaching, the palette will no longer follow its target's movement.
  Future<void> detachSnap() async {
    if (!_isSnapped) return;
    await _host.snapClient.detach(id);
    _isSnapped = false;
  }

  /// Re-snap this palette to its original snap position.
  ///
  /// Use after user drags the follower to snap it back.
  /// Only works if the palette has an existing snap binding.
  Future<void> reSnap() async {
    if (!_isSnapped) return;
    await _host.snapClient.reSnap(id);
  }

  /// Get current distance from this palette to its snap position.
  ///
  /// Returns the Euclidean distance in screen points.
  /// Useful for implementing magnetic snap behavior.
  Future<double> getSnapDistance() async {
    if (!_isSnapped) return 0;
    return _host.snapClient.getSnapDistance(id);
  }

  /// Listen for snap events on this palette.
  ///
  /// Events include:
  /// - [SnapDragStarted] - User starts dragging this palette
  /// - [SnapDragging] - During drag (for live distance updates)
  /// - [SnapDragEnded] - User releases the drag
  /// - [SnapDetached] - Snap binding was removed
  /// - [SnapSnapped] - Palette was snapped to target
  /// - [SnapProximityEntered] - Dragged palette enters snap zone
  /// - [SnapProximityExited] - Dragged palette exits snap zone
  /// - [SnapProximityUpdated] - Distance changes during drag in snap zone
  ///
  /// Example: Implement magnetic snap behavior:
  /// ```dart
  /// keyboard.onSnapEvent((event) {
  ///   if (event is SnapDragEnded) {
  ///     if (event.snapDistance < 50) {
  ///       keyboard.reSnap();  // Close enough, snap back
  ///     } else {
  ///       keyboard.detachSnap();  // Too far, fully detach
  ///     }
  ///   }
  /// });
  /// ```
  void onSnapEvent(void Function(SnapEvent) callback) {
    _host.snapClient.onSnapEvent(id, (event) {
      if (event is SnapDetached) {
        _isSnapped = false;
      } else if (event is SnapSnapped) {
        _isSnapped = true;
      }
      callback(event);
    });
  }

  /// Enable auto-snapping for this palette.
  ///
  /// When enabled, this palette will automatically snap to compatible
  /// palettes when dragged within proximity threshold.
  ///
  /// Example: Enable auto-snap on all edges:
  /// ```dart
  /// Palettes.keyboard.enableAutoSnap();
  /// ```
  ///
  /// Example: Only allow snapping from top edge:
  /// ```dart
  /// Palettes.keyboard.enableAutoSnap(AutoSnapConfig(
  ///   acceptsSnapOn: {},  // Nothing can snap to this palette
  ///   canSnapFrom: {SnapEdge.top},  // Can snap its top to other palettes
  /// ));
  /// ```
  Future<void> enableAutoSnap([AutoSnapConfig config = const AutoSnapConfig()]) async {
    await _host.snapClient.setAutoSnapConfig(id, config);
  }

  /// Disable auto-snapping for this palette.
  Future<void> disableAutoSnap() async {
    await _host.snapClient.disableAutoSnap(id);
  }

  // ════════════════════════════════════════════════════════════════════════════
  // Attach Convenience Methods
  // ════════════════════════════════════════════════════════════════════════════

  /// Attach this palette below another palette.
  ///
  /// The palettes will move together when either is dragged.
  ///
  /// ```dart
  /// // Attach keyboard below editor
  /// await Palettes.virtualKeyboard.attachBelow(Palettes.editor);
  /// ```
  Future<void> attachBelow(PaletteController target, {double gap = 0}) async {
    await snapTo(
      target,
      myEdge: SnapEdge.top,
      targetEdge: SnapEdge.bottom,
      gap: gap,
      config: SnapConfig.attached,
    );
  }

  /// Attach this palette above another palette.
  ///
  /// ```dart
  /// await Palettes.toolbar.attachAbove(Palettes.editor);
  /// ```
  Future<void> attachAbove(PaletteController target, {double gap = 0}) async {
    await snapTo(
      target,
      myEdge: SnapEdge.bottom,
      targetEdge: SnapEdge.top,
      gap: gap,
      config: SnapConfig.attached,
    );
  }

  /// Attach this palette to the left of another palette.
  ///
  /// ```dart
  /// await Palettes.sidebar.attachLeft(Palettes.editor);
  /// ```
  Future<void> attachLeft(PaletteController target, {double gap = 0}) async {
    await snapTo(
      target,
      myEdge: SnapEdge.right,
      targetEdge: SnapEdge.left,
      gap: gap,
      config: SnapConfig.attached,
    );
  }

  /// Attach this palette to the right of another palette.
  ///
  /// ```dart
  /// await Palettes.panel.attachRight(Palettes.editor);
  /// ```
  Future<void> attachRight(PaletteController target, {double gap = 0}) async {
    await snapTo(
      target,
      myEdge: SnapEdge.left,
      targetEdge: SnapEdge.right,
      gap: gap,
      config: SnapConfig.attached,
    );
  }

  /// Detach this palette from any attachment.
  ///
  /// After detaching, the palette will move independently.
  Future<void> detach() => detachSnap();

  // ════════════════════════════════════════════════════════════════════════════
  // Transform
  // ════════════════════════════════════════════════════════════════════════════

  Future<void> scale(double factor, {Alignment anchor = Alignment.center, bool animate = false, Duration? duration, String curve = 'easeOut'}) async {
    if (!_isVisible) return;
    await _transformHelper.scale(id, factor, anchor: anchor, animate: animate, duration: duration, curve: curve);
  }

  /// Rotate the palette around an anchor point.
  ///
  /// On platforms that don't support transforms, this will warn/throw/no-op based on
  /// [PaletteConfig.unsupportedBehavior].
  Future<void> rotate(double radians, {Alignment anchor = Alignment.center, bool animate = false, Duration? duration, String curve = 'easeOut'}) async {
    if (!_isVisible) return;
    if (!_guard.requireTransform('Rotation will have no effect.')) return;
    await _transformHelper.rotate(id, radians, anchor: anchor, animate: animate, duration: duration, curve: curve);
  }

  /// Flip the palette on an axis.
  ///
  /// On platforms that don't support transforms, this will warn/throw/no-op based on
  /// [PaletteConfig.unsupportedBehavior].
  Future<void> flip({Axis axis = Axis.horizontal, bool animate = false, Duration? duration, String curve = 'easeOut'}) async {
    if (!_isVisible) return;
    if (!_guard.requireTransform('Flip will have no effect.')) return;
    await _transformHelper.flip(id, axis: axis, animate: animate, duration: duration, curve: curve);
  }

  /// Reset all transforms to identity.
  Future<void> resetTransform({bool animate = false, Duration? duration}) async {
    if (!_isVisible) return;
    await _transformHelper.reset(id, animate: animate, duration: duration);
  }

  // ════════════════════════════════════════════════════════════════════════════
  // Feedback Effects (Composed from Animation Service)
  // ════════════════════════════════════════════════════════════════════════════

  /// Shake the palette for attention or error feedback.
  Future<void> shake({
    ShakeDirection direction = ShakeDirection.horizontal,
    double intensity = 10,
    int count = 3,
    Duration duration = const Duration(milliseconds: 300),
    ShakeDecay decay = ShakeDecay.exponential,
  }) async {
    if (!_isVisible) return;
    await _effects.shake(id,
        direction: direction,
        intensity: intensity,
        count: count,
        duration: duration,
        decay: decay);
  }

  /// Pulse the palette (scale animation).
  Future<void> pulse({
    double maxScale = 1.1,
    int count = 2,
    Duration duration = const Duration(milliseconds: 400),
  }) async {
    if (!_isVisible) return;
    await _effects.pulse(id, maxScale: maxScale, count: count, duration: duration);
  }

  /// Bounce the palette.
  Future<void> bounce({
    double height = 20,
    int count = 2,
    Duration duration = const Duration(milliseconds: 400),
  }) async {
    if (!_isVisible) return;
    await _effects.bounce(id, height: height, count: count, duration: duration);
  }

  // ════════════════════════════════════════════════════════════════════════════
  // Opacity
  // ════════════════════════════════════════════════════════════════════════════

  /// Fade to an opacity.
  Future<void> fade(
    double opacity, {
    Duration duration = const Duration(milliseconds: 200),
  }) async {
    if (!_isVisible) return;
    await _visibility.setOpacity(id, opacity, animate: true, durationMs: duration.inMilliseconds);
  }

  // ════════════════════════════════════════════════════════════════════════════
  // Z-Order
  // ════════════════════════════════════════════════════════════════════════════

  Future<void> bringToFront() => _zorder.bringToFront(id);
  Future<void> sendToBack() => _zorder.sendToBack(id);
  Future<void> moveAbove(String otherId) => _zorder.moveAbove(id, otherId);
  Future<void> moveBelow(String otherId) => _zorder.moveBelow(id, otherId);
  Future<void> pin({PinLevel level = PinLevel.abovePalettes}) => _zorder.pin(id, level: level);
  Future<void> unpin() => _zorder.unpin(id);

  // ════════════════════════════════════════════════════════════════════════════
  // Appearance
  // ════════════════════════════════════════════════════════════════════════════

  /// Enable or disable dragging for this palette at runtime.
  Future<void> setDraggable(bool draggable) async {
    _config = _config.copyWith(
      behavior: _config.behavior.copyWith(draggable: draggable),
    );
    if (_isVisible) {
      await _frame.setDraggable(id, draggable: draggable);
    }
  }

  /// Enable/disable system blur (NSVisualEffectView on macOS, Acrylic on Windows).
  ///
  /// On platforms that don't support blur, this will warn/throw/no-op based on
  /// [PaletteConfig.unsupportedBehavior].
  void setBlur({bool enabled = true, String material = 'hudWindow'}) {
    if (!_guard.requireBlur('Blur will have no effect.')) return;
    _appearance.setBlur(id, enabled: enabled, material: material);
  }

  // ════════════════════════════════════════════════════════════════════════════
  // Screen
  // ════════════════════════════════════════════════════════════════════════════

  /// Get full screen info for the screen this palette is currently on.
  Future<ScreenInfo?> getCurrentScreen() => _screen.getCurrentScreen(id);

  // ════════════════════════════════════════════════════════════════════════════
  // Focus
  // ════════════════════════════════════════════════════════════════════════════

  Future<void> focus() => _focus.focus(id);
  Future<void> unfocus() => _focus.unfocus(id);

  // ════════════════════════════════════════════════════════════════════════════
  // Input Events
  // ════════════════════════════════════════════════════════════════════════════

  /// Called when a key is pressed while this palette is active or wants this key.
  void onKeyDown(
    void Function(LogicalKeyboardKey key, Set<LogicalKeyboardKey> modifiers)
        callback,
  ) {
    _input.onKeyDown(id, callback);
  }

  /// Called when a key is released.
  void onKeyUp(void Function(LogicalKeyboardKey key) callback) {
    _input.onKeyUp(id, callback);
  }

  /// Called when user clicks outside this palette.
  void onClickOutside(void Function(Offset position) callback) {
    _input.onClickOutside(id, callback);
  }

  /// Stream of key events routed to this palette (focused or requested keys).
  Stream<(LogicalKeyboardKey, Set<LogicalKeyboardKey>)> get keyStream {
    return _host.inputManager.keyEventStream
        .where((event) => event.$1 == id)
        .map((event) => (event.$2, event.$3));
  }

  // ════════════════════════════════════════════════════════════════════════════
  // State Control
  // ════════════════════════════════════════════════════════════════════════════

  /// Freeze the palette (disable interaction).
  void freeze() {
    _isFrozen = true;
    _input.setPassthrough(id, enabled: true);
  }

  /// Unfreeze the palette.
  void unfreeze() {
    _isFrozen = false;
    _input.setPassthrough(id, enabled: false);
  }

  // ════════════════════════════════════════════════════════════════════════════
  // Messaging
  // ════════════════════════════════════════════════════════════════════════════

  /// Send a message to this palette (Host → Palette).
  Future<void> send(String type, [Map<String, dynamic>? data]) =>
      _messaging.send(type, data);

  /// Listen for messages from this palette (Palette → Host).
  void on(String type, void Function(Map<String, dynamic>) callback) =>
      _messaging.on(type, callback);

  /// Remove a message listener.
  void off(String type, void Function(Map<String, dynamic>) callback) =>
      _messaging.off(type, callback);

  /// Listen for typed palette events.
  ///
  /// Unlike [on], this method provides type-safe event handling using
  /// explicit event IDs that remain stable across code obfuscation.
  ///
  /// **Important**: The event type must be registered before calling this method:
  /// ```dart
  /// // Register once at app startup
  /// PaletteEvent.register<ItemSelectedEvent>(
  ///   'menu.item_selected',
  ///   ItemSelectedEvent.fromMap,
  /// );
  ///
  /// // Then use type-safe listener
  /// controller.onEvent<ItemSelectedEvent>((event) {
  ///   print('Selected: ${event.itemId}');
  /// });
  /// ```
  ///
  /// Throws [StateError] if the event type hasn't been registered.
  void onEvent<T extends PaletteEvent>(void Function(T event) callback) {
    final eventId = PaletteEvent.idFor<T>();
    if (eventId == null) {
      throw StateError(
        'Event type $T is not registered. '
        'Call PaletteEvent.register<$T>() before using onEvent<$T>().',
      );
    }

    _messaging.on(eventId, (data) {
      final event = PaletteEvent.deserialize(eventId, data);
      if (event != null && event is T) {
        callback(event);
      }
    });
  }

  /// Send a typed palette event to this palette.
  ///
  /// The event will be serialized using its [PaletteEvent.eventId] and
  /// [PaletteEvent.toMap] methods.
  Future<void> sendEvent(PaletteEvent event) =>
      _messaging.send(event.eventId, event.toMap());

  /// Show and wait for result (or null on cancel/timeout). Auto-hides after.
  Future<Map<String, dynamic>?> showAndWait({
    TArgs? args,
    PalettePosition? position,
    PaletteSize? size,
    bool? focus,
    Set<LogicalKeyboardKey>? keys,
    ClickOutsideBehavior? clickOutside,
    PaletteGroup? group,
    Duration timeout = const Duration(seconds: 60),
    bool animate = true,
  }) {
    return _messaging.waitForResult(
      showPalette: () => show(
        args: args,
        position: position,
        size: size,
        focus: focus,
        keys: keys,
        clickOutside: clickOutside,
        group: group,
        animate: animate,
      ),
      onHideCallback: onHide,
      removeHideCallback: (cb) => _onHideCallbacks.remove(cb),
      isVisible: () async => _isVisible,
      hidePalette: () => hide(animate: animate),
      timeout: timeout,
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // Config
  // ════════════════════════════════════════════════════════════════════════════

  /// Update configuration at runtime.
  void updateConfig({
    PaletteSize? size,
    PalettePosition? position,
    PaletteBehavior? behavior,
    PaletteKeyboard? keyboard,
    PaletteAppearance? appearance,
    PaletteAnimation? animation,
    PaletteLifecycle? lifecycle,
    UnsupportedBehavior? unsupportedBehavior,
  }) {
    _config = _config.copyWith(
      size: size,
      position: position,
      behavior: behavior,
      keyboard: keyboard,
      appearance: appearance,
      animation: animation,
      lifecycle: lifecycle,
      unsupportedBehavior: unsupportedBehavior,
    );

    // Rebuild capability guard if unsupportedBehavior changed
    if (unsupportedBehavior != null) {
      _guard = CapabilityGuard(
        _host.capabilities,
        behavior: _config.unsupportedBehavior,
      );
    }

    // Apply appearance immediately if visible
    if (_isVisible && appearance != null) {
      _appearance.applyAppearance(id, appearance);
    }

    // Apply draggable state to native when behavior changes
    if (_isVisible && behavior != null) {
      _frame.setDraggable(id, draggable: _config.behavior.draggable);
    }
  }

  /// Reset configuration to defaults.
  void resetConfig() {
    _config = _defaultConfig;

    // Rebuild capability guard with default behavior
    _guard = CapabilityGuard(
      _host.capabilities,
      behavior: _config.unsupportedBehavior,
    );

    if (_isVisible) {
      _appearance.applyAppearance(id, _config.appearance);
    }
  }

  // ════════════════════════════════════════════════════════════════════════════
  // Callbacks
  // ════════════════════════════════════════════════════════════════════════════

  void onShow(PaletteVoidCallback callback) => _onShowCallbacks.add(callback);
  void onHide(PaletteVoidCallback callback) => _onHideCallbacks.add(callback);
  void onDispose(PaletteVoidCallback callback) => _onDisposeCallbacks.add(callback);

  void onMessage<T>(PaletteMessageCallback<T> callback) {
    _messageCallbacks.putIfAbsent(T, () => []).add(_TypedCallback<T>(callback));
  }

  void removeAllCallbacks() {
    _onShowCallbacks.clear();
    _onHideCallbacks.clear();
    _onDisposeCallbacks.clear();
    _messageCallbacks.clear();
  }

  // ════════════════════════════════════════════════════════════════════════════
  // Hot Restart Recovery
  // ════════════════════════════════════════════════════════════════════════════

  /// Sync controller state from native window snapshot.
  ///
  /// Called by [PaletteHost.recover] after a hot restart to restore Dart state
  /// to match existing native windows.
  ///
  /// @nodoc Internal API - do not call directly.
  void syncFromNative({
    required bool visible,
    required Rect bounds,
    required bool focused,
  }) {
    // Mark as warm since window exists in native
    _isWarm = true;

    // Sync visibility state
    if (visible != _isVisible) {
      _isVisible = visible;
      _visibilityController.add(visible);

      if (visible) {
        // Re-register with input manager for keyboard/click handling
        _inputRegistration.register(
          behavior: _config.behavior,
          keyboard: _config.keyboard,
          onDismiss: () => hide(),
        );

        // Setup escape handler if configured
        if (_config.behavior.hideOnEscape) {
          _setupEscapeHandler();
        }
      }
    }

    debugPrint(
      '[PaletteController] Synced $id from native: '
      'visible=$visible, bounds=$bounds, focused=$focused',
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // Internal
  // ════════════════════════════════════════════════════════════════════════════

  /// Set up escape key handler to hide the palette.
  void _setupEscapeHandler() {
    _escapeSubscription?.cancel();
    _escapeSubscription = _host.inputManager.keyEventStream
        .where((event) => event.$1 == id && event.$2 == LogicalKeyboardKey.escape)
        .listen((_) {
      debugPrint('[PaletteController] Escape key pressed, hiding $id');
      hide();
    });
  }

  /// Clean up escape key handler.
  void _cleanupEscapeHandler() {
    _escapeSubscription?.cancel();
    _escapeSubscription = null;
  }

  void _setVisible(bool visible) {
    if (_isVisible == visible) return;
    _isVisible = visible;
    _visibilityController.add(visible);

    // When hidden, ensure keyboard/pointer capture is released
    // This handles the case when palette hides itself via PaletteWindow.hide()
    if (!visible) {
      _host.inputManager.unregisterPalette(id);
    }

    final callbacks = visible ? _onShowCallbacks : _onHideCallbacks;
    for (final cb in callbacks) {
      cb();
    }
  }

  void handleMessage<T>(T message) {
    final callbacks = _messageCallbacks[T];
    if (callbacks != null) {
      for (final cb in callbacks) {
        cb.call(message);
      }
    }
  }

  void dispose() {
    for (final cb in _onDisposeCallbacks) {
      cb();
    }
    _visibilityController.close();
    removeAllCallbacks();

    // Dispose service clients
    _window.dispose();
    _visibility.dispose();
    _frame.dispose();
    _transform.dispose();
    _animation.dispose();
    _input.dispose();
    _focus.dispose();
    _zorder.dispose();
    _appearance.dispose();
    _screen.dispose();
    _messageClient.dispose();
  }
}

/// Base class for type-safe message callback wrappers.
abstract class _TypedCallbackBase {
  void call(dynamic message);
}

/// Type-safe wrapper that eliminates unsafe casts in message dispatch.
class _TypedCallback<T> extends _TypedCallbackBase {
  final PaletteMessageCallback<T> _callback;
  _TypedCallback(this._callback);

  @override
  void call(dynamic message) {
    if (message is T) _callback(message);
  }
}
