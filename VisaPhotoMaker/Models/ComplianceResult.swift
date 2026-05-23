import Foundation
import CoreGraphics

enum ComplianceSeverity {
    case pass
    case warning
    case fail
}

enum ComplianceIssueKind {
    case format
    case resolution
    case background
    case singlePerson
    case headSize
    case faceCentered
    case headTilt
    case eyesVisible
    case eyeHeight
    case topMargin
    case expression
    case faceDetection
    case lighting
    case sharpness
    case backgroundShadows
    case fileSize
}

struct ComplianceCheck: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let severity: ComplianceSeverity
    let action: String?
    let kind: ComplianceIssueKind?

    init(title: String, message: String, severity: ComplianceSeverity, action: String? = nil, kind: ComplianceIssueKind? = nil) {
        self.title = title
        self.message = message
        self.severity = severity
        self.action = action
        self.kind = kind
    }
}

struct ComplianceResult {
    let checks: [ComplianceCheck]

    var score: Int {
        guard !checks.isEmpty else { return 0 }
        let failPenalty = checks.filter { $0.severity == .fail }.count * 18
        let warningPenalty = checks.filter { $0.severity == .warning }.count * 7
        return max(0, 100 - failPenalty - warningPenalty)
    }

    var isReadyForExport: Bool {
        !checks.contains { $0.severity == .fail }
    }

    var isFullyPassed: Bool {
        !checks.contains { $0.severity != .pass }
    }

    var blockingChecks: [ComplianceCheck] {
        checks.filter { $0.severity == .fail }
    }

    var warnings: [ComplianceCheck] {
        checks.filter { $0.severity == .warning }
    }
}

struct FaceAnalysis: Equatable {
    let faceRect: CGRect
    let headHeightRatio: Double
    let centerOffsetRatio: Double
    let signedCenterOffsetRatio: Double
    let rollDegrees: Double
    let quality: Double
    let eyeHeightRatio: Double?
    let topMarginRatio: Double
    let bottomMarginRatio: Double
    let visualTopMarginRatio: Double?
    let visualBottomMarginRatio: Double?
    let visualHeadHeightRatio: Double?
    let visualSignedCenterOffsetRatio: Double?
    let visualHeadRect: CGRect?
    let hasBothEyes: Bool
    let hasMouth: Bool

    static let strictCenterPassThreshold = 0.018
    static let centerWarningThreshold = 0.040
    static let centerAgreementThreshold = 0.025
    static let strictVerticalCenterPassThreshold = 0.035
    static let verticalCenterWarningThreshold = 0.060

    var effectiveSignedCenterOffsetRatio: Double {
        guard let visualSignedCenterOffsetRatio else {
            return signedCenterOffsetRatio
        }
        return abs(visualSignedCenterOffsetRatio) >= abs(signedCenterOffsetRatio)
            ? visualSignedCenterOffsetRatio
            : signedCenterOffsetRatio
    }

    var effectiveCenterOffsetRatio: Double {
        max(abs(signedCenterOffsetRatio), abs(visualSignedCenterOffsetRatio ?? signedCenterOffsetRatio))
    }

    var visualAndFaceCentersAgree: Bool {
        guard let visualSignedCenterOffsetRatio else { return true }
        return abs(visualSignedCenterOffsetRatio - signedCenterOffsetRatio) <= Self.centerAgreementThreshold
    }

    var isCentered: Bool {
        effectiveCenterOffsetRatio <= Self.strictCenterPassThreshold && visualAndFaceCentersAgree
    }

    var effectiveTopMarginRatio: Double {
        visualTopMarginRatio ?? topMarginRatio
    }

    var effectiveBottomMarginRatio: Double {
        visualBottomMarginRatio ?? bottomMarginRatio
    }

    var effectiveHeadHeightRatio: Double {
        visualHeadHeightRatio ?? headHeightRatio
    }

    var effectiveVerticalCenterOffsetRatio: Double {
        effectiveTopMarginRatio + effectiveHeadHeightRatio / 2 - 0.51
    }

    var isVerticallyCenteredInGuide: Bool {
        abs(effectiveVerticalCenterOffsetRatio) <= Self.strictVerticalCenterPassThreshold
    }
}

struct ImageQualityAnalysis: Equatable {
    let brightness: Double
    let contrast: Double
    let sharpness: Double
    let backgroundEvenness: Double

    var isWellLit: Bool {
        brightness > 0.30 && brightness < 0.82
    }

    var isTooDark: Bool {
        brightness <= 0.30
    }

    var isTooBright: Bool {
        brightness >= 0.82
    }

    var isSharp: Bool {
        sharpness > 0.035
    }

    var hasEvenBackground: Bool {
        backgroundEvenness < 0.18
    }
}

struct PhotoAnalysis: Equatable {
    let face: FaceAnalysis?
    let quality: ImageQualityAnalysis?
    let faceCount: Int
}

struct PhotoEditState: Equatable {
    var scale: CGFloat = 1
    var rotationDegrees: Double = 0
    var offset: CGSize = .zero
    var brightness: Double = 0
    var contrast: Double = 1
    var shadows: Double = 0
    var saturation: Double = 1
    var warmth: Double = 0
    var sharpness: Double = 0

    static let `default` = PhotoEditState()

    var hasImageAdjustments: Bool {
        abs(brightness) > 0.001 ||
            abs(contrast - 1) > 0.001 ||
            abs(shadows) > 0.001 ||
            abs(saturation - 1) > 0.001 ||
            abs(warmth) > 0.001 ||
            sharpness > 0.001
    }
}

enum ExportFormat: String, CaseIterable, Identifiable {
    case jpg = "JPG"
    case heif = "HEIF"
    case png = "PNG"
    case pdf = "PDF"

    var id: String { rawValue }

    var supportsTargetKB: Bool {
        self == .jpg || self == .heif
    }
}

enum PrintLayout: String, CaseIterable, Identifiable {
    case digitalOnly = "Digital only"
    case threeByFour = "3 x 4 in"
    case fourByFour = "4 x 4 in"
    case fourBySix = "4 x 6 in"
    case fiveBySeven = "5 x 7 in"
    case a4 = "A4"
    case letter = "Letter"

    var id: String { rawValue }
}

enum PrintPackingMode: String, CaseIterable, Identifiable {
    case safe = "Safe"
    case compact = "Compact"

    var id: String { rawValue }
}
