import AppKit

let root = URL(fileURLWithPath: CommandLine.arguments[1])
let output = root.appendingPathComponent("Resources/Assets.xcassets/AppIcon.appiconset")
var entries: [[String: String]] = []
func render(_ dimension: Int, _ filename: String, mac: Bool) throws {
  let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: dimension, pixelsHigh: dimension, bitsPerSample: 8,
    samplesPerPixel: mac ? 4 : 3, hasAlpha: mac, isPlanar: false, colorSpaceName: .deviceRGB,
    bytesPerRow: 0, bitsPerPixel: 0)!
  NSGraphicsContext.saveGraphicsState()
  NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
  let transform = NSAffineTransform()
  transform.scale(by: CGFloat(dimension) / 1024)
  transform.concat()
  NSColor(calibratedRed: 0.18, green: 0.2, blue: 0.24, alpha: 1).setFill()
  (mac
    ? NSBezierPath(
      roundedRect: NSRect(x: 40, y: 40, width: 944, height: 944), xRadius: 200, yRadius: 200)
    : NSBezierPath(rect: NSRect(x: 0, y: 0, width: 1024, height: 1024))).fill()
  let top = NSBezierPath()
  top.move(to: NSPoint(x: 512, y: 790)); top.line(to: NSPoint(x: 800, y: 630))
  top.line(to: NSPoint(x: 512, y: 465)); top.line(to: NSPoint(x: 224, y: 630)); top.close()
  NSColor(calibratedRed: 0.91, green: 0.78, blue: 0.54, alpha: 1).setFill(); top.fill()
  let left = NSBezierPath()
  left.move(to: NSPoint(x: 224, y: 595)); left.line(to: NSPoint(x: 493, y: 441))
  left.line(to: NSPoint(x: 493, y: 180)); left.line(to: NSPoint(x: 224, y: 335)); left.close()
  NSColor(calibratedRed: 0.43, green: 0.66, blue: 0.67, alpha: 1).setFill(); left.fill()
  let right = NSBezierPath()
  right.move(to: NSPoint(x: 531, y: 441)); right.line(to: NSPoint(x: 800, y: 595))
  right.line(to: NSPoint(x: 800, y: 335)); right.line(to: NSPoint(x: 531, y: 180)); right.close()
  NSColor(calibratedRed: 0.28, green: 0.49, blue: 0.51, alpha: 1).setFill(); right.fill()
  NSGraphicsContext.restoreGraphicsState()
  try bitmap.representation(using: .png, properties: [:])!.write(
    to: output.appendingPathComponent(filename))
}
for size in [16, 32, 128, 256, 512] {
  for scale in [1, 2] {
    let name = "icon-\(size)-\(scale).png"
    try render(size * scale, name, mac: true)
    entries.append([
      "idiom": "mac", "size": "\(size)x\(size)", "scale": "\(scale)x", "filename": name,
    ])
  }
}
try JSONSerialization.data(
  withJSONObject: ["images": entries, "info": ["version": 1, "author": "xcode"]],
  options: [.prettyPrinted, .sortedKeys]
).write(to: output.appendingPathComponent("Contents.json"))
