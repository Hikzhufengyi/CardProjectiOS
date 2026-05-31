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
    case eyesOpen
    case glasses
    case eyeHeight
    case topMargin
    case bottomMargin
    case headGuideAlignment
    case headCover
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
    let eyeLineRollDegrees: Double?
    let quality: Double
    let eyeHeightRatio: Double?
    let eyeCenterXRatio: Double?
    let noseCenterXRatio: Double?
    let topMarginRatio: Double
    let bottomMarginRatio: Double
    let visualTopMarginRatio: Double?
    let visualBottomMarginRatio: Double?
    let visualHeadHeightRatio: Double?
    let visualSignedCenterOffsetRatio: Double?
    let visualHeadRect: CGRect?
    let hasBothEyes: Bool
    let eyesOpenScore: Double?
    let hasGlassesRisk: Bool
    let hasGlareRisk: Bool
    let hasHeadCoveringRisk: Bool
    let hasMouth: Bool

    static let strictCenterPassThreshold = 0.050
    static let centerWarningThreshold = 0.085
    static let centerAgreementThreshold = 0.075
    static let strictVerticalCenterPassThreshold = 0.040
    static let verticalCenterWarningThreshold = 0.072

    var effectiveSignedCenterOffsetRatio: Double {
        if let facialCenterlineOffsetRatio {
            guard let visualSignedCenterOffsetRatio else {
                return facialCenterlineOffsetRatio
            }
            if abs(visualSignedCenterOffsetRatio - facialCenterlineOffsetRatio) <= Self.centerAgreementThreshold {
                return facialCenterlineOffsetRatio * 0.78 + visualSignedCenterOffsetRatio * 0.22
            }
            return facialCenterlineOffsetRatio
        }

        guard let visualSignedCenterOffsetRatio else {
            return signedCenterOffsetRatio
        }
        if abs(visualSignedCenterOffsetRatio - signedCenterOffsetRatio) <= Self.centerAgreementThreshold {
            return signedCenterOffsetRatio * 0.35 + visualSignedCenterOffsetRatio * 0.65
        }
        if abs(visualSignedCenterOffsetRatio - signedCenterOffsetRatio) <= Self.centerAgreementThreshold * 1.6 {
            return signedCenterOffsetRatio * 0.58 + visualSignedCenterOffsetRatio * 0.42
        }
        return signedCenterOffsetRatio
    }

    var facialCenterlineOffsetRatio: Double? {
        switch (eyeCenterXRatio, noseCenterXRatio) {
        case let (eyeX?, noseX?):
            return (eyeX * 0.58 + noseX * 0.42) - 0.5
        case let (eyeX?, nil):
            return eyeX - 0.5
        case let (nil, noseX?):
            return noseX - 0.5
        default:
            return nil
        }
    }

    var eyeNoseCenterlineGapRatio: Double? {
        guard let eyeCenterXRatio, let noseCenterXRatio else { return nil }
        return abs(eyeCenterXRatio - noseCenterXRatio)
    }

    var effectiveCenterOffsetRatio: Double {
        abs(effectiveSignedCenterOffsetRatio)
    }

    var visualAndFaceCentersAgree: Bool {
        guard let visualSignedCenterOffsetRatio else { return true }
        return abs(visualSignedCenterOffsetRatio - signedCenterOffsetRatio) <= Self.centerAgreementThreshold
    }

    var isCentered: Bool {
        effectiveCenterOffsetRatio <= Self.strictCenterPassThreshold
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

    var dominantLevelAngleDegrees: Double {
        if let eyeLineRollDegrees, abs(eyeLineRollDegrees) >= 0.35 {
            return eyeLineRollDegrees
        }
        return rollDegrees
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
