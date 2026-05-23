import SwiftUI

struct OnboardingView: View {
    let onFinish: () -> Void
    @State private var page = 0

    private var pages: [OnboardingPage] {
        [
            OnboardingPage(
                imageName: "OnboardingImport",
                title: L10n.text(en: "Passport & Visa Templates", zh: "护照与签证模板"),
                detail: L10n.text(en: "Start with official photo sizes for passports, visas, immigration forms, and print sheets.", zh: "从护照、签证、移民申请和打印排版的官方照片尺寸开始制作。"),
                tint: AppTheme.officialBlue
            ),
            OnboardingPage(
                imageName: "OnboardingEdit",
                title: L10n.text(en: "Adjust to the Guide", zh: "按参考线调整"),
                detail: L10n.text(en: "Drag, pinch, rotate, and fine-tune the photo so the head and face match the requirement guide.", zh: "拖动、缩放、旋转并精细调整照片，让头部和面部贴合规格参考线。"),
                tint: AppTheme.officialBlue
            ),
            OnboardingPage(
                imageName: "OnboardingCheck",
                title: L10n.text(en: "Compliance Checklist", zh: "合规检查清单"),
                detail: L10n.text(en: "Review head size, centering, background, lighting, sharpness, and file-size checks before export.", zh: "导出前检查头部比例、居中、背景、光线、清晰度和文件大小。"),
                tint: AppTheme.officialBlue
            ),
            OnboardingPage(
                imageName: "OnboardingExport",
                title: L10n.text(en: "Export Final Files", zh: "导出最终文件"),
                detail: L10n.text(en: "Save 300 DPI JPG, PNG, PDF, target-KB files, and 4x6, A4, or Letter print sheets.", zh: "保存 300 DPI JPG、PNG、PDF、指定 KB 文件，以及 4x6、A4 或 Letter 打印排版。"),
                tint: AppTheme.officialBlue
            ),
            OnboardingPage(
                imageName: "OnboardingPrivacy",
                title: L10n.text(en: "Private on Your Device", zh: "照片只在本机处理"),
                detail: L10n.text(en: "Photo editing, face checks, background replacement, and export stay on your device. No cloud upload, no ads.", zh: "照片编辑、人脸检测、换背景和导出都在设备上完成。不上传云端，无广告。"),
                tint: AppTheme.officialBlue
            )
        ]
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button(L10n.text(L10n.skip), action: onFinish)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.officialBlue)
                    .padding(.horizontal, 18)
                    .padding(.top, 16)
            }

            TabView(selection: $page) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, item in
                    OnboardingPageView(page: item)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))

            Button {
                if page == pages.count - 1 {
                    onFinish()
                } else {
                    withAnimation { page += 1 }
                }
            } label: {
                Text(page == pages.count - 1 ? L10n.text(L10n.getStarted) : L10n.text(L10n.next))
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.officialBlue)
            .padding(18)
        }
        .background(AppTheme.pageBackground.ignoresSafeArea())
        .tint(AppTheme.officialBlue)
    }
}

struct OnboardingPage {
    let imageName: String
    let title: String
    let detail: String
    let tint: Color
}

private struct OnboardingPageView: View {
    let page: OnboardingPage

    var body: some View {
        VStack(spacing: 26) {
            Spacer()
            Image(page.imageName)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 330)
                .accessibilityHidden(true)

            VStack(spacing: 12) {
                Text(page.title)
                    .font(.system(size: 31, weight: .bold, design: .default))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(AppTheme.ink)
                Text(page.detail)
                    .font(.body)
                    .foregroundStyle(AppTheme.secondaryInk)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .frame(maxWidth: 330)
            }
            Spacer()
            Spacer(minLength: 42)
        }
        .padding(.horizontal, 24)
    }
}
