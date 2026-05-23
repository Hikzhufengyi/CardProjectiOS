import UIKit

enum AppStoreReviewService {
    private static let appID = "6771586096"
    private static let successCountKey = "review_successful_export_count"
    private static let lastPromptDateKey = "review_last_prompt_date"
    private static let lastFailureDateKey = "review_last_failure_date"
    private static let promptMilestones: Set<Int> = [2, 5, 10]
    private static let minimumDaysBetweenPrompts: TimeInterval = 60 * 60 * 24 * 30
    private static let minimumHoursAfterFailure: TimeInterval = 60 * 60 * 24

    static func openWriteReview() {
        guard let url = URL(string: "itms-apps://itunes.apple.com/app/id\(appID)?action=write-review") else {
            return
        }
        UIApplication.shared.open(url)
    }

    static func recordExportFailure() {
        UserDefaults.standard.set(Date(), forKey: lastFailureDateKey)
    }

    static func shouldPromptAfterSuccessfulExport() -> Bool {
        let defaults = UserDefaults.standard
        let successCount = defaults.integer(forKey: successCountKey) + 1
        defaults.set(successCount, forKey: successCountKey)

        guard promptMilestones.contains(successCount) else {
            return false
        }

        if let lastFailureDate = defaults.object(forKey: lastFailureDateKey) as? Date,
           Date().timeIntervalSince(lastFailureDate) < minimumHoursAfterFailure {
            return false
        }

        if let lastPromptDate = defaults.object(forKey: lastPromptDateKey) as? Date,
           Date().timeIntervalSince(lastPromptDate) < minimumDaysBetweenPrompts {
            return false
        }

        defaults.set(Date(), forKey: lastPromptDateKey)
        return true
    }
}
