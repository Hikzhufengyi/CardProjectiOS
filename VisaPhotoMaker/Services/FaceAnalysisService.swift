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
                let leftEye = landmarks?.leftEye?.normalizedPoints.first
                let rightEye = landmarks?.rightEye?.normalizedPoints.first
                let eyeHeightRatio = Self.eyeHeight(leftEye: leftEye, rightEye: rightEye, in: rect)
                let rollDegrees = Self.rollDegrees(observationRoll: observation.roll?.doubleValue, leftEye: leftEye, rightEye: rightEye, in: rect)
                let visualMetrics = Self.visualHeadMetrics(for: cgImage, faceRect: rect)
                let topMarginRatio = visualMetrics?.topMarginRatio ?? (1 - rect.maxY)
                let bottomMarginRatio = visualMetrics?.bottomMarginRatio ?? rect.minY
                let visualCenterOffset = visualMetrics?.signedCenterOffsetRatio

                return FaceAnalysis(
                    faceRect: rect,
                    headHeightRatio: visualMetrics?.headHeightRatio ?? Double(rect.height),
                    centerOffsetRatio: abs(visualCenterOffset ?? Double(rect.midX - 0.5)),
                    signedCenterOffsetRatio: Double(rect.midX - 0.5),
                    rollDegrees: rollDegrees,
                    quality: min(1, max(0, Double(rect.width * rect.height) * 4)),
                    eyeHeightRatio: eyeHeightRatio,
                    topMarginRatio: Double(topMarginRatio),
                    bottomMarginRatio: Double(bottomMarginRatio),
                    visualTopMarginRatio: visualMetrics?.topMarginRatio,
                    visualBottomMarginRatio: visualMetrics?.bottomMarginRatio,
                    visualHeadHeightRatio: visualMetrics?.headHeightRatio,
                    visualSignedCenterOffsetRatio: visualCenterOffset,
                    visualHeadRect: visualMetrics?.headRect,
                    hasBothEyes: landmarks?.leftEye != nil && landmarks?.rightEye != nil,
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

    private static func rollDegrees(observationRoll: Double?, leftEye: CGPoint?, rightEye: CGPoint?, in faceRect: CGRect) -> Double {
        let visionDegrees = (observationRoll ?? 0) * 180 / .pi
        guard let leftEye, let rightEye else {
            return visionDegrees
        }

        let dx = Double((rightEye.x - leftEye.x) * faceRect.width)
        let dy = Double((rightEye.y - leftEye.y) * faceRect.height)
        guard abs(dx) > 0.0001 else { return visionDegrees }

        let eyeLineDegrees = atan2(dy, dx) * 180 / .pi
        return abs(eyeLineDegrees) >= abs(visionDegrees) ? eyeLineDegrees : visionDegrees
    }

    private static func visualHeadMetrics(for image: CGImage, faceRect: CGRect) -> (topMarginRatio: Double, bottomMarginRatio: Double, headHeightRatio: Double, signedCenterOffsetRatio: Double, headRect: CGRect)? {
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
        var fullMinSubjectX = maxX
        var fullMaxSubjectX = minX
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
                if let rowMinX, let rowMaxX {
                    fullMinSubjectX = min(fullMinSubjectX, rowMinX)
                    fullMaxSubjectX = max(fullMaxSubjectX, rowMaxX)
                }
            }
            if normalizedY <= 0.74, Double(hits) / Double(maxX - minX + 1) > 0.10, let rowMinX, let rowMaxX {
                minSubjectX = min(minSubjectX, rowMinX)
                maxSubjectX = max(maxSubjectX, rowMaxX)
                subjectRows += 1
            }
        }
        guard let topY else { return nil }

        let chinYFromTop = Int((1 - faceRect.minY) * Double(height))
        let estimatedChinY = min(maxYFromTop, max(bottomY ?? chinYFromTop, chinYFromTop, topY + 1))
        let topMarginRatio = Double(topY) / Double(height)
        let bottomMarginRatio = Double(height - estimatedChinY) / Double(height)
        let headHeightRatio = Double(estimatedChinY - topY) / Double(height)
        let visualMidX: Double
        if subjectRows >= 3, minSubjectX < maxSubjectX {
            visualMidX = (Double(minSubjectX) + Double(maxSubjectX)) / 2 / Double(width)
        } else {
            visualMidX = Double(faceRect.midX)
        }
        let headMinX = fullMinSubjectX < fullMaxSubjectX ? fullMinSubjectX : minSubjectX
        let headMaxX = fullMinSubjectX < fullMaxSubjectX ? fullMaxSubjectX : maxSubjectX
        let headRect = CGRect(
            x: Double(headMinX) / Double(width),
            y: 1 - Double(estimatedChinY) / Double(height),
            width: Double(max(headMaxX - headMinX, 1)) / Double(width),
            height: Double(estimatedChinY - topY) / Double(height)
        )
        return (topMarginRatio, bottomMarginRatio, headHeightRatio, visualMidX - 0.5, headRect)
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
}
