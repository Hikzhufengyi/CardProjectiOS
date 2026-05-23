import CoreImage
import CoreImage.CIFilterBuiltins
import PhotosUI
import SwiftUI
import UIKit

struct CreateView: View {
    @State private var selectedCategory: SpecCategory? = nil
    @State private var selectedCountry: String? = nil
    @State private var searchText = ""

    private var filteredSpecs: [PhotoSpec] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return PhotoSpec.catalog.filter { spec in
            let matchesCategory = selectedCategory == nil || spec.category == selectedCategory
            let matchesCountry = selectedCountry == nil || spec.country == selectedCountry
            let matchesSearch = query.isEmpty || spec.searchableText.contains(query)
            return matchesCategory && matchesCountry && matchesSearch
        }
    }

    private var popularCountries: [String] {
        var seen = Set<String>()
        let preferred = [
            "United States", "United Kingdom", "Canada", "Schengen Area", "European Union",
            "Australia", "China", "India", "Japan", "South Korea", "Singapore", "New Zealand"
        ]
        let preferredExisting = preferred.filter { country in
            PhotoSpec.catalog.contains { $0.country == country }
        }
        let remaining = PhotoSpec.catalog.map(\.country).filter { country in
            guard !preferredExisting.contains(country), !seen.contains(country) else { return false }
            seen.insert(country)
            return true
        }.sorted()
        return preferredExisting + remaining
    }

    private func localizedCountry(_ country: String) -> String {
        PhotoSpec.catalog.first { $0.country == country }?.displayCountry ?? country
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    searchField
                    specPicker
                }
                .padding(18)
            }
            .background(AppTheme.groupedBackground)
            .navigationTitle(L10n.text(L10n.document))
            .navigationBarTitleDisplayMode(.inline)
        }
        .tint(AppTheme.officialBlue)
        .background(AppTheme.groupedBackground.ignoresSafeArea())
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.text(en: "Choose Document Type", zh: "选择证件类型"))
                .font(.system(.largeTitle, design: .default, weight: .bold))
                .foregroundStyle(AppTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text(L10n.text(en: "Choose an official-size preset, then check, refine, compress, and export on device.", zh: "选择官方尺寸模板，在本地完成检测、换背景、压缩和 300 DPI 导出。"))
                .font(.subheadline)
                .foregroundStyle(AppTheme.secondaryInk)
            HStack(spacing: 8) {
                TrustPill(systemImage: "lock.shield.fill", text: L10n.text(en: "100% offline", zh: "本地离线处理"))
                TrustPill(systemImage: "checkmark.seal.fill", text: L10n.text(en: "One-time purchase", zh: "一次买断"))
            }
            .padding(.top, 4)
        }
        .padding(.top, 8)
    }

    private var searchField: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField(L10n.text(en: "Search country, visa, passport, or size", zh: "搜索国家、签证、护照或尺寸"), text: $searchText)
                    .textInputAutocapitalization(.never)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L10n.text(en: "Clear search", zh: "清空搜索"))
                }
            }
            .padding(12)
            .professionalCard()

            ZStack(alignment: .trailing) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        FilterChip(title: L10n.text(en: "All Countries", zh: "常用国家"), isSelected: selectedCountry == nil) {
                            selectedCountry = nil
                        }
                        ForEach(popularCountries.prefix(20), id: \.self) { country in
                            FilterChip(title: localizedCountry(country), isSelected: selectedCountry == country) {
                                selectedCountry = country
                            }
                        }
                    }
                    .padding(.trailing, 44)
                }

                MoreScrollHint()
            }
        }
    }

    private var specPicker: some View {
        VStack(alignment: .leading, spacing: 14) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    FilterChip(title: L10n.text(en: "All", zh: "全部"), isSelected: selectedCategory == nil) {
                        selectedCategory = nil
                    }
                    ForEach(SpecCategory.allCases) { category in
                        FilterChip(title: category.localizedTitle, isSelected: selectedCategory == category) {
                            selectedCategory = category
                        }
                    }
                }
            }

            if filteredSpecs.isEmpty {
                ContentUnavailableView(
                    L10n.text(en: "No Presets Found", zh: "没有找到规格"),
                    systemImage: "doc.text.magnifyingglass",
                    description: Text(L10n.text(en: "Try another keyword, or clear country/category filters.", zh: "换一个关键词，或清除国家/分类筛选。"))
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 34)
            } else {
                HStack {
                    Text(L10n.text(en: "\(filteredSpecs.count) presets", zh: "\(filteredSpecs.count) 个模板"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 158), spacing: 10)], spacing: 10) {
                    ForEach(filteredSpecs) { spec in
                        NavigationLink {
                            DocumentDetailView(spec: spec)
                        } label: {
                            SpecCard(spec: spec)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

private struct DocumentDetailView: View {
    let spec: PhotoSpec

    @Environment(\.dismiss) private var dismiss
    @State private var selectedBackground: PhotoBackground = .white
    @State private var inputImage: UIImage?
    @State private var processedImage: UIImage?
    @State private var photoAnalysis: PhotoAnalysis?
    @State private var complianceImage: UIImage?
    @State private var renderedAnalysis: PhotoAnalysis?
    @State private var editState: PhotoEditState = .default
    @State private var applyLightRepair = false
    @State private var repairIntensity: RepairIntensity = .balanced
    @State private var isAutoFixing = false
    @State private var isProcessingPhoto = false
    @State private var showingExport = false
    @State private var showingPaywall = false
    @State private var showingPrivacy = false
    @State private var showingCamera = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var gestureStartScale: CGFloat?
    @State private var gestureStartRotation: Double?
    @StateObject private var store = StoreService.shared
    private let complianceSectionID = "compliance-section"

    private let compliance = ComplianceService()
    private let faceService = FaceAnalysisService()
    private let backgroundService = BackgroundRemovalService()
    private let enhancementService = PhotoEnhancementService()
    private let renderer = PhotoRenderer()
    private var targetEyeHeightRatio: Double { 0.56 }
    private var targetBottomMarginRatio: Double { 0.12 }
    private var targetTopMarginRatio: Double { spec.minHeadRatio > 0.60 ? 0.05 : 0.07 }

    init(spec: PhotoSpec) {
        self.spec = spec
        self._selectedBackground = State(initialValue: spec.background.first ?? .white)
    }

    var result: ComplianceResult {
        compliance.evaluate(
            image: complianceImage ?? inputImage,
            spec: spec,
            selectedBackground: selectedBackground,
            analysis: renderedAnalysis ?? photoAnalysis
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            if inputImage != nil {
                stickyEditablePhotoPreview
            }

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: inputImage == nil ? 24 : 14) {
                        if inputImage == nil {
                            detailHeader
                        }
                        photoWorkspace
                        if inputImage != nil {
                            quickFixPanel {
                                applyAutomaticFixes()
                            } onDetails: {
                                scrollToComplianceDetails(proxy)
                            }
                        }
                        backgroundPicker
                        if inputImage != nil {
                            PrecisionAdjustSection(spec: spec, editState: $editState)
                        }
                        enhancementPanel
                        compliancePanel
                            .id(complianceSectionID)
                    }
                    .padding(18)
                    .padding(.bottom, 88)
                }
            }
        }
        .background(AppTheme.groupedBackground)
        .navigationTitle(spec.displayTitle)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(inputImage != nil)
        .toolbar(inputImage == nil ? .visible : .hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .tint(AppTheme.officialBlue)
        .safeAreaInset(edge: .bottom) {
            exportBottomBar
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingPrivacy = true
                } label: {
                    Image(systemName: "info.circle")
                }
            }
        }
        .sheet(isPresented: $showingExport) {
            ExportView(image: processedImage ?? inputImage, spec: spec, background: selectedBackground, analysis: renderedAnalysis ?? photoAnalysis, editState: editState, result: result)
        }
        .sheet(isPresented: $showingPaywall) {
            PaywallView(store: store) {
                showingExport = true
            }
        }
        .sheet(isPresented: $showingPrivacy) {
            PrivacyDisclaimerView()
        }
        .sheet(isPresented: $showingCamera) {
            CameraPicker(spec: spec, image: Binding(
                get: { inputImage },
                set: { newImage in
                    inputImage = newImage
                    if newImage != nil {
                        editState = .default
                    }
                }
            ))
            .ignoresSafeArea()
        }
        .onChange(of: selectedPhoto) { _, item in
            Task { await loadPhoto(from: item) }
        }
        .onChange(of: selectedBackground) { _, _ in
            Task { await processCurrentPhoto() }
        }
        .onChange(of: inputImage) { _, _ in
            Task { await processCurrentPhoto() }
        }
        .onChange(of: applyLightRepair) { _, _ in
            Task { await processCurrentPhoto() }
        }
        .onChange(of: editState) { _, _ in
            Task { await updateRenderedCompliance() }
        }
        .background(AppTheme.groupedBackground.ignoresSafeArea())
    }

    private func scrollToComplianceDetails(_ proxy: ScrollViewProxy) {
        withAnimation(.easeInOut(duration: 0.28)) {
            proxy.scrollTo(complianceSectionID, anchor: .top)
        }
    }

    private var stickyEditablePhotoPreview: some View {
        VStack(spacing: 8) {
            stickyEditorTopBar

            HStack {
                Spacer(minLength: 0)
                EditablePhotoPreview(
                    image: processedImage ?? inputImage,
                    spec: spec,
                    background: selectedBackground,
                    faceAnalysis: renderedAnalysis?.face,
                    editState: $editState,
                    isProcessing: isProcessingPhoto,
                    gestureStartScale: $gestureStartScale,
                    gestureStartRotation: $gestureStartRotation,
                    maxWidth: stickyPreviewWidth,
                    maxHeight: 350
                )
                Spacer(minLength: 0)
            }

            if inputImage != nil {
                Label(
                    L10n.text(en: "Drag to move · Pinch to zoom · Twist to rotate", zh: "拖动调整位置 · 双指缩放 · 双指旋转"),
                    systemImage: "hand.draw"
                )
                .font(.caption2.weight(.semibold))
                .foregroundStyle(AppTheme.secondaryInk)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 8)
            }

        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 6)
        .padding(.top, 6)
        .padding(.bottom, inputImage == nil ? 10 : 8)
        .background(AppTheme.cardBackground)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AppTheme.border)
                .frame(height: 1)
        }
    }

    private var stickyEditorTopBar: some View {
        HStack(spacing: 8) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.subheadline.weight(.bold))
                    .frame(width: 42, height: 38)
            }
            .buttonStyle(.plain)
            .foregroundStyle(AppTheme.officialBlue)
            .background(AppTheme.groupedBackground, in: RoundedRectangle(cornerRadius: 9))
            .accessibilityLabel(L10n.text(en: "Back", zh: "返回"))

            VStack(alignment: .leading, spacing: 1) {
                Text(spec.displayTitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.ink)
                    .lineLimit(1)
                Text("\(spec.displaySize) · \(spec.displayPixels)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(AppTheme.secondaryInk)
                    .lineLimit(1)
            }

            Spacer(minLength: 6)

            if let sourceURL = spec.sourceURL {
                Link(destination: sourceURL) {
                    Image(systemName: "safari")
                        .font(.subheadline.weight(.semibold))
                        .frame(width: 42, height: 38)
                }
                .buttonStyle(.plain)
                .foregroundStyle(AppTheme.officialBlue)
                .background(AppTheme.groupedBackground, in: RoundedRectangle(cornerRadius: 9))
                .accessibilityLabel(L10n.text(en: "Open official photo requirements", zh: "打开官方照片要求"))
            }

            Button {
                showingPrivacy = true
            } label: {
                Image(systemName: "info.circle")
                    .font(.subheadline.weight(.semibold))
                    .frame(width: 42, height: 38)
            }
            .buttonStyle(.plain)
            .foregroundStyle(AppTheme.officialBlue)
            .background(AppTheme.groupedBackground, in: RoundedRectangle(cornerRadius: 9))
            .accessibilityLabel(L10n.text(en: "Privacy and disclaimer", zh: "隐私和说明"))
        }
        .frame(maxWidth: .infinity)
    }

    private var stickyPreviewWidth: CGFloat {
        let availableWidth = UIScreen.main.bounds.width - 24
        return min(availableWidth, 350)
    }

    private var detailHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(spec.displayTitle)
                .font(.system(.title, design: .default, weight: .bold))
                .foregroundStyle(AppTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text("\(spec.displayCountry) · \(spec.displaySize) · \(spec.displayPixels)")
                .font(.subheadline)
                .foregroundStyle(AppTheme.secondaryInk)
            if let maxFileKB = spec.maxFileKB {
                Label(L10n.text(en: "Recommended file under \(maxFileKB) KB", zh: "建议文件小于 \(maxFileKB) KB"), systemImage: "archivebox")
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryInk)
            }
            if let sourceURL = spec.sourceURL {
                Link(destination: sourceURL) {
                    Label(L10n.text(en: "Official photo requirements - open website", zh: "官方照片要求 - 打开官网查看"), systemImage: "safari")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.officialBlue)
                }
                .accessibilityHint(L10n.text(en: "Opens the official requirement page outside the app", zh: "将在 App 外打开官方要求页面"))
            } else {
                Label(L10n.text(en: "Checks are based on official published photo requirements. Review the official source before submission.", zh: "检测基于官方公开照片要求，提交前请核对官方网站。"), systemImage: "shield.lefthalf.filled")
                    .font(.caption)
                    .foregroundStyle(AppTheme.officialBlue)
            }
            HStack(spacing: 8) {
                ForEach(spec.background) { background in
                    Label(background.localizedName, systemImage: "circle.fill")
                        .font(.caption)
                        .foregroundStyle(background.color == .white ? AppTheme.secondaryInk : background.color)
                }
            }
        }
        .padding(.top, 8)
    }

    private var photoWorkspace: some View {
        VStack(alignment: .leading, spacing: inputImage == nil ? 10 : 0) {
            if inputImage == nil {
                SectionTitle(title: L10n.text(L10n.photo))
                PhotoPreview(image: processedImage ?? inputImage, spec: spec, background: selectedBackground, faceAnalysis: renderedAnalysis?.face, editState: editState, isProcessing: isProcessingPhoto)
                    .frame(maxWidth: .infinity)
            }

            HStack(spacing: 8) {
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    CompactActionButton(title: L10n.text(en: "Album", zh: "相册"), systemImage: "photo.stack.fill")
                }
                .buttonStyle(.plain)

                Button {
                    showingCamera = true
                } label: {
                    CompactActionButton(title: L10n.text(L10n.camera), systemImage: "camera.fill")
                }
                .buttonStyle(.plain)
            }
            .padding(inputImage == nil ? 10 : 8)
            .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 10))
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(AppTheme.border, lineWidth: 1)
            }
        }
    }

    private var backgroundPicker: some View {
        HStack(spacing: 8) {
            Image(systemName: "circle.lefthalf.filled")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.officialBlue)

            Text(L10n.text(L10n.background))
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.ink)
                .lineLimit(1)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    ForEach(spec.background) { background in
                        Button {
                            selectedBackground = background
                        } label: {
                            HStack(spacing: 5) {
                                Circle()
                                    .fill(background.color)
                                    .stroke(selectedBackground == background ? AppTheme.officialBlue : AppTheme.border, lineWidth: 1.5)
                                    .frame(width: 16, height: 16)
                                Text(background.localizedName)
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(selectedBackground == background ? AppTheme.officialBlue : AppTheme.secondaryInk)
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 8)
                            .frame(height: 26)
                            .background(selectedBackground == background ? AppTheme.officialBlue.opacity(0.08) : AppTheme.cardBackground, in: Capsule())
                            .overlay {
                                Capsule()
                                    .stroke(selectedBackground == background ? AppTheme.officialBlue.opacity(0.34) : AppTheme.border, lineWidth: 1)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 1)
            }
        }
        .frame(height: 34)
    }

    private var enhancementPanel: some View {
        VStack(alignment: .leading, spacing: inputImage == nil ? 12 : 8) {
            if inputImage == nil {
                SectionTitle(title: L10n.text(L10n.enhance))
            }

            Toggle(isOn: $applyLightRepair) {
                VStack(alignment: .leading, spacing: 2) {
                    Label(L10n.text(L10n.lightRepair), systemImage: "sun.max")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.ink)
                    Text(L10n.text(en: "Light brightness and sharpness repair only", zh: "仅做轻度亮度和清晰度修复"))
                        .font(.caption2)
                        .foregroundStyle(AppTheme.secondaryInk)
                        .lineLimit(1)
                }
            }
            .tint(AppTheme.officialBlue)
            .padding(inputImage == nil ? 12 : 10)
            .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 10))
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(AppTheme.border, lineWidth: 1)
            }
        }
    }

    private var compliancePanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            ReadyCard(result: result)

            VStack(spacing: 10) {
                if !result.blockingChecks.isEmpty || !result.warnings.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Label(L10n.text(en: "Issues to Review", zh: "需要处理的问题"), systemImage: "exclamationmark.triangle.fill")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.ink)
                            Spacer(minLength: 0)
                            Text(compactComplianceCountText)
                                .font(.caption2.monospacedDigit().weight(.bold))
                                .foregroundStyle(compactComplianceColor)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(compactComplianceColor.opacity(0.10), in: Capsule())
                        }
                        ForEach((result.blockingChecks + result.warnings).prefix(5)) { check in
                            if let action = check.action {
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: check.severity == .fail ? "xmark.circle.fill" : "exclamationmark.triangle.fill")
                                        .foregroundStyle(check.severity == .fail ? AppTheme.danger : AppTheme.warning)
                                    Text(action)
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.secondaryInk)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }
                    .padding(10)
                    .background(AppTheme.groupedBackground, in: RoundedRectangle(cornerRadius: 8))
                }

                ForEach(result.checks) { check in
                    ComplianceRow(check: check) {
                        applyFix(for: check)
                    }
                }
            }
            .padding(12)
            .professionalCard()
        }
    }

    private var compactComplianceSummary: some View {
        HStack(spacing: 10) {
            Image(systemName: compactComplianceIcon)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(compactComplianceColor)

            VStack(alignment: .leading, spacing: 4) {
                Text(compactComplianceTitle)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppTheme.ink)
                if isProcessingPhoto {
                    Text(L10n.text(en: "Checking face, background, sharpness, and head proportion...", zh: "正在分析人脸、背景、清晰度和头部比例..."))
                        .font(.caption2)
                        .foregroundStyle(AppTheme.secondaryInk)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                } else if compactIssueChecks.isEmpty {
                    Text(primaryComplianceHint)
                        .font(.caption2)
                        .foregroundStyle(AppTheme.secondaryInk)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                } else {
                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(compactIssueChecks.prefix(2)) { check in
                            HStack(spacing: 4) {
                                Image(systemName: check.severity == .fail ? "xmark.circle.fill" : "exclamationmark.triangle.fill")
                                    .font(.caption2)
                                    .foregroundStyle(check.severity == .fail ? AppTheme.danger : AppTheme.warning)
                                Text(check.title)
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(AppTheme.ink)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.78)
                            }
                        }
                    }
                }
            }

            Spacer(minLength: 8)

            Text(compactComplianceCountText)
                .font(.headline.monospacedDigit().weight(.bold))
                .foregroundStyle(compactComplianceColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(compactComplianceColor.opacity(0.10), in: Capsule())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(AppTheme.border, lineWidth: 1)
        }
    }

    private var compactComplianceTitle: String {
        if isProcessingPhoto {
            return L10n.text(en: "Checking Photo", zh: "正在检测照片")
        }
        if !result.blockingChecks.isEmpty {
            return L10n.text(en: "Fix Required", zh: "必须修复")
        }
        if !result.warnings.isEmpty {
            return L10n.text(en: "Warnings Found", zh: "存在警告")
        }
        return L10n.text(en: "Ready to Export", zh: "照片已接近可导出")
    }

    private var autoFixButtonTitle: String {
        if isAutoFixing {
            return L10n.text(en: "Optimizing...", zh: "正在智能校准...")
        }
        if result.isFullyPassed {
            return L10n.text(en: "Refine Photo", zh: "继续精修")
        }
        return L10n.text(en: "1-Click Smart Fix", zh: "一键智能修复")
    }

    private func quickFixPanel(onFix: @escaping () -> Void, onDetails: @escaping () -> Void) -> some View {
        HStack(spacing: 8) {
            Button(action: onDetails) {
                compactComplianceSummary
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.text(en: "View compliance details", zh: "查看合规详情"))

            Button(action: onFix) {
                Image(systemName: isAutoFixing ? "progress.indicator" : "wand.and.stars")
                    .font(.subheadline.weight(.bold))
                    .frame(width: 38, height: 38)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .background(AppTheme.officialBlue, in: RoundedRectangle(cornerRadius: 9))
            .disabled(isProcessingPhoto || isAutoFixing)
            .opacity(isProcessingPhoto || isAutoFixing ? 0.58 : 1)
            .accessibilityLabel(autoFixButtonTitle)
        }
    }

    private var compactIssueChecks: [ComplianceCheck] {
        result.blockingChecks + result.warnings
    }

    private var compactComplianceIcon: String {
        if isProcessingPhoto { return "progress.indicator" }
        if !result.blockingChecks.isEmpty { return "xmark.octagon.fill" }
        if !result.warnings.isEmpty { return "exclamationmark.triangle.fill" }
        return "checkmark.seal.fill"
    }

    private var compactComplianceColor: Color {
        if isProcessingPhoto { return AppTheme.officialBlue }
        if !result.blockingChecks.isEmpty { return AppTheme.danger }
        if !result.warnings.isEmpty { return AppTheme.warning }
        return AppTheme.success
    }

    private var compactComplianceCountText: String {
        if isProcessingPhoto { return "..." }
        let failCount = result.blockingChecks.count
        let warningCount = result.warnings.count
        if failCount > 0 {
            return L10n.text(en: "\(failCount) fail", zh: "\(failCount) 项失败")
        }
        if warningCount > 0 {
            return L10n.text(en: "\(warningCount) warn", zh: "\(warningCount) 项警告")
        }
        return "\(result.score)%"
    }

    private var primaryComplianceHint: String {
        if result.isFullyPassed {
            return L10n.text(en: "Size, background, and head proportion checks passed.", zh: "尺寸、背景和头部比例检查通过。")
        }
        if let action = (result.blockingChecks + result.warnings).compactMap(\.action).first {
            return action
        }
        return L10n.text(en: "Review the checklist below for final adjustments.", zh: "查看下方检查清单完成最后调整。")
    }

    private var exportBottomBar: some View {
        VStack(spacing: 0) {
            exportButton
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .background(AppTheme.cardBackground)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(AppTheme.border)
                .frame(height: 1)
        }
    }

    private var exportButton: some View {
        Button {
            Task {
                await store.updatePurchases()
                if store.hasProAccess {
                    showingExport = true
                } else {
                    showingPaywall = true
                }
            }
        } label: {
            Label(exportButtonTitle, systemImage: result.isFullyPassed ? "checkmark.circle.fill" : "square.and.arrow.down")
                .font(.headline.weight(.bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .background(AppTheme.officialBlue, in: RoundedRectangle(cornerRadius: 10))
        .shadow(color: AppTheme.officialBlue.opacity(inputImage == nil ? 0 : 0.30), radius: 12, x: 0, y: 5)
        .opacity(inputImage == nil || store.isPurchasing ? 0.48 : 1)
        .disabled(inputImage == nil || store.isPurchasing)
    }

    private var exportButtonTitle: String {
        if result.isFullyPassed {
            return L10n.text(en: "Ready - Export to Photos", zh: "合规照片，导出到相册")
        }
        return L10n.text(en: "Export to Photos", zh: "导出到相册")
    }

    private func loadPhoto(from item: PhotosPickerItem?) async {
        guard let data = try? await item?.loadTransferable(type: Data.self),
              let loaded = UIImage(data: data) else {
            return
        }
        inputImage = loaded.preparedForIDPhotoProcessing()
        editState = .default
    }

    private func processCurrentPhoto() async {
        guard let inputImage else {
            processedImage = nil
            photoAnalysis = nil
            complianceImage = nil
            renderedAnalysis = nil
            return
        }

        isProcessingPhoto = true
        var workingImage = inputImage
        if applyLightRepair {
            workingImage = enhancementService.repair(workingImage, intensity: repairIntensity)
        }

        photoAnalysis = (try? await faceService.analyze(workingImage)) ?? nil
        processedImage = (try? await backgroundService.extractForeground(in: workingImage)) ?? workingImage
        await updateRenderedCompliance()
        isProcessingPhoto = false
    }

    private func applyAutomaticFixes() {
        Task { await applyAutomaticFixesIteratively() }
    }

    private func applyAutomaticFixesIteratively() async {
        guard !isAutoFixing else { return }
        isAutoFixing = true
        defer { isAutoFixing = false }

        if let preferredBackground = spec.background.first, !spec.background.contains(selectedBackground) {
            selectedBackground = preferredBackground
        }

        applyLightRepair = true
        repairIntensity = result.score < 82 ? .stronger : .balanced

        var bestState = editState
        var bestResult = result
        var bestScore = guideWeightedScore(for: result, analysis: renderedAnalysis ?? photoAnalysis)
        var bestAnalysis = renderedAnalysis ?? photoAnalysis

        for round in 0..<3 {
            let candidateSeeds = framingCandidateSeeds(from: bestState, analysis: bestAnalysis)
            var improved = false

            for (index, seed) in candidateSeeds.enumerated() {
                var candidate = seed
                let pass = min(round + index, 5)
                candidate = adjustedQualityCandidate(candidate, quality: bestAnalysis?.quality, pass: pass)

                if let face = bestAnalysis?.face {
                    candidate = correctedFraming(candidate, face: face, pass: pass)
                }

                let evaluation = await evaluateCandidate(candidate)
                let candidateScore = guideWeightedScore(for: evaluation.result, analysis: evaluation.analysis)
                if isViableFramingCandidate(evaluation.analysis),
                   candidateScore > bestScore || (candidateScore == bestScore && evaluation.result.score > bestResult.score) {
                    bestState = candidate
                    bestResult = evaluation.result
                    bestScore = candidateScore
                    bestAnalysis = evaluation.analysis
                    improved = true
                }

                if isViableFramingCandidate(evaluation.analysis),
                   isStrictGuideAligned(evaluation.result, analysis: evaluation.analysis) {
                    bestState = candidate
                    bestAnalysis = evaluation.analysis
                    improved = true
                    break
                }
            }

            if isStrictGuideAligned(bestResult, analysis: bestAnalysis) || !improved {
                break
            }
        }

        bestState = await finalGuideCenteredState(from: bestState, analysis: bestAnalysis)
        editState = bestState
        await processCurrentPhoto()
    }

    private func finalGuideCenteredState(from state: PhotoEditState, analysis: PhotoAnalysis?) async -> PhotoEditState {
        var currentState = state
        var currentAnalysis = analysis

        for pass in 0..<2 {
            guard let face = currentAnalysis?.face else { break }
            if isStrictGuideAligned(
                compliance.evaluate(
                    image: complianceImage ?? inputImage,
                    spec: spec,
                    selectedBackground: selectedBackground,
                    analysis: currentAnalysis
                ),
                analysis: currentAnalysis
            ) {
                break
            }

            var candidate = correctedFraming(currentState, face: face, pass: 5 + pass)
            if face.effectiveCenterOffsetRatio > 0.008 || !face.visualAndFaceCentersAgree {
                candidate.offset.width += horizontalCorrection(for: face, pass: 6)
            }
            if let eyeHeight = face.eyeHeightRatio, abs(eyeHeight - targetEyeHeightRatio) > 0.012 {
                candidate.offset.height += verticalCorrection(for: face, pass: 6)
            }

            let evaluation = await evaluateCandidate(candidate)
            if isViableFramingCandidate(evaluation.analysis),
               guideWeightedScore(for: evaluation.result, analysis: evaluation.analysis) >= guideWeightedScore(
                for: compliance.evaluate(
                    image: complianceImage ?? inputImage,
                    spec: spec,
                    selectedBackground: selectedBackground,
                    analysis: currentAnalysis
                ),
                analysis: currentAnalysis
            ) {
                currentState = candidate
                currentAnalysis = evaluation.analysis
            } else {
                break
            }
        }

        return currentState
    }

    private func adjustedQualityCandidate(_ state: PhotoEditState, quality: ImageQualityAnalysis?, pass: Int) -> PhotoEditState {
        var candidate = state
        if quality?.isTooBright == true {
            candidate.brightness = max(min(candidate.brightness, pass >= 2 ? -0.04 : -0.02), -0.09)
            candidate.shadows = max(min(candidate.shadows, 0.0), -0.03)
            candidate.contrast = min(max(candidate.contrast, 0.98), 1.08)
        } else if quality?.isTooDark == true {
            candidate.brightness = min(max(candidate.brightness, pass >= 2 ? 0.045 : 0.025), 0.075)
            candidate.shadows = min(max(candidate.shadows, pass >= 2 ? 0.06 : 0.035), 0.09)
            candidate.contrast = min(max(candidate.contrast, pass >= 2 ? 1.07 : 1.04), 1.12)
        } else {
            candidate.brightness = clamped(candidate.brightness, min: -0.025, max: 0.035)
            candidate.shadows = clamped(candidate.shadows, min: -0.02, max: 0.045)
            candidate.contrast = min(max(candidate.contrast, 1.02), 1.10)
        }
        candidate.saturation = min(max(candidate.saturation, 1.01), 1.05)
        candidate.sharpness = min(max(candidate.sharpness, pass >= 2 ? 0.62 : 0.42), 0.85)
        candidate.warmth = abs(candidate.warmth) < 0.02 ? 0.02 : clamped(candidate.warmth, min: -0.05, max: 0.05)
        return candidate
    }

    private func framingCandidateSeeds(from baseState: PhotoEditState, analysis: PhotoAnalysis?) -> [PhotoEditState] {
        guard let face = analysis?.face else { return [baseState] }
        var candidates: [PhotoEditState] = [baseState]

        let targetHeadRatios = [
            (spec.minHeadRatio + spec.maxHeadRatio) / 2,
            spec.minHeadRatio + (spec.maxHeadRatio - spec.minHeadRatio) * 0.42,
            spec.minHeadRatio + (spec.maxHeadRatio - spec.minHeadRatio) * 0.58
        ]

        for targetHeadRatio in targetHeadRatios {
            var candidate = baseState
            let scaleFactor = targetHeadRatio / max(face.effectiveHeadHeightRatio, 0.01)
            candidate.scale = clamped(candidate.scale * clamped(scaleFactor, min: 0.78, max: 1.28), min: 0.62, max: 2.80)
            candidates.append(candidate)
        }

        for verticalBias in [-42.0, -28.0, -14.0, 0.0, 14.0, 28.0, 42.0] {
            var candidate = correctedFraming(baseState, face: face, pass: 3)
            candidate.offset.height += verticalBias
            candidates.append(candidate)
        }

        if let eyeHeight = face.eyeHeightRatio {
            for targetEyeHeight in [0.535, 0.55, targetEyeHeightRatio, 0.575, 0.585] {
                var candidate = correctedFraming(baseState, face: face, pass: 4)
                candidate.offset.height += CGFloat(eyeHeight - targetEyeHeight) * spec.pixelSize.height * 0.78
                candidates.append(candidate)
            }
        }

        for topMarginTarget in [targetTopMarginRatio, targetTopMarginRatio + 0.02, targetTopMarginRatio + 0.04] {
            var candidate = correctedFraming(baseState, face: face, pass: 4)
            candidate.offset.height += CGFloat(topMarginTarget - face.effectiveTopMarginRatio) * spec.pixelSize.height * 0.72
            candidates.append(candidate)
        }

        for bottomMarginTarget in [0.10, targetBottomMarginRatio, 0.14] {
            var candidate = correctedFraming(baseState, face: face, pass: 4)
            candidate.offset.height -= CGFloat(bottomMarginTarget - face.effectiveBottomMarginRatio) * spec.pixelSize.height * 0.70
            candidates.append(candidate)
        }

        for horizontalBias in [-54.0, -36.0, -18.0, 0.0, 18.0, 36.0, 54.0] {
            var candidate = correctedFraming(baseState, face: face, pass: 4)
            candidate.offset.width += horizontalBias
            candidates.append(candidate)
        }

        return candidates
    }

    private func correctedFraming(_ state: PhotoEditState, face: FaceAnalysis, pass: Int) -> PhotoEditState {
        var fixed = state
        let targetHeadRatio = targetGuideHeadRatio
        let scaleFactor = targetHeadRatio / max(face.effectiveHeadHeightRatio, 0.01)
        let scaleTolerance = pass >= 2 ? 0.018 : 0.030
        let clampedScaleFactor = clamped(scaleFactor, min: pass >= 2 ? 0.78 : 0.88, max: pass >= 2 ? 1.26 : 1.14)
        if abs(face.effectiveHeadHeightRatio - targetHeadRatio) > scaleTolerance {
            fixed.scale = clamped(fixed.scale * clampedScaleFactor, min: 0.62, max: 2.80)
        }

        fixed.offset.width += horizontalCorrection(for: face, pass: pass)
        fixed.offset.height += verticalCorrection(for: face, pass: pass)
        fixed.offset = boundedOffset(fixed.offset, scale: fixed.scale)

        if abs(face.rollDegrees) >= 2.2 && abs(face.rollDegrees) < 18 {
            fixed.rotationDegrees = clamped(fixed.rotationDegrees - face.rollDegrees * (pass >= 2 ? 0.88 : 0.62), min: -20, max: 20)
        }

        return fixed
    }

    private func horizontalCorrection(for face: FaceAnalysis, pass: Int) -> CGFloat {
        let targetWidth = max(spec.pixelSize.width, 1)
        let gain = pass >= 2 ? 1.24 : 0.92
        let correction = -face.effectiveSignedCenterOffsetRatio * targetWidth * gain
        let limit = targetWidth * (pass >= 2 ? 0.28 : 0.18)
        return CGFloat(clamped(correction, min: -limit, max: limit))
    }

    private func verticalCorrection(for face: FaceAnalysis, pass: Int) -> CGFloat {
        let targetHeight = max(spec.pixelSize.height, 1)
        let gain = pass >= 2 ? 0.92 : 0.68
        var correction = 0.0

        if let eyeHeight = face.eyeHeightRatio {
            correction += (eyeHeight - targetEyeHeightRatio) * targetHeight * gain
        }

            if face.effectiveTopMarginRatio < targetTopMarginRatio {
                correction += (targetTopMarginRatio - face.effectiveTopMarginRatio) * targetHeight * 0.80
            }

            if face.effectiveBottomMarginRatio < targetBottomMarginRatio {
                correction -= (targetBottomMarginRatio - face.effectiveBottomMarginRatio) * targetHeight * 0.88
            } else if face.effectiveBottomMarginRatio > 0.18 {
                correction += (face.effectiveBottomMarginRatio - 0.16) * targetHeight * 0.42
            }

        let limit = targetHeight * (pass >= 2 ? 0.16 : 0.11)
        return CGFloat(clamped(correction, min: -limit, max: limit))
    }

    private func boundedOffset(_ offset: CGSize, scale: CGFloat) -> CGSize {
        let widthLimit = spec.pixelSize.width * max(0.18, min(0.34, 0.26 * Double(scale)))
        let heightLimit = spec.pixelSize.height * max(0.14, min(0.26, 0.20 * Double(scale)))
        return CGSize(
            width: CGFloat(clamped(Double(offset.width), min: -widthLimit, max: widthLimit)),
            height: CGFloat(clamped(Double(offset.height), min: -heightLimit, max: heightLimit))
        )
    }

    private var targetGuideHeadRatio: Double {
        let midpoint = (spec.minHeadRatio + spec.maxHeadRatio) / 2
        return clamped(midpoint, min: spec.minHeadRatio + 0.015, max: spec.maxHeadRatio - 0.015)
    }

    private func guideWeightedScore(for result: ComplianceResult, analysis: PhotoAnalysis?) -> Int {
        var score = result.score * 10
        let criticalKinds: Set<ComplianceIssueKind> = [.headSize, .faceCentered, .headTilt, .eyeHeight, .topMargin]
        for check in result.checks where criticalKinds.contains(check.kind ?? .format) {
            switch check.severity {
            case .pass:
                score += 24
            case .warning:
                score -= 45
            case .fail:
                score -= 120
            }
        }

        if let face = analysis?.face {
            if !isViableFramingCandidate(analysis) {
                score -= 2000
            }
            score -= Int(face.effectiveCenterOffsetRatio * 1800)
            if !face.visualAndFaceCentersAgree {
                score -= 520
            }
            score -= Int(abs(face.effectiveHeadHeightRatio - targetGuideHeadRatio) * 920)
            score -= Int(abs(face.rollDegrees) * 14)
            if let eyeHeight = face.eyeHeightRatio {
                score -= Int(abs(eyeHeight - targetEyeHeightRatio) * 640)
            }
            if face.effectiveTopMarginRatio < targetTopMarginRatio {
                score -= Int((targetTopMarginRatio - face.effectiveTopMarginRatio) * 1200)
            }
            if face.effectiveBottomMarginRatio < 0.10 {
                score -= Int((0.10 - face.effectiveBottomMarginRatio) * 1500)
            }
            score -= Int(abs(face.effectiveVerticalCenterOffsetRatio) * 1100)
        }
        return score
    }

    private func isViableFramingCandidate(_ analysis: PhotoAnalysis?) -> Bool {
        guard let face = analysis?.face else { return false }
        guard analysis?.faceCount == 1 else { return false }
        guard face.faceRect.minY > 0.015, face.faceRect.maxY < 0.985 else { return false }
        guard face.effectiveTopMarginRatio >= 0.025, face.effectiveBottomMarginRatio >= 0.055 else { return false }
        guard face.eyeHeightRatio.map({ $0 >= 0.44 && $0 <= 0.70 }) ?? false else { return false }
        guard face.effectiveCenterOffsetRatio <= FaceAnalysis.centerWarningThreshold else { return false }
        guard face.visualAndFaceCentersAgree else { return false }
        return true
    }

    private func isStrictGuideAligned(_ result: ComplianceResult, analysis: PhotoAnalysis?) -> Bool {
        let criticalKinds: Set<ComplianceIssueKind> = [.headSize, .faceCentered, .headTilt, .eyeHeight, .topMargin]
        let hasCriticalIssue = result.checks.contains { check in
            criticalKinds.contains(check.kind ?? .format) && check.severity != .pass
        }
        guard !hasCriticalIssue, let face = analysis?.face else { return false }
        let eyeAligned = face.eyeHeightRatio.map { $0 >= 0.535 && $0 <= 0.585 } ?? false
        return face.isCentered
            && face.isVerticallyCenteredInGuide
            && abs(face.rollDegrees) <= 3.5
            && abs(face.effectiveHeadHeightRatio - targetGuideHeadRatio) <= max((spec.maxHeadRatio - spec.minHeadRatio) * 0.30, 0.024)
            && face.effectiveTopMarginRatio >= targetTopMarginRatio
            && face.effectiveBottomMarginRatio >= 0.10
            && eyeAligned
    }

    private func evaluateCandidate(_ candidate: PhotoEditState) async -> (result: ComplianceResult, analysis: PhotoAnalysis?) {
        guard let sourceImage = processedImage ?? inputImage else {
            return (result, renderedAnalysis ?? photoAnalysis)
        }

        let rendered = renderer.render(image: sourceImage, spec: spec, background: selectedBackground, faceAnalysis: photoAnalysis?.face, editState: candidate)
        let candidateAnalysis = (try? await faceService.analyze(rendered)) ?? nil
        let candidateResult = compliance.evaluate(
            image: rendered,
            spec: spec,
            selectedBackground: selectedBackground,
            analysis: candidateAnalysis
        )
        return (candidateResult, candidateAnalysis)
    }

    private func applyFix(for check: ComplianceCheck) {
        guard let kind = check.kind else { return }
        if kind == .background, let preferredBackground = spec.background.first {
            selectedBackground = preferredBackground
        }

        var fixed = editState
        switch kind {
        case .background:
            break
        case .lighting:
            let quality = (renderedAnalysis ?? photoAnalysis)?.quality
            if quality?.isTooBright == true {
                applyLightRepair = false
                repairIntensity = .balanced
                fixed.brightness = max(min(fixed.brightness, -0.035), -0.09)
                fixed.contrast = min(max(fixed.contrast, 0.98), 1.08)
                fixed.shadows = max(min(fixed.shadows, 0.0), -0.03)
            } else {
                applyLightRepair = true
                repairIntensity = .balanced
                fixed.brightness = min(max(fixed.brightness, 0.035), 0.075)
                fixed.contrast = min(max(fixed.contrast, 1.06), 1.12)
                fixed.shadows = min(max(fixed.shadows, 0.05), 0.09)
            }
            fixed.warmth = abs(fixed.warmth) < 0.02 ? 0.02 : clamped(fixed.warmth, min: -0.05, max: 0.05)
        case .backgroundShadows:
            if let preferredBackground = spec.background.first {
                selectedBackground = preferredBackground
            }
            applyLightRepair = false
            repairIntensity = .balanced
            fixed.brightness = min(fixed.brightness, 0.025)
            fixed.shadows = min(fixed.shadows, 0.035)
            fixed.contrast = min(max(fixed.contrast, 1.02), 1.08)
            fixed.sharpness = min(max(fixed.sharpness, 0.34), 0.62)
        case .sharpness:
            applyLightRepair = true
            repairIntensity = .balanced
            fixed.sharpness = min(max(fixed.sharpness, 0.72), 0.95)
            fixed.contrast = min(max(fixed.contrast, 1.05), 1.12)
        case .headSize, .format:
            if let face = (renderedAnalysis ?? photoAnalysis)?.face {
                fixed = correctedFraming(fixed, face: face, pass: 4)
            }
        case .faceCentered, .eyeHeight, .topMargin:
            if let face = (renderedAnalysis ?? photoAnalysis)?.face {
                fixed = correctedFraming(fixed, face: face, pass: 4)
            }
        case .headTilt:
            if let face = (renderedAnalysis ?? photoAnalysis)?.face, abs(face.rollDegrees) < 18 {
                fixed.rotationDegrees = clamped(fixed.rotationDegrees - face.rollDegrees * 0.88, min: -20, max: 20)
            }
        case .resolution, .singlePerson, .eyesVisible, .expression, .faceDetection, .fileSize:
            break
        }

        editState = fixed
        Task { await processCurrentPhoto() }
    }

    private func clamped(_ value: Double, min minValue: Double, max maxValue: Double) -> Double {
        Swift.min(Swift.max(value, minValue), maxValue)
    }

    private func updateRenderedCompliance() async {
        guard let sourceImage = processedImage ?? inputImage else {
            complianceImage = nil
            renderedAnalysis = nil
            return
        }

        let rendered = renderer.render(image: sourceImage, spec: spec, background: selectedBackground, faceAnalysis: photoAnalysis?.face, editState: editState)
        complianceImage = rendered
        renderedAnalysis = (try? await faceService.analyze(rendered)) ?? nil
    }
}

private struct SectionTitle: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(AppTheme.ink)
    }
}

private struct CompactActionButton: View {
    let title: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 9) {
            ZStack {
                Circle()
                    .fill(AppTheme.officialBlue)
                    .frame(width: 30, height: 30)
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
            }

            Text(title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .foregroundStyle(AppTheme.officialBlue)
        .frame(maxWidth: .infinity, minHeight: 42)
        .padding(.horizontal, 10)
        .background(AppTheme.officialBlue.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(AppTheme.officialBlue.opacity(0.18), lineWidth: 1)
        }
    }
}

private struct TrustPill: View {
    let systemImage: String
    let text: String

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(.caption.weight(.bold))
            .foregroundStyle(AppTheme.officialBlue)
            .lineLimit(1)
            .minimumScaleFactor(0.78)
            .padding(.horizontal, 10)
            .frame(height: 28)
            .background(AppTheme.officialBlue.opacity(0.08), in: Capsule())
            .overlay {
                Capsule()
                    .stroke(AppTheme.officialBlue.opacity(0.18), lineWidth: 1)
            }
    }
}

private struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(isSelected ? AppTheme.officialBlue : AppTheme.cardBackground, in: Capsule())
                .foregroundStyle(isSelected ? .white : AppTheme.ink)
                .overlay {
                    Capsule()
                        .stroke(isSelected ? AppTheme.officialBlue.opacity(0) : AppTheme.border, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
    }
}

private struct MoreScrollHint: View {
    var body: some View {
        HStack(spacing: 0) {
            LinearGradient(
                colors: [AppTheme.groupedBackground.opacity(0), AppTheme.groupedBackground],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: 28)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.officialBlue)
                .frame(width: 30, height: 30)
                .background(AppTheme.cardBackground, in: Circle())
                .overlay {
                    Circle()
                        .stroke(AppTheme.border, lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 3)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct SpecCard: View {
    let spec: PhotoSpec

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .top) {
                Text(spec.displayTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                Spacer(minLength: 6)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }

            Text(spec.displayCountry)
                .font(.caption)
                .foregroundStyle(AppTheme.secondaryInk)

            Spacer(minLength: 0)

            HStack {
                Text(spec.displaySize)
                Spacer()
                Text(spec.displayPixels)
            }
            .font(.caption2.monospacedDigit())
            .foregroundStyle(AppTheme.secondaryInk)
        }
        .frame(height: 110)
        .padding(12)
        .professionalCard()
    }
}

private struct PhotoPreview: View {
    let image: UIImage?
    let spec: PhotoSpec
    let background: PhotoBackground
    let faceAnalysis: FaceAnalysis?
    let editState: PhotoEditState
    let isProcessing: Bool
    var maxWidth: CGFloat = 300
    var maxHeight: CGFloat = 390
    var showsShadow: Bool = true
    @State private var previewImage: UIImage?
    private let previewFilter = TonePreviewFilter()

    var body: some View {
        ZStack {
            background.color
            if let image {
                Image(uiImage: previewImage ?? image)
                    .resizable()
                    .scaledToFill()
                    .scaleEffect(editState.scale)
                    .rotationEffect(.degrees(editState.rotationDegrees))
                    .offset(editState.offset)
                    .frame(width: previewSize.width, height: previewSize.height)
                    .clipped()
                    .opacity(0.96)
            } else {
                PassportPhotoPlaceholderGuide()
            }

            guideOverlay

            if isProcessing {
                ProgressView()
                    .padding(12)
                    .background(.thinMaterial, in: Capsule())
            }
        }
        .frame(width: previewSize.width, height: previewSize.height)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        }
        .shadow(color: .black.opacity(showsShadow ? 0.08 : 0), radius: showsShadow ? 14 : 0, x: 0, y: showsShadow ? 8 : 0)
        .task(id: imageAdjustmentID) {
            previewImage = previewFilter.filteredPreview(image: image, editState: editState, maxDimension: 900)
        }
    }

    private var imageAdjustmentID: String {
        [
            "\(ObjectIdentifier(image as AnyObject).hashValue)",
            String(format: "%.3f", editState.brightness),
            String(format: "%.3f", editState.contrast),
            String(format: "%.3f", editState.shadows),
            String(format: "%.3f", editState.saturation),
            String(format: "%.3f", editState.warmth),
            String(format: "%.3f", editState.sharpness)
        ].joined(separator: "-")
    }

    private var previewSize: CGSize {
        let ratio = spec.pixelSize.height / max(spec.pixelSize.width, 1)
        let heightFromMaxWidth = maxWidth * ratio
        if heightFromMaxWidth > maxHeight {
            return CGSize(width: maxHeight / ratio, height: maxHeight)
        }
        return CGSize(width: maxWidth, height: heightFromMaxWidth)
    }

    private var guideOverlay: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let targetHeadRatio = min((spec.minHeadRatio + spec.maxHeadRatio) / 2, spec.maxHeadRatio - 0.035)
            let headHeight = height * targetHeadRatio
            let headWidth = headHeight * 0.72

            ZStack {
                if let faceAnalysis {
                    let faceRect = guideSubjectRect(for: faceAnalysis, in: proxy.size)
                    Rectangle()
                        .stroke((faceAnalysis.isCentered && faceAnalysis.isVerticallyCenteredInGuide) ? AppTheme.success : AppTheme.warning, lineWidth: 2)
                        .frame(width: faceRect.width, height: faceRect.height)
                        .position(x: faceRect.midX, y: faceRect.midY)

                    movementGuides(
                        faceAnalysis: faceAnalysis,
                        faceRect: faceRect,
                        canvasSize: proxy.size,
                        targetHeadHeight: headHeight
                    )
                }

                Ellipse()
                    .stroke(AppTheme.officialBlue.opacity(0.82), style: StrokeStyle(lineWidth: 2, dash: [7, 5]))
                    .frame(width: headWidth, height: headHeight)
                    .position(x: width / 2, y: height * 0.51)

                Rectangle()
                    .fill(AppTheme.danger.opacity(0.34))
                    .frame(height: 1)
                    .padding(.horizontal, 22)
                    .position(x: width / 2, y: max(height * strictTopMarginRatio, 6))

                Rectangle()
                    .stroke(AppTheme.officialBlue.opacity(0.28), lineWidth: 1)
                    .padding(18)
            }
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func movementGuides(faceAnalysis: FaceAnalysis, faceRect: CGRect, canvasSize: CGSize, targetHeadHeight: CGFloat) -> some View {
        let targetCenter = CGPoint(x: canvasSize.width / 2, y: canvasSize.height * 0.51)
        let currentCenter = CGPoint(x: faceRect.midX, y: faceRect.midY)
        let horizontalOffset = faceAnalysis.effectiveSignedCenterOffsetRatio
        let verticalGuide = verticalAdjustmentDirection(for: faceAnalysis)
        let scaleGuide = scaleAdjustmentDirection(for: faceAnalysis)

        ZStack {
            if abs(horizontalOffset) > 0.025 {
                let direction: GuideDirection = horizontalOffset < 0 ? .right : .left
                GuideArrowLine(
                    start: currentCenter,
                    end: CGPoint(x: targetCenter.x, y: currentCenter.y),
                    direction: direction,
                    label: direction == .right ? L10n.text(en: "Move right", zh: "向右移动") : L10n.text(en: "Move left", zh: "向左移动")
                )
            }

            if let verticalGuide {
                let endY = verticalGuide == .up
                    ? min(currentCenter.y - max(abs(currentCenter.y - targetCenter.y), 34), canvasSize.height - 24)
                    : max(currentCenter.y + max(abs(currentCenter.y - targetCenter.y), 34), 24)
                GuideArrowLine(
                    start: currentCenter,
                    end: CGPoint(x: currentCenter.x, y: endY),
                    direction: verticalGuide,
                    label: verticalGuide == .up ? L10n.text(en: "Move up", zh: "向上移动") : L10n.text(en: "Move down", zh: "向下移动")
                )
            }

            if let scaleGuide {
                GuideScaleBadge(
                    direction: scaleGuide,
                    targetHeadHeight: targetHeadHeight,
                    canvasSize: canvasSize
                )
            }
        }
    }

    private func verticalAdjustmentDirection(for faceAnalysis: FaceAnalysis) -> GuideDirection? {
        if faceAnalysis.effectiveVerticalCenterOffsetRatio > FaceAnalysis.strictVerticalCenterPassThreshold {
            return .up
        }
        if faceAnalysis.effectiveVerticalCenterOffsetRatio < -FaceAnalysis.strictVerticalCenterPassThreshold {
            return .down
        }
        if faceAnalysis.effectiveTopMarginRatio < Double(strictTopMarginRatio) {
            return .down
        }
        if faceAnalysis.effectiveBottomMarginRatio < 0.10 {
            return .up
        }
        if let eyeHeight = faceAnalysis.eyeHeightRatio {
            if eyeHeight < 0.535 { return .up }
            if eyeHeight > 0.585 { return .down }
        }
        return nil
    }

    private func scaleAdjustmentDirection(for faceAnalysis: FaceAnalysis) -> GuideScaleDirection? {
        let targetHeadRatio = min((spec.minHeadRatio + spec.maxHeadRatio) / 2, spec.maxHeadRatio - 0.035)
        let tolerance = max((spec.maxHeadRatio - spec.minHeadRatio) * 0.32, 0.025)
        if faceAnalysis.effectiveHeadHeightRatio < targetHeadRatio - tolerance {
            return .zoomIn
        }
        if faceAnalysis.effectiveHeadHeightRatio > targetHeadRatio + tolerance {
            return .zoomOut
        }
        return nil
    }

    private var strictTopMarginRatio: CGFloat {
        let isUSPassport = spec.country.lowercased().contains("united states")
            && spec.title.lowercased().contains("passport")
        return isUSPassport ? 0.06 : 0.045
    }

    private func previewRect(for normalizedRect: CGRect, in size: CGSize) -> CGRect {
        CGRect(
            x: normalizedRect.minX * size.width,
            y: (1 - normalizedRect.maxY) * size.height,
            width: normalizedRect.width * size.width,
            height: normalizedRect.height * size.height
        )
    }

    private func guideSubjectRect(for faceAnalysis: FaceAnalysis, in size: CGSize) -> CGRect {
        if let visualHeadRect = faceAnalysis.visualHeadRect {
            return previewRect(for: visualHeadRect, in: size)
        }
        var rect = previewRect(for: faceAnalysis.faceRect, in: size)
        if let visualSignedCenterOffsetRatio = faceAnalysis.visualSignedCenterOffsetRatio {
            rect.origin.x += CGFloat(visualSignedCenterOffsetRatio - faceAnalysis.signedCenterOffsetRatio) * size.width
        }
        return rect
    }
}

private enum GuideDirection {
    case left
    case right
    case up
    case down

    var systemImage: String {
        switch self {
        case .left: return "arrow.left"
        case .right: return "arrow.right"
        case .up: return "arrow.up"
        case .down: return "arrow.down"
        }
    }
}

private enum GuideScaleDirection {
    case zoomIn
    case zoomOut

    var systemImage: String {
        switch self {
        case .zoomIn: return "plus.magnifyingglass"
        case .zoomOut: return "minus.magnifyingglass"
        }
    }

    var label: String {
        switch self {
        case .zoomIn:
            return L10n.text(en: "Zoom in", zh: "放大")
        case .zoomOut:
            return L10n.text(en: "Zoom out", zh: "缩小")
        }
    }
}

private struct GuideArrowLine: View {
    let start: CGPoint
    let end: CGPoint
    let direction: GuideDirection
    let label: String

    var body: some View {
        ZStack {
            Path { path in
                path.move(to: start)
                path.addLine(to: end)
            }
            .stroke(AppTheme.danger, style: StrokeStyle(lineWidth: 2.2, lineCap: .round, dash: [7, 4]))

            Image(systemName: direction.systemImage)
                .font(.caption.weight(.black))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(AppTheme.danger, in: Circle())
                .position(x: end.x, y: end.y)

            Text(label)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(AppTheme.danger, in: Capsule())
                .position(x: labelPosition.x, y: labelPosition.y)
        }
    }

    private var labelPosition: CGPoint {
        let mid = CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2)
        switch direction {
        case .left, .right:
            return CGPoint(x: mid.x, y: max(mid.y - 18, 16))
        case .up, .down:
            return CGPoint(x: min(mid.x + 48, UIScreen.main.bounds.width), y: mid.y)
        }
    }
}

private struct GuideScaleBadge: View {
    let direction: GuideScaleDirection
    let targetHeadHeight: CGFloat
    let canvasSize: CGSize

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: direction.systemImage)
                .font(.caption.weight(.black))
            Text(direction.label)
                .font(.caption2.weight(.bold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(AppTheme.warning, in: Capsule())
        .position(x: canvasSize.width / 2, y: max((canvasSize.height * 0.51) - targetHeadHeight / 2 - 18, 20))
    }
}

private struct PassportPhotoPlaceholderGuide: View {
    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let headWidth = min(width * 0.36, 108)
            let headHeight = headWidth * 1.3
            let centerX = width / 2
            let foreheadY = height * 0.32
            let eyeY = height * 0.45
            let chinY = height * 0.66

            ZStack {
                VStack(spacing: 5) {
                    Image(systemName: "person.crop.rectangle.badge.plus")
                        .font(.system(size: 25, weight: .semibold))
                        .foregroundStyle(AppTheme.officialBlue)
                    Text(L10n.text(en: "Import a clear front-facing photo", zh: "导入清晰正面照片"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.ink)
                        .multilineTextAlignment(.center)
                    Text(L10n.text(en: "Keep forehead, eyes and chin inside the guide.", zh: "额头、眼睛和下巴请对齐参考线。"))
                        .font(.caption2)
                        .foregroundStyle(AppTheme.secondaryInk)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: width * 0.8)
                .position(x: centerX, y: height * 0.14)

                RoundedRectangle(cornerRadius: 7)
                    .stroke(AppTheme.officialBlue.opacity(0.20), style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
                    .frame(width: width * 0.70, height: height * 0.72)
                    .position(x: centerX, y: height * 0.58)

                VStack(spacing: 0) {
                    Ellipse()
                        .fill(AppTheme.officialBlue.opacity(0.10))
                        .frame(width: headWidth, height: headHeight)
                        .overlay {
                            Ellipse()
                                .stroke(AppTheme.officialBlue.opacity(0.45), lineWidth: 1.5)
                        }
                    RoundedRectangle(cornerRadius: 12)
                        .fill(AppTheme.officialBlue.opacity(0.08))
                        .frame(width: headWidth * 0.34, height: headWidth * 0.24)
                        .offset(y: -4)
                    Capsule()
                        .fill(AppTheme.officialBlue.opacity(0.10))
                        .frame(width: headWidth * 1.45, height: headWidth * 0.34)
                        .offset(y: -8)
                }
                .position(x: centerX, y: height * 0.57)

                guideLine(y: foreheadY, title: L10n.text(en: "Forehead", zh: "额头"), alignment: .leading)
                guideLine(y: eyeY, title: L10n.text(en: "Eyes level", zh: "眼睛水平"), alignment: .trailing)
                guideLine(y: chinY, title: L10n.text(en: "Chin", zh: "下巴"), alignment: .leading)
            }
        }
        .padding(10)
    }

    private func guideLine(y: CGFloat, title: String, alignment: HorizontalAlignment) -> some View {
        GeometryReader { proxy in
            let labelWidth: CGFloat = 78
            let isLeading = alignment == .leading

            ZStack(alignment: isLeading ? .leading : .trailing) {
                Rectangle()
                    .fill(AppTheme.officialBlue.opacity(0.26))
                    .frame(height: 1)
                    .padding(.horizontal, 28)
                    .position(x: proxy.size.width / 2, y: y)

                Text(title)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(AppTheme.officialBlue)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .frame(width: labelWidth, height: 18)
                    .background(AppTheme.cardBackground.opacity(0.94), in: Capsule())
                    .overlay {
                        Capsule()
                            .stroke(AppTheme.officialBlue.opacity(0.18), lineWidth: 1)
                    }
                    .position(x: isLeading ? labelWidth / 2 + 12 : proxy.size.width - labelWidth / 2 - 12, y: y)
            }
        }
    }
}

private struct TonePreviewFilter {
    private let context = CIContext()

    func filteredPreview(image: UIImage?, editState: PhotoEditState, maxDimension: CGFloat) -> UIImage? {
        guard let image else { return nil }
        guard editState.hasImageAdjustments else { return image }
        let source = resizedForPreview(image, maxDimension: maxDimension)
        guard let cgImage = source.normalized().cgImage else { return source }

        let input = CIImage(cgImage: cgImage)
        let controls = CIFilter.colorControls()
        controls.inputImage = input
        controls.brightness = Float(clamp(editState.brightness * 0.75 + editState.shadows * 0.28, min: -0.18, max: 0.18))
        controls.contrast = Float(clamp(1 + (editState.contrast - 1) * 0.85, min: 0.72, max: 1.32))
        controls.saturation = Float(clamp(1 + (editState.saturation - 1) * 0.95, min: 0.78, max: 1.25))

        var output = controls.outputImage ?? input

        if abs(editState.warmth) > 0.001 {
            let temperature = CIFilter.temperatureAndTint()
            temperature.inputImage = output
            temperature.neutral = CIVector(x: 6500 + editState.warmth * 1600, y: 0)
            temperature.targetNeutral = CIVector(x: 6500, y: 0)
            output = temperature.outputImage ?? output
        }

        if editState.sharpness > 0.001 {
            let sharpen = CIFilter.sharpenLuminance()
            sharpen.inputImage = output
            sharpen.sharpness = Float(min(editState.sharpness * 1.25, 1.8))
            output = sharpen.outputImage ?? output
        }

        guard let outputCG = context.createCGImage(output, from: input.extent) else {
            return source
        }
        return UIImage(cgImage: outputCG, scale: source.scale, orientation: .up)
    }

    private func resizedForPreview(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let longestSide = max(image.size.width, image.size.height)
        guard longestSide > maxDimension else { return image }
        let ratio = maxDimension / longestSide
        let size = CGSize(width: image.size.width * ratio, height: image.size.height * ratio)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    private func clamp(_ value: Double, min minValue: Double, max maxValue: Double) -> Double {
        Swift.min(Swift.max(value, minValue), maxValue)
    }
}

private struct EditablePhotoPreview: View {
    let image: UIImage?
    let spec: PhotoSpec
    let background: PhotoBackground
    let faceAnalysis: FaceAnalysis?
    @Binding var editState: PhotoEditState
    let isProcessing: Bool
    @Binding var gestureStartScale: CGFloat?
    @Binding var gestureStartRotation: Double?
    var maxWidth: CGFloat = min(UIScreen.main.bounds.width - 48, 360)
    var maxHeight: CGFloat = 520
    @GestureState private var dragTranslation: CGSize = .zero

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            PhotoPreview(
                image: image,
                spec: spec,
                background: background,
                faceAnalysis: faceAnalysis,
                editState: liveEditState,
                isProcessing: isProcessing,
                maxWidth: previewWidth,
                maxHeight: maxHeight
            )
            .contentShape(Rectangle())
            .gesture(dragGesture)
            .simultaneousGesture(magnificationGesture)
            .simultaneousGesture(rotationGesture)
        }
        .frame(width: previewWidth, alignment: .center)
    }

    private var previewWidth: CGFloat {
        let ratio = spec.pixelSize.height / max(spec.pixelSize.width, 1)
        let widthForFixedHeight = maxHeight / ratio
        return min(maxWidth, widthForFixedHeight)
    }

    private var liveEditState: PhotoEditState {
        var state = editState
        state.offset.width += dragTranslation.width
        state.offset.height += dragTranslation.height
        return state
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .updating($dragTranslation) { value, state, _ in
                state = value.translation
            }
            .onEnded { value in
                editState.offset.width += value.translation.width
                editState.offset.height += value.translation.height
            }
    }

    private var magnificationGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                let start = gestureStartScale ?? editState.scale
                gestureStartScale = start
                editState.scale = clamp(start * value.magnification, min: 0.65, max: 2.6)
            }
            .onEnded { _ in
                gestureStartScale = nil
            }
    }

    private var rotationGesture: some Gesture {
        RotateGesture()
            .onChanged { value in
                let start = gestureStartRotation ?? editState.rotationDegrees
                gestureStartRotation = start
                editState.rotationDegrees = clamp(start + value.rotation.degrees, min: -20, max: 20)
            }
            .onEnded { _ in
                gestureStartRotation = nil
            }
    }

    private func clamp<T: Comparable>(_ value: T, min minValue: T, max maxValue: T) -> T {
        min(max(value, minValue), maxValue)
    }
}

private struct PrecisionAdjustSection: View {
    let spec: PhotoSpec
    @Binding var editState: PhotoEditState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                SectionTitle(title: L10n.text(L10n.adjust))
                Spacer()
                Text("\(Int(spec.pixelSize.width)) x \(Int(spec.pixelSize.height)) px")
                    .font(.caption2.monospacedDigit().weight(.medium))
                    .foregroundStyle(AppTheme.secondaryInk)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AppTheme.groupedBackground, in: Capsule())
                Button {
                    editState = .default
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.caption.weight(.bold))
                        .frame(width: 30, height: 24)
                }
                .buttonStyle(.plain)
                .foregroundStyle(editState == .default ? AppTheme.secondaryInk.opacity(0.4) : AppTheme.officialBlue)
                .background(AppTheme.groupedBackground, in: RoundedRectangle(cornerRadius: 7))
                .disabled(editState == .default)
                .accessibilityLabel(L10n.text(en: "Reset adjustments", zh: "重置调整"))
            }

            VStack(spacing: 9) {
                positionControls

                AdjustmentGroup(title: L10n.text(en: "Framing", zh: "画面构图"), systemImage: "viewfinder") {
                    CompactAdjustmentSlider(title: L10n.text(en: "Scale", zh: "缩放"), value: $editState.scale, range: 0.65...2.60, step: 0.01)
                    CompactAdjustmentSlider(title: L10n.text(en: "Rotate", zh: "旋转"), value: $editState.rotationDegrees, range: -20...20, step: 0.5, suffix: "°")
                }

                AdjustmentGroup(title: L10n.text(en: "Image Tone", zh: "图像质感"), systemImage: "camera.filters") {
                    CompactAdjustmentSlider(title: L10n.text(en: "Bright", zh: "亮度"), value: $editState.brightness, range: -0.42...0.42, step: 0.01)
                    CompactAdjustmentSlider(title: L10n.text(en: "Contrast", zh: "对比"), value: $editState.contrast, range: 0.62...1.58, step: 0.01)
                    CompactAdjustmentSlider(title: L10n.text(en: "Shadow", zh: "阴影"), value: $editState.shadows, range: -0.42...0.46, step: 0.01)
                    CompactAdjustmentSlider(title: L10n.text(en: "Saturate", zh: "饱和"), value: $editState.saturation, range: 0.65...1.42, step: 0.01)
                    CompactAdjustmentSlider(title: L10n.text(en: "Warmth", zh: "色温"), value: $editState.warmth, range: -0.70...0.70, step: 0.01)
                    CompactAdjustmentSlider(title: L10n.text(en: "Sharp", zh: "锐化"), value: $editState.sharpness, range: 0...1.65, step: 0.03)
                }
            }
            .padding(12)
            .professionalCard()
        }
    }

    private var positionControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Label(L10n.text(en: "Position", zh: "位置微调"), systemImage: "arrow.up.and.down.and.arrow.left.and.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.ink)
                Spacer()
                Text("8 px")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(AppTheme.secondaryInk)
            }

            HStack(spacing: 8) {
                nudgeButton(systemImage: "arrow.left") {
                    editState.offset.width -= 8
                }
                nudgeButton(systemImage: "arrow.right") {
                    editState.offset.width += 8
                }
                nudgeButton(systemImage: "arrow.up") {
                    editState.offset.height -= 8
                }
                nudgeButton(systemImage: "arrow.down") {
                    editState.offset.height += 8
                }
            }
        }
        .padding(10)
        .background(AppTheme.groupedBackground, in: RoundedRectangle(cornerRadius: 8))
    }

    private func nudgeButton(systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.officialBlue)
                .frame(maxWidth: .infinity, minHeight: 32)
                .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 7))
                .overlay {
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(AppTheme.border, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
    }
}

private struct AdjustmentGroup<Content: View>: View {
    let title: String
    let systemImage: String
    let content: Content

    init(title: String, systemImage: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.systemImage = systemImage
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Label(title, systemImage: systemImage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.ink)
                Spacer()
            }

            VStack(spacing: 6) {
                content
            }
        }
        .padding(10)
        .background(AppTheme.groupedBackground, in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct CompactAdjustmentSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    var suffix: String

    init(title: String, value: Binding<Double>, range: ClosedRange<Double>, step: Double, suffix: String = "") {
        self.title = title
        self._value = value
        self.range = range
        self.step = step
        self.suffix = suffix
    }

    init(title: String, value: Binding<CGFloat>, range: ClosedRange<Double>, step: Double, suffix: String = "") {
        self.title = title
        self._value = Binding(
            get: { Double(value.wrappedValue) },
            set: { value.wrappedValue = CGFloat($0) }
        )
        self.range = range
        self.step = step
        self.suffix = suffix
    }

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(AppTheme.ink)
                .frame(width: 54, alignment: .leading)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Slider(value: $value, in: range, step: step)
                .tint(AppTheme.officialBlue)
            Text(formattedValue)
                .font(.caption2.monospacedDigit())
                .foregroundStyle(AppTheme.secondaryInk)
                .frame(width: 42, alignment: .trailing)
        }
        .frame(height: 24)
    }

    private var formattedValue: String {
        if suffix.isEmpty {
            return String(format: "%.2f", value)
        }
        return "\(String(format: "%.1f", value))\(suffix)"
    }
}

private struct ComplianceRow: View {
    let check: ComplianceCheck
    let onFix: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 3) {
                Text(check.title)
                    .font(.subheadline.weight(.semibold))
                Text(check.message)
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
                if let action = check.action {
                    VStack(alignment: .leading, spacing: 6) {
                        Label(action, systemImage: "wand.and.stars")
                            .font(.caption2)
                            .foregroundStyle(color)
                            .fixedSize(horizontal: false, vertical: true)
                        if canAutoFix {
                            Button(action: onFix) {
                                Label(fixTitle, systemImage: "wand.and.stars")
                                    .font(.caption2.weight(.bold))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(color.opacity(0.10), in: Capsule())
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(color)
                        }
                    }
                    .padding(.top, 2)
                }
            }
            Spacer(minLength: 0)
        }
    }

    private var icon: String {
        switch check.severity {
        case .pass: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .fail: return "xmark.circle.fill"
        }
    }

    private var color: Color {
        switch check.severity {
        case .pass: return AppTheme.success
        case .warning: return AppTheme.warning
        case .fail: return AppTheme.danger
        }
    }

    private var canAutoFix: Bool {
        guard check.severity != .pass else { return false }
        switch check.kind {
        case .background, .headSize, .faceCentered, .headTilt, .eyeHeight, .topMargin, .lighting, .sharpness, .backgroundShadows, .format:
            return true
        case .resolution, .singlePerson, .eyesVisible, .expression, .faceDetection, .fileSize, .none:
            return false
        }
    }

    private var fixTitle: String {
        switch check.kind {
        case .background:
            return L10n.text(en: "Fix Background", zh: "修复背景")
        case .lighting:
            return L10n.text(en: "Fix Lighting", zh: "修复光线")
        case .sharpness:
            return L10n.text(en: "Improve Sharpness", zh: "增强清晰度")
        case .backgroundShadows:
            return L10n.text(en: "Fix Shadows", zh: "修复阴影")
        case .headSize, .format, .faceCentered, .headTilt, .eyeHeight, .topMargin:
            return L10n.text(en: "Adjust Framing", zh: "调整构图")
        default:
            return L10n.text(en: "Fix", zh: "修复")
        }
    }
}

private struct ReadyCard: View {
    let result: ComplianceResult

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: result.isFullyPassed ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 34))
                .foregroundStyle(result.isFullyPassed ? AppTheme.success : AppTheme.warning)

            VStack(alignment: .leading, spacing: 4) {
                Text(result.isFullyPassed ? L10n.text(L10n.ready) : L10n.text(L10n.needsAttention))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(AppTheme.ink)
                Text(result.isFullyPassed ? L10n.text(L10n.readyDetail) : L10n.text(L10n.attentionDetail))
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            Text("\(result.score)%")
                .font(.title3.monospacedDigit().weight(.bold))
                .foregroundStyle(result.isFullyPassed ? AppTheme.success : AppTheme.warning)
        }
        .padding(14)
        .professionalCard()
    }
}
