import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

@MainActor
struct PhotoEnhancementService {
    private let context = CIContext()

    func repair(_ image: UIImage) -> UIImage {
        repair(image, intensity: .balanced)
    }

    func repair(_ image: UIImage, intensity: RepairIntensity) -> UIImage {
        guard let cgImage = image.normalized().cgImage else { return image }
        let input = CIImage(cgImage: cgImage)

        let controls = CIFilter.colorControls()
        controls.inputImage = input
        controls.brightness = Float(intensity.brightness)
        controls.contrast = Float(intensity.contrast)
        controls.saturation = Float(intensity.saturation)

        var output = controls.outputImage ?? input

        let exposure = CIFilter.exposureAdjust()
        exposure.inputImage = output
        exposure.ev = Float(intensity.exposure)
        output = exposure.outputImage ?? output

        let highlightShadow = CIFilter.highlightShadowAdjust()
        highlightShadow.inputImage = output
        highlightShadow.shadowAmount = Float(intensity.shadowLift)
        highlightShadow.highlightAmount = Float(intensity.highlightHold)
        output = highlightShadow.outputImage ?? output

        let sharpen = CIFilter.sharpenLuminance()
        sharpen.inputImage = output
        sharpen.sharpness = Float(intensity.sharpness)
        output = sharpen.outputImage ?? output

        let unsharp = CIFilter.unsharpMask()
        unsharp.inputImage = output
        unsharp.radius = Float(intensity.unsharpRadius)
        unsharp.intensity = Float(intensity.unsharpIntensity)
        output = unsharp.outputImage ?? output

        guard let outputCG = context.createCGImage(output, from: input.extent) else {
            return image
        }

        return UIImage(cgImage: outputCG, scale: image.scale, orientation: .up)
    }
}

enum RepairIntensity {
    case balanced
    case stronger

    var brightness: Double {
        switch self {
        case .balanced: return 0.025
        case .stronger: return 0.045
        }
    }

    var exposure: Double {
        switch self {
        case .balanced: return 0.025
        case .stronger: return 0.055
        }
    }

    var contrast: Double {
        switch self {
        case .balanced: return 1.06
        case .stronger: return 1.10
        }
    }

    var saturation: Double {
        switch self {
        case .balanced: return 1.05
        case .stronger: return 1.07
        }
    }

    var shadowLift: Double {
        switch self {
        case .balanced: return 0.16
        case .stronger: return 0.24
        }
    }

    var highlightHold: Double {
        switch self {
        case .balanced: return 0.92
        case .stronger: return 0.88
        }
    }

    var sharpness: Double {
        switch self {
        case .balanced: return 0.72
        case .stronger: return 1.05
        }
    }

    var unsharpRadius: Double {
        switch self {
        case .balanced: return 1.6
        case .stronger: return 2.0
        }
    }

    var unsharpIntensity: Double {
        switch self {
        case .balanced: return 0.36
        case .stronger: return 0.52
        }
    }
}
