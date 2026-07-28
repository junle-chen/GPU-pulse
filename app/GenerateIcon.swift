import AppKit

let size = NSSize(width: 1024, height: 1024)
let image = NSImage(size: size)
image.lockFocus()
guard let context = NSGraphicsContext.current else { fatalError("No graphics context") }
context.imageInterpolation = .high

let bounds = NSRect(origin: .zero, size: size)
NSColor.clear.setFill()
bounds.fill()

let tile = NSBezierPath(roundedRect: NSRect(x: 62, y: 62, width: 900, height: 900), xRadius: 216, yRadius: 216)
NSGradient(colors: [
    NSColor(red: 0.035, green: 0.055, blue: 0.15, alpha: 1),
    NSColor(red: 0.095, green: 0.055, blue: 0.19, alpha: 1),
    NSColor(red: 0.018, green: 0.026, blue: 0.065, alpha: 1)
])!.draw(in: tile, angle: -55)

NSColor(calibratedWhite: 1, alpha: 0.085).setStroke()
let rim = NSBezierPath(roundedRect: NSRect(x: 102, y: 102, width: 820, height: 820), xRadius: 178, yRadius: 178)
rim.lineWidth = 3
rim.stroke()

let points: [NSPoint] = [
    .init(x: 210, y: 494), .init(x: 322, y: 494), .init(x: 381, y: 632),
    .init(x: 464, y: 359), .init(x: 544, y: 550), .init(x: 607, y: 459),
    .init(x: 672, y: 669), .init(x: 730, y: 494), .init(x: 814, y: 494)
]
let pulse = NSBezierPath()
pulse.move(to: points[0])
for point in points.dropFirst() { pulse.line(to: point) }
pulse.lineJoinStyle = .round
pulse.lineCapStyle = .round

NSColor(red: 0.25, green: 0.85, blue: 1, alpha: 0.20).setStroke()
pulse.lineWidth = 52
pulse.stroke()

NSColor(red: 0.24, green: 0.91, blue: 1, alpha: 1).setStroke()
pulse.lineWidth = 28
pulse.stroke()

let accent = NSBezierPath()
accent.move(to: points[4])
for point in points.dropFirst(5) { accent.line(to: point) }
accent.lineJoinStyle = .round
accent.lineCapStyle = .round
NSColor(red: 1, green: 0.30, blue: 0.66, alpha: 0.9).setStroke()
accent.lineWidth = 12
accent.stroke()

for (point, color) in [(points.first!, NSColor.cyan), (points.last!, NSColor.systemPink)] {
    color.setFill()
    NSBezierPath(ovalIn: NSRect(x: point.x - 15, y: point.y - 15, width: 30, height: 30)).fill()
}

let paragraph = NSMutableParagraphStyle()
paragraph.alignment = .center
let attributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 80, weight: .bold),
    .foregroundColor: NSColor(calibratedWhite: 1, alpha: 0.86),
    .paragraphStyle: paragraph,
    .kern: 16
]
("ZX" as NSString).draw(in: NSRect(x: 0, y: 194, width: 1024, height: 100), withAttributes: attributes)

image.unlockFocus()
guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("Could not encode icon")
}
try png.write(to: URL(fileURLWithPath: ".icon-work/AppIcon-1024.png"))
