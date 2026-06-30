import StoreKit
import SwiftUI

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: StoreService
    let onUnlocked: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if store.hasProAccess {
                        unlockedState
                    } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L10n.text(en: "Lifetime Unlock", zh: "终身解锁"))
                            .font(.system(.largeTitle, design: .default, weight: .bold))
                            .foregroundStyle(AppTheme.ink)
                        Text(L10n.text(en: "One-time purchase. No subscription, no ads, no recurring charges. Check your photo first, then unlock export.", zh: "一次买断。无订阅、无广告、无重复扣费。确认照片可导出后再购买。"))
                            .foregroundStyle(AppTheme.secondaryInk)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                HStack(spacing: 8) {
                    TrustBadge(icon: "checkmark.seal.fill", text: L10n.text(en: "One-time", zh: "一次买断"))
                    TrustBadge(icon: "repeat.circle", text: L10n.text(en: "No subscription", zh: "无订阅"))
                    TrustBadge(icon: "lock.shield", text: L10n.text(en: "On device", zh: "本地处理"))
                }

                VStack(spacing: 12) {
                    PaywallBenefit(
                        icon: "photo.badge.checkmark",
                        title: L10n.text(en: "Unlock HD export", zh: "解锁高清导出"),
                        detail: L10n.text(en: "Save digital ID photos, PDFs, or print sheets to Photos and Files.", zh: "保存电子证件照、PDF 或打印排版图到相册和文件。")
                    )
                    PaywallBenefit(
                        icon: "person.crop.rectangle",
                        title: L10n.text(en: "Compliance checks", zh: "合规检查"),
                        detail: L10n.text(en: "Review head size, centering, sharpness, background, file size, and checklist items.", zh: "检查头部比例、居中、清晰度、背景和文件大小，并生成检查清单。")
                    )
                    PaywallBenefit(
                        icon: "lock.shield",
                        title: L10n.text(en: "Private on-device workflow", zh: "本地隐私处理"),
                        detail: L10n.text(en: "Photo processing runs on device. Analytics only measures product usage and never includes your photos.", zh: "照片处理在设备上完成。统计只用于了解功能使用情况，不包含你的照片。")
                    )
                }

                if store.products.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L10n.text(en: "Purchase Temporarily Unavailable", zh: "购买暂时不可用"))
                            .font(.headline)
                            .foregroundStyle(AppTheme.ink)
                        Text(L10n.text(en: "Check your connection and try again, or come back later. Previous buyers can use Restore Purchase.", zh: "请检查网络后重试，或稍后再试。已购买用户可以使用恢复购买。"))
                            .font(.footnote)
                            .foregroundStyle(AppTheme.secondaryInk)
                        Button {
                            Task { await store.loadProducts() }
                        } label: {
                            Label(L10n.text(en: "Retry Loading", zh: "重试加载"), systemImage: "arrow.clockwise")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(AppTheme.officialBlue)
                        .disabled(store.isLoadingProducts || store.isPurchasing)
                    }
                    .padding(14)
                    .professionalCard()
                } else {
                    ForEach(store.products, id: \.id) { product in
                        Button {
                            Task {
                                await store.purchase(product)
                                if store.hasProAccess {
                                    onUnlocked()
                                    dismiss()
                                }
                            }
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(L10n.text(en: "Unlock Lifetime", zh: "解锁终身版"))
                                        .font(.headline)
                                        .foregroundStyle(AppTheme.ink)
                                    Text(L10n.text(en: "One purchase for HD export, PDF, print layouts, and compliance reports.", zh: "一次购买，永久使用高清导出、PDF、打印排版和合规报告。"))
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.secondaryInk)
                                }
                                Spacer()
                                Text(product.displayPrice)
                                    .font(.headline)
                                    .foregroundStyle(AppTheme.officialBlue)
                            }
                            .padding(14)
                            .professionalCard()
                        }
                        .buttonStyle(.plain)
                        .disabled(store.isPurchasing)
                    }
                }

                Button {
                    Task { await store.restore() }
                } label: {
                    Text(L10n.text(en: "Restore Purchase", zh: "恢复购买"))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(AppTheme.officialBlue)
                .disabled(store.isPurchasing)

                #if DEBUG
                Button {
                    onUnlocked()
                    dismiss()
                } label: {
                    Text("Debug Unlock")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.officialBlue)
                #endif

                if store.isPurchasing || store.isLoadingProducts {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                }

                if let purchaseMessage = store.purchaseMessage {
                    Text(purchaseMessage)
                        .font(.footnote)
                        .foregroundStyle(AppTheme.success)
                }

                if let purchaseError = store.purchaseError {
                    Text(purchaseError)
                        .font(.footnote)
                        .foregroundStyle(AppTheme.danger)
                }

                Text(L10n.text(en: "This app is not affiliated with any government agency. Checks are based on published requirements; review the official source before submission.", zh: "本 App 不隶属于任何政府机构。检查结果基于公开要求，提交前请核对官方网站。"))
                    .font(.caption2)
                    .foregroundStyle(AppTheme.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(20)
            }
            .background(AppTheme.groupedBackground)
            .tint(AppTheme.officialBlue)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.text(en: "Close", zh: "关闭")) { dismiss() }
                }
            }
            .task {
                await store.loadProducts()
                if store.hasProAccess {
                    onUnlocked()
                    dismiss()
                }
            }
            .onChange(of: store.hasProAccess) { _, hasAccess in
                if hasAccess {
                    onUnlocked()
                    dismiss()
                }
            }
            .background(AppTheme.groupedBackground.ignoresSafeArea())
        }
    }

    private var unlockedState: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(L10n.text(en: "Lifetime Unlock Active", zh: "终身版已解锁"), systemImage: "checkmark.seal.fill")
                .font(.title2.weight(.bold))
                .foregroundStyle(AppTheme.success)

            Text(L10n.text(en: "You already purchased once. No additional purchase is needed. HD export, PDF, print layouts, and compliance reports are available.", zh: "你已经购买过一次，不需要再次购买。高清导出、PDF、打印排版和合规报告已可使用。"))
                .foregroundStyle(AppTheme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                onUnlocked()
                dismiss()
            } label: {
                Text(L10n.text(en: "Continue Export", zh: "继续导出"))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.officialBlue)
        }
        .padding(16)
        .professionalCard()
    }
}

private struct TrustBadge: View {
    let icon: String
    let text: String

    var body: some View {
        Label(text, systemImage: icon)
            .font(.caption.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .foregroundStyle(AppTheme.officialBlue)
            .frame(maxWidth: .infinity, minHeight: 32)
            .padding(.horizontal, 8)
            .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(AppTheme.border, lineWidth: 1)
            }
    }
}

private struct PaywallBenefit: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(AppTheme.officialBlue)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(AppTheme.ink)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.secondaryInk)
            }
        }
    }
}
