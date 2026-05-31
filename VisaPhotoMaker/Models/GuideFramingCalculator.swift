import Foundation

enum GuideFramingCalculator {
    static let eyePositionWithinHead = 0.43

    static func guideTopRatio(
        headRatio: Double,
        eyeTargetRatio: Double,
        profile: PhotoComplianceProfile
    ) -> Double {
        let eyeTop = (1 - eyeTargetRatio) - headRatio * eyePositionWithinHead
        let marginTop = profile.minimumTopMarginRatio
        let balancedTop = (1 - headRatio - profile.minimumBottomMarginRatio) * 0.46
        let visualDownBias = 0.024
        let weightedTop = eyeTop * 0.34 + marginTop * 0.43 + balancedTop * 0.23 + visualDownBias
        let documentMinimumTop = profile.minimumTopMarginRatio
        let visualMinimumTop = max(0.065, min(0.105, 0.064 + profile.targetHeadRatio * 0.055))
        let minimumTop = max(documentMinimumTop, visualMinimumTop)
        let maximumTop = max(minimumTop, 1 - headRatio - profile.minimumBottomMarginRatio)
        return min(max(weightedTop, minimumTop), maximumTop)
    }
}
