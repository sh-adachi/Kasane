import AppKit
let size = 1024
let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8, samplesPerPixel: 3, hasAlpha: false, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
NSColor(red: 0.09, green: 0.25, blue: 0.21, alpha: 1).setFill()
NSBezierPath(rect: NSRect(x: 0, y: 0, width: size, height: size)).fill()
let layers: [(CGFloat, CGFloat, CGFloat, NSColor)] = [
 (218, 248, 590, NSColor(red: 0.48, green: 0.65, blue: 0.54, alpha: 1)),
 (185, 417, 570, NSColor(red: 0.70, green: 0.82, blue: 0.68, alpha: 1)),
 (275, 586, 474, NSColor(red: 0.91, green: 0.94, blue: 0.80, alpha: 1))
]
for (x, y, width, color) in layers {
 color.setFill()
 NSBezierPath(roundedRect: NSRect(x: x, y: y, width: width, height: 125), xRadius: 62.5, yRadius: 62.5).fill()
}
NSGraphicsContext.restoreGraphicsState()
try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
