import AppKit
import CoreGraphics
import Foundation

struct RGB {
    let r: CGFloat
    let g: CGFloat
    let b: CGFloat
    let a: CGFloat

    init(_ hex: UInt32, alpha: CGFloat = 1) {
        r = CGFloat((hex >> 16) & 0xff) / 255
        g = CGFloat((hex >> 8) & 0xff) / 255
        b = CGFloat(hex & 0xff) / 255
        a = alpha
    }

    var cg: CGColor {
        CGColor(red: r, green: g, blue: b, alpha: a)
    }
}

let workspace = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let assets = workspace.appendingPathComponent("VisaPhotoMaker/Resources/Assets.xcassets")
let appIconSet = assets.appendingPathComponent("AppIcon.appiconset")
let appStorePackage = workspace.appendingPathComponent("AppStorePackage")

let officialBlue = RGB(0x0047AB)
let deepBlue = RGB(0x002B66)
let ink = RGB(0x1A1F29)
let secondaryInk = RGB(0x5B6470)
let paper = RGB(0xFFFFFF)
let grouped = RGB(0xF6F8FB)
let border = RGB(0xD8DEE8)
let softBlue = RGB(0xEAF2FF)
let paleBlue = RGB(0xF3F7FE)
let success = RGB(0x147A45)
let warning = RGB(0xB86A07)

func ensureDirectory(_ url: URL) throws {
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
}

func savePNG(width: Int, height: Int, url: URL, opaque: Bool = false, draw: (CGContext, CGSize) -> Void) throws {
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    let alphaInfo: CGImageAlphaInfo = opaque ? .noneSkipLast : .premultipliedLast
    guard let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: alphaInfo.rawValue
    ) else {
        fatalError("Cannot create bitmap context")
    }

    context.interpolationQuality = .high
    context.setShouldAntialias(true)
    context.translateBy(x: 0, y: CGFloat(height))
    context.scaleBy(x: CGFloat(width) / 1024, y: -CGFloat(height) / 1024)
    draw(context, CGSize(width: 1024, height: 1024))

    guard let image = context.makeImage() else {
        fatalError("Cannot make CGImage")
    }
    let rep = NSBitmapImageRep(cgImage: image)
    guard let data = rep.representation(using: .png, properties: [:]) else {
        fatalError("Cannot encode PNG")
    }
    try data.write(to: url)
}

func fill(_ context: CGContext, _ rect: CGRect, _ color: RGB, radius: CGFloat = 0) {
    context.setFillColor(color.cg)
    if radius > 0 {
        context.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil))
        context.fillPath()
    } else {
        context.fill(rect)
    }
}

func stroke(_ context: CGContext, _ rect: CGRect, _ color: RGB, width: CGFloat, radius: CGFloat = 0) {
    context.setStrokeColor(color.cg)
    context.setLineWidth(width)
    context.setLineCap(.round)
    context.setLineJoin(.round)
    if radius > 0 {
        context.addPath(CGPath(roundedRect: rect.insetBy(dx: width / 2, dy: width / 2), cornerWidth: radius, cornerHeight: radius, transform: nil))
        context.strokePath()
    } else {
        context.stroke(rect.insetBy(dx: width / 2, dy: width / 2))
    }
}

func line(_ context: CGContext, _ points: [CGPoint], _ color: RGB, width: CGFloat) {
    guard let first = points.first else { return }
    context.setStrokeColor(color.cg)
    context.setLineWidth(width)
    context.setLineCap(.round)
    context.setLineJoin(.round)
    context.beginPath()
    context.move(to: first)
    points.dropFirst().forEach { context.addLine(to: $0) }
    context.strokePath()
}

func ellipse(_ context: CGContext, _ rect: CGRect, _ color: RGB) {
    context.setFillColor(color.cg)
    context.fillEllipse(in: rect)
}

func checkmark(_ context: CGContext, origin: CGPoint, size: CGFloat, color: RGB, width: CGFloat) {
    line(
        context,
        [
            CGPoint(x: origin.x + size * 0.18, y: origin.y + size * 0.54),
            CGPoint(x: origin.x + size * 0.42, y: origin.y + size * 0.76),
            CGPoint(x: origin.x + size * 0.84, y: origin.y + size * 0.25)
        ],
        color,
        width: width
    )
}

func shieldPath(rect: CGRect) -> CGPath {
    let path = CGMutablePath()
    let minX = rect.minX
    let maxX = rect.maxX
    let midX = rect.midX
    let minY = rect.minY
    let maxY = rect.maxY
    let width = rect.width
    let height = rect.height

    path.move(to: CGPoint(x: midX, y: minY))
    path.addCurve(
        to: CGPoint(x: maxX, y: minY + height * 0.18),
        control1: CGPoint(x: midX + width * 0.22, y: minY + height * 0.03),
        control2: CGPoint(x: maxX - width * 0.04, y: minY + height * 0.04)
    )
    path.addLine(to: CGPoint(x: maxX - width * 0.08, y: minY + height * 0.55))
    path.addCurve(
        to: CGPoint(x: midX, y: maxY),
        control1: CGPoint(x: maxX - width * 0.10, y: minY + height * 0.78),
        control2: CGPoint(x: midX + width * 0.15, y: maxY - height * 0.05)
    )
    path.addCurve(
        to: CGPoint(x: minX + width * 0.08, y: minY + height * 0.55),
        control1: CGPoint(x: midX - width * 0.15, y: maxY - height * 0.05),
        control2: CGPoint(x: minX + width * 0.10, y: minY + height * 0.78)
    )
    path.addLine(to: CGPoint(x: minX, y: minY + height * 0.18))
    path.addCurve(
        to: CGPoint(x: midX, y: minY),
        control1: CGPoint(x: minX + width * 0.04, y: minY + height * 0.04),
        control2: CGPoint(x: midX - width * 0.22, y: minY + height * 0.03)
    )
    path.closeSubpath()
    return path
}

func fillShield(_ context: CGContext, rect: CGRect, color: RGB) {
    context.addPath(shieldPath(rect: rect))
    context.setFillColor(color.cg)
    context.fillPath()
}

func strokeShield(_ context: CGContext, rect: CGRect, color: RGB, width: CGFloat) {
    context.addPath(shieldPath(rect: rect).copy(strokingWithWidth: width, lineCap: .round, lineJoin: .round, miterLimit: 10))
    context.setFillColor(color.cg)
    context.fillPath()
}

func drawPortrait(_ context: CGContext, in rect: CGRect, background: RGB = paleBlue) {
    fill(context, rect, background, radius: 20)
    stroke(context, rect, border, width: 5, radius: 20)

    let head = CGRect(x: rect.midX - rect.width * 0.15, y: rect.minY + rect.height * 0.18, width: rect.width * 0.30, height: rect.width * 0.36)
    ellipse(context, head, RGB(0xF1D4C2))

    let hair = CGMutablePath()
    hair.move(to: CGPoint(x: rect.midX - rect.width * 0.23, y: rect.minY + rect.height * 0.25))
    hair.addCurve(to: CGPoint(x: rect.midX + rect.width * 0.22, y: rect.minY + rect.height * 0.26), control1: CGPoint(x: rect.midX - rect.width * 0.10, y: rect.minY + rect.height * 0.07), control2: CGPoint(x: rect.midX + rect.width * 0.18, y: rect.minY + rect.height * 0.10))
    hair.addCurve(to: CGPoint(x: rect.midX + rect.width * 0.14, y: rect.minY + rect.height * 0.49), control1: CGPoint(x: rect.midX + rect.width * 0.30, y: rect.minY + rect.height * 0.35), control2: CGPoint(x: rect.midX + rect.width * 0.24, y: rect.minY + rect.height * 0.49))
    hair.addCurve(to: CGPoint(x: rect.midX - rect.width * 0.18, y: rect.minY + rect.height * 0.48), control1: CGPoint(x: rect.midX + rect.width * 0.02, y: rect.minY + rect.height * 0.55), control2: CGPoint(x: rect.midX - rect.width * 0.10, y: rect.minY + rect.height * 0.55))
    hair.addCurve(to: CGPoint(x: rect.midX - rect.width * 0.23, y: rect.minY + rect.height * 0.25), control1: CGPoint(x: rect.midX - rect.width * 0.27, y: rect.minY + rect.height * 0.43), control2: CGPoint(x: rect.midX - rect.width * 0.31, y: rect.minY + rect.height * 0.32))
    context.addPath(hair)
    context.setFillColor(ink.cg)
    context.fillPath()

    ellipse(context, CGRect(x: rect.midX - rect.width * 0.12, y: rect.minY + rect.height * 0.22, width: rect.width * 0.24, height: rect.width * 0.29), RGB(0xF1D4C2))

    let shoulders = CGMutablePath()
    shoulders.move(to: CGPoint(x: rect.minX + rect.width * 0.16, y: rect.maxY))
    shoulders.addCurve(to: CGPoint(x: rect.maxX - rect.width * 0.16, y: rect.maxY), control1: CGPoint(x: rect.minX + rect.width * 0.26, y: rect.maxY - rect.height * 0.22), control2: CGPoint(x: rect.maxX - rect.width * 0.26, y: rect.maxY - rect.height * 0.22))
    shoulders.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
    shoulders.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
    shoulders.closeSubpath()
    context.addPath(shoulders)
    context.setFillColor(deepBlue.cg)
    context.fillPath()

    let ellipseRect = CGRect(x: rect.midX - rect.width * 0.24, y: rect.minY + rect.height * 0.15, width: rect.width * 0.48, height: rect.height * 0.54)
    context.setStrokeColor(officialBlue.cg)
    context.setLineWidth(5)
    context.setLineDash(phase: 0, lengths: [18, 12])
    context.strokeEllipse(in: ellipseRect)
    context.setLineDash(phase: 0, lengths: [])
}

func drawIDCard(_ context: CGContext, rect: CGRect, checked: Bool = true) {
    fill(context, rect, paper, radius: 34)
    stroke(context, rect, border, width: 6, radius: 34)

    let photo = CGRect(x: rect.minX + rect.width * 0.08, y: rect.minY + rect.height * 0.12, width: rect.width * 0.38, height: rect.height * 0.62)
    drawPortrait(context, in: photo)

    let lineX = rect.minX + rect.width * 0.54
    let lineW = rect.width * 0.32
    line(context, [CGPoint(x: lineX, y: rect.minY + rect.height * 0.20), CGPoint(x: lineX + lineW, y: rect.minY + rect.height * 0.20)], officialBlue, width: 12)
    line(context, [CGPoint(x: lineX, y: rect.minY + rect.height * 0.32), CGPoint(x: lineX + lineW * 0.78, y: rect.minY + rect.height * 0.32)], secondaryInk, width: 8)
    line(context, [CGPoint(x: lineX, y: rect.minY + rect.height * 0.44), CGPoint(x: lineX + lineW * 0.90, y: rect.minY + rect.height * 0.44)], secondaryInk, width: 8)
    line(context, [CGPoint(x: lineX, y: rect.minY + rect.height * 0.56), CGPoint(x: lineX + lineW * 0.58, y: rect.minY + rect.height * 0.56)], secondaryInk, width: 8)

    fill(context, CGRect(x: rect.minX + rect.width * 0.08, y: rect.maxY - rect.height * 0.16, width: rect.width * 0.78, height: rect.height * 0.045), softBlue, radius: 14)
    fill(context, CGRect(x: rect.minX + rect.width * 0.08, y: rect.maxY - rect.height * 0.08, width: rect.width * 0.54, height: rect.height * 0.045), softBlue, radius: 14)

    if checked {
        ellipse(context, CGRect(x: rect.maxX - rect.width * 0.24, y: rect.maxY - rect.width * 0.24, width: rect.width * 0.22, height: rect.width * 0.22), success)
        checkmark(context, origin: CGPoint(x: rect.maxX - rect.width * 0.205, y: rect.maxY - rect.width * 0.205), size: rect.width * 0.15, color: paper, width: rect.width * 0.035)
    }
}

func drawPhoneFrame(_ context: CGContext, rect: CGRect) {
    fill(context, rect, ink, radius: rect.width * 0.11)
    fill(context, rect.insetBy(dx: rect.width * 0.045, dy: rect.width * 0.045), paper, radius: rect.width * 0.08)
    fill(context, CGRect(x: rect.midX - rect.width * 0.15, y: rect.minY + rect.width * 0.045, width: rect.width * 0.30, height: rect.width * 0.035), ink, radius: 10)
}

func drawAppIcon(_ context: CGContext, _: CGSize) {
    fill(context, CGRect(x: 0, y: 0, width: 1024, height: 1024), paper)
    fill(context, CGRect(x: 88, y: 88, width: 848, height: 848), grouped, radius: 188)

    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: 20), blur: 28, color: RGB(0x002B66, alpha: 0.18).cg)
    fillShield(context, rect: CGRect(x: 238, y: 142, width: 548, height: 700), color: officialBlue)
    context.restoreGState()

    strokeShield(context, rect: CGRect(x: 238, y: 142, width: 548, height: 700), color: deepBlue, width: 18)
    fill(context, CGRect(x: 328, y: 318, width: 368, height: 270), paper, radius: 34)
    stroke(context, CGRect(x: 328, y: 318, width: 368, height: 270), paper, width: 12, radius: 34)
    fill(context, CGRect(x: 368, y: 372, width: 118, height: 148), softBlue, radius: 18)
    ellipse(context, CGRect(x: 407, y: 402, width: 40, height: 48), officialBlue)
    fill(context, CGRect(x: 386, y: 466, width: 82, height: 46), officialBlue, radius: 22)
    line(context, [CGPoint(x: 534, y: 394), CGPoint(x: 650, y: 394)], officialBlue, width: 16)
    line(context, [CGPoint(x: 534, y: 444), CGPoint(x: 626, y: 444)], deepBlue, width: 12)
    line(context, [CGPoint(x: 534, y: 492), CGPoint(x: 646, y: 492)], deepBlue, width: 12)
    ellipse(context, CGRect(x: 626, y: 574, width: 118, height: 118), success)
    checkmark(context, origin: CGPoint(x: 648, y: 602), size: 74, color: paper, width: 18)
}

func drawLaunchMark(_ context: CGContext, _: CGSize) {
    fillShield(context, rect: CGRect(x: 260, y: 118, width: 504, height: 676), color: officialBlue)
    fill(context, CGRect(x: 338, y: 300, width: 348, height: 250), paper, radius: 34)
    stroke(context, CGRect(x: 338, y: 300, width: 348, height: 250), paper, width: 10, radius: 34)
    fill(context, CGRect(x: 376, y: 354, width: 112, height: 136), softBlue, radius: 18)
    ellipse(context, CGRect(x: 412, y: 382, width: 42, height: 48), officialBlue)
    fill(context, CGRect(x: 394, y: 446, width: 78, height: 40), officialBlue, radius: 20)
    line(context, [CGPoint(x: 532, y: 382), CGPoint(x: 640, y: 382)], officialBlue, width: 14)
    line(context, [CGPoint(x: 532, y: 430), CGPoint(x: 618, y: 430)], deepBlue, width: 10)
    line(context, [CGPoint(x: 532, y: 474), CGPoint(x: 636, y: 474)], deepBlue, width: 10)
    ellipse(context, CGRect(x: 612, y: 540, width: 102, height: 102), success)
    checkmark(context, origin: CGPoint(x: 632, y: 564), size: 64, color: paper, width: 16)
}

func drawSplashHero(_ context: CGContext, _: CGSize) {
    drawIDCard(context, rect: CGRect(x: 230, y: 120, width: 500, height: 640))
    fill(context, CGRect(x: 640, y: 540, width: 238, height: 152), paper, radius: 30)
    stroke(context, CGRect(x: 640, y: 540, width: 238, height: 152), border, width: 6, radius: 30)
    ellipse(context, CGRect(x: 676, y: 588, width: 56, height: 56), success)
    checkmark(context, origin: CGPoint(x: 688, y: 600), size: 34, color: paper, width: 9)
    line(context, [CGPoint(x: 758, y: 594), CGPoint(x: 838, y: 594)], officialBlue, width: 10)
    line(context, [CGPoint(x: 758, y: 632), CGPoint(x: 816, y: 632)], secondaryInk, width: 8)
    fill(context, CGRect(x: 130, y: 662, width: 236, height: 128), paper, radius: 28)
    stroke(context, CGRect(x: 130, y: 662, width: 236, height: 128), border, width: 6, radius: 28)
    line(context, [CGPoint(x: 180, y: 712), CGPoint(x: 314, y: 712)], officialBlue, width: 12)
    line(context, [CGPoint(x: 180, y: 752), CGPoint(x: 278, y: 752)], secondaryInk, width: 9)
}

func drawImportOnboarding(_ context: CGContext, _: CGSize) {
    drawPhoneFrame(context, rect: CGRect(x: 176, y: 130, width: 430, height: 744))
    fill(context, CGRect(x: 232, y: 238, width: 318, height: 72), softBlue, radius: 20)
    fill(context, CGRect(x: 232, y: 342, width: 318, height: 72), grouped, radius: 20)
    fill(context, CGRect(x: 232, y: 446, width: 318, height: 72), grouped, radius: 20)
    fill(context, CGRect(x: 232, y: 550, width: 318, height: 72), grouped, radius: 20)
    for y in [270, 374, 478, 582] {
        ellipse(context, CGRect(x: 264, y: CGFloat(y), width: 18, height: 18), officialBlue)
        line(context, [CGPoint(x: 306, y: CGFloat(y) + 8), CGPoint(x: 500, y: CGFloat(y) + 8)], y == 270 ? officialBlue : secondaryInk, width: 9)
    }
    drawIDCard(context, rect: CGRect(x: 628, y: 310, width: 260, height: 340), checked: false)
}

func drawEditOnboarding(_ context: CGContext, _: CGSize) {
    fill(context, CGRect(x: 170, y: 130, width: 520, height: 688), paper, radius: 42)
    stroke(context, CGRect(x: 170, y: 130, width: 520, height: 688), border, width: 7, radius: 42)
    let photo = CGRect(x: 244, y: 194, width: 372, height: 470)
    drawPortrait(context, in: photo, background: RGB(0xFFFFFF))
    stroke(context, CGRect(x: 218, y: 170, width: 424, height: 522), officialBlue, width: 8, radius: 22)
    line(context, [CGPoint(x: 216, y: 744), CGPoint(x: 636, y: 744)], border, width: 14)
    line(context, [CGPoint(x: 216, y: 744), CGPoint(x: 472, y: 744)], officialBlue, width: 14)
    ellipse(context, CGRect(x: 452, y: 724, width: 40, height: 40), officialBlue)
    fill(context, CGRect(x: 720, y: 240, width: 94, height: 94), paper, radius: 28)
    stroke(context, CGRect(x: 720, y: 240, width: 94, height: 94), border, width: 6, radius: 28)
    fill(context, CGRect(x: 720, y: 374, width: 94, height: 94), softBlue, radius: 28)
    stroke(context, CGRect(x: 720, y: 374, width: 94, height: 94), officialBlue, width: 6, radius: 28)
    fill(context, CGRect(x: 720, y: 508, width: 94, height: 94), grouped, radius: 28)
    stroke(context, CGRect(x: 720, y: 508, width: 94, height: 94), border, width: 6, radius: 28)
}

func drawCheckOnboarding(_ context: CGContext, _: CGSize) {
    fill(context, CGRect(x: 210, y: 104, width: 604, height: 812), paper, radius: 46)
    stroke(context, CGRect(x: 210, y: 104, width: 604, height: 812), border, width: 7, radius: 46)
    drawIDCard(context, rect: CGRect(x: 336, y: 176, width: 352, height: 392), checked: true)

    let rows: [CGFloat] = [642, 718, 794]
    for y in rows {
        ellipse(context, CGRect(x: 300, y: y, width: 46, height: 46), success)
        checkmark(context, origin: CGPoint(x: 309, y: y + 10), size: 28, color: paper, width: 8)
        line(context, [CGPoint(x: 380, y: y + 14), CGPoint(x: 708, y: y + 14)], officialBlue, width: 11)
        line(context, [CGPoint(x: 380, y: y + 44), CGPoint(x: 640, y: y + 44)], secondaryInk, width: 8)
    }
}

func drawExportOnboarding(_ context: CGContext, _: CGSize) {
    fill(context, CGRect(x: 190, y: 122, width: 482, height: 676), paper, radius: 38)
    stroke(context, CGRect(x: 190, y: 122, width: 482, height: 676), border, width: 7, radius: 38)
    let photoSize = CGSize(width: 138, height: 172)
    let origins = [
        CGPoint(x: 252, y: 206),
        CGPoint(x: 456, y: 206),
        CGPoint(x: 252, y: 432),
        CGPoint(x: 456, y: 432)
    ]
    for origin in origins {
        drawPortrait(context, in: CGRect(origin: origin, size: photoSize), background: RGB(0xFFFFFF))
    }
    line(context, [CGPoint(x: 252, y: 674), CGPoint(x: 606, y: 674)], officialBlue, width: 12)
    line(context, [CGPoint(x: 252, y: 720), CGPoint(x: 518, y: 720)], secondaryInk, width: 9)

    fill(context, CGRect(x: 682, y: 402, width: 196, height: 262), paper, radius: 34)
    stroke(context, CGRect(x: 682, y: 402, width: 196, height: 262), officialBlue, width: 8, radius: 34)
    line(context, [CGPoint(x: 780, y: 480), CGPoint(x: 780, y: 574)], officialBlue, width: 17)
    line(context, [CGPoint(x: 736, y: 536), CGPoint(x: 780, y: 580), CGPoint(x: 824, y: 536)], officialBlue, width: 17)
    fill(context, CGRect(x: 700, y: 612, width: 160, height: 26), softBlue, radius: 13)
}

func drawProUnlockImage(_ context: CGContext, _: CGSize) {
    fill(context, CGRect(x: 0, y: 0, width: 1024, height: 1024), paper)
    fill(context, CGRect(x: 76, y: 76, width: 872, height: 872), grouped, radius: 136)

    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: 20), blur: 34, color: RGB(0x002B66, alpha: 0.18).cg)
    fill(context, CGRect(x: 198, y: 160, width: 628, height: 704), paper, radius: 62)
    context.restoreGState()
    stroke(context, CGRect(x: 198, y: 160, width: 628, height: 704), border, width: 8, radius: 62)

    drawIDCard(context, rect: CGRect(x: 288, y: 238, width: 448, height: 430), checked: true)

    fill(context, CGRect(x: 326, y: 716, width: 372, height: 92), officialBlue, radius: 46)
    drawLettersPRO(context, rect: CGRect(x: 386, y: 738, width: 252, height: 50), color: paper, width: 13)

    fillShield(context, rect: CGRect(x: 640, y: 108, width: 180, height: 236), color: officialBlue)
    fill(context, CGRect(x: 688, y: 218, width: 84, height: 70), paper, radius: 16)
    context.setStrokeColor(paper.cg)
    context.setLineWidth(13)
    context.setLineCap(.round)
    context.beginPath()
    context.addArc(center: CGPoint(x: 730, y: 220), radius: 34, startAngle: CGFloat.pi, endAngle: 0, clockwise: false)
    context.strokePath()
    ellipse(context, CGRect(x: 716, y: 246, width: 28, height: 28), officialBlue)
}

func drawLettersPRO(_ context: CGContext, rect: CGRect, color: RGB, width: CGFloat) {
    let letterWidth = rect.width / 3.4
    let gap = rect.width * 0.08
    let top = rect.minY
    let bottom = rect.maxY
    let midY = rect.midY

    let pX = rect.minX
    line(context, [CGPoint(x: pX, y: bottom), CGPoint(x: pX, y: top), CGPoint(x: pX + letterWidth * 0.68, y: top), CGPoint(x: pX + letterWidth * 0.80, y: midY), CGPoint(x: pX, y: midY)], color, width: width)

    let rX = pX + letterWidth + gap
    line(context, [CGPoint(x: rX, y: bottom), CGPoint(x: rX, y: top), CGPoint(x: rX + letterWidth * 0.68, y: top), CGPoint(x: rX + letterWidth * 0.80, y: midY), CGPoint(x: rX, y: midY)], color, width: width)
    line(context, [CGPoint(x: rX + letterWidth * 0.34, y: midY), CGPoint(x: rX + letterWidth * 0.86, y: bottom)], color, width: width)

    let oX = rX + letterWidth + gap
    context.setStrokeColor(color.cg)
    context.setLineWidth(width)
    context.addEllipse(in: CGRect(x: oX, y: top, width: letterWidth * 0.9, height: rect.height))
    context.strokePath()
}

func drawPrivacyOnboarding(_ context: CGContext, _: CGSize) {
    drawPhoneFrame(context, rect: CGRect(x: 270, y: 120, width: 484, height: 762))
    fill(context, CGRect(x: 342, y: 232, width: 340, height: 432), softBlue, radius: 34)
    stroke(context, CGRect(x: 342, y: 232, width: 340, height: 432), border, width: 6, radius: 34)
    fillShield(context, rect: CGRect(x: 410, y: 292, width: 204, height: 266), color: officialBlue)
    fill(context, CGRect(x: 455, y: 418, width: 114, height: 94), paper, radius: 20)
    stroke(context, CGRect(x: 455, y: 418, width: 114, height: 94), paper, width: 8, radius: 20)
    context.setStrokeColor(paper.cg)
    context.setLineWidth(18)
    context.setLineCap(.round)
    context.beginPath()
    context.addArc(center: CGPoint(x: 512, y: 420), radius: 48, startAngle: CGFloat.pi, endAngle: 0, clockwise: false)
    context.strokePath()
    ellipse(context, CGRect(x: 493, y: 452, width: 38, height: 38), officialBlue)
    line(context, [CGPoint(x: 512, y: 486), CGPoint(x: 512, y: 502)], officialBlue, width: 13)

    let badgeRect = CGRect(x: 220, y: 654, width: 584, height: 106)
    fill(context, badgeRect, paper, radius: 26)
    stroke(context, badgeRect, border, width: 6, radius: 26)
    ellipse(context, CGRect(x: 260, y: 685, width: 44, height: 44), success)
    checkmark(context, origin: CGPoint(x: 268, y: 694), size: 28, color: paper, width: 8)
    line(context, [CGPoint(x: 334, y: 692), CGPoint(x: 704, y: 692)], officialBlue, width: 10)
    line(context, [CGPoint(x: 334, y: 724), CGPoint(x: 654, y: 724)], secondaryInk, width: 8)

    context.setStrokeColor(warning.cg)
    context.setLineWidth(8)
    context.setLineDash(phase: 0, lengths: [18, 14])
    context.addEllipse(in: CGRect(x: 168, y: 210, width: 688, height: 614))
    context.strokePath()
    context.setLineDash(phase: 0, lengths: [])
}

func writeImageSet(name: String, pointSize: CGSize, draw: @escaping (CGContext, CGSize) -> Void) throws {
    let dir = assets.appendingPathComponent("\(name).imageset")
    try ensureDirectory(dir)
    let scales = [1, 2, 3]
    for scale in scales {
        let suffix = scale == 1 ? "" : "@\(scale)x"
        let filename = "\(name)\(suffix).png"
        try savePNG(width: Int(pointSize.width) * scale, height: Int(pointSize.height) * scale, url: dir.appendingPathComponent(filename), draw: draw)
    }
    let contents: [String: Any] = [
        "images": scales.map { scale in
            [
                "idiom": "universal",
                "filename": "\(name)\(scale == 1 ? "" : "@\(scale)x").png",
                "scale": "\(scale)x"
            ]
        },
        "info": ["author": "xcode", "version": 1]
    ]
    let data = try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
    try data.write(to: dir.appendingPathComponent("Contents.json"))
}

struct AppIconSlot {
    let idiom: String
    let size: String
    let scale: String
    let pixels: Int
    let filename: String
}

let iconSlots: [AppIconSlot] = [
    .init(idiom: "iphone", size: "20x20", scale: "2x", pixels: 40, filename: "AppIcon-iphone-20@2x.png"),
    .init(idiom: "iphone", size: "20x20", scale: "3x", pixels: 60, filename: "AppIcon-iphone-20@3x.png"),
    .init(idiom: "iphone", size: "29x29", scale: "2x", pixels: 58, filename: "AppIcon-iphone-29@2x.png"),
    .init(idiom: "iphone", size: "29x29", scale: "3x", pixels: 87, filename: "AppIcon-iphone-29@3x.png"),
    .init(idiom: "iphone", size: "40x40", scale: "2x", pixels: 80, filename: "AppIcon-iphone-40@2x.png"),
    .init(idiom: "iphone", size: "40x40", scale: "3x", pixels: 120, filename: "AppIcon-iphone-40@3x.png"),
    .init(idiom: "iphone", size: "60x60", scale: "2x", pixels: 120, filename: "AppIcon-iphone-60@2x.png"),
    .init(idiom: "iphone", size: "60x60", scale: "3x", pixels: 180, filename: "AppIcon-iphone-60@3x.png"),
    .init(idiom: "ipad", size: "20x20", scale: "1x", pixels: 20, filename: "AppIcon-ipad-20@1x.png"),
    .init(idiom: "ipad", size: "20x20", scale: "2x", pixels: 40, filename: "AppIcon-ipad-20@2x.png"),
    .init(idiom: "ipad", size: "29x29", scale: "1x", pixels: 29, filename: "AppIcon-ipad-29@1x.png"),
    .init(idiom: "ipad", size: "29x29", scale: "2x", pixels: 58, filename: "AppIcon-ipad-29@2x.png"),
    .init(idiom: "ipad", size: "40x40", scale: "1x", pixels: 40, filename: "AppIcon-ipad-40@1x.png"),
    .init(idiom: "ipad", size: "40x40", scale: "2x", pixels: 80, filename: "AppIcon-ipad-40@2x.png"),
    .init(idiom: "ipad", size: "76x76", scale: "1x", pixels: 76, filename: "AppIcon-ipad-76@1x.png"),
    .init(idiom: "ipad", size: "76x76", scale: "2x", pixels: 152, filename: "AppIcon-ipad-76@2x.png"),
    .init(idiom: "ipad", size: "83.5x83.5", scale: "2x", pixels: 167, filename: "AppIcon-ipad-83.5@2x.png"),
    .init(idiom: "ios-marketing", size: "1024x1024", scale: "1x", pixels: 1024, filename: "AppIcon-1024.png")
]

func writeAppIcons() throws {
    try ensureDirectory(appIconSet)
    for slot in iconSlots {
        try savePNG(width: slot.pixels, height: slot.pixels, url: appIconSet.appendingPathComponent(slot.filename), opaque: true, draw: drawAppIcon)
    }
    try? FileManager.default.removeItem(at: appIconSet.appendingPathComponent("AppIcon.png"))

    let images: [[String: Any]] = iconSlots.map { slot in
        [
            "idiom": slot.idiom,
            "size": slot.size,
            "scale": slot.scale,
            "filename": slot.filename
        ]
    }
    let contents: [String: Any] = [
        "images": images,
        "info": ["author": "xcode", "version": 1]
    ]
    let data = try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
    try data.write(to: appIconSet.appendingPathComponent("Contents.json"))
}

try ensureDirectory(assets)
try ensureDirectory(appStorePackage)
try writeAppIcons()
try savePNG(width: 1024, height: 1024, url: appStorePackage.appendingPathComponent("iap-lifetime-unlock-1024.png"), opaque: true, draw: drawProUnlockImage)
try writeImageSet(name: "LaunchMark", pointSize: CGSize(width: 220, height: 220), draw: drawLaunchMark)
try writeImageSet(name: "SplashHero", pointSize: CGSize(width: 390, height: 360), draw: drawSplashHero)
try writeImageSet(name: "OnboardingImport", pointSize: CGSize(width: 330, height: 286), draw: drawImportOnboarding)
try writeImageSet(name: "OnboardingEdit", pointSize: CGSize(width: 330, height: 286), draw: drawEditOnboarding)
try writeImageSet(name: "OnboardingCheck", pointSize: CGSize(width: 330, height: 286), draw: drawCheckOnboarding)
try writeImageSet(name: "OnboardingExport", pointSize: CGSize(width: 330, height: 286), draw: drawExportOnboarding)
try writeImageSet(name: "OnboardingPrivacy", pointSize: CGSize(width: 330, height: 286), draw: drawPrivacyOnboarding)

print("Generated professional app icons, splash, and onboarding assets in \(assets.path)")
