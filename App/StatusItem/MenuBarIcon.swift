import AppKit

enum Brand {
    /// Brand accent orange #E8590C: 3.3:1 on #F6F6F3, 4.8:1 on #1C1C1E.
    static let accent = NSColor(srgbRed: 0xE8 / 255, green: 0x59 / 255, blue: 0x0C / 255, alpha: 1)

    /// The accent for text: #E8590C reaches only 3.3:1 in light, so text takes #A84300 in light (5.6:1 on #F6F6F3)
    /// and #FF8A3D in dark (7.3:1 on #1C1C1E). Graphics keep `accent`.
    static let accentText = NSColor(name: "Brand.accentText") { appearance in
        appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            ? NSColor(srgbRed: 0xFF / 255, green: 0x8A / 255, blue: 0x3D / 255, alpha: 1)
            : NSColor(srgbRed: 0xA8 / 255, green: 0x43 / 255, blue: 0x00 / 255, alpha: 1)
    }
}

@MainActor
enum MenuBarIcon {
    /// Renewal ring with arrow head and an accent centre dot; 18×18 pt, drawn non-template in the label colour.
    /// `badge` adds the update badge: a 5 pt dot in the system accent at the bottom right, in a gap cut out of the ring.
    static func image(badge: Bool = false) -> NSImage {
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

            if badge {
                // A 1 pt gap cut out of the ring keeps the dot apart from the ring's line.
                NSGraphicsContext.current?.compositingOperation = .clear
                NSBezierPath(ovalIn: NSRect(x: 12, y: 12, width: 7, height: 7)).fill()
                NSGraphicsContext.current?.compositingOperation = .sourceOver
                NSColor.controlAccentColor.setFill()
                NSBezierPath(ovalIn: NSRect(x: 13, y: 13, width: 5, height: 5)).fill()
            }
            return true
        }
        image.isTemplate = false
        return image
    }
}
