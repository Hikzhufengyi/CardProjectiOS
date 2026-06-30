import FirebaseCore
import SwiftUI

@main
struct VisaPhotoMakerApp: App {
    init() {
        if Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil {
            FirebaseApp.configure()
            AnalyticsService.logAppOpen()
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
