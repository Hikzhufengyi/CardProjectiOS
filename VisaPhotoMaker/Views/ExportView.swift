import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct ExportView: View {
    @Environment(\.dismiss) private var dismiss

    let image: UIImage?
    let spec: PhotoSpec
    let background: PhotoBackground
    let analysis: PhotoAnalysis?
    let editState: PhotoEditState
    let result: ComplianceResult

    @State private var digitalImage: UIImage?
    @State private var printImage: UIImage?
    @State private var exportFormat: ExportFormat = .jpg
    @State private var printLayout: PrintLayout = .fourBySix
    @State private var packingMode: PrintPackingMode = .safe
    @State private var selectedCompactOptionID: String?
    @State private var targetKBText: String = ""
    @State private var showsCropMarks = true
    @State private var exportData: Data?
    @State private var shareItem: ExportShareItem?
    @State private var fileExporterItem: ExportFileDocument?
    @State private var saveMessage: String?
    @State private var exportAlert: ExportAlert?
    @State private var didAddCreationRecord = false
    @StateObject private var profile = LocalProfileStore.shared

    private let renderer = PhotoRenderer()
    private let saver = ImageSaver()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    exportStatusSummary

                    exportOptions

                    if let selectedOutputImage {
                        ExportPreview(title: currentPreviewTitle, subtitle: currentPreviewSubtitle, image: selectedOutputImage)
                    }

                    trustSummary
                    complianceReport

                    VStack(alignment: .leading, spacing: 8) {
                        Text(L10n.text(en: "Requirement Notes", zh: "规格备注"))
                            .font(.headline)
                            .foregroundStyle(AppTheme.ink)
                        ForEach(spec.displayNotes, id: \.self) { note in
                            Label(note, systemImage: "checkmark.circle")
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.secondaryInk)
                        }
                        if let sourceURL = spec.sourceURL {
                            Link(destination: sourceURL) {
                                Label(L10n.text(en: "Review Official Requirement Source", zh: "查看官方要求来源"), systemImage: "link")
                                    .font(.subheadline.weight(.medium))
                            }
                            .padding(.top, 4)
                        }
                    }
                    .padding(14)
                    .professionalCard()

                    statusMessage
                }
                .padding(18)
            }
            .background(AppTheme.groupedBackground)
            .navigationTitle(L10n.text(en: "Export", zh: "导出"))
            .navigationBarTitleDisplayMode(.inline)
            .tint(AppTheme.officialBlue)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 10) {
                    Button {
                        save(selectedOutputImage)
                    } label: {
                        Label(primarySaveTitle, systemImage: "square.and.arrow.down")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white)
                    .background(AppTheme.officialBlue, in: RoundedRectangle(cornerRadius: 11))
                    .disabled(selectedOutputImage == nil)

                    HStack(spacing: 10) {
                        Button {
                            share()
                        } label: {
                            Label(L10n.text(en: "Share", zh: "分享"), systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity)
                                .frame(height: 38)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(AppTheme.officialBlue)
                        .background(AppTheme.groupedBackground, in: RoundedRectangle(cornerRadius: 10))
                        .disabled(exportData == nil)

                        Button {
                            exportToFiles()
                        } label: {
                            Label(L10n.text(en: "Files", zh: "文件"), systemImage: "folder.badge.plus")
                                .frame(maxWidth: .infinity)
                                .frame(height: 38)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(AppTheme.officialBlue)
                        .background(AppTheme.groupedBackground, in: RoundedRectangle(cornerRadius: 10))
                        .disabled(exportData == nil)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, 10)
                .padding(.bottom, 12)
                .background(AppTheme.cardBackground)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(AppTheme.border)
                        .frame(height: 1)
                }
            }
            .task {
                render()
            }
            .onChange(of: exportFormat) { _, _ in render() }
            .onChange(of: printLayout) { _, _ in
                normalizePackingMode()
                render()
            }
            .onChange(of: packingMode) { _, _ in
                normalizePackingMode()
                render()
            }
            .onChange(of: selectedCompactOptionID) { _, _ in render() }
            .onChange(of: targetKBText) { _, _ in render() }
            .onChange(of: showsCropMarks) { _, _ in render() }
            .sheet(item: $shareItem) { item in
                ShareSheet(items: [item.url])
            }
            .fileExporter(
                isPresented: Binding(
                    get: { fileExporterItem != nil },
                    set: { if !$0 { fileExporterItem = nil } }
                ),
                document: fileExporterItem,
                contentType: contentType,
                defaultFilename: defaultFilename
            ) { result in
                switch result {
                case .success:
                    saveMessage = L10n.text(en: "File saved.", zh: "文件已保存。")
                    exportAlert = .filesSuccess(shouldAskForRating: AppStoreReviewService.shouldPromptAfterSuccessfulExport())
                    addCreationRecord()
                case .failure(let error):
                    AppStoreReviewService.recordExportFailure()
                    saveMessage = error.localizedDescription
                    exportAlert = .failure(error.localizedDescription)
                }
            }
            .alert(item: $exportAlert) { alert in
                if alert.showsRatingAction {
                    Alert(
                        title: Text(alert.title),
                        message: Text(alert.message),
                        primaryButton: .default(Text(L10n.text(en: "Rate App", zh: "去评分"))) {
                            AppStoreReviewService.openWriteReview()
                        },
                        secondaryButton: .cancel(Text(L10n.text(en: "Not Now", zh: "稍后")))
                    )
                } else {
                    Alert(
                        title: Text(alert.title),
                        message: Text(alert.message),
                        dismissButton: .default(Text(L10n.text(en: "OK", zh: "好的")))
                    )
                }
            }
        }
    }

    private var statusMessage: some View {
        Group {
            if let saveMessage {
                Label(saveMessage, systemImage: "info.circle")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.secondaryInk)
            }
        }
    }

    private var exportStatusSummary: some View {
        HStack(spacing: 7) {
            Image(systemName: result.isFullyPassed ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                .font(.caption.weight(.bold))
                .foregroundStyle(result.isFullyPassed ? AppTheme.success : AppTheme.warning)
            Text(result.isFullyPassed ? L10n.text(en: "Ready", zh: "可导出") : L10n.text(en: "Review", zh: "需复核"))
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.ink)
            Text("\(result.score)%")
                .font(.caption.monospacedDigit().weight(.bold))
                .foregroundStyle(result.isFullyPassed ? AppTheme.success : AppTheme.warning)
            if let exportData {
                Text("\(exportData.count / 1024) KB")
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(AppTheme.success)
            }
            Spacer(minLength: 0)
            Text(printLayout == .digitalOnly ? exportFormat.rawValue : printLayout.rawValue)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(AppTheme.secondaryInk)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .frame(height: 32)
        .background(AppTheme.cardBackground, in: Capsule())
        .overlay {
            Capsule()
                .stroke(AppTheme.border, lineWidth: 1)
        }
    }

    private var complianceReport: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(
                    result.isFullyPassed ? L10n.text(L10n.ready) : (L10n.text(en: "Review Before Export", zh: "导出前复核")),
                    systemImage: result.isFullyPassed ? "checkmark.seal.fill" : "exclamationmark.triangle.fill"
                )
                    .font(.headline)
                    .foregroundStyle(result.isFullyPassed ? AppTheme.success : AppTheme.warning)
                Spacer()
                Text("\(result.score)%")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(result.isFullyPassed ? AppTheme.success : AppTheme.warning)
            }

            ForEach(result.checks) { check in
                HStack(alignment: .top, spacing: 9) {
                    Image(systemName: icon(for: check.severity))
                        .foregroundStyle(color(for: check.severity))
                        .frame(width: 18)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(check.title)
                            .font(.subheadline.weight(.semibold))
                        Text(check.message)
                            .font(.caption)
                            .foregroundStyle(AppTheme.secondaryInk)
                        if let action = check.action {
                            Label(action, systemImage: "wand.and.stars")
                                .font(.caption2)
                                .foregroundStyle(color(for: check.severity))
                        }
                    }
                    Spacer(minLength: 0)
                }
            }

            Divider()

            Label(L10n.text(en: "Format: \(exportFormat.rawValue)", zh: "格式：\(exportFormat.rawValue)"), systemImage: "doc")
                .font(.caption)
                .foregroundStyle(AppTheme.secondaryInk)
            if exportFormat.supportsTargetKB, let targetKB {
                Label(L10n.text(en: "Compression target: under \(targetKB) KB", zh: "压缩目标：\(targetKB) KB 以下"), systemImage: "archivebox")
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryInk)
            }
            Label(L10n.text(en: "Output: \(printLayout.rawValue)", zh: "输出：\(printLayout.rawValue)"), systemImage: "rectangle.on.rectangle")
                .font(.caption)
                .foregroundStyle(AppTheme.secondaryInk)
            Label(L10n.text(en: "300 DPI export. Review official requirements before submission.", zh: "300 DPI 高清导出，提交前请核对官方网站要求。"), systemImage: "shield.lefthalf.filled")
                .font(.caption)
                .foregroundStyle(AppTheme.officialBlue)
        }
        .padding(14)
        .professionalCard()
    }

    private var trustSummary: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(L10n.text(en: "Built around official published photo requirements", zh: "基于官方公开照片要求设计"), systemImage: "checkmark.seal.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.officialBlue)
            Label(L10n.text(en: "All processing stays on your device. No photo upload.", zh: "所有处理都在本机完成，照片不会上传。"), systemImage: "lock.shield.fill")
                .font(.caption)
                .foregroundStyle(AppTheme.secondaryInk)
            Label(L10n.text(en: "300 DPI high-resolution export for digital and print use", zh: "300 DPI 高清导出，适合电子版和打印使用"), systemImage: "printer.fill")
                .font(.caption)
                .foregroundStyle(AppTheme.secondaryInk)
            Text(L10n.text(en: "IDPhoto Pro is not affiliated with any government agency. Always review the official source before final submission.", zh: "IDPhoto Pro 不隶属于任何政府机构。最终提交前请核对官方网站要求。"))
                .font(.caption2)
                .foregroundStyle(AppTheme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .professionalCard()
    }

    private var exportOptions: some View {
        VStack(alignment: .leading, spacing: 11) {
            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.text(en: "Digital File", zh: "电子文件"))
                    .font(.headline)
                    .foregroundStyle(AppTheme.ink)

                Picker(L10n.text(en: "Format", zh: "格式"), selection: $exportFormat) {
                    ForEach(ExportFormat.allCases) { format in
                        Text(format.rawValue).tag(format)
                    }
                }
                .pickerStyle(.segmented)

                HStack {
                    Label(L10n.text(en: "Target size", zh: "目标大小"), systemImage: "tray.and.arrow.down")
                    Spacer()
                    TextField(defaultKBPlaceholder, text: $targetKBText)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 110)
                        .textFieldStyle(.roundedBorder)
                    Text("KB")
                        .foregroundStyle(AppTheme.secondaryInk)
                }
                .opacity(exportFormat.supportsTargetKB ? 1 : 0.45)
                .disabled(!exportFormat.supportsTargetKB)
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text(L10n.text(en: "Print Layout", zh: "打印排版"))
                        .font(.headline)
                        .foregroundStyle(AppTheme.ink)
                    Spacer()
                    Text(L10n.text(en: "4 x 6 in recommended", zh: "推荐 4 x 6 英寸"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.officialBlue)
                }

                if printLayout == .fourBySix {
                    Label(L10n.text(en: "Auto-filled for common photo labs at 300 DPI.", zh: "300 DPI 自动铺满，适合常见照片冲印店。"), systemImage: "square.grid.3x2")
                        .font(.caption)
                        .foregroundStyle(AppTheme.officialBlue)
                        .fixedSize(horizontal: false, vertical: true)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(orderedPrintLayouts) { layout in
                            ExportLayoutOption(
                                layout: layout,
                                isSelected: printLayout == layout,
                                title: title(for: layout),
                                subtitle: subtitle(for: layout)
                            ) {
                                printLayout = layout
                            }
                        }
                    }
                    .padding(.vertical, 1)
                }
                .scrollClipDisabled()
                .overlay(alignment: .trailing) {
                    LinearGradient(colors: [.clear, AppTheme.cardBackground], startPoint: .leading, endPoint: .trailing)
                        .frame(width: 22)
                        .allowsHitTesting(false)
                }
            }

            if printLayout != .digitalOnly {
                if !compactOptions.isEmpty {
                    VStack(alignment: .leading, spacing: 7) {
                        Picker(L10n.text(en: "Packing", zh: "排版方式"), selection: $packingMode) {
                            Text(L10n.text(en: "Safe", zh: "安全排版")).tag(PrintPackingMode.safe)
                            Text(L10n.text(en: "Compact", zh: "紧凑满铺")).tag(PrintPackingMode.compact)
                        }
                        .pickerStyle(.segmented)

                        if packingMode == .compact {
                            Label(L10n.text(en: "Advanced options below have no safety margin on at least one paper edge. Use only if your printer will not crop edges.", zh: "下面的高级选项至少有一个方向没有安全边距。仅在确认打印机不会裁边时使用。"), systemImage: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundStyle(AppTheme.warning)
                                .fixedSize(horizontal: false, vertical: true)

                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 8)], spacing: 8) {
                                ForEach(compactOptions, id: \.id) { option in
                                    CompactLayoutOption(
                                        option: option,
                                        isSelected: selectedCompactOptionID == option.id,
                                        edgeText: edgeText(for: option)
                                    ) {
                                        selectedCompactOptionID = option.id
                                        render()
                                    }
                                }
                            }
                        } else {
                            Label(L10n.text(en: "Safe layout leaves room for photo-lab cropping and easier trimming.", zh: "安全排版会留出冲印裁边和手动裁剪空间。"), systemImage: "checkmark.shield.fill")
                                .font(.caption)
                                .foregroundStyle(AppTheme.success)
                        }
                    }
                }

                cropMarksToggle
            }

        }
        .padding(14)
        .professionalCard()
    }

    private var cropMarksToggle: some View {
        Button {
            showsCropMarks.toggle()
        } label: {
            HStack(spacing: 7) {
                Image(systemName: showsCropMarks ? "checkmark.circle.fill" : "circle")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(showsCropMarks ? AppTheme.success : AppTheme.secondaryInk.opacity(0.6))
                Text(L10n.text(en: "Crop marks", zh: "裁切线"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.ink)
                Spacer(minLength: 0)
                Text(showsCropMarks ? L10n.text(en: "On", zh: "开") : L10n.text(en: "Off", zh: "关"))
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(showsCropMarks ? AppTheme.officialBlue : AppTheme.secondaryInk)
            }
            .frame(height: 28)
            .padding(.horizontal, 10)
            .background(AppTheme.groupedBackground, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func title(for layout: PrintLayout) -> String {
        switch layout {
        case .fourBySix:
            return L10n.text(en: "4 x 6 in", zh: "4 x 6 英寸")
        case .digitalOnly:
            return L10n.text(en: "No Print", zh: "不打印")
        default:
            return layout.rawValue
        }
    }

    private var orderedPrintLayouts: [PrintLayout] {
        [.fourBySix, .digitalOnly, .letter, .a4, .fiveBySeven, .fourByFour, .threeByFour]
    }

    private func subtitle(for layout: PrintLayout) -> String {
        switch layout {
        case .fourBySix:
            return L10n.text(en: "Auto fit, 300 DPI", zh: "自动排版，300 DPI")
        case .digitalOnly:
            return L10n.text(en: "Online only", zh: "仅线上提交")
        default:
            return L10n.text(en: "Specific request", zh: "按要求选择")
        }
    }

    private var defaultKBPlaceholder: String {
        if let maxFileKB = spec.maxFileKB {
            return "\(maxFileKB)"
        }
        return "500"
    }

    private var targetKB: Int? {
        guard exportFormat.supportsTargetKB else { return nil }
        if let typed = Int(targetKBText), typed > 0 {
            return typed
        }
        return spec.maxFileKB
    }

    private var digitalSubtitle: String {
        var parts = ["\(spec.displayPixels)", exportFormat.rawValue]
        if let targetKB, exportFormat.supportsTargetKB {
            parts.append(L10n.text(en: "under \(targetKB) KB", zh: "\(targetKB) KB 以下"))
        }
        return parts.joined(separator: " · ")
    }

    private var printSubtitle: String {
        let markText = showsCropMarks ? (L10n.text(en: "with crop marks", zh: "含裁切线")) : (L10n.text(en: "no crop marks", zh: "无裁切线"))
        return "\(printLayout.rawValue) · \(L10n.text(en: "auto filled", zh: "自动铺满")) · \(markText)"
    }

    private var primarySaveTitle: String {
        printLayout == .digitalOnly
            ? L10n.text(en: "Save Digital Photo to Photos", zh: "保存电子照到相册")
            : L10n.text(en: "Save Print Sheet to Photos", zh: "保存打印版到相册")
    }

    private var currentPreviewTitle: String {
        printLayout == .digitalOnly
            ? L10n.text(en: "Digital Photo Preview", zh: "电子照预览")
            : L10n.text(en: "Print Sheet Preview", zh: "打印版预览")
    }

    private var currentPreviewSubtitle: String {
        printLayout == .digitalOnly ? digitalSubtitle : printSubtitle
    }

    private var outputSummaryText: String {
        if printLayout == .digitalOnly {
            return "\(L10n.text(en: "Digital file", zh: "电子文件")) · \(digitalSubtitle)"
        }
        return "\(L10n.text(en: "Print layout", zh: "打印排版")) · \(printSubtitle)"
    }

    private var selectedOutputImage: UIImage? {
        printLayout == .digitalOnly ? digitalImage : printImage
    }

    private var contentType: UTType {
        switch exportFormat {
        case .jpg:
            return .jpeg
        case .heif:
            return .heic
        case .png:
            return .png
        case .pdf:
            return .pdf
        }
    }

    private var defaultFilename: String {
        let safeTitle = spec.title
            .lowercased()
            .replacingOccurrences(of: " / ", with: "-")
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "--", with: "-")
        return "\(safeTitle)-photo.\(fileExtension)"
    }

    private func render() {
        guard let image else { return }
        normalizePackingMode()
        let digital = renderer.render(image: image, spec: spec, background: background, faceAnalysis: analysis?.face, editState: editState)
        digitalImage = digital
        if printLayout == .digitalOnly {
            printImage = nil
            exportData = renderer.exportData(image: digital, format: exportFormat, targetKB: targetKB)
        } else {
            let sheet = renderer.renderPrintSheet(
                image: image,
                spec: spec,
                background: background,
                faceAnalysis: analysis?.face,
                editState: editState,
                layout: printLayout,
                copies: 0,
                showsCropMarks: showsCropMarks,
                packingMode: packingMode,
                compactOptionID: selectedCompactOptionID
            )
            printImage = sheet
            exportData = renderer.exportData(image: sheet, format: exportFormat, targetKB: targetKB)
        }
    }

    private var compactOption: PhotoRenderer.CompactPrintOption? {
        compactOptions.first
    }

    private var compactOptions: [PhotoRenderer.CompactPrintOption] {
        renderer.compactPrintOptions(for: printLayout, spec: spec)
    }

    private func normalizePackingMode() {
        let options = compactOptions
        if packingMode == .safe {
            selectedCompactOptionID = options.first?.id
            return
        }
        if options.isEmpty {
            packingMode = .safe
            selectedCompactOptionID = nil
            return
        }
        if !options.contains(where: { $0.id == selectedCompactOptionID }) {
            selectedCompactOptionID = options.first?.id
        }
    }

    private func edgeText(for option: PhotoRenderer.CompactPrintOption) -> String {
        if option.fillsWidth && option.fillsHeight {
            return L10n.text(en: "No margins", zh: "四边无边距")
        }
        if option.fillsWidth {
            return L10n.text(en: "No side margins", zh: "左右无边距")
        }
        return L10n.text(en: "No top/bottom margins", zh: "上下无边距")
    }

    private func share() {
        guard let exportData else { return }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("visa-photo-\(UUID().uuidString)")
            .appendingPathExtension(fileExtension)

        do {
            try exportData.write(to: url, options: .atomic)
            shareItem = ExportShareItem(url: url)
            addCreationRecord()
        } catch {
            saveMessage = error.localizedDescription
            exportAlert = .failure(error.localizedDescription)
        }
    }

    private var fileExtension: String {
        switch exportFormat {
        case .jpg: return "jpg"
        case .heif: return "heic"
        case .png: return "png"
        case .pdf: return "pdf"
        }
    }

    private func exportToFiles() {
        guard let exportData else { return }
        fileExporterItem = ExportFileDocument(data: exportData)
    }

    private func icon(for severity: ComplianceSeverity) -> String {
        switch severity {
        case .pass: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .fail: return "xmark.circle.fill"
        }
    }

    private func color(for severity: ComplianceSeverity) -> Color {
        switch severity {
        case .pass: return AppTheme.success
        case .warning: return AppTheme.warning
        case .fail: return AppTheme.danger
        }
    }

    private func save(_ image: UIImage?) {
        guard let image else { return }
        if exportData == nil {
            exportData = renderer.exportData(image: image, format: exportFormat, targetKB: targetKB)
        }
        saver.save(image) { result in
            switch result {
            case .success:
                saveMessage = L10n.text(en: "Saved to Photos.", zh: "已保存到相册。")
                exportAlert = .success(shouldAskForRating: AppStoreReviewService.shouldPromptAfterSuccessfulExport())
                addCreationRecord()
            case .failure(let error):
                AppStoreReviewService.recordExportFailure()
                saveMessage = error.localizedDescription
                exportAlert = .failure(error.localizedDescription)
            }
        }
    }

    private func addCreationRecord() {
        guard !didAddCreationRecord else { return }
        didAddCreationRecord = true

        let id = UUID()
        let previewImage = printLayout == .digitalOnly ? digitalImage : printImage
        let imageData = previewImage?.jpegData(compressionQuality: 0.9)
        let assets = profile.saveRecordAssets(
            id: id,
            imageData: imageData,
            fileData: exportData,
            fileExtension: fileExtension
        )

        profile.addRecord(CreationRecord(
            id: id,
            title: spec.displayTitle,
            country: spec.displayCountry,
            format: exportFormat.rawValue,
            layout: printLayout.rawValue,
            imageFilename: assets.imageFilename,
            fileFilename: assets.fileFilename
        ))
    }
}

private struct ExportAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let showsRatingAction: Bool

    static func success(shouldAskForRating: Bool) -> ExportAlert {
        ExportAlert(
            title: L10n.text(en: "Export Complete", zh: "导出成功"),
            message: shouldAskForRating
                ? (L10n.text(en: "Your photo has been saved to Photos. If IDPhoto Pro helped, you can leave an honest rating.", zh: "照片已经保存到系统相册。如果这个工具帮到了你，可以留下真实评分。"))
                : (L10n.text(en: "Your photo has been saved to Photos.", zh: "照片已经保存到系统相册。")),
            showsRatingAction: shouldAskForRating
        )
    }

    static func filesSuccess(shouldAskForRating: Bool) -> ExportAlert {
        ExportAlert(
            title: L10n.text(en: "Export Complete", zh: "导出成功"),
            message: shouldAskForRating
                ? (L10n.text(en: "Your file has been saved. If IDPhoto Pro helped, you can leave an honest rating.", zh: "文件已经保存。如果这个工具帮到了你，可以留下真实评分。"))
                : (L10n.text(en: "Your file has been saved.", zh: "文件已经保存。")),
            showsRatingAction: shouldAskForRating
        )
    }

    static func failure(_ message: String) -> ExportAlert {
        ExportAlert(
            title: L10n.text(en: "Export Failed", zh: "导出失败"),
            message: message,
            showsRatingAction: false
        )
    }
}

private struct ExportShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

private struct ExportFileDocument: FileDocument {
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

private struct ExportLayoutOption: View {
    let layout: PrintLayout
    let isSelected: Bool
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 7) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(isSelected ? .white : AppTheme.ink)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(isSelected ? .white.opacity(0.82) : AppTheme.secondaryInk)
                        .lineLimit(1)
                }

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                }
            }
            .frame(height: 38)
            .padding(.horizontal, 10)
            .background(isSelected ? AppTheme.officialBlue : AppTheme.groupedBackground, in: Capsule())
            .overlay {
                Capsule()
                    .stroke(isSelected ? AppTheme.officialBlue.opacity(0.45) : AppTheme.border, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct CompactLayoutOption: View {
    let option: PhotoRenderer.CompactPrintOption
    let isSelected: Bool
    let edgeText: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "exclamationmark.triangle")
                        .foregroundStyle(isSelected ? AppTheme.officialBlue : AppTheme.warning)
                    Text(option.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.ink)
                }

                Text(L10n.text(en: "\(option.capacity) photos", zh: "\(option.capacity) 张照片"))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(AppTheme.secondaryInk)

                Text(edgeText)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(AppTheme.warning)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(isSelected ? AppTheme.officialBlue.opacity(0.08) : AppTheme.groupedBackground, in: RoundedRectangle(cornerRadius: 9))
            .overlay {
                RoundedRectangle(cornerRadius: 9)
                    .stroke(isSelected ? AppTheme.officialBlue.opacity(0.45) : AppTheme.border, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private struct ExportPreview: View {
    let title: String
    let subtitle: String
    let image: UIImage

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(AppTheme.ink)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryInk)
            }

            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .frame(maxHeight: 360)
                .background(AppTheme.groupedBackground, in: RoundedRectangle(cornerRadius: 8))
        }
        .padding(14)
        .professionalCard()
    }
}
