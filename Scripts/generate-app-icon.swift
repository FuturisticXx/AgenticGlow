#!/usr/bin/env xcrun swift

import AppKit

let canvasSize: CGFloat = 1024
let tileRect = CGRect(x: 32, y: 32, width: 960, height: 960)
let tileRadius: CGFloat = 218
let ringRect = CGRect(x: 289, y: 289, width: 446, height: 446)
let ringWidth: CGFloat = 58
let signalRect = CGRect(x: 334, y: 479, width: 356, height: 66)

let tileTop = NSColor(srgbRed: 0.075, green: 0.110, blue: 0.145, alpha: 1)
let tileBottom = NSColor(srgbRed: 0.035, green: 0.055, blue: 0.080, alpha: 1)
let workingBlue = NSColor(srgbRed: 0.416, green: 0.663, blue: 0.984, alpha: 1)
let attentionAmber = NSColor(srgbRed: 0.957, green: 0.710, blue: 0.271, alpha: 1)
let completedGreen = NSColor(srgbRed: 0.400, green: 0.788, blue: 0.478, alpha: 1)

guard CommandLine.arguments.count == 2 else {
    fputs("Usage: generate-app-icon.swift <output-path>\n", stderr)
    exit(64)
}

guard let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: Int(canvasSize),
    pixelsHigh: Int(canvasSize),
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
), let graphics = NSGraphicsContext(bitmapImageRep: bitmap) else {
    fatalError("Unable to create icon canvas")
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = graphics
graphics.imageInterpolation = .high
graphics.shouldAntialias = true

NSColor.clear.setFill()
NSRect(x: 0, y: 0, width: canvasSize, height: canvasSize).fill()

let tile = NSBezierPath(roundedRect: tileRect, xRadius: tileRadius, yRadius: tileRadius)
tile.addClip()
NSGradient(starting: tileTop, ending: tileBottom)?.draw(in: tile, angle: -90)

let insetBorder = NSBezierPath(
    roundedRect: tileRect.insetBy(dx: 4, dy: 4),
    xRadius: tileRadius - 4,
    yRadius: tileRadius - 4
)
insetBorder.lineWidth = 5
NSColor(srgbRed: 0.30, green: 0.37, blue: 0.45, alpha: 0.48).setStroke()
insetBorder.stroke()

func drawRingGlow(
    color: NSColor,
    offset: CGSize,
    startAngle: CGFloat,
    endAngle: CGFloat
) {
    let context = graphics.cgContext
    context.saveGState()
    context.setLineWidth(ringWidth)
    context.setLineCap(.round)
    context.setStrokeColor(color.withAlphaComponent(0.20).cgColor)
    context.setShadow(offset: offset, blur: 54, color: color.withAlphaComponent(0.98).cgColor)
    for _ in 0..<3 {
        context.addArc(
            center: CGPoint(x: ringRect.midX, y: ringRect.midY),
            radius: ringRect.width / 2,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: false
        )
        context.strokePath()
    }
    context.restoreGState()
}

drawRingGlow(
    color: workingBlue,
    offset: CGSize(width: -22, height: 26),
    startAngle: 65 * .pi / 180,
    endAngle: 205 * .pi / 180
)
drawRingGlow(
    color: attentionAmber,
    offset: CGSize(width: 26, height: 18),
    startAngle: -25 * .pi / 180,
    endAngle: 105 * .pi / 180
)
drawRingGlow(
    color: completedGreen,
    offset: CGSize(width: -12, height: -28),
    startAngle: 175 * .pi / 180,
    endAngle: 330 * .pi / 180
)

let ring = NSBezierPath(ovalIn: ringRect)
ring.lineWidth = ringWidth
workingBlue.setStroke()
ring.stroke()

NSGraphicsContext.saveGraphicsState()
let signal = NSBezierPath(
    roundedRect: signalRect,
    xRadius: signalRect.height / 2,
    yRadius: signalRect.height / 2
)
signal.addClip()

workingBlue.setFill()
signalRect.fill()

let amber = NSBezierPath()
amber.move(to: CGPoint(x: 476, y: signalRect.minY))
amber.line(to: CGPoint(x: 552, y: signalRect.minY))
amber.line(to: CGPoint(x: 580, y: signalRect.maxY))
amber.line(to: CGPoint(x: 500, y: signalRect.maxY))
amber.close()
attentionAmber.setFill()
amber.fill()

let green = NSBezierPath()
green.move(to: CGPoint(x: 552, y: signalRect.minY))
green.line(to: CGPoint(x: signalRect.maxX, y: signalRect.minY))
green.line(to: CGPoint(x: signalRect.maxX, y: signalRect.maxY))
green.line(to: CGPoint(x: 580, y: signalRect.maxY))
green.close()
completedGreen.setFill()
green.fill()
NSGraphicsContext.restoreGraphicsState()

NSGraphicsContext.restoreGraphicsState()

guard let png = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("Unable to encode icon PNG")
}

try png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]), options: .atomic)
