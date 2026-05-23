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

        let mask = try await generateMask(for: cgImage)
        let input = CIImage(cgImage: cgImage)
        let transparentBackground = CIImage(color: CIColor(red: 0, green: 0, blue: 0, alpha: 0))
            .cropped(to: input.extent)

        let scaledMask = refinedMask(mask.transformed(by: maskTransform(maskExtent: mask.extent, targetExtent: input.extent)), extent: input.extent)
        let blend = CIFilter.blendWithMask()
        blend.inputImage = input
        blend.backgroundImage = transparentBackground
        blend.maskImage = scaledMask

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

        let mask = try await generateMask(for: cgImage)
        let input = CIImage(cgImage: cgImage)
        let backgroundImage = CIImage(color: CIColor(color: UIColor(background.color)))
            .cropped(to: input.extent)

        let scaledMask = refinedMask(mask.transformed(by: maskTransform(maskExtent: mask.extent, targetExtent: input.extent)), extent: input.extent)
        let blend = CIFilter.blendWithMask()
        blend.inputImage = input
        blend.backgroundImage = backgroundImage
        blend.maskImage = scaledMask

        guard let output = blend.outputImage,
              let outputCG = context.createCGImage(output, from: input.extent) else {
            throw BackgroundRemovalError.renderFailed
        }

        return UIImage(cgImage: outputCG, scale: image.scale, orientation: .up)
    }

    private nonisolated func generateMask(for cgImage: CGImage) async throws -> CIImage {
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

    private func refinedMask(_ mask: CIImage, extent: CGRect) -> CIImage {
        let clamped = mask.clampedToExtent()

        let maximum = CIFilter.morphologyMaximum()
        maximum.inputImage = clamped
        maximum.radius = 1.2

        let blur = CIFilter.gaussianBlur()
        blur.inputImage = maximum.outputImage ?? clamped
        blur.radius = 1.1

        let controls = CIFilter.colorControls()
        controls.inputImage = blur.outputImage?.cropped(to: extent) ?? mask
        controls.contrast = 1.18
        controls.brightness = 0.015

        return (controls.outputImage ?? mask).cropped(to: extent)
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
