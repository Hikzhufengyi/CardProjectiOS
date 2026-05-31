import UIKit
import Vision

enum FaceAnalysisError: Error {
    case missingCGImage
}

struct FaceAnalysisService {
    func analyze(_ image: UIImage) async throws -> PhotoAnalysis {
        guard let cgImage = image.normalized().cgImage else {
            throw FaceAnalysisError.missingCGImage
        }

        return try await Task.detached(priority: .userInitiated) {
            let request = VNDetectFaceLandmarksRequest()
            request.revision = VNDetectFaceLandmarksRequestRevision3
            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up)
            try handler.perform([request])

            let faces = request.results ?? []
            let face = faces.max(by: { $0.boundingBox.width * $0.boundingBox.height < $1.boundingBox.width * $1.boundingBox.height })
            let faceAnalysis = face.map { observation in
                let rect = observation.boundingBox
                let landmarks = observation.landmarks
                let leftEye = Self.featureCenter(landmarks?.leftEye?.normalizedPoints)
                let rightEye = Self.featureCenter(landmarks?.rightEye?.normalizedPoints)
                let noseCenter = Self.featureCenter(landmarks?.nose?.normalizedPoints)
                    ?? Self.featureCenter(landmarks?.noseCrest?.normalizedPoints)
                let mouthCenter = Self.featureCenter(landmarks?.outerLips?.normalizedPoints)
                    ?? Self.featureCenter(landmarks?.innerLips?.normalizedPoints)
                let eyeHeightRatio = Self.eyeHeight(leftEye: leftEye, rightEye: rightEye, in: rect)
                let eyeCenterXRatio = Self.eyeCenterX(leftEye: leftEye, rightEye: rightEye, in: rect)
                let noseCenterXRatio = Self.featureX(noseCenter, in: rect)
                let eyeLineRollDegrees = Self.eyeLineRollDegrees(leftEye: leftEye, rightEye: rightEye, in: rect)
                let rollDegrees = Self.rollDegrees(
                    observationRoll: observation.roll?.doubleValue,
                    eyeLineRollDegrees: eyeLineRollDegrees
                )
                let visualMetrics = Self.visualHeadMetrics(
                    for: cgImage,
                    faceRect: rect,
                    faceContour: landmarks?.faceContour?.normalizedPoints,
                    leftEye: leftEye,
                    rightEye: rightEye,
                    mouthCenter: mouthCenter
                )
                let topMarginRatio = visualMetrics?.topMarginRatio ?? (1 - rect.maxY)
                let bottomMarginRatio = visualMetrics?.bottomMarginRatio ?? rect.minY
                let visualCenterOffset = visualMetrics?.signedCenterOffsetRatio
                let eyesOpenScore = Self.eyesOpenScore(
                    leftEye: landmarks?.leftEye?.normalizedPoints,
                    rightEye: landmarks?.rightEye?.normalizedPoints
                )
                let glassesSignals = Self.glassesSignals(
                    for: cgImage,
                    faceRect: rect,
                    leftEye: leftEye,
                    rightEye: rightEye
                )
                let headCoveringRisk = Self.hasHeadCoveringRisk(
                    for: cgImage,
                    faceRect: rect,
                    hairTopRatio: visualMetrics?.topMarginRatio
                )

                return FaceAnalysis(
                    faceRect: rect,
                    headHeightRatio: visualMetrics?.headHeightRatio ?? Double(rect.height),
                    centerOffsetRatio: abs(visualCenterOffset ?? Double(rect.midX - 0.5)),
                    signedCenterOffsetRatio: Double(rect.midX - 0.5),
                    rollDegrees: rollDegrees,
                    eyeLineRollDegrees: eyeLineRollDegrees,
                    quality: min(1, max(0, Double(rect.width * rect.height) * 4)),
                    eyeHeightRatio: eyeHeightRatio,
                    eyeCenterXRatio: eyeCenterXRatio,
                    noseCenterXRatio: noseCenterXRatio,
                    topMarginRatio: Double(topMarginRatio),
                    bottomMarginRatio: Double(bottomMarginRatio),
                    visualTopMarginRatio: visualMetrics?.topMarginRatio,
                    visualBottomMarginRatio: visualMetrics?.bottomMarginRatio,
                    visualHeadHeightRatio: visualMetrics?.headHeightRatio,
                    visualSignedCenterOffsetRatio: visualCenterOffset,
                    visualHeadRect: visualMetrics?.headRect,
                    hasBothEyes: landmarks?.leftEye != nil && landmarks?.rightEye != nil,
                    eyesOpenScore: eyesOpenScore,
                    hasGlassesRisk: glassesSignals.hasGlassesRisk,
                    hasGlareRisk: glassesSignals.hasGlareRisk,
                    hasHeadCoveringRisk: headCoveringRisk,
                    hasMouth: landmarks?.outerLips != nil || landmarks?.innerLips != nil
                )
            }

            return PhotoAnalysis(face: faceAnalysis, quality: Self.qualityAnalysis(for: cgImage, excluding: faceAnalysis?.faceRect), faceCount: faces.count)
        }.value
    }

    private static func eyeHeight(leftEye: CGPoint?, rightEye: CGPoint?, in faceRect: CGRect) -> Double? {
        guard let leftEye, let rightEye else { return nil }
        let localY = (leftEye.y + rightEye.y) / 2
        return Double(faceRect.minY + localY * faceRect.height)
    }

    private static func eyeCenterX(leftEye: CGPoint?, rightEye: CGPoint?, in faceRect: CGRect) -> Double? {
        guard let leftEye, let rightEye else { return nil }
        let localX = (leftEye.x + rightEye.x) / 2
        return Double(faceRect.minX + localX * faceRect.width)
    }

    private static func featureX(_ point: CGPoint?, in faceRect: CGRect) -> Double? {
        guard let point else { return nil }
        return Double(faceRect.minX + point.x * faceRect.width)
    }

    private static func featureCenter(_ points: [CGPoint]?) -> CGPoint? {
        guard let points, !points.isEmpty else { return nil }
        let sum = points.reduce(CGPoint.zero) { partial, point in
            CGPoint(x: partial.x + point.x, y: partial.y + point.y)
        }
        let count = CGFloat(points.count)
        return CGPoint(x: sum.x / count, y: sum.y / count)
    }

    private static func eyesOpenScore(leftEye: [CGPoint]?, rightEye: [CGPoint]?) -> Double? {
        let left = eyeOpenRatio(points: leftEye)
        let right = eyeOpenRatio(points: rightEye)
        switch (left, right) {
        case let (l?, r?):
            return (l + r) / 2
        case let (l?, nil):
            return l
        case let (nil, r?):
            return r
        default:
            return nil
        }
    }

    private static func eyeOpenRatio(points: [CGPoint]?) -> Double? {
        guard let points, points.count >= 4 else { return nil }
        let xs = points.map(\.x)
        let ys = points.map(\.y)
        let width = (xs.max() ?? 0) - (xs.min() ?? 0)
        let height = (ys.max() ?? 0) - (ys.min() ?? 0)
        guard width > 0.0001 else { return nil }
        return Double(height / width)
    }

    private static func eyeLineRollDegrees(leftEye: CGPoint?, rightEye: CGPoint?, in faceRect: CGRect) -> Double? {
        guard let leftEye, let rightEye else { return nil }
        let dx = Double((rightEye.x - leftEye.x) * faceRect.width)
        let dy = Double((rightEye.y - leftEye.y) * faceRect.height)
        guard abs(dx) > 0.0001 else { return nil }
        return atan2(dy, dx) * 180 / .pi
    }

    private static func rollDegrees(observationRoll: Double?, eyeLineRollDegrees: Double?) -> Double {
        let visionDegrees = (observationRoll ?? 0) * 180 / .pi
        guard let eyeLineRollDegrees else {
            return visionDegrees
        }
        return abs(eyeLineRollDegrees) >= abs(visionDegrees) ? eyeLineRollDegrees : visionDegrees
    }

    private static func visualHeadMetrics(
        for image: CGImage,
        faceRect: CGRect,
        faceContour: [CGPoint]?,
        leftEye: CGPoint?,
        rightEye: CGPoint?,
        mouthCenter: CGPoint?
    ) -> (topMarginRatio: Double, bottomMarginRatio: Double, headHeightRatio: Double, signedCenterOffsetRatio: Double, headRect: CGRect)? {
        let width = 160
        let height = 160
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var pixels = [UInt8](repeating: 0, count: width * height * bytesPerPixel)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
        context?.interpolationQuality = .low
        context?.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        let minX = max(Int((faceRect.minX - faceRect.width * 0.45) * Double(width)), 0)
        let maxX = min(Int((faceRect.maxX + faceRect.width * 0.45) * Double(width)), width - 1)
        let minYFromTop = max(Int((1 - faceRect.maxY - faceRect.height * 0.55) * Double(height)), 0)
        let maxYFromTop = min(Int((1 - faceRect.minY + faceRect.height * 0.35) * Double(height)), height - 1)
        guard minX < maxX, minYFromTop < maxYFromTop else { return nil }

        var backgroundSamples: [(Double, Double, Double)] = []
        backgroundSamples.reserveCapacity(width * 2 + height * 2)
        for x in 0..<width {
            backgroundSamples.append(rgb(atX: x, y: 0, pixels: pixels, bytesPerPixel: bytesPerPixel, bytesPerRow: bytesPerRow))
            backgroundSamples.append(rgb(atX: x, y: height - 1, pixels: pixels, bytesPerPixel: bytesPerPixel, bytesPerRow: bytesPerRow))
        }
        for y in 0..<height {
            backgroundSamples.append(rgb(atX: 0, y: y, pixels: pixels, bytesPerPixel: bytesPerPixel, bytesPerRow: bytesPerRow))
            backgroundSamples.append(rgb(atX: width - 1, y: y, pixels: pixels, bytesPerPixel: bytesPerPixel, bytesPerRow: bytesPerRow))
        }
        let background = averageRGB(backgroundSamples)

        var topY: Int?
        var bottomY: Int?
        var minSubjectX = maxX
        var maxSubjectX = minX
        var subjectRows = 0
        for y in minYFromTop...maxYFromTop {
            let normalizedY = Double(y - minYFromTop) / Double(max(maxYFromTop - minYFromTop, 1))
            var hits = 0
            var rowMinX: Int?
            var rowMaxX: Int?
            for x in minX...maxX {
                let color = rgb(atX: x, y: y, pixels: pixels, bytesPerPixel: bytesPerPixel, bytesPerRow: bytesPerRow)
                if colorDistance(color, background) > 0.20 && luminance(color) < 0.92 {
                    hits += 1
                    rowMinX = min(rowMinX ?? x, x)
                    rowMaxX = max(rowMaxX ?? x, x)
                }
            }
            if topY == nil, Double(hits) / Double(maxX - minX + 1) > 0.08 {
                topY = y
            }
            if Double(hits) / Double(maxX - minX + 1) > 0.08 {
                bottomY = y
            }
            if normalizedY <= 0.74, Double(hits) / Double(maxX - minX + 1) > 0.10, let rowMinX, let rowMaxX {
                minSubjectX = min(minSubjectX, rowMinX)
                maxSubjectX = max(maxSubjectX, rowMaxX)
                subjectRows += 1
            }
        }
        guard let topY else { return nil }

        let faceContourChinYFromTop = faceContourChinYFromTop(
            faceContour: faceContour,
            faceRect: faceRect,
            imageHeight: height
        )
        let geometricChinYFromTop = geometricChinYFromTop(
            faceRect: faceRect,
            leftEye: leftEye,
            rightEye: rightEye,
            mouthCenter: mouthCenter,
            imageHeight: height
        )
        let visionChinYFromTop = Int((1 - faceRect.minY) * Double(height))
        let faceHeightPixels = max(Int(faceRect.height * Double(height)), 1)
        let fallbackChinPadding = max(Int(Double(faceHeightPixels) * 0.075), 2)
        let minimumChinY = max(visionChinYFromTop - max(Int(Double(faceHeightPixels) * 0.025), 1), topY + 1)
        let subjectChinY = bottomY.map {
            min($0, visionChinYFromTop + max(Int(Double(faceHeightPixels) * 0.12), 3))
        }
        let contourChinIsUsable = faceContourChinYFromTop.map {
            $0 >= visionChinYFromTop - Int(Double(faceHeightPixels) * 0.08)
        } ?? false
        let estimatedChinY = min(
            maxYFromTop,
            max(
                geometricChinYFromTop ?? 0,
                contourChinIsUsable ? (faceContourChinYFromTop ?? 0) : 0,
                subjectChinY ?? 0,
                visionChinYFromTop + fallbackChinPadding,
                minimumChinY
            )
        )
        let topMarginRatio = Double(topY) / Double(height)
        let bottomMarginRatio = Double(height - estimatedChinY) / Double(height)
        let headHeightRatio = Double(estimatedChinY - topY) / Double(height)
        let robustHeadBounds = robustSubjectBounds(
            topY: topY,
            estimatedChinY: estimatedChinY,
            minX: minX,
            maxX: maxX,
            imageWidth: width,
            faceRect: faceRect,
            background: background,
            pixels: pixels,
            bytesPerPixel: bytesPerPixel,
            bytesPerRow: bytesPerRow
        )
        let rawHeadMinX = robustHeadBounds?.minX ?? (subjectRows >= 3 ? minSubjectX : Int(faceRect.minX * Double(width)))
        let rawHeadMaxX = robustHeadBounds?.maxX ?? (subjectRows >= 3 ? maxSubjectX : Int(faceRect.maxX * Double(width)))
        let rawHeadMidX = (Double(rawHeadMinX) + Double(rawHeadMaxX)) / 2 / Double(width)
        let faceMidX = Double(faceRect.midX)
        let visualMidX = abs(rawHeadMidX - faceMidX) > 0.08
            ? faceMidX
            : faceMidX * 0.62 + rawHeadMidX * 0.38
        let rawHeadWidthRatio = Double(max(rawHeadMaxX - rawHeadMinX, 1)) / Double(width)
        let minHeadWidthRatio = Double(faceRect.width) * 1.04
        let maxHeadWidthRatio = min(headHeightRatio * 0.76, Double(faceRect.width) * 1.58)
        let headWidthRatio = clamp(rawHeadWidthRatio, min: minHeadWidthRatio, max: max(maxHeadWidthRatio, minHeadWidthRatio))
        let headMinXRatio = clamp(visualMidX - headWidthRatio / 2, min: 0, max: 1 - headWidthRatio)
        let headRect = CGRect(
            x: headMinXRatio,
            y: 1 - Double(estimatedChinY) / Double(height),
            width: headWidthRatio,
            height: Double(estimatedChinY - topY) / Double(height)
        )
        return (topMarginRatio, bottomMarginRatio, headHeightRatio, visualMidX - 0.5, headRect)
    }

    private static func faceContourChinYFromTop(faceContour: [CGPoint]?, faceRect: CGRect, imageHeight: Int) -> Int? {
        guard let faceContour, !faceContour.isEmpty else { return nil }
        let localYs = faceContour.map(\.y)
        guard let minLocalY = localYs.min(), let maxLocalY = localYs.max() else { return nil }

        let candidates = [
            faceRect.minY + minLocalY * faceRect.height,
            faceRect.minY + maxLocalY * faceRect.height,
            faceRect.minY + (1 - minLocalY) * faceRect.height,
            faceRect.minY + (1 - maxLocalY) * faceRect.height
        ]
        .map { Int((1 - $0) * Double(imageHeight)) }

        return candidates.max()
    }

    private static func geometricChinYFromTop(
        faceRect: CGRect,
        leftEye: CGPoint?,
        rightEye: CGPoint?,
        mouthCenter: CGPoint?,
        imageHeight: Int
    ) -> Int? {
        guard let mouthCenter else { return nil }
        let eyeCenter = switch (leftEye, rightEye) {
        case let (left?, right?):
            CGPoint(x: (left.x + right.x) / 2, y: (left.y + right.y) / 2)
        case let (left?, nil):
            left
        case let (nil, right?):
            right
        default:
            CGPoint(x: 0.5, y: 0.68)
        }

        let eyeYFromTop = yFromTop(point: eyeCenter, faceRect: faceRect, imageHeight: imageHeight)
        let mouthYFromTop = yFromTop(point: mouthCenter, faceRect: faceRect, imageHeight: imageHeight)
        let eyeToMouth = mouthYFromTop - eyeYFromTop
        guard eyeToMouth > Double(imageHeight) * 0.025 else { return nil }

        let estimated = mouthYFromTop + eyeToMouth * 0.72
        return Int(estimated.rounded())
    }

    private static func yFromTop(point: CGPoint, faceRect: CGRect, imageHeight: Int) -> Double {
        let normalizedY = faceRect.minY + point.y * faceRect.height
        return (1 - normalizedY) * Double(imageHeight)
    }

    private static func robustSubjectBounds(
        topY: Int,
        estimatedChinY: Int,
        minX: Int,
        maxX: Int,
        imageWidth: Int,
        faceRect: CGRect,
        background: (Double, Double, Double),
        pixels: [UInt8],
        bytesPerPixel: Int,
        bytesPerRow: Int
    ) -> (minX: Int, maxX: Int)? {
        let faceWidthPixels = max(Int(faceRect.width * Double(imageWidth)), 1)
        let maxReasonableWidth = max(Int(Double(faceWidthPixels) * 1.95), faceWidthPixels + 4)
        var rowBounds: [(minX: Int, maxX: Int, width: Int)] = []

        for y in topY...estimatedChinY {
            var hits = 0
            var rowMinX: Int?
            var rowMaxX: Int?
            for x in minX...maxX {
                let color = rgb(atX: x, y: y, pixels: pixels, bytesPerPixel: bytesPerPixel, bytesPerRow: bytesPerRow)
                if colorDistance(color, background) > 0.20 && luminance(color) < 0.92 {
                    hits += 1
                    rowMinX = min(rowMinX ?? x, x)
                    rowMaxX = max(rowMaxX ?? x, x)
                }
            }

            guard
                let rowMinX,
                let rowMaxX,
                Double(hits) / Double(maxX - minX + 1) > 0.08
            else { continue }

            let rowWidth = rowMaxX - rowMinX
            guard rowWidth <= maxReasonableWidth else { continue }
            rowBounds.append((rowMinX, rowMaxX, rowWidth))
        }

        guard rowBounds.count >= 3 else { return nil }
        rowBounds.sort { $0.width < $1.width }
        let trimmed = rowBounds.dropFirst(rowBounds.count / 5).dropLast(rowBounds.count / 5)
        let candidates = trimmed.isEmpty ? rowBounds[...] : trimmed[...]
        let minSubjectX = candidates.map(\.minX).min() ?? minX
        let maxSubjectX = candidates.map(\.maxX).max() ?? maxX
        return minSubjectX < maxSubjectX ? (minSubjectX, maxSubjectX) : nil
    }

    private static func clamp(_ value: Double, min minValue: Double, max maxValue: Double) -> Double {
        Swift.min(Swift.max(value, minValue), maxValue)
    }

    private static func hasHeadCoveringRisk(for image: CGImage, faceRect: CGRect, hairTopRatio: Double?) -> Bool {
        let width = 96
        let height = 96
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var pixels = [UInt8](repeating: 0, count: width * height * bytesPerPixel)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
        context?.interpolationQuality = .low
        context?.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        let sampleTop = max(Int((1 - faceRect.maxY - faceRect.height * 0.30) * Double(height)), 0)
        let sampleBottom = min(Int((1 - faceRect.maxY + faceRect.height * 0.10) * Double(height)), height - 1)
        let sampleLeft = max(Int((faceRect.minX + faceRect.width * 0.12) * Double(width)), 0)
        let sampleRight = min(Int((faceRect.maxX - faceRect.width * 0.12) * Double(width)), width - 1)
        guard sampleTop < sampleBottom, sampleLeft < sampleRight else { return false }

        var darkHits = 0
        var opaqueHits = 0
        let total = max((sampleBottom - sampleTop + 1) * (sampleRight - sampleLeft + 1), 1)

        for y in sampleTop...sampleBottom {
            for x in sampleLeft...sampleRight {
                let rgb = rgb(atX: x, y: y, pixels: pixels, bytesPerPixel: bytesPerPixel, bytesPerRow: bytesPerRow)
                let lum = luminance(rgb)
                if lum < 0.22 {
                    darkHits += 1
                }
                if colorDistance(rgb, (1, 1, 1)) > 0.18 {
                    opaqueHits += 1
                }
            }
        }

        let darkRatio = Double(darkHits) / Double(total)
        let opaqueRatio = Double(opaqueHits) / Double(total)
        let tooFlatTop = (hairTopRatio ?? 0.08) < 0.028
        return tooFlatTop && darkRatio > 0.48 && opaqueRatio > 0.78
    }

    private static func rgb(atX x: Int, y: Int, pixels: [UInt8], bytesPerPixel: Int, bytesPerRow: Int) -> (Double, Double, Double) {
        let index = y * bytesPerRow + x * bytesPerPixel
        return (
            Double(pixels[index]) / 255,
            Double(pixels[index + 1]) / 255,
            Double(pixels[index + 2]) / 255
        )
    }

    private static func averageRGB(_ values: [(Double, Double, Double)]) -> (Double, Double, Double) {
        guard !values.isEmpty else { return (1, 1, 1) }
        let sum = values.reduce((0.0, 0.0, 0.0)) { partial, value in
            (partial.0 + value.0, partial.1 + value.1, partial.2 + value.2)
        }
        let count = Double(values.count)
        return (sum.0 / count, sum.1 / count, sum.2 / count)
    }

    private static func colorDistance(_ lhs: (Double, Double, Double), _ rhs: (Double, Double, Double)) -> Double {
        sqrt(pow(lhs.0 - rhs.0, 2) + pow(lhs.1 - rhs.1, 2) + pow(lhs.2 - rhs.2, 2))
    }

    private static func luminance(_ rgb: (Double, Double, Double)) -> Double {
        0.2126 * rgb.0 + 0.7152 * rgb.1 + 0.0722 * rgb.2
    }

    private static func qualityAnalysis(for image: CGImage, excluding faceRect: CGRect?) -> ImageQualityAnalysis {
        let width = 40
        let height = 40
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var pixels = [UInt8](repeating: 0, count: width * height * bytesPerPixel)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
        context?.interpolationQuality = .low
        context?.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        var luminance = [Double]()
        luminance.reserveCapacity(width * height)
        for index in stride(from: 0, to: pixels.count, by: bytesPerPixel) {
            let r = Double(pixels[index]) / 255
            let g = Double(pixels[index + 1]) / 255
            let b = Double(pixels[index + 2]) / 255
            luminance.append(0.2126 * r + 0.7152 * g + 0.0722 * b)
        }

        let average = luminance.reduce(0, +) / Double(max(luminance.count, 1))
        let faceValues = faceSampleValues(luminance: luminance, width: width, height: height, faceRect: faceRect)
        let faceAverage = faceValues.reduce(0, +) / Double(max(faceValues.count, 1))
        let subjectBrightness = faceValues.isEmpty ? average : faceAverage
        let variance = luminance.reduce(0) { $0 + pow($1 - average, 2) } / Double(max(luminance.count, 1))
        let contrast = sqrt(variance)

        var edgeSum = 0.0
        for y in 1..<(height - 1) {
            for x in 1..<(width - 1) {
                let center = luminance[y * width + x]
                let laplacian = abs(4 * center - luminance[y * width + x - 1] - luminance[y * width + x + 1] - luminance[(y - 1) * width + x] - luminance[(y + 1) * width + x])
                edgeSum += laplacian
            }
        }
        let sharpness = edgeSum / Double(width * height)

        let backgroundValues = backgroundSampleValues(luminance: luminance, width: width, height: height, excluding: faceRect)
        let backgroundAverage = backgroundValues.reduce(0, +) / Double(max(backgroundValues.count, 1))
        let backgroundEvenness = sqrt(backgroundValues.reduce(0) { $0 + pow($1 - backgroundAverage, 2) } / Double(max(backgroundValues.count, 1)))

        return ImageQualityAnalysis(
            brightness: subjectBrightness,
            contrast: contrast,
            sharpness: sharpness,
            backgroundEvenness: backgroundEvenness
        )
    }

    private static func faceSampleValues(luminance: [Double], width: Int, height: Int, faceRect: CGRect?) -> [Double] {
        guard let faceRect else { return [] }
        let minX = max(Int((faceRect.minX + faceRect.width * 0.12) * Double(width)), 0)
        let maxX = min(Int((faceRect.maxX - faceRect.width * 0.12) * Double(width)), width - 1)
        let minY = max(Int((1 - faceRect.maxY + faceRect.height * 0.10) * Double(height)), 0)
        let maxY = min(Int((1 - faceRect.minY - faceRect.height * 0.18) * Double(height)), height - 1)
        guard minX < maxX, minY < maxY else { return [] }

        var values: [Double] = []
        values.reserveCapacity((maxX - minX + 1) * (maxY - minY + 1))
        for y in minY...maxY {
            for x in minX...maxX {
                values.append(luminance[y * width + x])
            }
        }
        return values
    }

    private static func backgroundSampleValues(luminance: [Double], width: Int, height: Int, excluding faceRect: CGRect?) -> [Double] {
        var values: [Double] = []
        values.reserveCapacity(width * height / 2)
        let expandedFaceRect = faceRect?.insetBy(dx: -0.10, dy: -0.16)
        for y in 0..<height {
            for x in 0..<width {
                let normalizedX = (Double(x) + 0.5) / Double(width)
                let normalizedYFromBottom = 1 - ((Double(y) + 0.5) / Double(height))
                let isNearBorder = x < 8 || x >= width - 8 || y < 8 || y >= height - 8
                let isCorner = (x < 13 || x >= width - 13) && (y < 13 || y >= height - 13)
                let insideFace = expandedFaceRect?.contains(CGPoint(x: normalizedX, y: normalizedYFromBottom)) ?? false
                guard (isNearBorder || isCorner), !insideFace else { continue }
                let value = luminance[y * width + x]
                if value > 0.72 {
                    values.append(value)
                }
            }
        }
        if values.count >= 24 {
            return values
        }

        var fallback: [Double] = []
        fallback.reserveCapacity(width * 2 + height * 2)
        for x in 0..<width {
            fallback.append(luminance[x])
            fallback.append(luminance[(height - 1) * width + x])
        }
        for y in 0..<height {
            fallback.append(luminance[y * width])
            fallback.append(luminance[y * width + width - 1])
        }
        return fallback
    }

    private static func glassesSignals(
        for image: CGImage,
        faceRect: CGRect,
        leftEye: CGPoint?,
        rightEye: CGPoint?
    ) -> (hasGlassesRisk: Bool, hasGlareRisk: Bool) {
        guard let leftEye, let rightEye else { return (false, false) }

        let width = 120
        let height = 120
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var pixels = [UInt8](repeating: 0, count: width * height * bytesPerPixel)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
        context?.interpolationQuality = .low
        context?.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        let eyeCenters = [leftEye, rightEye].map { eye -> CGPoint in
            CGPoint(
                x: (faceRect.minX + eye.x * faceRect.width) * Double(width),
                y: (1 - (faceRect.minY + eye.y * faceRect.height)) * Double(height)
            )
        }

        var glareHits = 0
        var totalSamples = 0
        var horizontalFrameLineScore = 0
        var verticalFrameLineScore = 0

        for center in eyeCenters {
            let minX = max(Int(center.x) - 12, 1)
            let maxX = min(Int(center.x) + 12, width - 2)
            let minY = max(Int(center.y) - 7, 1)
            let maxY = min(Int(center.y) + 7, height - 2)

            for y in minY...maxY {
                var rowDarkEdgeHits = 0
                for x in minX...maxX {
                    totalSamples += 1
                    let current = rgb(atX: x, y: y, pixels: pixels, bytesPerPixel: bytesPerPixel, bytesPerRow: bytesPerRow)
                    let lum = luminance(current)
                    let left = rgb(atX: x - 1, y: y, pixels: pixels, bytesPerPixel: bytesPerPixel, bytesPerRow: bytesPerRow)
                    let right = rgb(atX: x + 1, y: y, pixels: pixels, bytesPerPixel: bytesPerPixel, bytesPerRow: bytesPerRow)
                    let up = rgb(atX: x, y: y - 1, pixels: pixels, bytesPerPixel: bytesPerPixel, bytesPerRow: bytesPerRow)
                    let down = rgb(atX: x, y: y + 1, pixels: pixels, bytesPerPixel: bytesPerPixel, bytesPerRow: bytesPerRow)
                    let horizontalEdge = abs(luminance(left) - lum) + abs(luminance(right) - lum)
                    let verticalEdge = abs(luminance(up) - lum) + abs(luminance(down) - lum)
                    let isNearPupil = abs(Double(x) - Double(center.x)) < 5 && abs(Double(y) - Double(center.y)) < 4

                    if !isNearPupil, lum < 0.24, horizontalEdge > 0.42 {
                        rowDarkEdgeHits += 1
                    }
                    if !isNearPupil, lum < 0.24, verticalEdge > 0.42 {
                        verticalFrameLineScore += 1
                    }
                    if lum > 0.96 && colorDistance(current, (1, 1, 1)) < 0.08 {
                        glareHits += 1
                    }
                }
                if rowDarkEdgeHits >= 9 {
                    horizontalFrameLineScore += 1
                }
            }
        }

        guard totalSamples > 0 else { return (false, false) }
        let glareRatio = Double(glareHits) / Double(totalSamples)
        let hasStrongGlare = glareRatio > 0.10
        let hasLikelyFrame = horizontalFrameLineScore >= 6 && verticalFrameLineScore >= 26
        return (hasLikelyFrame, hasStrongGlare)
    }
}
