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
                    hasCompletedOnboarding = true
                }
                .transition(.opacity)
            }
        }
        .background(AppTheme.groupedBackground.ignoresSafeArea())
        .preferredColorScheme(nil)
        .task {
            try? await Task.sleep(for: .seconds(0.45))
            withAnimation(.easeInOut(duration: 0.25)) {
                showSplash = false
            }
        }
    }
}
