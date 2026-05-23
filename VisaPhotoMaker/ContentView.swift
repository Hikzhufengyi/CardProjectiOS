import SwiftUI

struct ContentView: View {
    @StateObject private var store = StoreService.shared

    var body: some View {
        ZStack {
            AppTheme.groupedBackground
                .ignoresSafeArea()

            TabView {
                CreateView()
                    .tabItem {
                        Label(L10n.text(L10n.createTab), systemImage: "person.crop.rectangle")
                    }

                ProfileView()
                    .tabItem {
                        Label(L10n.text(L10n.profileTab), systemImage: "person.circle")
                }
            }
            .tint(AppTheme.officialBlue)
        }
        .background(AppTheme.groupedBackground.ignoresSafeArea())
        .task {
            try? await Task.sleep(for: .milliseconds(450))
            await store.updatePurchases()
        }
    }
}
