import Foundation
import FirebaseAnalytics

enum AnalyticsService {
    static func logAppOpen() {
        log("app_open")
    }

    static func logOnboardingComplete(method: String) {
        log("onboarding_complete", [
            "method": method
        ])
    }

    static func logSpecSelected(_ spec: PhotoSpec) {
        log("spec_select", specParameters(spec))
    }

    static func logPhotoImport(source: String, spec: PhotoSpec) {
        var parameters = specParameters(spec)
        parameters["source"] = source
        log("photo_import", parameters)
    }

    static func logCheckComplete(spec: PhotoSpec, result: ComplianceResult) {
        var parameters = specParameters(spec)
        parameters["score"] = result.score
        parameters["fail_count"] = result.blockingChecks.count
        parameters["warning_count"] = result.warnings.count
        parameters["passed"] = result.isFullyPassed
        log("check_complete", parameters)
    }

    static func logExportAttempt(spec: PhotoSpec, hasProAccess: Bool) {
        var parameters = specParameters(spec)
        parameters["has_pro_access"] = hasProAccess
        log("export_attempt", parameters)
    }

    static func logExportSuccess(spec: PhotoSpec, format: String, layout: String, fileSizeBytes: Int?) {
        var parameters = specParameters(spec)
        parameters["format"] = format
        parameters["layout"] = layout
        if let fileSizeBytes {
            parameters["file_size_kb"] = max(fileSizeBytes / 1024, 1)
        }
        log("export_success", parameters)
    }

    static func logPurchaseStart(productID: String) {
        log("purchase_start", [
            "product_id": productID
        ])
    }

    static func logPurchaseSuccess(productID: String) {
        log("purchase_success", [
            "product_id": productID
        ])
    }

    static func logPurchaseFailure(productID: String?, error: String) {
        var parameters: [String: Any] = [
            "error": String(error.prefix(96))
        ]
        if let productID {
            parameters["product_id"] = productID
        }
        log("purchase_failure", parameters)
    }

    static func logRestorePurchase(hasProAccess: Bool) {
        log("restore_purchase", [
            "has_pro_access": hasProAccess
        ])
    }

    private static func log(_ name: String, _ parameters: [String: Any]? = nil) {
        Analytics.logEvent(name, parameters: parameters)
    }

    private static func specParameters(_ spec: PhotoSpec) -> [String: Any] {
        [
            "spec_id": spec.id,
            "country": spec.country,
            "category": spec.category.rawValue,
            "width_mm": spec.widthMM,
            "height_mm": spec.heightMM,
            "width_px": spec.pixelSize.width,
            "height_px": spec.pixelSize.height
        ]
    }
}
