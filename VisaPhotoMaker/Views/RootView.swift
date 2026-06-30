import SwiftUI

struct RootView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var showSplash = true

    var body: some View {
        ZStack {
            AppTheme.groupedBackground
                .ignoresSafeArea()

            if showSplash {
                SplashView()
                    .transition(.opacity)
            } else if hasCompletedOnboarding {
                ContentView()
                    .transition(.opacity)
            } else {
                OnboardingView {
                    AnalyticsService.logOnboardingComplete(method: "primary")
                    hasCompletedOnboarding = true
                }
                .transition(.opacity)
            }
        }
        .background(AppTheme.groupedBackground.ignoresSafeArea())
        .preferredColorScheme(nil)
        .environment(\.layoutDirection, L10n.layoutDirection)
        .task {
            try? await Task.sleep(for: .seconds(0.45))
            withAnimation(.easeInOut(duration: 0.25)) {
                showSplash = false
            }
        }
    }
}
