import Cocoa
import CoreVideo
import os.log
import SwiftUI

/// Dumb infrastructure service for glass mask effect.
/// Knows nothing about shapes, SDF, or metaballs.
/// Just reads path commands from shared memory and applies as mask.
///
/// On macOS 26+ (Tahoe): Uses SwiftUI `.glassEffect()` for true Liquid Glass.
/// On older macOS: Falls back to NSVisualEffectView blur.
final class GlassMaskService {
    static let shared = GlassMaskService()

    // Shared memory buffers (raw pointers for direct memory access)
    private var buffers: [String: [Int: UnsafeMutableRawPointer]] = [:]

    // Fallback for pre-macOS 26 (NSVisualEffectView)
    private var blurViews: [String: [Int: NSVisualEffectView]] = [:]
    private var maskLayers: [String: [Int: CAShapeLayer]] = [:]

    // macOS 26+ Liquid Glass (SwiftUI)
    private var hostingViews: [String: [Int: NSView]] = [:]  // NSHostingView<LiquidGlassView>
    private var glassStates: [String: [Int: AnyObject]] = [:]  // GlassPathState (type-erased for availability)
    private var tintLayers: [String: CALayer] = [:]  // Tint overlay behind glass

    // Display link and state tracking
    private var displayLinks: [String: CVDisplayLink] = [:]
    private var lastFrameIds: [String: [Int: UInt64]] = [:]
    private var isEnabled: [String: Bool] = [:]
    private var usesLiquidGlass: [String: Bool] = [:]  // Track which mode each window uses

    // Window focus observers (to force redraw when focus changes)
    private var focusObservers: [String: [NSObjectProtocol]] = [:]

    private let lock = NSLock()

    /// Whether Liquid Glass (macOS 26+) is available
    var isLiquidGlassAvailable: Bool {
        if #available(macOS 26.0, *) {
            return true
        }
        return false
    }

    private init() {}

    // MARK: - Buffer Management

    /// Create a shared path buffer for a window and layer.
    /// Returns pointer that Flutter can write path data to.
    func createBuffer(windowId: String, layerId: Int) -> UnsafeMutableRawPointer {
        os_log("createBuffer windowId=%{public}@ layerId=%d", log: Log.glass, type: .debug, windowId, layerId)
        lock.lock()
        defer { lock.unlock() }

        var windowBuffers = buffers[windowId] ?? [:]
        if let existing = windowBuffers[layerId] {
            os_log("cleaning up existing buffer layer=%d", log: Log.glass, type: .debug, layerId)
            existing.deallocate()
        }

        let ptr = GlassPathBufferReader.allocateBuffer()
        windowBuffers[layerId] = ptr
        buffers[windowId] = windowBuffers

        os_log("buffer created ptr=%{public}@ size=%d", log: Log.glass, type: .debug, String(describing: ptr), GlassPathBufferReader.totalSize)

        if (isEnabled[windowId] ?? false) {
            DispatchQueue.main.async { [weak self] in
                guard let window = WindowStore.shared.get(windowId),
                      !window.isDestroyed,
                      let contentView = window.panel.contentView else { return }
                self?.ensureLayer(windowId: windowId, layerId: layerId, contentView: contentView)
            }
        }
        return ptr
    }

    /// Destroy the shared path buffer for a window and layer.
    func destroyBuffer(windowId: String, layerId: Int) {
        lock.lock()
        defer { lock.unlock() }

        if var windowBuffers = buffers[windowId],
           let ptr = windowBuffers.removeValue(forKey: layerId) {
            ptr.deallocate()
            if windowBuffers.isEmpty {
                buffers.removeValue(forKey: windowId)
            } else {
                buffers[windowId] = windowBuffers
            }
        }
    }

    /// Backward-compatible buffer creation for layer 0.
    func createBuffer(windowId: String) -> UnsafeMutableRawPointer {
        return createBuffer(windowId: windowId, layerId: 0)
    }

    /// Backward-compatible buffer destroy for layer 0.
    func destroyBuffer(windowId: String) {
        destroyBuffer(windowId: windowId, layerId: 0)
    }

    // MARK: - Enable/Disable

    /// Enable glass effect for a window.
    func enable(windowId: String) {
        os_log("enable windowId=%{public}@", log: Log.glass, type: .debug, windowId)

        guard WindowStore.shared.exists(windowId) else {
            os_log("enable failed: window not found windowId=%{public}@", log: Log.glass, type: .error, windowId)
            return
        }

        lock.lock()
        let alreadyEnabled = isEnabled[windowId] ?? false
        if alreadyEnabled {
            lock.unlock()
            os_log("enable: already enabled windowId=%{public}@", log: Log.glass, type: .debug, windowId)
            return
        }
        isEnabled[windowId] = true  // atomic with check
        lock.unlock()

        os_log("setting up glass view on main thread", log: Log.glass, type: .debug)
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            // Re-check — disable() may have run between our check and this dispatch
            self.lock.lock()
            let stillEnabled = self.isEnabled[windowId] ?? false
            self.lock.unlock()
            guard stillEnabled,
                  let window = WindowStore.shared.get(windowId),
                  !window.isDestroyed else {
                self.lock.lock()
                self.isEnabled[windowId] = false
                self.lock.unlock()
                return
            }
            self.setupGlassView(windowId: windowId, window: window)
        }
    }

    /// Disable glass effect for a window.
    func disable(windowId: String) {
        lock.lock()
        isEnabled[windowId] = false
        lock.unlock()

        stopDisplayLink(windowId: windowId)

        DispatchQueue.main.async { [weak self] in
            self?.teardownGlassView(windowId: windowId)
        }
    }

    /// Set the blur material for a window and layer.
    /// On macOS 26+ Liquid Glass: This is ignored (use setDark instead)
    /// On older macOS: Sets the NSVisualEffectView material
    func setMaterial(windowId: String, layerId: Int, material: Int32) {
        lock.lock()
        let useLiquidGlass = usesLiquidGlass[windowId] ?? false
        lock.unlock()

        if useLiquidGlass {
            // Liquid Glass doesn't use materials - it uses the .glassEffect modifier
            os_log("setMaterial ignored on Liquid Glass windowId=%{public}@ layer=%d", log: Log.glass, type: .debug, windowId, layerId)
            return
        }

        os_log("setMaterial windowId=%{public}@ layer=%d material=%d", log: Log.glass, type: .debug, windowId, layerId, material)

        let materials: [NSVisualEffectView.Material] = [
            .hudWindow,     // 0 - Dark HUD style
            .sidebar,       // 1 - Sidebar style (adapts to system)
            .popover,       // 2 - Light popover style
            .menu,          // 3 - Menu style
            .sheet          // 4 - Sheet style
        ]

        let mat = materials[safe: Int(material)] ?? .hudWindow

        // Choose appearance based on material
        let appearance: NSAppearance?
        switch mat {
        case .hudWindow:
            appearance = NSAppearance(named: .vibrantDark)
        case .popover, .menu, .sheet:
            appearance = NSAppearance(named: .vibrantLight)
        default:
            appearance = nil
        }

        os_log("setMaterial to=%{public}@", log: Log.glass, type: .debug, String(describing: mat))

        DispatchQueue.main.async { [weak self] in
            if let blurView = self?.blurViews[windowId]?[layerId] {
                blurView.material = mat
                blurView.appearance = appearance
            }
        }
    }

    /// Set dark mode for a window's glass effect layer.
    /// isDark: false = clear glass, true = dark/regular glass
    func setDark(windowId: String, layerId: Int, isDark: Bool) {
        lock.lock()
        let useLiquidGlass = usesLiquidGlass[windowId] ?? false
        let state = glassStates[windowId]?[layerId]
        lock.unlock()

        if useLiquidGlass {
            if #available(macOS 26.0, *) {
                if let glassState = state as? GlassPathState {
                    DispatchQueue.main.async {
                        glassState.isDark = isDark
                    }
                }
            }
        }
    }

    /// Set tint opacity for a window's glass effect.
    /// A dark tint layer is added behind the glass to reduce transparency.
    /// opacity: 0.0 = fully transparent (default), 1.0 = fully opaque black
    /// cornerRadius: Corner radius for the tint layer (default 16)
    func setTintOpacity(windowId: String, opacity: Float, cornerRadius: CGFloat = 16) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            self.lock.lock()
            let hostingView = self.hostingViews[windowId]?.values.first
            var tintLayer = self.tintLayers[windowId]
            self.lock.unlock()

            guard let hv = hostingView, let contentView = hv.superview else { return }

            if tintLayer == nil {
                // Create tint layer behind hosting view
                let layer = CALayer()
                layer.backgroundColor = NSColor.black.cgColor
                layer.frame = contentView.bounds
                layer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
                layer.cornerRadius = cornerRadius
                layer.masksToBounds = true

                // Insert at bottom of content view's layer
                contentView.wantsLayer = true
                contentView.layer?.insertSublayer(layer, at: 0)

                self.lock.lock()
                self.tintLayers[windowId] = layer
                self.lock.unlock()

                tintLayer = layer
            }

            // Update opacity and corner radius
            tintLayer?.opacity = opacity
            tintLayer?.cornerRadius = cornerRadius
        }
    }

    // MARK: - Glass View Setup

    private func setupGlassView(windowId: String, window: PaletteWindow) {
        os_log("setupGlassView windowId=%{public}@", log: Log.glass, type: .debug, windowId)

        guard let contentView = window.panel.contentView else {
            os_log("setupGlassView failed: contentView is nil", log: Log.glass, type: .error)
            return
        }

        let bounds = contentView.bounds
        os_log("setupGlassView contentView bounds=%{public}@", log: Log.glass, type: .debug, NSStringFromRect(bounds))

        lock.lock()
        let layerIds = Array((buffers[windowId] ?? [:]).keys).sorted()
        lock.unlock()
        let layers = layerIds.isEmpty ? [0] : layerIds

        // Try macOS 26+ Liquid Glass first, fall back to NSVisualEffectView
        if #available(macOS 26.0, *) {
            for layerId in layers {
                ensureLayer(windowId: windowId, layerId: layerId, contentView: contentView)
            }
        } else {
            for layerId in layers {
                ensureLayer(windowId: windowId, layerId: layerId, contentView: contentView)
            }
        }

        os_log("starting display link", log: Log.glass, type: .debug)
        startDisplayLink(windowId: windowId)
        os_log("setup complete windowId=%{public}@", log: Log.glass, type: .info, windowId)
    }

    private func ensureLayer(windowId: String, layerId: Int, contentView: NSView) {
        let bounds = contentView.bounds

        if #available(macOS 26.0, *) {
            if hostingViews[windowId]?[layerId] != nil { return }
            setupLiquidGlassLayer(windowId: windowId, layerId: layerId, contentView: contentView, bounds: bounds)
        } else {
            if blurViews[windowId]?[layerId] != nil { return }
            setupFallbackBlurLayer(windowId: windowId, layerId: layerId, contentView: contentView, bounds: bounds)
        }
    }

    private func insertLayerView(windowId: String, layerId: Int, view: NSView, in contentView: NSView) {
        let existingHosting = hostingViews[windowId] ?? [:]
        let existingBlur = blurViews[windowId] ?? [:]
        var allViews: [Int: NSView] = existingHosting
        for (key, value) in existingBlur {
            allViews[key] = value
        }

        let lowerLayerId = allViews.keys.filter { $0 < layerId }.max()
        let upperLayerId = allViews.keys.filter { $0 > layerId }.min()

        if let upperId = upperLayerId, let upperView = allViews[upperId] {
            contentView.addSubview(view, positioned: .below, relativeTo: upperView)
        } else if let lowerId = lowerLayerId, let lowerView = allViews[lowerId] {
            contentView.addSubview(view, positioned: .above, relativeTo: lowerView)
        } else {
            contentView.addSubview(view, positioned: .below, relativeTo: nil)
        }
    }

    /// Setup true Liquid Glass using SwiftUI .glassEffect() (macOS 26+) for a layer.
    @available(macOS 26.0, *)
    private func setupLiquidGlassLayer(windowId: String, layerId: Int, contentView: NSView, bounds: CGRect) {
        os_log("setupLiquidGlass windowId=%{public}@ layer=%d bounds=(%.0f, %.0f)",
               log: Log.glass, type: .debug, windowId, layerId, bounds.size.width, bounds.size.height)

        // Create observable state for path updates
        let state = GlassPathState()
        state.bounds = bounds
        // Set initial path from buffer if available, otherwise full bounds
        let initialPath: CGPath
        lock.lock()
        let ptr = buffers[windowId]?[layerId]
        lock.unlock()
        if let ptr = ptr {
            let buffer = GlassPathBufferReader(ptr)
            let cmdCount = buffer.commandCount
            let preId = buffer.frameId
            let postId = buffer.frameIdPost
            if cmdCount > 0 && preId == postId {
                initialPath = GlassPathBuilder.buildPath(from: buffer, flipY: false)
            } else {
                let rect = CGMutablePath()
                rect.addRect(bounds)
                initialPath = rect
            }
        } else {
            let rect = CGMutablePath()
            rect.addRect(bounds)
            initialPath = rect
        }
        state.path = initialPath

        // Create SwiftUI view with glass effect
        let glassView = LiquidGlassView(state: state)
        let hostingView = NSHostingView(rootView: glassView)
        hostingView.frame = bounds
        hostingView.autoresizingMask = [.width, .height]

        // Make hosting view transparent so glass effect shows through
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = .clear

        // Insert below Flutter content, in layer order
        insertLayerView(windowId: windowId, layerId: layerId, view: hostingView, in: contentView)
        os_log("Liquid Glass view added windowId=%{public}@ layer=%d", log: Log.glass, type: .info, windowId, layerId)

        lock.lock()
        var hostingMap = hostingViews[windowId] ?? [:]
        var stateMap = glassStates[windowId] ?? [:]
        hostingMap[layerId] = hostingView
        stateMap[layerId] = state
        hostingViews[windowId] = hostingMap
        glassStates[windowId] = stateMap
        isEnabled[windowId] = true
        usesLiquidGlass[windowId] = true
        lock.unlock()

        // Set up focus observers to force redraw when window gains/loses focus
        setupFocusObservers(windowId: windowId, window: contentView.window)
    }

    /// Set up observers to force glass effect redraw on focus changes.
    @available(macOS 26.0, *)
    private func setupFocusObservers(windowId: String, window: NSWindow?) {
        guard let window = window else { return }

        lock.lock()
        let alreadySetup = focusObservers[windowId] != nil
        lock.unlock()
        if alreadySetup { return }

        var observers: [NSObjectProtocol] = []

        let becameKeyObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.bumpLayerFrames(windowId: windowId)
            self?.hostingViews[windowId]?.values.forEach { $0.needsDisplay = true }
        }
        observers.append(becameKeyObserver)

        let resignedKeyObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.bumpLayerFrames(windowId: windowId)
            self?.hostingViews[windowId]?.values.forEach { $0.needsDisplay = true }
        }
        observers.append(resignedKeyObserver)

        // App-level activation observers — handle glass when entire app deactivates/reactivates
        let appResignObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.bumpLayerFrames(windowId: windowId)
            self?.hostingViews[windowId]?.values.forEach { $0.needsDisplay = true }
        }
        observers.append(appResignObserver)

        let appBecameActiveObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.bumpLayerFrames(windowId: windowId)
            self?.hostingViews[windowId]?.values.forEach { $0.needsDisplay = true }
        }
        observers.append(appBecameActiveObserver)

        let didMoveObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didMoveNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.bumpLayerFrames(windowId: windowId)
        }
        observers.append(didMoveObserver)

        lock.lock()
        focusObservers[windowId] = observers
        lock.unlock()
    }

    @available(macOS 26.0, *)
    private func bumpLayerFrames(windowId: String) {
        lock.lock()
        let states = glassStates[windowId]
        lock.unlock()

        states?.values.forEach { state in
            if let glassState = state as? GlassPathState {
                glassState.frameId &+= 1
            }
        }
    }

    /// Setup fallback blur using NSVisualEffectView (pre-macOS 26) for a layer.
    private func setupFallbackBlurLayer(windowId: String, layerId: Int, contentView: NSView, bounds: CGRect) {
        os_log("setupFallbackBlur windowId=%{public}@ layer=%d", log: Log.glass, type: .debug, windowId, layerId)

        let blurView = NSVisualEffectView(frame: bounds)
        blurView.material = .popover
        blurView.blendingMode = .behindWindow
        blurView.state = .active
        blurView.wantsLayer = true
        blurView.autoresizingMask = [.width, .height]
        blurView.appearance = NSAppearance(named: .vibrantLight)

        // Create mask layer
        let maskLayer = CAShapeLayer()
        maskLayer.fillColor = NSColor.white.cgColor
        maskLayer.frame = bounds

        // Set initial path from buffer if available, otherwise full bounds
        let initialPath: CGPath
        lock.lock()
        let ptr = buffers[windowId]?[layerId]
        lock.unlock()
        if let ptr = ptr {
            let buffer = GlassPathBufferReader(ptr)
            let cmdCount = buffer.commandCount
            let preId = buffer.frameId
            let postId = buffer.frameIdPost
            if cmdCount > 0 && preId == postId {
                initialPath = GlassPathBuilder.buildPath(from: buffer, flipY: true)
            } else {
                let rect = CGMutablePath()
                rect.addRect(bounds)
                initialPath = rect
            }
        } else {
            let rect = CGMutablePath()
            rect.addRect(bounds)
            initialPath = rect
        }
        maskLayer.path = initialPath

        blurView.layer?.mask = maskLayer
        insertLayerView(windowId: windowId, layerId: layerId, view: blurView, in: contentView)
        os_log("NSVisualEffectView fallback added layer=%d", log: Log.glass, type: .info, layerId)

        lock.lock()
        var blurMap = blurViews[windowId] ?? [:]
        var maskMap = maskLayers[windowId] ?? [:]
        blurMap[layerId] = blurView
        maskMap[layerId] = maskLayer
        blurViews[windowId] = blurMap
        maskLayers[windowId] = maskMap
        isEnabled[windowId] = true
        usesLiquidGlass[windowId] = false
        lock.unlock()
    }

    private func teardownGlassView(windowId: String) {
        lock.lock()
        let useLiquidGlass = usesLiquidGlass[windowId] ?? false
        let blurViewMap = blurViews.removeValue(forKey: windowId)
        let hostingViewMap = hostingViews.removeValue(forKey: windowId)
        let observers = focusObservers.removeValue(forKey: windowId)
        let tintLayer = tintLayers.removeValue(forKey: windowId)
        maskLayers.removeValue(forKey: windowId)
        glassStates.removeValue(forKey: windowId)
        lastFrameIds.removeValue(forKey: windowId)
        usesLiquidGlass.removeValue(forKey: windowId)
        lock.unlock()

        // Remove focus observers
        if let obs = observers {
            for observer in obs {
                NotificationCenter.default.removeObserver(observer)
            }
        }

        // Remove tint layer
        tintLayer?.removeFromSuperlayer()

        if useLiquidGlass {
            hostingViewMap?.values.forEach { $0.removeFromSuperview() }
        } else {
            blurViewMap?.values.forEach { $0.removeFromSuperview() }
        }
    }

    // MARK: - Display Link

    // Store contexts to prevent memory leaks
    private var displayLinkContexts: [String: Unmanaged<NSString>] = [:]

    private func startDisplayLink(windowId: String) {
        lock.lock()
        defer { lock.unlock() }

        guard displayLinks[windowId] == nil else { return }

        var displayLink: CVDisplayLink?
        CVDisplayLinkCreateWithActiveCGDisplays(&displayLink)

        guard let link = displayLink else {
            os_log("failed to create CVDisplayLink windowId=%{public}@", log: Log.glass, type: .error, windowId)
            return
        }

        // Store windowId in context for callback - retain for lifetime of display link
        let unmanagedContext = Unmanaged.passRetained(windowId as NSString)
        displayLinkContexts[windowId] = unmanagedContext
        let context = unmanagedContext.toOpaque()

        CVDisplayLinkSetOutputCallback(link, { (_, _, _, _, _, context) -> CVReturn in
            guard let ctx = context else { return kCVReturnError }
            let windowId = Unmanaged<NSString>.fromOpaque(ctx).takeUnretainedValue() as String
            GlassMaskService.shared.onDisplayRefresh(windowId: windowId)
            return kCVReturnSuccess
        }, context)

        CVDisplayLinkStart(link)
        displayLinks[windowId] = link
    }

    private func stopDisplayLink(windowId: String) {
        lock.lock()
        defer { lock.unlock() }

        if let link = displayLinks.removeValue(forKey: windowId) {
            CVDisplayLinkStop(link)
        }

        // Release the retained context string
        if let context = displayLinkContexts.removeValue(forKey: windowId) {
            context.release()
        }
    }

    // MARK: - Display Refresh Callback

    private func onDisplayRefresh(windowId: String) {
        lock.lock()
        guard isEnabled[windowId] == true else {
            lock.unlock()
            return
        }
        let layerBuffers = buffers[windowId] ?? [:]
        let useLiquidGlass = usesLiquidGlass[windowId] ?? false
        let lastIds = lastFrameIds[windowId] ?? [:]
        let states = glassStates[windowId]
        let maskLayerMap = maskLayers[windowId]
        let hostingViewMap = hostingViews[windowId]
        lock.unlock()

        // Collect all layer IDs (from both path buffers and animation buffers)
        let allLayerIds = Set(layerBuffers.keys)

        // Check animation driver for each layer
        for layerId in allLayerIds {
            // PRIORITY 1: Check native animation driver
            if let animated = GlassAnimationDriver.shared.readAnimatedBounds(windowId: windowId, layerId: layerId) {
                // Build RRect path from interpolated bounds
                let path = GlassPathBuilder.buildRRectPath(bounds: animated.bounds, cornerRadius: animated.cornerRadius)

                DispatchQueue.main.async {
                    if useLiquidGlass {
                        if #available(macOS 26.0, *) {
                            if let glassState = states?[layerId] as? GlassPathState {
                                glassState.path = path

                                if let hv = hostingViewMap?[layerId], let contentView = hv.superview {
                                    let contentBounds = contentView.bounds
                                    hv.frame = contentBounds
                                    glassState.bounds = contentBounds
                                } else {
                                    glassState.bounds = animated.bounds
                                }
                                glassState.frameId &+= 1
                            }
                        }
                    } else {
                        maskLayerMap?[layerId]?.path = path
                    }
                }
                continue  // Skip path buffer for this layer
            }

            // PRIORITY 2: Fall back to path buffer (arbitrary shapes)
            guard let ptr = layerBuffers[layerId] else { continue }

            let buffer = GlassPathBufferReader(ptr)
            let preId = buffer.frameId
            let lastId = lastIds[layerId] ?? 0

            // Skip if no change
            guard preId != lastId else { continue }

            // Check for torn write
            let postId = buffer.frameIdPost
            guard preId == postId else { continue }

            lock.lock()
            var windowLastIds = lastFrameIds[windowId] ?? [:]
            windowLastIds[layerId] = preId
            lastFrameIds[windowId] = windowLastIds
            lock.unlock()

            DispatchQueue.main.async {
                let mainBuffer = GlassPathBufferReader(ptr)

                if useLiquidGlass {
                    let path = GlassPathBuilder.buildPath(from: mainBuffer, flipY: false)

                    if #available(macOS 26.0, *) {
                        if let glassState = states?[layerId] as? GlassPathState {
                            glassState.path = path

                            if let hv = hostingViewMap?[layerId], let contentView = hv.superview {
                                let contentBounds = contentView.bounds
                                hv.frame = contentBounds
                                glassState.bounds = contentBounds
                            } else {
                                let pathBounds = path.boundingBox
                                glassState.bounds = CGRect(
                                    x: 0,
                                    y: 0,
                                    width: pathBounds.maxX,
                                    height: pathBounds.maxY
                                )
                            }
                            glassState.frameId = preId
                        }
                    }
                } else {
                    let path = GlassPathBuilder.buildPath(from: mainBuffer, flipY: true)
                    maskLayerMap?[layerId]?.path = path
                }
            }
        }

        // For Liquid Glass, always bump frameId AND copy the path so the glass effect
        // re-samples the background at display refresh rate.
        // Copying the path creates a new CGPath reference each frame, which forces
        // SwiftUI to rebuild .glassEffect() (matching animated shapes behavior).
        // Without the copy, static paths (same pointer) let glass "warm up" into frosted state.
        if useLiquidGlass {
            DispatchQueue.main.async {
                if #available(macOS 26.0, *) {
                    states?.values.forEach { state in
                        if let glassState = state as? GlassPathState {
                            glassState.path = glassState.path?.copy()
                            glassState.frameId &+= 1
                        }
                    }
                }
            }
        }
    }

    // MARK: - Cleanup

    /// Clean up all resources for a window (called when window is destroyed).
    func cleanup(windowId: String) {
        disable(windowId: windowId)
        destroyAllBuffers(windowId: windowId)
    }

    /// Destroy all shared path buffers for a window.
    func destroyAllBuffers(windowId: String) {
        lock.lock()
        let layerIds = Array((buffers[windowId] ?? [:]).keys)
        lock.unlock()

        for layerId in layerIds {
            destroyBuffer(windowId: windowId, layerId: layerId)
        }
    }
}

// MARK: - Array Safe Subscript

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
