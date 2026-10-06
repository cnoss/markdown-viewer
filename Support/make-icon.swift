// Zeichnet das App-Icon: swift Support/make-icon.swift <ausgabe.iconset>
import AppKit

let out = URL(fileURLWithPath: CommandLine.arguments[1])
try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

func draw(size: CGFloat) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let s = size / 1024

    // Grundform im macOS-Raster (824 px Kachel auf 1024 px Fläche)
    let tile = NSRect(x: 100 * s, y: 100 * s, width: 824 * s, height: 824 * s)
    let path = NSBezierPath(roundedRect: tile, xRadius: 185 * s, yRadius: 185 * s)
    NSShadow().apply { $0.shadowBlurRadius = 24 * s; $0.shadowOffset = NSSize(width: 0, height: -10 * s)
        $0.shadowColor = NSColor.black.withAlphaComponent(0.28) }
    NSGradient(starting: NSColor(calibratedRed: 0.17, green: 0.17, blue: 0.19, alpha: 1),
               ending: NSColor(calibratedRed: 0.08, green: 0.08, blue: 0.09, alpha: 1))!
        .draw(in: path, angle: -90)
    NSShadow().set()

    // Papierblatt
    let paper = NSRect(x: 262 * s, y: 190 * s, width: 500 * s, height: 640 * s)
    NSColor(calibratedRed: 0.98, green: 0.975, blue: 0.96, alpha: 1).setFill()
    NSBezierPath(roundedRect: paper, xRadius: 34 * s, yRadius: 34 * s).fill()

    // Überschrift + Textzeilen
    let ink = NSColor(calibratedRed: 0.12, green: 0.12, blue: 0.14, alpha: 1)
    ink.setFill()
    NSBezierPath(roundedRect: NSRect(x: 322 * s, y: 690 * s, width: 250 * s, height: 46 * s),
                 xRadius: 12 * s, yRadius: 12 * s).fill()
    ink.withAlphaComponent(0.22).setFill()
    for (i, w) in [380.0, 340, 365, 220].enumerated() {
        NSBezierPath(roundedRect: NSRect(x: 322 * s, y: (610 - CGFloat(i) * 62) * s, width: w * s, height: 22 * s),
                     xRadius: 11 * s, yRadius: 11 * s).fill()
    }

    // Prompt-Zeichen als Akzent
    let accent = NSColor(calibratedRed: 0.22, green: 0.55, blue: 1.0, alpha: 1)
    let attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.monospacedSystemFont(ofSize: 150 * s, weight: .bold),
        .foregroundColor: accent,
    ]
    NSAttributedString(string: "›_", attributes: attrs).draw(at: NSPoint(x: 316 * s, y: 196 * s))

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

extension NSShadow {
    func apply(_ configure: (NSShadow) -> Void) { configure(self); set() }
}

for base in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let px = CGFloat(base * scale)
        let name = scale == 1 ? "icon_\(base)x\(base).png" : "icon_\(base)x\(base)@2x.png"
        try! draw(size: px).representation(using: .png, properties: [:])!.write(to: out.appending(path: name))
    }
}
