import AppKit

@MainActor
enum MenuBarIcon {
    static func image(accent: Bool) -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { @Sendable _ in
            NSColor.black.setFill()
            NSColor.black.setStroke()
            NSBezierPath(rect: NSRect(x: 2, y: 8, width: 14, height: 2)).fill()

            let ring = NSRect(x: 2, y: 6, width: 6, height: 6)
            NSGraphicsContext.current?.saveGraphicsState()
            NSGraphicsContext.current?.compositingOperation = .clear
            NSBezierPath(ovalIn: ring).fill()
            NSGraphicsContext.current?.restoreGraphicsState()
            let stroke = NSBezierPath(ovalIn: ring.insetBy(dx: 0.75, dy: 0.75))
            stroke.lineWidth = 1.5
            stroke.stroke()

            NSBezierPath(ovalIn: NSRect(x: 10.5, y: 6.5, width: 5, height: 5)).fill()
            if accent {
                NSBezierPath(ovalIn: NSRect(x: 14, y: 14, width: 4, height: 4)).fill()
            }
            return true
        }
        image.isTemplate = true
        return image
    }
}
