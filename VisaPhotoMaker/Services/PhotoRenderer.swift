import CoreImage
import CoreImage.CIFilterBuiltins
import ImageIO
import SwiftUI
import UIKit
import UniformTypeIdentifiers

@MainActor
struct PhotoRenderer {
    private let context = CIContext()

    func render(image: UIImage, spec: PhotoSpec, background: PhotoBackground, faceAnalysis: FaceAnalysis? = nil, editState: PhotoEditState = .default, scale: CGFloat = 1) -> UIImage {
        let targetSize = CGSize(width: spec.pixelSize.width * scale, height: spec.pixelSize.height * scale)
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let adjusted = adjustedImage(image, editState: editState)

        return renderer.image { context in
            UIColor(background.color).setFill()
            context.fill(CGRect(origin: .zero, size: targetSize))
            drawEdited(image: adjusted, in: targetSize, context: context.cgContext, editState: editState, renderScale: scale)
        }
    }

    func renderPrintSheet(image: UIImage, spec: PhotoSpec, background: PhotoBackground, faceAnalysis: FaceAnalysis? = nil, editState: PhotoEditState = .default, layout: PrintLayout = .fourBySix, copies: Int = 0, showsCropMarks: Bool = true, packingMode: PrintPackingMode = .safe, compactOptionID: String? = nil) -> UIImage {
        let canvasSize = canvasSize(for: layout)
        let plan = printLayoutPlan(for: layout, spec: spec, copies: copies, packingMode: packingMode, compactOptionID: compactOptionID)
        let renderer = UIGraphicsImageRenderer(size: canvasSize)
        let renderScale = max(plan.photoSize.width / max(spec.pixelSize.width, 1), plan.photoSize.height / max(spec.pixelSize.height, 1), 1)
        let single = render(image: image, spec: spec, background: background, faceAnalysis: faceAnalysis, editState: editState, scale: renderScale)

        return renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: canvasSize))

            var renderedCopies = 0
            for row in 0..<plan.rows {
                for column in 0..<plan.columns where renderedCopies < plan.maxCopies {
                    let rect = CGRect(
                        x: plan.startX + CGFloat(column) * (plan.photoSize.width + plan.spacing),
                        y: plan.startY + CGFloat(row) * (plan.photoSize.height + plan.spacing),
                        width: plan.photoSize.width,
                        height: plan.photoSize.height
                    )
                    single.draw(in: rect)
                    if showsCropMarks {
                        drawCropMarks(in: rect, context: context.cgContext)
                    }
                    renderedCopies += 1
                }
            }
        }
    }

    func exportData(image: UIImage, format: ExportFormat, targetKB: Int?) -> Data? {
        switch format {
        case .jpg:
            return compressedData(image: image, format: .jpg, targetKB: targetKB)
        case .heif:
            return compressedData(image: image, format: .heif, targetKB: targetKB)
        case .png:
            return image.pngData()
        case .pdf:
            return pdfData(image: image)
        }
    }

    private func compressedData(image: UIImage, format: ExportFormat, targetKB: Int?) -> Data? {
        guard let targetKB, targetKB > 0 else {
            return lossyData(image: image, format: format, quality: 0.92)
        }

        let targetBytes = targetKB * 1024
        var workingImage = image
        var smallestData: Data?

        for _ in 0..<7 {
            var low: CGFloat = 0.08
            var high: CGFloat = 0.95
            var bestUnderTarget: Data?

            for _ in 0..<10 {
                let mid = (low + high) / 2
                guard let data = lossyData(image: workingImage, format: format, quality: mid) else { break }
                if smallestData == nil || data.count < (smallestData?.count ?? Int.max) {
                    smallestData = data
                }
                if data.count > targetBytes {
                    high = mid
                } else {
                    bestUnderTarget = data
                    low = mid
                }
            }

            if let bestUnderTarget {
                return bestUnderTarget
            }

            guard let currentData = smallestData else { break }
            let shrink = max(0.55, min(0.90, sqrt(CGFloat(targetBytes) / CGFloat(max(currentData.count, 1))) * 0.92))
            guard let resized = resize(image: workingImage, scale: shrink) else { break }
            workingImage = resized
            if min(workingImage.size.width, workingImage.size.height) < 320 {
                break
            }
        }

        return smallestData
    }

    private func lossyData(image: UIImage, format: ExportFormat, quality: CGFloat) -> Data? {
        switch format {
        case .jpg:
            return image.jpegData(compressionQuality: quality)
        case .heif:
            return heifData(image: image, quality: quality)
        case .png:
            return image.pngData()
        case .pdf:
            return pdfData(image: image)
        }
    }

    private func heifData(image: UIImage, quality: CGFloat) -> Data? {
        guard let cgImage = image.normalized().cgImage else { return nil }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.heic.identifier as CFString, 1, nil) else {
            return nil
        }
        let options: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: quality
        ]
        CGImageDestinationAddImage(destination, cgImage, options as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }

    private func resize(image: UIImage, scale: CGFloat) -> UIImage? {
        let size = CGSize(width: max(1, floor(image.size.width * scale)), height: max(1, floor(image.size.height * scale)))
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    private func pdfData(image: UIImage) -> Data {
        let data = NSMutableData()
        let bounds = CGRect(origin: .zero, size: image.size)
        UIGraphicsBeginPDFContextToData(data, bounds, nil)
        UIGraphicsBeginPDFPageWithInfo(bounds, nil)
        image.draw(in: bounds)
        UIGraphicsEndPDFContext()
        return data as Data
    }

    struct PrintSheetPlan {
        let columns: Int
        let rows: Int
        let maxCopies: Int
        let photoSize: CGSize
        let margin: CGFloat
        let startX: CGFloat
        let startY: CGFloat
        let spacing: CGFloat
    }

    struct CompactPrintOption {
        let id: String
        let columns: Int
        let rows: Int
        let fillsWidth: Bool
        let fillsHeight: Bool
        let photoSize: CGSize

        var capacity: Int {
            columns * rows
        }

        var title: String {
            "\(columns) x \(rows)"
        }

        var edgeSummary: String {
            if fillsWidth && fillsHeight {
                return "no margins"
            }
            if fillsWidth {
                return "no side margins"
            }
            return "no top/bottom margins"
        }
    }

    private func drawEdited(image: UIImage, in targetSize: CGSize, context: CGContext, editState: PhotoEditState, renderScale: CGFloat) {
        let baseRect = aspectFillRect(imageSize: image.size, targetSize: targetSize)
        context.saveGState()
        context.translateBy(
            x: targetSize.width / 2 + editState.offset.width * renderScale,
            y: targetSize.height / 2 + editState.offset.height * renderScale
        )
        context.rotate(by: CGFloat(editState.rotationDegrees * .pi / 180))
        context.scaleBy(x: editState.scale, y: editState.scale)
        let drawRect = CGRect(x: -baseRect.width / 2, y: -baseRect.height / 2, width: baseRect.width, height: baseRect.height)
        image.draw(in: drawRect, blendMode: .normal, alpha: 0.98)
        context.restoreGState()
    }

    private func adjustedImage(_ image: UIImage, editState: PhotoEditState) -> UIImage {
        guard editState.hasImageAdjustments,
              let cgImage = image.normalized().cgImage else {
            return image
        }

        let input = CIImage(cgImage: cgImage)
        let controls = CIFilter.colorControls()
        controls.inputImage = input
        controls.brightness = Float(clamp(editState.brightness * 0.75 + editState.shadows * 0.28, min: -0.18, max: 0.18))
        controls.contrast = Float(clamp(1 + (editState.contrast - 1) * 0.85, min: 0.72, max: 1.32))
        controls.saturation = Float(clamp(1 + (editState.saturation - 1) * 0.95, min: 0.78, max: 1.25))

        var output = controls.outputImage ?? input

        if abs(editState.warmth) > 0.001 {
            let temperature = CIFilter.temperatureAndTint()
            temperature.inputImage = output
            temperature.neutral = CIVector(x: 6500 + editState.warmth * 1600, y: 0)
            temperature.targetNeutral = CIVector(x: 6500, y: 0)
            output = temperature.outputImage ?? output
        }

        if editState.sharpness > 0.001 {
            let sharpen = CIFilter.sharpenLuminance()
            sharpen.inputImage = output
            sharpen.sharpness = Float(min(editState.sharpness * 1.25, 1.8))
            output = sharpen.outputImage ?? output
        }

        if imageHasAlpha(cgImage) {
            output = output.premultiplyingAlpha().unpremultiplyingAlpha()
        }

        guard let outputCG = context.createCGImage(output, from: input.extent) else {
            return image
        }
        return UIImage(cgImage: outputCG, scale: image.scale, orientation: .up)
    }

    private func imageHasAlpha(_ cgImage: CGImage) -> Bool {
        switch cgImage.alphaInfo {
        case .first, .last, .premultipliedFirst, .premultipliedLast:
            return true
        default:
            return false
        }
    }

    private func clamp(_ value: Double, min minValue: Double, max maxValue: Double) -> Double {
        Swift.min(Swift.max(value, minValue), maxValue)
    }

    func compactPrintOption(for layout: PrintLayout, spec: PhotoSpec) -> CompactPrintOption? {
        compactPrintOptions(for: layout, spec: spec).first
    }

    func compactPrintOptions(for layout: PrintLayout, spec: PhotoSpec) -> [CompactPrintOption] {
        guard layout != .digitalOnly else { return [] }

        let canvasSize = canvasSize(for: layout)
        let paperSize = paperSizeMM(for: layout)
        let photoSizeMM = compactPhotoSizeMM(for: spec)
        let pixelsPerMM = min(canvasSize.width / max(paperSize.width, 1), canvasSize.height / max(paperSize.height, 1))
        let photoWidth = photoSizeMM.width * pixelsPerMM
        let photoHeight = photoSizeMM.height * pixelsPerMM
        guard photoWidth > 0, photoHeight > 0 else { return [] }

        let tolerance = max(2, pixelsPerMM * 0.35)
        let maxColumns = Int(floor((canvasSize.width + tolerance) / photoWidth))
        let maxRows = Int(floor((canvasSize.height + tolerance) / photoHeight))
        guard maxColumns > 0, maxRows > 0 else { return [] }

        var options: [CompactPrintOption] = []
        for columns in 1...maxColumns {
            for rows in 1...maxRows {
                let usedWidth = CGFloat(columns) * photoWidth
                let usedHeight = CGFloat(rows) * photoHeight
                guard usedWidth <= canvasSize.width + tolerance, usedHeight <= canvasSize.height + tolerance else {
                    continue
                }
                let fillsWidth = abs(usedWidth - canvasSize.width) <= tolerance
                let fillsHeight = abs(usedHeight - canvasSize.height) <= tolerance
                guard fillsWidth || fillsHeight else { continue }
                let id = "\(layout.id)-\(Int(round(photoSizeMM.width * 10)))-\(Int(round(photoSizeMM.height * 10)))-\(columns)x\(rows)"
                options.append(
                    CompactPrintOption(
                        id: id,
                        columns: columns,
                        rows: rows,
                        fillsWidth: fillsWidth,
                        fillsHeight: fillsHeight,
                        photoSize: CGSize(width: photoWidth, height: photoHeight)
                    )
                )
            }
        }

        return options.sorted { lhs, rhs in
            if (lhs.fillsWidth && lhs.fillsHeight) != (rhs.fillsWidth && rhs.fillsHeight) {
                return lhs.fillsWidth && lhs.fillsHeight
            }
            if lhs.capacity != rhs.capacity {
                return lhs.capacity > rhs.capacity
            }
            if lhs.rows != rhs.rows {
                return lhs.rows > rhs.rows
            }
            return lhs.columns > rhs.columns
        }
    }

    private func printLayoutPlan(for layout: PrintLayout, spec: PhotoSpec, copies: Int, packingMode: PrintPackingMode, compactOptionID: String?) -> PrintSheetPlan {
        if packingMode == .compact {
            let compactOptions = compactPrintOptions(for: layout, spec: spec)
            let compact = compactOptions.first { $0.id == compactOptionID } ?? compactOptions.first
            if let compact {
                let canvasSize = canvasSize(for: layout)
                let photoSize = compact.photoSize
                let usedWidth = CGFloat(compact.columns) * photoSize.width
                let usedHeight = CGFloat(compact.rows) * photoSize.height
                let capacity = compact.capacity
                return PrintSheetPlan(
                    columns: compact.columns,
                    rows: compact.rows,
                    maxCopies: copies <= 0 ? capacity : min(max(1, copies), capacity),
                    photoSize: photoSize,
                    margin: 0,
                    startX: max(0, (canvasSize.width - usedWidth) / 2),
                    startY: max(0, (canvasSize.height - usedHeight) / 2),
                    spacing: 0
                )
            }
        }

        if layout == .fourBySix, isTwoByTwoInch(spec) {
            let photoSize = CGSize(width: 600, height: 600)
            let capacity = 4
            return PrintSheetPlan(
                columns: 2,
                rows: 2,
                maxCopies: copies <= 0 ? capacity : min(max(1, copies), capacity),
                photoSize: photoSize,
                margin: 0,
                startX: 0,
                startY: 300,
                spacing: 0
            )
        }

        let canvasSize = canvasSize(for: layout)
        let paperSizeMM = paperSizeMM(for: layout)
        let pixelsPerMM = min(canvasSize.width / max(paperSizeMM.width, 1), canvasSize.height / max(paperSizeMM.height, 1))
        let spacing = max(18, 2 * pixelsPerMM)
        let safeMargin = max(margin(for: layout), 3.5 * pixelsPerMM)
        let photoSize = CGSize(width: spec.widthMM * pixelsPerMM, height: spec.heightMM * pixelsPerMM)
        let availableWidth = max(canvasSize.width - safeMargin * 2 + spacing, photoSize.width)
        let availableHeight = max(canvasSize.height - safeMargin * 2 + spacing, photoSize.height)
        let columns = max(1, Int(floor(availableWidth / max(photoSize.width + spacing, 1))))
        let rows = max(1, Int(floor(availableHeight / max(photoSize.height + spacing, 1))))

        let capacity = max(1, columns * rows)
        let maxCopies = copies <= 0 ? capacity : min(max(1, copies), capacity)
        let usedWidth = CGFloat(columns) * photoSize.width + CGFloat(max(columns - 1, 0)) * spacing
        let usedHeight = CGFloat(rows) * photoSize.height + CGFloat(max(rows - 1, 0)) * spacing
        let startX = max(safeMargin, (canvasSize.width - usedWidth) / 2)
        let startY = max(safeMargin, (canvasSize.height - usedHeight) / 2)

        return PrintSheetPlan(
            columns: columns,
            rows: rows,
            maxCopies: maxCopies,
            photoSize: photoSize,
            margin: min(startX, startY),
            startX: startX,
            startY: startY,
            spacing: spacing
        )
    }

    private func isTwoByTwoInch(_ spec: PhotoSpec) -> Bool {
        abs(spec.widthMM - 50.8) <= 2.5 && abs(spec.heightMM - 50.8) <= 2.5
    }

    private func isOneByOneInch(_ spec: PhotoSpec) -> Bool {
        abs(spec.widthMM - 25.4) <= 1.5 && abs(spec.heightMM - 25.4) <= 1.5
    }

    private func compactPhotoSize(for spec: PhotoSpec) -> CGSize? {
        if isTwoByTwoInch(spec) {
            return CGSize(width: 600, height: 600)
        }
        if isOneByOneInch(spec) {
            return CGSize(width: 300, height: 300)
        }
        return nil
    }

    private func compactPhotoSizeMM(for spec: PhotoSpec) -> CGSize {
        if isTwoByTwoInch(spec) {
            return CGSize(width: 50.8, height: 50.8)
        }
        if isOneByOneInch(spec) {
            return CGSize(width: 25.4, height: 25.4)
        }
        return CGSize(width: spec.widthMM, height: spec.heightMM)
    }

    private func drawCropMarks(in rect: CGRect, context: CGContext) {
        context.saveGState()
        context.setStrokeColor(UIColor.black.withAlphaComponent(0.55).cgColor)
        context.setLineWidth(1)
        let length: CGFloat = 16
        let gap: CGFloat = 5

        let points: [(CGPoint, CGPoint)] = [
            (CGPoint(x: rect.minX - gap - length, y: rect.minY), CGPoint(x: rect.minX - gap, y: rect.minY)),
            (CGPoint(x: rect.minX, y: rect.minY - gap - length), CGPoint(x: rect.minX, y: rect.minY - gap)),
            (CGPoint(x: rect.maxX + gap, y: rect.minY), CGPoint(x: rect.maxX + gap + length, y: rect.minY)),
            (CGPoint(x: rect.maxX, y: rect.minY - gap - length), CGPoint(x: rect.maxX, y: rect.minY - gap)),
            (CGPoint(x: rect.minX - gap - length, y: rect.maxY), CGPoint(x: rect.minX - gap, y: rect.maxY)),
            (CGPoint(x: rect.minX, y: rect.maxY + gap), CGPoint(x: rect.minX, y: rect.maxY + gap + length)),
            (CGPoint(x: rect.maxX + gap, y: rect.maxY), CGPoint(x: rect.maxX + gap + length, y: rect.maxY)),
            (CGPoint(x: rect.maxX, y: rect.maxY + gap), CGPoint(x: rect.maxX, y: rect.maxY + gap + length))
        ]

        for (start, end) in points {
            context.move(to: start)
            context.addLine(to: end)
        }
        context.strokePath()
        context.restoreGState()
    }

    private func aspectFillRect(imageSize: CGSize, targetSize: CGSize) -> CGRect {
        let imageRatio = imageSize.width / max(imageSize.height, 1)
        let targetRatio = targetSize.width / max(targetSize.height, 1)
        if imageRatio > targetRatio {
            let height = targetSize.height
            let width = height * imageRatio
            return CGRect(x: (targetSize.width - width) / 2, y: 0, width: width, height: height)
        } else {
            let width = targetSize.width
            let height = width / imageRatio
            return CGRect(x: 0, y: (targetSize.height - height) / 2, width: width, height: height)
        }
    }

    private func canvasSize(for layout: PrintLayout) -> CGSize {
        switch layout {
        case .digitalOnly:
            return CGSize(width: 1800, height: 1200)
        case .threeByFour:
            return CGSize(width: 900, height: 1200)
        case .fourByFour:
            return CGSize(width: 1200, height: 1200)
        case .fourBySix:
            return CGSize(width: 1200, height: 1800)
        case .fiveBySeven:
            return CGSize(width: 1500, height: 2100)
        case .a4:
            return CGSize(width: 2480, height: 3508)
        case .letter:
            return CGSize(width: 2550, height: 3300)
        }
    }

    private func margin(for layout: PrintLayout) -> CGFloat {
        switch layout {
        case .digitalOnly:
            return 80
        case .threeByFour, .fourByFour:
            return 48
        case .fourBySix:
            return 70
        case .fiveBySeven:
            return 86
        case .a4, .letter:
            return 110
        }
    }

    private func spacing(for layout: PrintLayout) -> CGFloat {
        switch layout {
        case .digitalOnly:
            return 42
        case .threeByFour, .fourByFour:
            return 34
        case .fourBySix:
            return 42
        case .fiveBySeven:
            return 48
        case .a4, .letter:
            return 54
        }
    }

    private func paperSizeMM(for layout: PrintLayout) -> CGSize {
        switch layout {
        case .digitalOnly:
            return CGSize(width: 152.4, height: 101.6)
        case .threeByFour:
            return CGSize(width: 76.2, height: 101.6)
        case .fourByFour:
            return CGSize(width: 101.6, height: 101.6)
        case .fourBySix:
            return CGSize(width: 101.6, height: 152.4)
        case .fiveBySeven:
            return CGSize(width: 127, height: 177.8)
        case .a4:
            return CGSize(width: 210, height: 297)
        case .letter:
            return CGSize(width: 215.9, height: 279.4)
        }
    }

    private func cropRectForExport(imageSize: CGSize, targetRatio: CGFloat, faceAnalysis: FaceAnalysis?, spec: PhotoSpec) -> CGRect {
        guard let faceAnalysis else {
            return cropRectForAspectFit(imageSize: imageSize, targetRatio: targetRatio)
        }

        let faceRect = denormalize(faceAnalysis.faceRect, imageSize: imageSize)
        let targetHeadRatio = CGFloat(spec.complianceProfile.targetHeadRatio)
        var cropHeight = faceRect.height / max(targetHeadRatio, 0.1)
        var cropWidth = cropHeight * targetRatio

        if cropWidth > imageSize.width {
            cropWidth = imageSize.width
            cropHeight = cropWidth / targetRatio
        }
        if cropHeight > imageSize.height {
            cropHeight = imageSize.height
            cropWidth = cropHeight * targetRatio
        }

        let centerX = faceRect.midX
        let centerY = faceRect.midY + cropHeight * 0.03
        let x = min(max(centerX - cropWidth / 2, 0), imageSize.width - cropWidth)
        let y = min(max(centerY - cropHeight / 2, 0), imageSize.height - cropHeight)
        return CGRect(x: x, y: y, width: cropWidth, height: cropHeight).integral
    }

    private func cropRectForAspectFit(imageSize: CGSize, targetRatio: CGFloat) -> CGRect {
        let imageRatio = imageSize.width / max(imageSize.height, 1)

        if imageRatio > targetRatio {
            let width = imageSize.height * targetRatio
            return CGRect(x: (imageSize.width - width) / 2, y: 0, width: width, height: imageSize.height)
        } else {
            let height = imageSize.width / targetRatio
            return CGRect(x: 0, y: (imageSize.height - height) / 2, width: imageSize.width, height: height)
        }
    }

    private func denormalize(_ rect: CGRect, imageSize: CGSize) -> CGRect {
        CGRect(
            x: rect.minX * imageSize.width,
            y: (1 - rect.maxY) * imageSize.height,
            width: rect.width * imageSize.width,
            height: rect.height * imageSize.height
        )
    }
}
