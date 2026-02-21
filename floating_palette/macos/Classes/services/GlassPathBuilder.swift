import CoreGraphics

// MARK: - Path Building

/// Builds CGPath objects from path commands and RRect specs.
enum GlassPathBuilder {

    /// Builds a CGPath for a rounded rectangle.
    /// Used by animation driver for native-interpolated RRect bounds.
    static func buildRRectPath(bounds: CGRect, cornerRadius: CGFloat) -> CGPath {
        let path = CGMutablePath()
        path.addRoundedRect(in: bounds, cornerWidth: cornerRadius, cornerHeight: cornerRadius)
        return path
    }

    /// Builds CGPath from raw commands and points in a buffer.
    /// No shape semantics whatsoever - just reads commands and applies them.
    ///
    /// - Parameter flipY: If true, flips Y coordinates (for Core Graphics/CALayer).
    ///                    If false, uses coordinates as-is (for SwiftUI which has Y=0 at top like Flutter).
    static func buildPath(from buffer: GlassPathBufferReader, flipY: Bool) -> CGPath {
        let path = CGMutablePath()
        let windowHeight = CGFloat(buffer.windowHeight)
        var pointIndex = 0

        for cmdIndex in 0..<Int(buffer.commandCount) {
            let cmd = buffer.getCommand(at: cmdIndex)

            switch cmd {
            case 0: // moveTo - 1 point
                let x = CGFloat(buffer.getPoint(at: pointIndex))
                let rawY = CGFloat(buffer.getPoint(at: pointIndex + 1))
                let y = flipY ? (windowHeight - rawY) : rawY
                path.move(to: CGPoint(x: x, y: y))
                pointIndex += 2

            case 1: // lineTo - 1 point
                let x = CGFloat(buffer.getPoint(at: pointIndex))
                let rawY = CGFloat(buffer.getPoint(at: pointIndex + 1))
                let y = flipY ? (windowHeight - rawY) : rawY
                path.addLine(to: CGPoint(x: x, y: y))
                pointIndex += 2

            case 2: // quadTo - 2 points
                let cx = CGFloat(buffer.getPoint(at: pointIndex))
                let rawCY = CGFloat(buffer.getPoint(at: pointIndex + 1))
                let cy = flipY ? (windowHeight - rawCY) : rawCY
                let x = CGFloat(buffer.getPoint(at: pointIndex + 2))
                let rawY = CGFloat(buffer.getPoint(at: pointIndex + 3))
                let y = flipY ? (windowHeight - rawY) : rawY
                path.addQuadCurve(to: CGPoint(x: x, y: y), control: CGPoint(x: cx, y: cy))
                pointIndex += 4

            case 3: // cubicTo - 3 points
                let c1x = CGFloat(buffer.getPoint(at: pointIndex))
                let rawC1Y = CGFloat(buffer.getPoint(at: pointIndex + 1))
                let c1y = flipY ? (windowHeight - rawC1Y) : rawC1Y
                let c2x = CGFloat(buffer.getPoint(at: pointIndex + 2))
                let rawC2Y = CGFloat(buffer.getPoint(at: pointIndex + 3))
                let c2y = flipY ? (windowHeight - rawC2Y) : rawC2Y
                let x = CGFloat(buffer.getPoint(at: pointIndex + 4))
                let rawY = CGFloat(buffer.getPoint(at: pointIndex + 5))
                let y = flipY ? (windowHeight - rawY) : rawY
                path.addCurve(to: CGPoint(x: x, y: y),
                             control1: CGPoint(x: c1x, y: c1y),
                             control2: CGPoint(x: c2x, y: c2y))
                pointIndex += 6

            case 4: // close - 0 points
                path.closeSubpath()

            default:
                break
            }
        }

        return path
    }
}
