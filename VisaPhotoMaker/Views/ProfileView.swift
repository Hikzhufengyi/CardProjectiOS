import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct ProfileView: View {
    @StateObject private var profile = LocalProfileStore.shared
    @StateObject private var store = StoreService.shared
    @State private var showingPrivacy = false
    @State private var showingPaywall = false

    var body: some View {
        NavigationStack {
            List {
                proSection
                trustSection
                recordsSection
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(AppTheme.groupedBackground)
            .navigationTitle(L10n.text(L10n.profileTab))
            .tint(AppTheme.officialBlue)
            .sheet(isPresented: $showingPrivacy) {
                PrivacyDisclaimerView()
            }
            .sheet(isPresented: $showingPaywall) {
                PaywallView(store: store) {
                    showingPaywall = false
                }
            }
            .task {
                await store.loadProducts()
            }
            .background(AppTheme.groupedBackground.ignoresSafeArea())
        }
    }

    private var proSection: some View {
        Section {
            MembershipIdentityCard(hasProAccess: store.hasProAccess)

            if !store.hasProAccess {
                Button {
                    showingPaywall = true
                } label: {
                    Label(L10n.text(en: "Unlock Lifetime", zh: "解锁终身版"), systemImage: "lock.open.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.officialBlue)
                .disabled(store.isLoadingProducts || store.isPurchasing)
            }

            Button {
                Task { await store.restore() }
            } label: {
                Label(L10n.text(en: "Restore Purchase", zh: "恢复购买"), systemImage: "arrow.clockwise")
            }
            .disabled(store.isPurchasing)

            if store.isPurchasing || store.isLoadingProducts {
                ProgressView()
            }

            if let purchaseMessage = store.purchaseMessage {
                Text(purchaseMessage)
                    .font(.caption)
                    .foregroundStyle(AppTheme.success)
            }

            if let purchaseError = store.purchaseError {
                Text(purchaseError)
                    .font(.caption)
                    .foregroundStyle(AppTheme.danger)
            }
        } header: {
            Text(L10n.text(en: "Pro Access", zh: "专业版"))
        } footer: {
            Text(L10n.text(en: "Purchases and restore are handled by the App Store. Your photos are not uploaded.", zh: "购买和恢复购买只通过 App Store 完成，不会上传你的照片。"))
        }
    }

    private var trustSection: some View {
        Section {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "lock.shield.fill")
                    .font(.title2)
                    .foregroundStyle(AppTheme.officialBlue)
                    .frame(width: 32)
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.text(en: "Private, Secure, Compliant", zh: "安全、隐私、合规"))
                        .font(.headline)
                        .foregroundStyle(AppTheme.ink)
                    Text(L10n.text(en: "Photo processing happens on device. Compliance checks are based on published requirements; review the official source before submission.", zh: "照片处理在设备本地完成，不上传云端。合规检查基于公开证件照要求，导出前仍建议核对官方页面。"))
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondaryInk)
                }
            }

            Label(L10n.text(en: "Photos are not uploaded to a server", zh: "照片不会上传服务器"), systemImage: "icloud.slash")
            Label(L10n.text(en: "No ad SDKs, fewer distractions", zh: "无广告 SDK，少打扰"), systemImage: "hand.raised")
            Label(L10n.text(en: "Local records stay on this device", zh: "本地制作记录只保存在本机"), systemImage: "internaldrive")

            Button {
                showingPrivacy = true
            } label: {
                Label(L10n.text(L10n.privacyTitle), systemImage: "doc.text.magnifyingglass")
            }

            Button {
                AppStoreReviewService.openWriteReview()
            } label: {
                Label(L10n.text(en: "Rate IDPhoto Pro", zh: "给 IDPhoto Pro 评分"), systemImage: "star")
            }

            LabeledContent {
                Text(appVersionText)
                    .foregroundStyle(AppTheme.secondaryInk)
            } label: {
                Label(L10n.text(en: "Version", zh: "版本号"), systemImage: "info.circle")
            }
        } header: {
            Text(L10n.text(en: "Trust & Support", zh: "信任与支持"))
        } footer: {
            Text(L10n.text(en: "IDPhoto Pro is not a government agency. Checks are assistive; verify official requirements before final submission.", zh: "IDPhoto Pro 不是政府机构，检查结果仅作辅助，最终提交前请核对对应国家/地区的官方要求。"))
        }
    }

    private var appVersionText: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
        return build.isEmpty ? "v\(version)" : "v\(version) (\(build))"
    }

    private var recordsSection: some View {
        Section {
            NavigationLink {
                CreationRecordsView()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.title3)
                        .foregroundStyle(AppTheme.officialBlue)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(L10n.text(L10n.records))
                            .font(.headline)
                            .foregroundStyle(AppTheme.ink)
                        Text(profile.records.isEmpty ? (L10n.text(en: "No records yet", zh: "暂无记录")) : (L10n.text(en: "\(profile.records.count) local records", zh: "\(profile.records.count) 条本地记录")))
                            .font(.caption)
                            .foregroundStyle(AppTheme.secondaryInk)
                    }
                }
            }
        } header: {
            Text(L10n.text(L10n.records))
        } footer: {
            Text(L10n.text(en: "Local records can be saved again and are never synced to the cloud.", zh: "本地制作记录可二次保存，不会同步到云端。"))
        }
    }
}

private struct MembershipIdentityCard: View {
    let hasProAccess: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(hasProAccess ? AppTheme.success.opacity(0.14) : AppTheme.officialBlue.opacity(0.10))
                    Image(systemName: hasProAccess ? "crown.fill" : "seal.fill")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(hasProAccess ? AppTheme.success : AppTheme.officialBlue)
                }
                .frame(width: 46, height: 46)

                VStack(alignment: .leading, spacing: 5) {
                    Text(hasProAccess ? L10n.text(en: "Pro Member", zh: "尊贵专业会员") : L10n.text(en: "Free Member", zh: "免费用户"))
                        .font(.title3.weight(.bold))
                        .foregroundStyle(AppTheme.ink)
                    Text(hasProAccess ? L10n.text(en: "Lifetime access is active. HD export, PDF, print layouts, compression, and compliance reports are unlocked.", zh: "终身版已生效。高清导出、PDF、打印排版、压缩和合规报告已解锁。") : L10n.text(en: "Preview and check photos for free. Unlock once when you are ready to export final files.", zh: "可以免费预览和检测照片。确认需要导出最终文件时再一次买断解锁。"))
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondaryInk)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                ProfileTrustPill(title: hasProAccess ? L10n.text(en: "Lifetime", zh: "终身版") : L10n.text(en: "Not unlocked", zh: "未解锁"), systemImage: hasProAccess ? "checkmark.seal" : "lock")
                ProfileTrustPill(title: L10n.text(en: "No Ads", zh: "无广告"), systemImage: "nosign")
                ProfileTrustPill(title: L10n.text(en: "On-device", zh: "本地处理"), systemImage: "iphone.gen3")
            }
        }
        .padding(.vertical, 4)
    }
}

private struct ProfileTrustPill: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(AppTheme.officialBlue)
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .background(AppTheme.officialBlue.opacity(0.07), in: Capsule())
    }
}

private struct CreationRecordsView: View {
    @StateObject private var profile = LocalProfileStore.shared

    var body: some View {
        List {
            if profile.records.isEmpty {
                ContentUnavailableView(
                    L10n.text(en: "No Records", zh: "暂无制作记录"),
                    systemImage: "clock",
                    description: Text(L10n.text(en: "Export or save a photo to keep a local record on this device.", zh: "导出或保存证件照后，会在本机保存记录。"))
                )
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
            } else {
                Section {
                    ForEach(profile.records) { record in
                        NavigationLink {
                            CreationRecordDetailView(record: record)
                        } label: {
                            CreationRecordRow(record: record)
                        }
                    }
                } footer: {
                    Text(L10n.text(en: "Records are stored on this device only and are not uploaded.", zh: "记录只保存在本机，不上传云端。"))
                }

                Section {
                    Button(role: .destructive) {
                        profile.clearRecords()
                    } label: {
                        Label(L10n.text(en: "Clear Local Records", zh: "清空本地记录"), systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(AppTheme.groupedBackground)
        .navigationTitle(L10n.text(L10n.records))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }
}

private struct CreationRecordRow: View {
    @StateObject private var profile = LocalProfileStore.shared
    let record: CreationRecord

    var body: some View {
        HStack(spacing: 12) {
            thumbnail

            VStack(alignment: .leading, spacing: 4) {
                Text(record.title)
                    .font(.headline)
                Text("\(record.country) · \(record.format) · \(record.layout)")
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryInk)
                Text(record.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(AppTheme.secondaryInk)
            }
        }
        .padding(.vertical, 4)
    }

    private var thumbnail: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(AppTheme.groupedBackground)

            if let imageURL = profile.imageURL(for: record),
               let image = UIImage(contentsOfFile: imageURL.path) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "photo")
                    .foregroundStyle(AppTheme.secondaryInk)
            }
        }
        .frame(width: 54, height: 70)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(AppTheme.border, lineWidth: 1)
        }
    }
}

private struct CreationRecordDetailView: View {
    @StateObject private var profile = LocalProfileStore.shared
    let record: CreationRecord
    @State private var saveMessage: String?
    @State private var saveError: String?
    @State private var shareItem: RecordShareItem?
    @State private var fileExporterItem: RecordFileDocument?
    @State private var saver = ImageSaver()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                preview
                actions
                details
            }
            .padding(18)
        }
        .background(AppTheme.groupedBackground)
        .navigationTitle(record.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .sheet(item: $shareItem) { item in
            RecordShareSheet(items: [item.url])
        }
        .fileExporter(
            isPresented: Binding(
                get: { fileExporterItem != nil },
                set: { if !$0 { fileExporterItem = nil } }
            ),
            document: fileExporterItem,
            contentType: recordContentType,
            defaultFilename: defaultFilename
        ) { result in
            switch result {
            case .success:
                saveMessage = L10n.text(en: "File saved again.", zh: "文件已再次保存。")
                saveError = nil
            case .failure(let error):
                saveError = error.localizedDescription
            }
        }
        .alert(L10n.text(en: "Save Failed", zh: "保存失败"), isPresented: Binding(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )) {
            Button(L10n.text(en: "OK", zh: "好的"), role: .cancel) {}
        } message: {
            Text(saveError ?? "")
        }
    }

    private var preview: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.text(en: "Exported Photo", zh: "历史导出照片"))
                .font(.headline)

            ZStack {
                AppTheme.groupedBackground
                if let imageURL = profile.imageURL(for: record),
                   let image = UIImage(contentsOfFile: imageURL.path) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .padding(12)
                } else {
                    ContentUnavailableView(
                        L10n.text(en: "Photo Not Found", zh: "照片文件不存在"),
                        systemImage: "photo.badge.exclamationmark",
                        description: Text(L10n.text(en: "The record exists, but the local image file may have been removed.", zh: "这条记录仍在，但本地图片文件可能已被清理。"))
                    )
                }
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 360)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding(14)
        .professionalCard()
    }

    private var actions: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.text(en: "Save Again", zh: "二次保存"))
                .font(.headline)

            Button {
                saveAgainToPhotos()
            } label: {
                Label(L10n.text(en: "Save to Photos Again", zh: "再次保存到相册"), systemImage: "square.and.arrow.down")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.officialBlue)
            .disabled(recordImage == nil)

            HStack(spacing: 10) {
                Button {
                    shareRecordFile()
                } label: {
                    Label(L10n.text(en: "Share", zh: "分享"), systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(AppTheme.officialBlue)
                .disabled(recordShareURL == nil)

                Button {
                    exportRecordFile()
                } label: {
                    Label(L10n.text(en: "Files", zh: "存文件"), systemImage: "folder.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(AppTheme.officialBlue)
                .disabled(recordFileData == nil)
            }

            if let saveMessage {
                Label(saveMessage, systemImage: "checkmark.circle")
                    .font(.caption)
                    .foregroundStyle(AppTheme.success)
            }
        }
        .padding(14)
        .professionalCard()
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.text(en: "Export Details", zh: "导出信息"))
                .font(.headline)

            LabeledContent(L10n.text(en: "Country", zh: "国家/地区"), value: record.country)
            LabeledContent(L10n.text(en: "Format", zh: "格式"), value: record.format)
            LabeledContent(L10n.text(en: "Layout", zh: "版式"), value: record.layout)
            LabeledContent(L10n.text(en: "Date", zh: "时间"), value: record.createdAt.formatted(date: .abbreviated, time: .shortened))
            LabeledContent(L10n.text(en: "Export File", zh: "导出文件"), value: profile.fileURL(for: record) == nil ? (L10n.text(en: "Not saved", zh: "未保存")) : (L10n.text(en: "Saved locally", zh: "已保存在本机")))
        }
        .padding(14)
        .professionalCard()
    }

    private var recordImage: UIImage? {
        guard let imageURL = profile.imageURL(for: record) else { return nil }
        return UIImage(contentsOfFile: imageURL.path)
    }

    private var recordShareURL: URL? {
        profile.fileURL(for: record) ?? profile.imageURL(for: record)
    }

    private var recordFileData: Data? {
        guard let url = recordShareURL else { return nil }
        return try? Data(contentsOf: url)
    }

    private var recordContentType: UTType {
        guard let url = recordShareURL else { return .data }
        switch url.pathExtension.lowercased() {
        case "jpg", "jpeg": return .jpeg
        case "heic": return .heic
        case "png": return .png
        case "pdf": return .pdf
        default: return .data
        }
    }

    private var defaultFilename: String {
        let safeTitle = record.title
            .lowercased()
            .replacingOccurrences(of: " / ", with: "-")
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "--", with: "-")
        let ext = recordShareURL?.pathExtension.isEmpty == false ? recordShareURL!.pathExtension : "jpg"
        return "\(safeTitle)-record.\(ext)"
    }

    private func saveAgainToPhotos() {
        guard let image = recordImage else { return }
        saver.save(image) { result in
            switch result {
            case .success:
                saveMessage = L10n.text(en: "Saved to Photos again.", zh: "已再次保存到相册。")
                saveError = nil
            case .failure(let error):
                saveError = error.localizedDescription
            }
        }
    }

    private func shareRecordFile() {
        guard let url = recordShareURL else { return }
        shareItem = RecordShareItem(url: url)
    }

    private func exportRecordFile() {
        guard let data = recordFileData else { return }
        fileExporterItem = RecordFileDocument(data: data)
    }
}

private struct RecordShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

private struct RecordFileDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.data] }
    let data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        self.data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

private struct RecordShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
