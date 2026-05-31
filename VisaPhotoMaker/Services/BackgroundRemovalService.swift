import CoreImage
import CoreImage.CIFilterBuiltins
import SwiftUI
import UIKit
import Vision

enum BackgroundRemovalError: Error {
    case missingCGImage
    case missingMask
    case renderFailed
}

@MainActor
struct BackgroundRemovalService {
    private let context = CIContext()

    func extractForeground(in image: UIImage) async throws -> UIImage {
        guard let cgImage = image.normalized().cgImage else {
            throw BackgroundRemovalError.missingCGImage
        }

        let input = CIImage(cgImage: cgImage)
        let transparentBackground = CIImage(color: CIColor(red: 0, green: 0, blue: 0, alpha: 0))
            .cropped(to: input.extent)
        let mask = try await generateBestMask(for: cgImage, targetExtent: input.extent)
        let blend = CIFilter.blendWithMask()
        blend.inputImage = input
        blend.backgroundImage = transparentBackground
        blend.maskImage = mask

        guard let output = blend.outputImage,
              let outputCG = context.createCGImage(output, from: input.extent) else {
            throw BackgroundRemovalError.renderFailed
        }

        return UIImage(cgImage: outputCG, scale: image.scale, orientation: .up)
    }

    func replaceBackground(in image: UIImage, with background: PhotoBackground) async throws -> UIImage {
        guard let cgImage = image.normalized().cgImage else {
            throw BackgroundRemovalError.missingCGImage
        }

        let input = CIImage(cgImage: cgImage)
        let backgroundImage = CIImage(color: CIColor(color: UIColor(background.color)))
            .cropped(to: input.extent)
        let mask = try await generateBestMask(for: cgImage, targetExtent: input.extent)
        let blend = CIFilter.blendWithMask()
        blend.inputImage = input
        blend.backgroundImage = backgroundImage
        blend.maskImage = mask

        guard let output = blend.outputImage,
              let outputCG = context.createCGImage(output, from: input.extent) else {
            throw BackgroundRemovalError.renderFailed
        }

        return UIImage(cgImage: outputCG, scale: image.scale, orientation: .up)
    }

    private func generateBestMask(for cgImage: CGImage, targetExtent: CGRect) async throws -> CIImage {
        async let foregroundMask = try? generateForegroundInstanceMask(for: cgImage)
        async let personMask = try? generatePersonSegmentationMask(for: cgImage)

        let foreground = await foregroundMask
        let person = await personMask

        if let foreground, let person {
            let combined = combinedMask(
                resizedMask(foreground, targetExtent: targetExtent),
                resizedMask(person, targetExtent: targetExtent),
                extent: targetExtent
            )
            return refinedMask(combined, extent: targetExtent)
        }

        if let foreground {
            return refinedMask(resizedMask(foreground, targetExtent: targetExtent), extent: targetExtent)
        }

        if let person {
            return refinedMask(resizedMask(person, targetExtent: targetExtent), extent: targetExtent)
        }

        throw BackgroundRemovalError.missingMask
    }

    private nonisolated func generateForegroundInstanceMask(for cgImage: CGImage) async throws -> CIImage {
        try await Task.detached(priority: .userInitiated) {
            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up)
            let request = VNGenerateForegroundInstanceMaskRequest()
            try handler.perform([request])

            guard let observation = request.results?.first,
                  !observation.allInstances.isEmpty else {
                throw BackgroundRemovalError.missingMask
            }

            let scaledMask = try observation.generateScaledMaskForImage(
                forInstances: observation.allInstances,
                from: handler
            )
            return CIImage(cvPixelBuffer: scaledMask)
        }.value
    }

    private nonisolated func generatePersonSegmentationMask(for cgImage: CGImage) async throws -> CIImage {
        try await Task.detached(priority: .userInitiated) {
            let request = VNGeneratePersonSegmentationRequest()
            request.qualityLevel = .accurate
            request.outputPixelFormat = kCVPixelFormatType_OneComponent8

            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up)
            try handler.perform([request])

            guard let buffer = request.results?.first?.pixelBuffer else {
                throw BackgroundRemovalError.missingMask
            }

            return CIImage(cvPixelBuffer: buffer)
        }.value
    }

    private func maskTransform(maskExtent: CGRect, targetExtent: CGRect) -> CGAffineTransform {
        let scaleX = targetExtent.width / max(maskExtent.width, 1)
        let scaleY = targetExtent.height / max(maskExtent.height, 1)
        return CGAffineTransform(scaleX: scaleX, y: scaleY)
    }

    private func resizedMask(_ mask: CIImage, targetExtent: CGRect) -> CIImage {
        guard mask.extent.size != targetExtent.size else {
            return mask.cropped(to: targetExtent)
        }
        return mask
            .transformed(by: maskTransform(maskExtent: mask.extent, targetExtent: targetExtent))
            .cropped(to: targetExtent)
    }

    private func combinedMask(_ foreground: CIImage, _ person: CIImage, extent: CGRect) -> CIImage {
        let foregroundPrepared = preparedMask(foreground, extent: extent)
        let personPrepared = preparedMask(person, extent: extent)

        if let maximum = CIFilter(name: "CIMaximumCompositing") {
            maximum.setValue(foregroundPrepared, forKey: kCIInputImageKey)
            maximum.setValue(personPrepared, forKey: kCIInputBackgroundImageKey)
            return (maximum.outputImage ?? foregroundPrepared).cropped(to: extent)
        }

        return foregroundPrepared.cropped(to: extent)
    }

    private func preparedMask(_ mask: CIImage, extent: CGRect) -> CIImage {
        let controls = CIFilter.colorControls()
        controls.inputImage = mask.cropped(to: extent)
        controls.saturation = 0
        controls.contrast = 1.08
        controls.brightness = 0
        return (controls.outputImage ?? mask).cropped(to: extent)
    }

    private func refinedMask(_ mask: CIImage, extent: CGRect) -> CIImage {
        let clamped = preparedMask(mask, extent: extent).clampedToExtent()

        let closeMaximum = CIFilter.morphologyMaximum()
        closeMaximum.inputImage = clamped
        closeMaximum.radius = 0.55

        let closeMinimum = CIFilter.morphologyMinimum()
        closeMinimum.inputImage = closeMaximum.outputImage ?? clamped
        closeMinimum.radius = 0.50

        let closed = (closeMinimum.outputImage ?? closeMaximum.outputImage ?? clamped).cropped(to: extent)

        let solidCore = CIFilter.morphologyMinimum()
        solidCore.inputImage = closed.clampedToExtent()
        solidCore.radius = 0.22

        let blur = CIFilter.gaussianBlur()
        blur.inputImage = closed.clampedToExtent()
        blur.radius = 0.72

        let gamma = CIFilter.gammaAdjust()
        gamma.inputImage = blur.outputImage?.cropped(to: extent) ?? closed
        gamma.power = 0.86

        let controls = CIFilter.colorControls()
        controls.inputImage = gamma.outputImage?.cropped(to: extent) ?? blur.outputImage?.cropped(to: extent) ?? closed
        controls.contrast = 1.22
        controls.brightness = -0.015

        let featheredEdge = (controls.outputImage ?? closed).cropped(to: extent)
        let core = (solidCore.outputImage ?? closed).cropped(to: extent)

        if let maximum = CIFilter(name: "CIMaximumCompositing") {
            maximum.setValue(core, forKey: kCIInputImageKey)
            maximum.setValue(featheredEdge, forKey: kCIInputBackgroundImageKey)
            return (maximum.outputImage ?? featheredEdge).cropped(to: extent)
        }

        return featheredEdge.cropped(to: extent)
    }
}

extension UIImage {
    func normalized() -> UIImage {
        guard imageOrientation != .up else { return self }
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }

    func preparedForIDPhotoProcessing(maxPixelLength: CGFloat = 2600) -> UIImage {
        let normalizedImage = normalized()
        let pixelWidth = normalizedImage.size.width * normalizedImage.scale
        let pixelHeight = normalizedImage.size.height * normalizedImage.scale
        let longestPixelSide = max(pixelWidth, pixelHeight)
        guard longestPixelSide > maxPixelLength else { return normalizedImage }

        let ratio = maxPixelLength / longestPixelSide
        let targetPixelSize = CGSize(width: pixelWidth * ratio, height: pixelHeight * ratio)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: targetPixelSize, format: format)
        return renderer.image { _ in
            normalizedImage.draw(in: CGRect(origin: .zero, size: targetPixelSize))
        }
    }
}
