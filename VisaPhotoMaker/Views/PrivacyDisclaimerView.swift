import SwiftUI
import WebKit

struct PrivacyDisclaimerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var isLoading = true
    @State private var loadError: String?

    private let privacyURL = URL(string: "https://hikzhufengyi.github.io/idphoto-pro/privacy.html")!

    var body: some View {
        NavigationStack {
            ZStack {
                PrivacyPolicyWebView(url: privacyURL, isLoading: $isLoading, loadError: $loadError)
                    .background(AppTheme.groupedBackground)

                if isLoading {
                    ProgressView()
                        .padding(14)
                        .background(.thinMaterial, in: Capsule())
                }

                if let loadError {
                    VStack(spacing: 12) {
                        Image(systemName: "wifi.exclamationmark")
                            .font(.system(size: 34))
                            .foregroundStyle(AppTheme.warning)
                        Text(L10n.text(en: "Privacy Policy Could Not Load", zh: "隐私协议暂时无法加载"))
                            .font(.headline)
                            .foregroundStyle(AppTheme.ink)
                        Text(loadError)
                            .font(.caption)
                            .foregroundStyle(AppTheme.secondaryInk)
                            .multilineTextAlignment(.center)
                        Button {
                            openURL(privacyURL)
                        } label: {
                            Label(L10n.text(en: "Open in Browser", zh: "在浏览器打开"), systemImage: "safari")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(AppTheme.officialBlue)
                    }
                    .padding(18)
                    .frame(maxWidth: 320)
                    .professionalCard()
                }
            }
            .navigationTitle(L10n.text(L10n.privacyTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        openURL(privacyURL)
                    } label: {
                        Image(systemName: "safari")
                    }
                    .accessibilityLabel(L10n.text(en: "Open in Browser", zh: "在浏览器打开"))
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.text(en: "Done", zh: "完成")) { dismiss() }
                }
            }
            .background(AppTheme.groupedBackground.ignoresSafeArea())
        }
    }
}

private struct PrivacyPolicyWebView: UIViewRepresentable {
    let url: URL
    @Binding var isLoading: Bool
    @Binding var loadError: String?

    func makeCoordinator() -> Coordinator {
        Coordinator(isLoading: $isLoading, loadError: $loadError)
    }

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate {
        @Binding private var isLoading: Bool
        @Binding private var loadError: String?

        init(isLoading: Binding<Bool>, loadError: Binding<String?>) {
            self._isLoading = isLoading
            self._loadError = loadError
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            isLoading = true
            loadError = nil
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isLoading = false
            loadError = nil
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            isLoading = false
            loadError = error.localizedDescription
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            isLoading = false
            loadError = error.localizedDescription
        }
    }
}
