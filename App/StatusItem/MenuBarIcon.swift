import AppKit

enum Brand {
    /// Brand accent red #E5352B.
    static let accent = NSColor(srgbRed: 0xE5 / 255, green: 0x35 / 255, blue: 0x2B / 255, alpha: 1)
}

@MainActor
enum MenuBarIcon {
    /// Renewal ring with arrow head and an accent centre dot; 18×18 pt, drawn non-template in the label colour.
    static func image() -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: true) { @Sendable _ in
            NSColor.labelColor.setStroke()
            let ring = NSBezierPath()
            ring.lineWidth = 2
            ring.lineCapStyle = .round
            ring.lineJoinStyle = .round
            // SVG arc "M15 9a6 6 0 1 1-2.2-4.65", sampled clockwise on screen.
            let end = atan2(4.65 - 9, 12.8 - 9) + 2 * Double.pi
            var t = 0.0
            ring.move(to: NSPoint(x: 15, y: 9))
            while t < end {
                t = min(t + 0.05, end)
                ring.line(to: NSPoint(x: 9 + 6 * cos(t), y: 9 + 6 * sin(t)))
            }
            ring.stroke()

            let arrow = NSBezierPath()
            arrow.lineWidth = 2
            arrow.lineCapStyle = .round
            arrow.lineJoinStyle = .round
            arrow.move(to: NSPoint(x: 13.6, y: 1.9))
            arrow.line(to: NSPoint(x: 13.6, y: 5.1))
            arrow.line(to: NSPoint(x: 10.4, y: 5.1))
            arrow.stroke()

            Brand.accent.setFill()
            NSBezierPath(ovalIn: NSRect(x: 6.4, y: 6.4, width: 5.2, height: 5.2)).fill()
            return true
        }
        image.isTemplate = false
        return image
    }
}
