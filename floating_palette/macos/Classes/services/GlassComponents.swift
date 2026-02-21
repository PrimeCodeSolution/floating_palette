import Cocoa
import SwiftUI

// MARK: - SwiftUI Liquid Glass Components

/// Observable object that holds the current glass path for SwiftUI updates.
/// Using ObservableObject + @Published for reliable NSHostingView integration.
@available(macOS 26.0, *)
final class GlassPathState: ObservableObject {
    @Published var path: CGPath?
    @Published var bounds: CGRect = .zero
    @Published var isDark: Bool = false  // false = clear glass, true = dark glass
    @Published var frameId: UInt64 = 0  // Incremented on each update to force SwiftUI re-render
}

/// Custom SwiftUI Shape that renders a CGPath.
/// Used to apply .glassEffect() to arbitrary shapes from Flutter.
/// CGPath is immutable and safe to use across threads.
@available(macOS 26.0, *)
struct GlassShape: Shape, @unchecked Sendable {
    let cgPath: CGPath?
    let bounds: CGRect
    let frameId: UInt64  // Forces SwiftUI to re-apply .glassEffect() each frame

    func path(in rect: CGRect) -> Path {
        guard let cgPath = cgPath else {
            return Path(rect)
        }
        return Path(cgPath)
    }
}

/// SwiftUI view that renders Liquid Glass effect with dynamic path updates.
/// Uses `.glassEffect(..., in: Shape)` pattern for dynamic mask updates.
@available(macOS 26.0, *)
struct LiquidGlassView: View {
    @ObservedObject var state: GlassPathState
    @Namespace private var glassNamespace

    var body: some View {
        let glass: Glass = state.isDark ? .regular : .clear

        // Fill the entire container - the path shape handles masking
        // .id(state.frameId) forces SwiftUI to tear down and recreate the view each frame,
        // preventing the glass effect from "warming up" into its frosted state.
        // This matches animated shapes behavior where a new CGPath each frame keeps glass transparent.
        Color.clear
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .glassEffect(glass, in: GlassShape(cgPath: state.path, bounds: state.bounds, frameId: state.frameId))
            .glassEffectID(state.frameId, in: glassNamespace)
            .allowsHitTesting(false)  // Don't intercept mouse events (allow resize at edges)
            // Palettes are floating panels — always render glass as "active"
            // regardless of window key status (prevents glass from deactivating on focus loss)
            .environment(\.controlActiveState, .key)
            .id(state.frameId)
    }
}

/// Fallback view for older macOS versions (uses NSVisualEffectView via representable)
struct FallbackBlurView: NSViewRepresentable {
    let material: NSVisualEffectView.Material

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
    }
}
