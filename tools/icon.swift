import AppKit
let size = 1024
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8, samplesPerPixel: 3, hasAlpha: false, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let rect = NSRect(x: 0, y: 0, width: size, height: size)
NSGradient(colors: [NSColor(red: 0.10, green: 0.09, blue: 0.12, alpha: 1), NSColor(red: 0.02, green: 0.02, blue: 0.03, alpha: 1)])!.draw(in: rect, angle: -90)
NSGradient(colors: [NSColor(red: 0.93, green: 0.77, blue: 0.42, alpha: 0.18), .clear])!.draw(in: NSBezierPath(ovalIn: rect.insetBy(dx: 120, dy: 120)), relativeCenterPosition: .zero)
let config = NSImage.SymbolConfiguration(pointSize: 520, weight: .semibold)
let sym = NSImage(systemSymbolName: "crown.fill", accessibilityDescription: nil)!.withSymbolConfiguration(config)!
let s = sym.size
let target = NSRect(x: (CGFloat(size) - s.width) / 2, y: (CGFloat(size) - s.height) / 2 + 20, width: s.width, height: s.height)
let mask = NSImage(size: s, flipped: false) { r in
    sym.draw(in: r)
    NSGradient(colors: [NSColor(red: 0.98, green: 0.86, blue: 0.55, alpha: 1), NSColor(red: 0.76, green: 0.53, blue: 0.22, alpha: 1)])!.draw(in: r, angle: -90)
    return true
}
_ = mask
// Draw symbol as gold via sourceAtop compositing
let tinted = NSImage(size: s)
tinted.lockFocus()
sym.draw(in: NSRect(origin: .zero, size: s))
NSGraphicsContext.current?.compositingOperation = .sourceAtop
NSGradient(colors: [NSColor(red: 0.98, green: 0.86, blue: 0.55, alpha: 1), NSColor(red: 0.76, green: 0.53, blue: 0.22, alpha: 1)])!.draw(in: NSRect(origin: .zero, size: s), angle: -90)
tinted.unlockFocus()
tinted.draw(in: target)
NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
