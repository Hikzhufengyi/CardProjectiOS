import SwiftUI

struct SplashView: View {
    var body: some View {
        ZStack {
            AppTheme.pageBackground
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Image("SplashHero")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 390)
                    .accessibilityHidden(true)

                VStack(spacing: 8) {
                    Text(L10n.text(L10n.fullName))
                        .font(.system(size: 34, weight: .bold, design: .default))
                        .multilineTextAlignment(.center)
                    Text(L10n.text(L10n.subtitle))
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(AppTheme.secondaryInk)
                        .frame(maxWidth: 330)
                }
                .foregroundStyle(AppTheme.ink)

                HStack(spacing: 14) {
                    SplashFeature(icon: "person.text.rectangle", text: L10n.text(en: "ID Photo", zh: "证件照"))
                    SplashFeature(icon: "checklist", text: L10n.text(en: "Checks", zh: "检测"))
                    SplashFeature(icon: "lock.shield", text: L10n.text(en: "On Device", zh: "本地处理"))
                }

                PrivacyPromise()
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 24)
        }
    }
}

private struct PrivacyPromise: View {
    var body: some View {
        Label(
            L10n.text(en: "No cloud uploads · No ad SDKs · No third-party analytics", zh: "照片不上传云端 · 无广告 SDK · 无第三方统计"),
            systemImage: "lock.shield.fill"
        )
        .font(.caption.weight(.semibold))
        .foregroundStyle(AppTheme.officialBlue)
        .multilineTextAlignment(.center)
        .lineLimit(2)
        .minimumScaleFactor(0.82)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(AppTheme.border, lineWidth: 1)
        )
    }
}

private struct SplashFeature: View {
    let icon: String
    let text: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.headline)
            Text(text)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .foregroundStyle(AppTheme.officialBlue)
        .frame(width: 86, height: 70)
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(AppTheme.border, lineWidth: 1)
        )
    }
}
