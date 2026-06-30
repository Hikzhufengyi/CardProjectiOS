import CoreImage
import CoreImage.CIFilterBuiltins
import PhotosUI
import SwiftUI
import UIKit

struct CreateView: View {
    @State private var selectedCategory: SpecCategory? = nil
    @State private var selectedCountry: String? = nil
    @State private var searchText = ""
    @State private var recentSpecPreference = RecentSpecPreference.load()

    private var filteredSpecs: [PhotoSpec] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let specs = PhotoSpec.catalog.filter { spec in
            let matchesCategory = selectedCategory == nil || spec.category == selectedCategory
            let matchesCountry = selectedCountry == nil || spec.country == selectedCountry
            let matchesSearch = query.isEmpty || spec.searchableText.contains(query)
            return matchesCategory && matchesCountry && matchesSearch
        }
        return Self.sortedSpecs(specs, recent: recentSpecPreference)
    }

    private var popularCountries: [String] {
        var seen = Set<String>()
        let preferred = Self.preferredCountryOrder(recentCountry: recentSpecPreference?.country)
        let preferredExisting = preferred.filter { country in
            guard !seen.contains(country), PhotoSpec.catalog.contains(where: { $0.country == country }) else {
                return false
            }
            seen.insert(country)
            return true
        }
        let remaining = PhotoSpec.catalog.map(\.country).filter { country in
            guard !preferredExisting.contains(country), !seen.contains(country) else { return false }
            seen.insert(country)
            return true
        }.sorted()
        return preferredExisting + remaining
    }

    private static func preferredCountryOrder(recentCountry: String? = nil) -> [String] {
        let gcc = ["Saudi Arabia", "United Arab Emirates", "Qatar", "Kuwait", "Oman", "Bahrain"]
        let global = [
            "United States", "United Kingdom", "Canada", "Schengen Area", "European Union",
            "Australia", "China", "India", "Japan", "South Korea", "Singapore", "New Zealand"
        ]
        let preferredLanguages = Locale.preferredLanguages.map { $0.lowercased() }
        let language = preferredLanguages.first ?? ""
        let localeIdentifier = Locale.current.identifier.lowercased()
        let region = Locale.current.region?.identifier.uppercased() ?? ""
        let gccRegions = Set(["SA", "AE", "QA", "KW", "OM", "BH"])
        let usesArabic = L10n.isArabic
            || preferredLanguages.contains(where: { $0.hasPrefix("ar") || $0.contains("-ar") || $0.contains("_ar") })
            || localeIdentifier.hasPrefix("ar")
            || localeIdentifier.contains("_ar")

        var base: [String]
        if usesArabic || gccRegions.contains(region) {
            base = gcc + global
        } else if region == "IN" {
            base = ["India", "United Arab Emirates", "Saudi Arabia", "Qatar", "Kuwait", "Oman", "Bahrain"] + global
        } else if region == "CN" || language.hasPrefix("zh") {
            base = ["China", "Hong Kong", "Taiwan", "Japan", "South Korea", "Singapore", "United States", "Canada", "United Kingdom"] + gcc + global
        } else {
            base = global + gcc
        }

        if let recentCountry, !recentCountry.isEmpty {
            base.removeAll { $0 == recentCountry }
            base.insert(recentCountry, at: 0)
        }
        return base
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
            Text(L10n.text(en: "Choose Document Type", zh: "选择证件类型", ar: "اختر نوع المستند"))
                .font(.system(.largeTitle, design: .default, weight: .bold))
                .foregroundStyle(AppTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text(L10n.text(en: "Choose an official-size preset, then check, refine, compress, and export on device.", zh: "选择官方尺寸模板，在本地完成检测、换背景、压缩和 300 DPI 导出。", ar: "اختر قالبا بالمقاس الرسمي، ثم افحص وعدل واضغط وصدّر على الجهاز."))
                .font(.subheadline)
                .foregroundStyle(AppTheme.secondaryInk)
            HStack(spacing: 8) {
                TrustPill(systemImage: "lock.shield.fill", text: L10n.text(en: "100% offline", zh: "本地离线处理", ar: "بدون رفع"))
                TrustPill(systemImage: "checkmark.seal.fill", text: L10n.text(en: "One-time purchase", zh: "一次买断", ar: "شراء مرة واحدة"))
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
                TextField(L10n.text(en: "Search country, visa, passport, or size", zh: "搜索国家、签证、护照或尺寸", ar: "ابحث عن دولة أو تأشيرة أو جواز أو مقاس"), text: $searchText)
                    .textInputAutocapitalization(.never)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L10n.text(en: "Clear search", zh: "清空搜索", ar: "مسح البحث"))
                }
            }
            .padding(12)
            .professionalCard()

            ZStack(alignment: .trailing) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        FilterChip(title: L10n.text(en: "All Countries", zh: "常用国家", ar: "كل الدول"), isSelected: selectedCountry == nil) {
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
                    FilterChip(title: L10n.text(en: "All", zh: "全部", ar: "الكل"), isSelected: selectedCategory == nil) {
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
                    L10n.text(en: "No Presets Found", zh: "没有找到规格", ar: "لم يتم العثور على قوالب"),
                    systemImage: "doc.text.magnifyingglass",
                    description: Text(L10n.text(en: "Try another keyword, or clear country/category filters.", zh: "换一个关键词，或清除国家/分类筛选。", ar: "جرّب كلمة أخرى أو امسح فلتر الدولة أو الفئة."))
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 34)
            } else {
                HStack {
                    Text(L10n.text(en: "\(filteredSpecs.count) presets", zh: "\(filteredSpecs.count) 个模板", ar: "\(filteredSpecs.count) قالب"))
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
                        .simultaneousGesture(TapGesture().onEnded {
                            remember(spec)
                        })
                    }
                }
            }
        }
    }

    private func remember(_ spec: PhotoSpec) {
        let preference = RecentSpecPreference(spec: spec)
        recentSpecPreference = preference
        preference.save()
        AnalyticsService.logSpecSelected(spec)
    }

    private static func sortedSpecs(_ specs: [PhotoSpec], recent: RecentSpecPreference?) -> [PhotoSpec] {
        guard let recent else { return specs }
        return specs.sorted { left, right in
            let leftScore = recent.score(for: left)
            let rightScore = recent.score(for: right)
            if leftScore != rightScore { return leftScore > rightScore }
            return left.displayTitle.localizedStandardCompare(right.displayTitle) == .orderedAscending
        }
    }
}

private struct RecentSpecPreference: Codable {
    private static let storageKey = "recentSpecPreference.v1"

    let specID: String
    let country: String
    let category: SpecCategory
    let selectedAt: Date

    init(spec: PhotoSpec) {
        self.specID = spec.id
        self.country = spec.country
        self.category = spec.category
        self.selectedAt = Date()
    }

    func score(for spec: PhotoSpec) -> Int {
        if spec.id == specID { return 300 }
        if spec.country == country { return 200 }
        if spec.category == category { return 40 }
        return 0
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }

    static func load() -> RecentSpecPreference? {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return nil }
        return try? JSONDecoder().decode(RecentSpecPreference.self, from: data)
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
    @State private var renderedAnalysisKey: String?
    @State private var editState: PhotoEditState = .default
    @State private var applyLightRepair = false
    @State private var repairIntensity: RepairIntensity = .balanced
    @State private var isAutoFixing = false
    @State private var isProcessingPhoto = false
    @State private var isPreparingExport = false
    @State private var showingExport = false
    @State private var showingPaywall = false
    @State private var showingPrivacy = false
    @State private var showingCamera = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showsPassedChecks = false
    @State private var gestureStartScale: CGFloat?
    @State private var gestureStartRotation: Double?
    @State private var editStateUpdateTask: Task<Void, Never>?
    @State private var pendingInitialCameraEditState: PhotoEditState?
    @State private var pendingInitialCameraImageID = UUID()
    @StateObject private var store = StoreService.shared
    private let complianceSectionID = "compliance-section"

    private let compliance = ComplianceService()
    private let faceService = FaceAnalysisService()
    private let backgroundService = BackgroundRemovalService()
    private let enhancementService = PhotoEnhancementService()
    private let renderer = PhotoRenderer()
    private var complianceProfile: PhotoComplianceProfile { spec.complianceProfile }
    private var targetEyeHeightRatio: Double {
        (complianceProfile.eyeHeightRange.lowerBound + complianceProfile.eyeHeightRange.upperBound) / 2
    }
    private var targetBottomMarginRatio: Double { complianceProfile.minimumBottomMarginRatio }
    private var targetTopMarginRatio: Double { complianceProfile.minimumTopMarginRatio }
    private var shouldUseEyeHeightForAutoFix: Bool { complianceProfile.shouldDriveEyeHeightAutoFix }
    private var targetGuideCenterRatio: Double {
        let targetTop = GuideFramingCalculator.guideTopRatio(
            headRatio: targetGuideHeadRatio,
            eyeTargetRatio: targetEyeHeightRatio,
            profile: complianceProfile
        )
        return targetTop + targetGuideHeadRatio / 2
    }

    init(spec: PhotoSpec) {
        self.spec = spec
        self._selectedBackground = State(initialValue: spec.background.first ?? .white)
    }

    var result: ComplianceResult {
        compliance.evaluate(
            image: displayedRenderedAnalysis == nil && inputImage != nil ? nil : (complianceImage ?? inputImage),
            spec: spec,
            selectedBackground: selectedBackground,
            analysis: displayedRenderedAnalysis ?? (inputImage == nil ? photoAnalysis : nil)
        )
    }

    private var currentRenderedAnalysis: PhotoAnalysis? {
        renderedAnalysisKey == currentRenderAnalysisKey ? renderedAnalysis : nil
    }

    private var displayedRenderedAnalysis: PhotoAnalysis? {
        currentRenderedAnalysis ?? renderedAnalysis
    }

    private var currentRenderAnalysisKey: String {
        [
            String(format: "%.3f", editState.scale),
            String(format: "%.3f", editState.rotationDegrees),
            String(format: "%.1f", editState.offset.width),
            String(format: "%.1f", editState.offset.height),
            String(format: "%.3f", editState.brightness),
            String(format: "%.3f", editState.contrast),
            String(format: "%.3f", editState.shadows),
            String(format: "%.3f", editState.saturation),
            String(format: "%.3f", editState.warmth),
            String(format: "%.3f", editState.sharpness),
            selectedBackground.rawValue,
            spec.id
        ].joined(separator: "|")
    }

    var body: some View {
        VStack(spacing: 0) {
            if inputImage != nil {
                stickyEditablePhotoPreview
            }

            ScrollViewReader { proxy in
                detailScrollContent(proxy: proxy)
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
            if inputImage != nil {
                exportBottomBar
            }
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
            exportSheetContent
        }
        .sheet(isPresented: $showingPaywall) {
            PaywallView(store: store) {
                showingExport = true
            }
        }
        .sheet(isPresented: $showingPrivacy) {
            PrivacyDisclaimerView()
        }
        .fullScreenCover(isPresented: $showingCamera) {
            cameraCoverContent
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
        .onChange(of: editState) { _, _ in
            scheduleRenderedComplianceUpdate()
        }
        .onDisappear {
            editStateUpdateTask?.cancel()
            editStateUpdateTask = nil
        }
        .background(AppTheme.groupedBackground.ignoresSafeArea())
    }

    @ViewBuilder
    private func detailScrollContent(proxy: ScrollViewProxy) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: detailScrollSpacing) {
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
                if inputImage != nil {
                    PrecisionAdjustSection(
                        spec: spec,
                        selectedBackground: $selectedBackground,
                        editState: $editState,
                        showsAdvancedTone: !result.isFullyPassed
                    )
                } else {
                    backgroundPicker
                }
                if inputImage != nil {
                    compliancePanel
                        .id(complianceSectionID)
                }
            }
            .padding(18)
            .padding(.bottom, inputImage == nil ? 24 : 88)
        }
    }

    private var detailScrollSpacing: CGFloat {
        inputImage == nil ? 24 : 14
    }

    private var exportSheetContent: some View {
        ExportView(
            image: processedImage ?? inputImage,
            spec: spec,
            background: selectedBackground,
            analysis: currentRenderedAnalysis ?? (inputImage == nil ? photoAnalysis : nil),
            editState: editState,
            result: result
        )
    }

    private var cameraImageBinding: Binding<UIImage?> {
        Binding(
            get: { inputImage },
            set: { newImage in
                inputImage = newImage
                if newImage != nil {
                    AnalyticsService.logPhotoImport(source: "camera", spec: spec)
                    editState = pendingInitialCameraEditState ?? .default
                    pendingInitialCameraEditState = nil
                    pendingInitialCameraImageID = UUID()
                }
            }
        )
    }

    private var cameraCoverContent: some View {
        CameraPicker(
            spec: spec,
            image: cameraImageBinding,
            onCapturePrepared: { captured in
                pendingInitialCameraImageID = UUID()
                let captureID = pendingInitialCameraImageID
                pendingInitialCameraEditState = nil
                let suggestedState = await suggestedInitialEditState(for: captured)
                guard captureID == pendingInitialCameraImageID else { return }
                await MainActor.run {
                    pendingInitialCameraEditState = suggestedState
                }
            }
        )
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
                    faceAnalysis: currentRenderedAnalysis?.face,
                    showsMovementGuides: !result.isFullyPassed,
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
        let targetRatio = spec.pixelSize.width / max(spec.pixelSize.height, 1)
        let maxCanvasHeight: CGFloat = 318
        return min(availableWidth, maxCanvasHeight * targetRatio)
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
                PhotoPreview(
                    image: processedImage ?? inputImage,
                    spec: spec,
                    background: selectedBackground,
                    faceAnalysis: currentRenderedAnalysis?.face,
                    editState: editState,
                    isProcessing: isProcessingPhoto,
                    showsMovementGuides: !result.isFullyPassed
                )
                    .frame(maxWidth: .infinity)
            }

            HStack(spacing: 8) {
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    CompactActionButton(title: L10n.text(en: "Album", zh: "相册"), systemImage: "photo.stack.fill")
                }
                .buttonStyle(.plain)

                Button {
                    AnalyticsService.logPhotoImport(source: "camera_open", spec: spec)
                    showingCamera = true
                } label: {
                    CompactActionButton(title: L10n.text(L10n.camera), systemImage: "camera.fill")
                }
                .buttonStyle(.plain)

                if inputImage != nil {
                    PositionJoystick(offset: $editState.offset, controlSize: 58)
                }
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

                if compactIssueChecks.isEmpty {
                    Label(L10n.text(en: "All key checks passed. Export now or open the full report if you need to review every item.", zh: "关键检查已通过。可以直接导出，也可以展开完整报告逐项查看。", ar: "اجتازت الصورة الفحوصات الأساسية. يمكنك التصدير الآن أو فتح التقرير الكامل لمراجعة كل بند."), systemImage: "checkmark.seal.fill")
                        .font(.caption)
                        .foregroundStyle(AppTheme.success)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(10)
                        .background(AppTheme.success.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                } else {
                    ForEach(compactIssueChecks.prefix(3)) { check in
                        ComplianceRow(check: check) {
                            applyFix(for: check)
                        }
                    }
                }

                DisclosureGroup(isExpanded: $showsPassedChecks) {
                    VStack(spacing: 10) {
                        ForEach(result.checks.filter { $0.severity == .pass }) { check in
                            ComplianceRow(check: check) {
                                applyFix(for: check)
                            }
                        }
                    }
                    .padding(.top, 8)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(AppTheme.success)
                        Text(L10n.text(en: "Passed checks", zh: "已通过检查", ar: "الفحوصات المجتازة"))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.ink)
                        Spacer(minLength: 0)
                        Text("\(result.checks.filter { $0.severity == .pass }.count)")
                            .font(.caption2.monospacedDigit().weight(.bold))
                            .foregroundStyle(AppTheme.success)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(AppTheme.success.opacity(0.10), in: Capsule())
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
            return L10n.text(en: "Already optimized", zh: "已完成校准")
        }
        return L10n.text(en: "1-Click Smart Fix", zh: "一键智能修复")
    }

    private var canRunAutoFix: Bool {
        !result.isFullyPassed && !isProcessingPhoto && !isAutoFixing
    }

    private func quickFixPanel(onFix: @escaping () -> Void, onDetails: @escaping () -> Void) -> some View {
        HStack(spacing: 8) {
            Button(action: onDetails) {
                compactComplianceSummary
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.text(en: "View compliance details", zh: "查看合规详情"))

            Button(action: onFix) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9)
                        .fill(canRunAutoFix || isAutoFixing ? AppTheme.officialBlue : AppTheme.border.opacity(0.9))

                    if isAutoFixing {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                            .scaleEffect(0.82)
                    } else {
                        Image(systemName: result.isFullyPassed ? "checkmark.circle.fill" : "wand.and.stars")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.white)
                    }
                }
                .frame(width: 38, height: 38)
            }
            .buttonStyle(.plain)
            .disabled(!canRunAutoFix)
            .opacity(isAutoFixing ? 1 : (result.isFullyPassed ? 0.92 : (canRunAutoFix ? 1 : 0.58)))
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
        let scoreText = "\(result.score)%"
        if failCount > 0 {
            return L10n.text(en: "\(scoreText) · \(failCount) fail", zh: "\(scoreText) · \(failCount) 项失败")
        }
        if warningCount > 0 {
            return L10n.text(en: "\(scoreText) · \(warningCount) warn", zh: "\(scoreText) · \(warningCount) 项警告")
        }
        return scoreText
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
                guard !isPreparingExport else { return }
                isPreparingExport = true
                defer { isPreparingExport = false }
                await store.updatePurchases()
                AnalyticsService.logExportAttempt(spec: spec, hasProAccess: store.hasProAccess)
                if store.hasProAccess {
                    showingExport = true
                } else {
                    showingPaywall = true
                }
            }
        } label: {
            HStack(spacing: 9) {
                if isPreparingExport {
                    ProgressView()
                        .tint(.white)
                        .controlSize(.small)
                } else {
                    Image(systemName: result.isFullyPassed ? "checkmark.circle.fill" : "square.and.arrow.down")
                }
                Text(isPreparingExport ? L10n.text(en: "Preparing Export...", zh: "正在准备导出...") : exportButtonTitle)
            }
            .font(.headline.weight(.bold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .background(AppTheme.officialBlue, in: RoundedRectangle(cornerRadius: 10))
        .shadow(color: AppTheme.officialBlue.opacity(inputImage == nil ? 0 : 0.30), radius: 12, x: 0, y: 5)
        .opacity(inputImage == nil || store.isPurchasing || isPreparingExport ? 0.70 : 1)
        .disabled(inputImage == nil || store.isPurchasing || isPreparingExport)
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
        AnalyticsService.logPhotoImport(source: "photo_library", spec: spec)
    }

    private func suggestedInitialEditState(for image: UIImage) async -> PhotoEditState {
        let evaluationBackground = spec.background.first ?? selectedBackground
        guard let initialAnalysis = try? await faceService.analyze(image) else { return .default }
        guard let initialFace = initialAnalysis.face else { return .default }

        var bestState = correctedFraming(.default, face: initialFace, pass: 5)
        var bestEvaluation = await evaluateInitialCameraCandidate(
            bestState,
            sourceImage: image,
            background: evaluationBackground
        )
        var bestScore = guideWeightedScore(for: bestEvaluation.result, analysis: bestEvaluation.analysis)

        if isStrictGuideAligned(bestEvaluation.result, analysis: bestEvaluation.analysis) {
            return bestState
        }

        for pass in 0..<3 {
            guard let currentFace = bestEvaluation.analysis?.face else { break }
            var candidate = correctedFraming(bestState, face: currentFace, pass: 6 + pass)

            if currentFace.effectiveCenterOffsetRatio > FaceAnalysis.strictCenterPassThreshold || !currentFace.visualAndFaceCentersAgree {
                candidate.offset.width += horizontalCorrection(for: currentFace, pass: 6 + pass)
            }
            if shouldUseEyeHeightForAutoFix,
               let eyeHeight = currentFace.eyeHeightRatio,
               abs(eyeHeight - targetEyeHeightRatio) > 0.008 {
                candidate.offset.height += verticalCorrection(for: currentFace, pass: 6 + pass)
            }
            if abs(currentFace.rollDegrees) > 1.0, abs(currentFace.rollDegrees) < 15 {
                candidate.rotationDegrees = clamped(
                    candidate.rotationDegrees - currentFace.rollDegrees * 0.95,
                    min: -20,
                    max: 20
                )
            }

            let evaluation = await evaluateInitialCameraCandidate(
                candidate,
                sourceImage: image,
                background: evaluationBackground
            )
            let candidateScore = guideWeightedScore(for: evaluation.result, analysis: evaluation.analysis)

            if candidateScore >= bestScore || isStrictGuideAligned(evaluation.result, analysis: evaluation.analysis) {
                bestState = candidate
                bestEvaluation = evaluation
                bestScore = candidateScore
            }

            if isStrictGuideAligned(bestEvaluation.result, analysis: bestEvaluation.analysis) {
                break
            }
        }

        return bestState
    }

    private func isSameImage(_ lhs: UIImage?, _ rhs: UIImage) -> Bool {
        guard let lhs else { return false }
        if lhs === rhs { return true }
        return lhs.pngData() == rhs.pngData()
    }

    private func evaluateInitialCameraCandidate(_ candidate: PhotoEditState, sourceImage: UIImage, background: PhotoBackground) async -> (result: ComplianceResult, analysis: PhotoAnalysis?) {
        let rendered = renderer.render(
            image: sourceImage,
            spec: spec,
            background: background,
            faceAnalysis: nil,
            editState: candidate
        )
        let candidateAnalysis = (try? await faceService.analyze(rendered)) ?? nil
        let candidateResult = compliance.evaluate(
            image: rendered,
            spec: spec,
            selectedBackground: background,
            analysis: candidateAnalysis
        )
        return (candidateResult, candidateAnalysis)
    }

    private func processCurrentPhoto() async {
        guard let inputImage else {
            processedImage = nil
            photoAnalysis = nil
            complianceImage = nil
            renderedAnalysis = nil
            renderedAnalysisKey = nil
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
        guard !result.isFullyPassed else { return }
        isAutoFixing = true
        defer { isAutoFixing = false }

        if let preferredBackground = spec.background.first, !spec.background.contains(selectedBackground) {
            selectedBackground = preferredBackground
        }

        applyLightRepair = true
        repairIntensity = result.score < 82 ? .stronger : .balanced

        var bestState = editState
        var bestResult = result
        var bestScore = guideWeightedScore(for: result, analysis: currentRenderedAnalysis ?? photoAnalysis)
        var bestAnalysis = currentRenderedAnalysis ?? photoAnalysis

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
        let leveledState = await refinedAutoLeveledState(from: bestState)
        let leveledEvaluation = await evaluateCandidate(leveledState)
        bestState = await finalGuideCenteredState(from: leveledState, analysis: leveledEvaluation.analysis)
        editState = bestState
        await processCurrentPhoto()
    }

    private func finalGuideCenteredState(from state: PhotoEditState, analysis: PhotoAnalysis?) async -> PhotoEditState {
        var currentState = state
        var currentAnalysis = analysis

        for pass in 0..<3 {
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
            if face.effectiveCenterOffsetRatio > FaceAnalysis.strictCenterPassThreshold || !face.visualAndFaceCentersAgree {
                candidate.offset.width += horizontalCorrection(for: face, pass: 7)
            }
            if shouldUseEyeHeightForAutoFix,
               let eyeHeight = face.eyeHeightRatio,
               abs(eyeHeight - targetEyeHeightRatio) > 0.010 {
                candidate.offset.height += verticalCorrection(for: face, pass: 7)
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

        return await resolveDirectCentering(from: currentState, analysis: currentAnalysis)
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

        let dominantLevelAngle = face.dominantLevelAngleDegrees
        if abs(dominantLevelAngle) >= 0.8 && abs(dominantLevelAngle) < 18 {
            let multipliers = [1.0, 0.88, 1.08]
            for multiplier in multipliers {
                var candidate = baseState
                candidate.rotationDegrees = clamped(
                    candidate.rotationDegrees - dominantLevelAngle * multiplier,
                    min: -20,
                    max: 20
                )
                candidate.offset = boundedOffset(candidate.offset, scale: candidate.scale)
                candidates.append(candidate)
            }
        }

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

        if shouldUseEyeHeightForAutoFix, let eyeHeight = face.eyeHeightRatio {
            let eyeRange = complianceProfile.eyeHeightRange
            let targetEyeHeights = [
                eyeRange.lowerBound,
                (eyeRange.lowerBound + targetEyeHeightRatio) / 2,
                targetEyeHeightRatio,
                (targetEyeHeightRatio + eyeRange.upperBound) / 2,
                eyeRange.upperBound
            ]
            for targetEyeHeight in targetEyeHeights {
                var candidate = correctedFraming(baseState, face: face, pass: 4)
                candidate.offset.height += CGFloat(eyeHeight - targetEyeHeight) * spec.pixelSize.height * 0.78
                candidates.append(candidate)
            }
        }

        for topMarginTarget in [targetTopMarginRatio, targetTopMarginRatio + 0.015, targetTopMarginRatio + 0.03] {
            var candidate = correctedFraming(baseState, face: face, pass: 4)
            candidate.offset.height += CGFloat(topMarginTarget - topMarginForCompliance(face)) * spec.pixelSize.height * 0.88
            candidates.append(candidate)
        }

        let bottomMarginTargets = [
            targetBottomMarginRatio * 0.86,
            targetBottomMarginRatio,
            min(targetBottomMarginRatio * 1.14, 0.18)
        ]
        for bottomMarginTarget in bottomMarginTargets {
            var candidate = correctedFraming(baseState, face: face, pass: 4)
            candidate.offset.height -= CGFloat(bottomMarginTarget - face.effectiveBottomMarginRatio) * spec.pixelSize.height * 0.82
            candidates.append(candidate)
        }

        for horizontalBias in [-72.0, -54.0, -36.0, -24.0, -12.0, 0.0, 12.0, 24.0, 36.0, 54.0, 72.0] {
            var candidate = correctedFraming(baseState, face: face, pass: 4)
            candidate.offset.width += horizontalBias
            candidates.append(candidate)
        }

        return candidates
    }

    private func correctedFraming(_ state: PhotoEditState, face: FaceAnalysis, pass: Int) -> PhotoEditState {
        var fixed = state

        let dominantLevelAngle = face.dominantLevelAngleDegrees
        if abs(dominantLevelAngle) >= 0.8 && abs(dominantLevelAngle) < 18 {
            let rotationGain = pass >= 3 ? 1.0 : (pass >= 2 ? 0.92 : 0.72)
            fixed.rotationDegrees = clamped(
                fixed.rotationDegrees - dominantLevelAngle * rotationGain,
                min: -20,
                max: 20
            )
        }

        let targetHeadRatio = targetGuideHeadRatio
        let scaleFactor = targetHeadRatio / max(face.effectiveHeadHeightRatio, 0.01)
        let scaleTolerance = pass >= 2 ? 0.018 : 0.030
        let clampedScaleFactor = clamped(scaleFactor, min: pass >= 2 ? 0.78 : 0.88, max: pass >= 2 ? 1.26 : 1.14)
        if abs(face.effectiveHeadHeightRatio - targetHeadRatio) > scaleTolerance {
            fixed.scale = clamped(fixed.scale * clampedScaleFactor, min: 0.62, max: 2.80)
        }

        fixed.offset.width += horizontalCorrection(for: face, pass: pass)
        fixed.offset.height += verticalCorrection(for: face, pass: pass, preferGuideLock: true)
        fixed.offset = boundedOffset(fixed.offset, scale: fixed.scale)

        return fixed
    }

    private func horizontalCorrection(for face: FaceAnalysis, pass: Int) -> CGFloat {
        let targetWidth = max(spec.pixelSize.width, 1)
        let gain = pass >= 6 ? 1.72 : (pass >= 2 ? 1.42 : 1.02)
        let correction = -face.effectiveSignedCenterOffsetRatio * targetWidth * gain
        let limit = targetWidth * (pass >= 6 ? 0.38 : (pass >= 2 ? 0.32 : 0.20))
        return CGFloat(clamped(correction, min: -limit, max: limit))
    }

    private func verticalCorrection(for face: FaceAnalysis, pass: Int, preferGuideLock: Bool = false) -> CGFloat {
        let targetHeight = max(spec.pixelSize.height, 1)
        let weights = complianceProfile.framingWeights
        let gain = pass >= 2 ? 1.06 : 0.78
        var correction = 0.0
        let guideOffset = guideAlignmentOffset(for: face)
        let topMargin = topMarginForCompliance(face)
        let guideAlreadyGood =
            abs(guideOffset) <= FaceAnalysis.verticalCenterWarningThreshold * 0.72
            && topMargin >= targetTopMarginRatio * 0.92
            && face.effectiveBottomMarginRatio >= targetBottomMarginRatio * 0.92

        if abs(guideOffset) > FaceAnalysis.strictVerticalCenterPassThreshold * 0.70 {
            correction -= guideOffset * targetHeight * (gain * 1.16 * weights.guide)
        }

        if let eyeHeight = face.eyeHeightRatio,
           shouldUseEyeHeightForAutoFix,
           !(preferGuideLock && guideAlreadyGood) {
            correction += (eyeHeight - targetEyeHeightRatio) * targetHeight * (gain * 1.02 * weights.eyeHeight)
        }

        if topMargin < targetTopMarginRatio {
            correction += (targetTopMarginRatio - topMargin) * targetHeight * 1.02 * weights.margins
        }

        if face.effectiveBottomMarginRatio < targetBottomMarginRatio {
            correction -= (targetBottomMarginRatio - face.effectiveBottomMarginRatio) * targetHeight * 1.02 * weights.margins
        } else if face.effectiveBottomMarginRatio > 0.18 {
            correction += (face.effectiveBottomMarginRatio - 0.16) * targetHeight * 0.50 * weights.margins
        }

        let limit = targetHeight * (pass >= 2 ? 0.19 : 0.12)
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
        complianceProfile.targetHeadRatio
    }

    private func guideAlignmentOffset(for face: FaceAnalysis) -> Double {
        let actualCenter = face.effectiveTopMarginRatio + face.effectiveHeadHeightRatio / 2
        return actualCenter - targetGuideCenterRatio
    }

    private func topMarginForCompliance(_ face: FaceAnalysis) -> Double {
        guard let eyeHeight = face.eyeHeightRatio else {
            return face.effectiveTopMarginRatio
        }
        let normalEyePositionWithinHead = GuideFramingCalculator.eyePositionWithinHead
        let inferredTopMargin = (1 - eyeHeight) - face.effectiveHeadHeightRatio * normalEyePositionWithinHead
        return max(face.effectiveTopMarginRatio, min(max(inferredTopMargin, 0), 1))
    }

    private func guideWeightedScore(for result: ComplianceResult, analysis: PhotoAnalysis?) -> Int {
        var score = result.score * 10
        let weights = complianceProfile.framingWeights
        var criticalKinds: Set<ComplianceIssueKind> = [.headSize, .faceCentered, .headTilt, .topMargin, .bottomMargin, .headGuideAlignment]
        if complianceProfile.shouldCheckEyeHeightStrictly {
            criticalKinds.insert(.eyeHeight)
        }
        for check in result.checks where criticalKinds.contains(check.kind ?? .format) {
            let kindWeight: Double = switch check.kind {
            case .headSize:
                weights.headSize
            case .faceCentered:
                weights.center
            case .headTilt:
                weights.tilt
            case .topMargin, .bottomMargin, .headGuideAlignment:
                weights.margins
            case .eyeHeight:
                weights.eyeHeight
            default:
                1.0
            }
            switch check.severity {
            case .pass:
                score += Int(24 * kindWeight)
            case .warning:
                score -= Int(45 * kindWeight)
            case .fail:
                score -= Int(120 * kindWeight)
            }
        }

        if let face = analysis?.face {
            if !isViableFramingCandidate(analysis) {
                score -= 2000
            }
            score -= Int(face.effectiveCenterOffsetRatio * 2600 * weights.center)
            if !face.visualAndFaceCentersAgree {
                score -= Int(720 * weights.visualAgreement)
            }
            score -= Int(abs(face.effectiveHeadHeightRatio - targetGuideHeadRatio) * 1180 * weights.headSize)
            score -= Int(abs(face.dominantLevelAngleDegrees) * 24 * weights.tilt)
            let guideOffset = guideAlignmentOffset(for: face)
            let topMargin = topMarginForCompliance(face)
            let guideAlreadyGood =
                abs(guideOffset) <= FaceAnalysis.verticalCenterWarningThreshold * 0.72
                && topMargin >= targetTopMarginRatio * 0.92
                && face.effectiveBottomMarginRatio >= targetBottomMarginRatio * 0.92
            if let eyeHeight = face.eyeHeightRatio,
               shouldUseEyeHeightForAutoFix,
               !guideAlreadyGood {
                score -= Int(abs(eyeHeight - targetEyeHeightRatio) * 1800 * weights.eyeHeight)
            }
            if topMargin < targetTopMarginRatio {
                score -= Int((targetTopMarginRatio - topMargin) * 1800 * weights.margins)
            }
            if face.effectiveBottomMarginRatio < targetBottomMarginRatio {
                score -= Int((targetBottomMarginRatio - face.effectiveBottomMarginRatio) * 2200 * weights.margins)
            }
            score -= Int(abs(guideOffset) * 2200 * max(weights.guide, 0.34))
        }
        return score
    }

    private func snapToCenterIfNeeded(_ state: PhotoEditState, analysis: PhotoAnalysis?) async -> PhotoEditState {
        guard let face = analysis?.face else { return state }
        guard face.effectiveCenterOffsetRatio > FaceAnalysis.strictCenterPassThreshold || !face.visualAndFaceCentersAgree else { return state }

        var bestState = state
        var bestAnalysis = analysis
        var bestScore = guideWeightedScore(
            for: compliance.evaluate(
                image: complianceImage ?? inputImage,
                spec: spec,
                selectedBackground: selectedBackground,
                analysis: analysis
            ),
            analysis: analysis
        )

        let baseCorrection = horizontalCorrection(for: face, pass: 8)
        let nudges: [CGFloat] = [baseCorrection, baseCorrection * 0.7, baseCorrection * 1.18]

        for nudge in nudges {
            var candidate = state
            candidate.offset.width += nudge
            candidate.offset = boundedOffset(candidate.offset, scale: candidate.scale)

            let evaluation = await evaluateCandidate(candidate)
            guard let candidateFace = evaluation.analysis?.face else { continue }
            let candidateScore = guideWeightedScore(for: evaluation.result, analysis: evaluation.analysis)

            let improvedCentering =
                candidateFace.effectiveCenterOffsetRatio < (bestAnalysis?.face?.effectiveCenterOffsetRatio ?? .greatestFiniteMagnitude)
            let strictEnough = candidateFace.effectiveCenterOffsetRatio <= FaceAnalysis.strictCenterPassThreshold

            if strictEnough || improvedCentering || candidateScore > bestScore {
                bestState = candidate
                bestAnalysis = evaluation.analysis
                bestScore = candidateScore
            }

            if strictEnough && candidateFace.visualAndFaceCentersAgree {
                break
            }
        }

        return bestState
    }

    private func resolveDirectCentering(from state: PhotoEditState, analysis: PhotoAnalysis?) async -> PhotoEditState {
        guard let face = analysis?.face else { return state }
        guard face.effectiveCenterOffsetRatio > FaceAnalysis.strictCenterPassThreshold || !face.visualAndFaceCentersAgree else {
            return state
        }

        var currentState = state
        var currentAnalysis = analysis
        var bestState = state
        var bestAnalysis = analysis

        for pass in 0..<3 {
            guard let workingFace = currentAnalysis?.face else { break }
            let baseDelta = directCenterOffsetDelta(for: workingFace, pass: pass)
            let horizontalCandidates: [CGFloat] = [
                baseDelta,
                baseDelta * 0.88,
                baseDelta * 1.08,
                baseDelta + (baseDelta.sign == .minus ? -8 : 8),
                baseDelta + (baseDelta.sign == .minus ? 8 : -8)
            ]

            var localBestState = bestState
            var localBestAnalysis = bestAnalysis
            var localBestOffset = bestAnalysis?.face?.effectiveCenterOffsetRatio ?? .greatestFiniteMagnitude
            var localBestScore = guideWeightedScore(
                for: compliance.evaluate(
                    image: complianceImage ?? inputImage,
                    spec: spec,
                    selectedBackground: selectedBackground,
                    analysis: bestAnalysis
                ),
                analysis: bestAnalysis
            )

            for delta in horizontalCandidates {
                var candidate = currentState
                candidate.offset.width += delta
                candidate.offset = boundedOffset(candidate.offset, scale: candidate.scale)

                let evaluation = await evaluateCandidate(candidate)
                guard let candidateFace = evaluation.analysis?.face else { continue }
                let candidateOffset = candidateFace.effectiveCenterOffsetRatio
                let candidateScore = guideWeightedScore(for: evaluation.result, analysis: evaluation.analysis)
                let offsetImproved = candidateOffset < localBestOffset - 0.0008
                let sameOffsetBetterScore = abs(candidateOffset - localBestOffset) <= 0.0012 && candidateScore > localBestScore

                if offsetImproved || sameOffsetBetterScore {
                    localBestState = candidate
                    localBestAnalysis = evaluation.analysis
                    localBestOffset = candidateOffset
                    localBestScore = candidateScore
                }

                if candidateFace.effectiveCenterOffsetRatio <= FaceAnalysis.strictCenterPassThreshold,
                   candidateFace.visualAndFaceCentersAgree {
                    localBestState = candidate
                    localBestAnalysis = evaluation.analysis
                    localBestOffset = candidateOffset
                    break
                }
            }

            bestState = localBestState
            bestAnalysis = localBestAnalysis
            currentState = localBestState
            currentAnalysis = localBestAnalysis

            if let centeredFace = bestAnalysis?.face,
               centeredFace.effectiveCenterOffsetRatio <= FaceAnalysis.strictCenterPassThreshold,
               centeredFace.visualAndFaceCentersAgree {
                break
            }
        }

        return await snapToCenterIfNeeded(bestState, analysis: bestAnalysis)
    }

    private func directCenterOffsetDelta(for face: FaceAnalysis, pass: Int) -> CGFloat {
        let targetWidth = max(spec.pixelSize.width, 1)
        let signedOffset = face.effectiveSignedCenterOffsetRatio
        let gain = pass == 0 ? 1.02 : (pass == 1 ? 0.92 : 0.78)
        let delta = -signedOffset * targetWidth * gain
        let limit = targetWidth * 0.42
        return CGFloat(clamped(delta, min: -limit, max: limit))
    }

    private func isViableFramingCandidate(_ analysis: PhotoAnalysis?) -> Bool {
        guard let face = analysis?.face else { return false }
        guard analysis?.faceCount == 1 else { return false }
        guard face.faceRect.minY > 0.015, face.faceRect.maxY < 0.985 else { return false }
        guard topMarginForCompliance(face) >= complianceProfile.viableTopMarginRatio,
              face.effectiveBottomMarginRatio >= complianceProfile.viableBottomMarginRatio else { return false }
        if shouldUseEyeHeightForAutoFix {
            guard face.eyeHeightRatio.map({ complianceProfile.viableEyeHeightRange.contains($0) }) ?? false else { return false }
        }
        guard face.effectiveCenterOffsetRatio <= FaceAnalysis.centerWarningThreshold else { return false }
        guard abs(face.dominantLevelAngleDegrees) <= 7.5 else { return false }
        guard face.visualAndFaceCentersAgree else { return false }
        return true
    }

    private func isStrictGuideAligned(_ result: ComplianceResult, analysis: PhotoAnalysis?) -> Bool {
        var criticalKinds: Set<ComplianceIssueKind> = [.headSize, .faceCentered, .headTilt, .topMargin, .bottomMargin, .headGuideAlignment]
        if complianceProfile.shouldCheckEyeHeightStrictly {
            criticalKinds.insert(.eyeHeight)
        }
        let hasCriticalIssue = result.checks.contains { check in
            criticalKinds.contains(check.kind ?? .format) && check.severity != .pass
        }
        guard !hasCriticalIssue, let face = analysis?.face else { return false }
        let eyeStrictlyAligned = !complianceProfile.shouldCheckEyeHeightStrictly
            || face.eyeHeightRatio.map {
                $0 >= complianceProfile.eyeHeightRange.lowerBound - 0.006
                    && $0 <= complianceProfile.eyeHeightRange.upperBound + 0.006
            } == true
        return face.isCentered
            && abs(face.dominantLevelAngleDegrees) <= 2.2
            && abs(face.effectiveHeadHeightRatio - targetGuideHeadRatio) <= max((spec.maxHeadRatio - spec.minHeadRatio) * 0.24, 0.018)
            && abs(guideAlignmentOffset(for: face)) <= FaceAnalysis.strictVerticalCenterPassThreshold
            && topMarginForCompliance(face) >= targetTopMarginRatio
            && face.effectiveBottomMarginRatio >= targetBottomMarginRatio
            && eyeStrictlyAligned
    }

    private func evaluateCandidate(_ candidate: PhotoEditState) async -> (result: ComplianceResult, analysis: PhotoAnalysis?) {
        guard let sourceImage = processedImage ?? inputImage else {
            return (result, currentRenderedAnalysis ?? photoAnalysis)
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
        case .glasses:
            break
        case .lighting:
            let quality = (currentRenderedAnalysis ?? photoAnalysis)?.quality
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
            if let face = (currentRenderedAnalysis ?? photoAnalysis)?.face {
                fixed = correctedFraming(fixed, face: face, pass: 4)
            }
        case .faceCentered:
            Task {
                guard let currentAnalysis = currentRenderedAnalysis ?? photoAnalysis else { return }
                let snapped = await resolveDirectCentering(from: editState, analysis: currentAnalysis)
                await MainActor.run {
                    editState = snapped
                }
                await processCurrentPhoto()
            }
            return
        case .eyeHeight, .topMargin, .bottomMargin, .headGuideAlignment:
            if let face = (currentRenderedAnalysis ?? photoAnalysis)?.face {
                fixed = correctedFraming(fixed, face: face, pass: 5)
            }
        case .eyesOpen, .headCover:
            break
        case .headTilt:
            autoLevelCurrentPhoto()
            return
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
            renderedAnalysisKey = nil
            return
        }

        let analysisKey = currentRenderAnalysisKey
        let rendered = renderer.render(image: sourceImage, spec: spec, background: selectedBackground, faceAnalysis: photoAnalysis?.face, editState: editState)
        guard analysisKey == currentRenderAnalysisKey else { return }
        complianceImage = rendered
        renderedAnalysis = (try? await faceService.analyze(rendered)) ?? nil
        renderedAnalysisKey = analysisKey
        AnalyticsService.logCheckComplete(spec: spec, result: result)
    }

    private func scheduleRenderedComplianceUpdate() {
        editStateUpdateTask?.cancel()
        editStateUpdateTask = Task {
            try? await Task.sleep(nanoseconds: 220_000_000)
            guard !Task.isCancelled else { return }
            await updateRenderedCompliance()
        }
    }

    private func autoLevelCurrentPhoto() {
        Task {
        guard let initialAnalysis = (currentRenderedAnalysis ?? photoAnalysis)?.face else { return }
        let bestState = await bestAutoLeveledCandidate(from: editState, initialFace: initialAnalysis)

        await MainActor.run {
            editState = bestState
        }
        await processCurrentPhoto()
        }
    }

    private func refinedAutoLeveledState(from state: PhotoEditState) async -> PhotoEditState {
        guard let sourceImage = processedImage ?? inputImage else { return state }

        let initialRendered = renderer.render(
            image: sourceImage,
            spec: spec,
            background: selectedBackground,
            faceAnalysis: photoAnalysis?.face,
            editState: state
        )
        guard let initialAnalysis = try? await faceService.analyze(initialRendered),
              let initialFace = initialAnalysis.face else {
            return state
        }

        return await bestAutoLeveledCandidate(from: state, initialFace: initialFace)
    }

    private func bestAutoLeveledCandidate(from state: PhotoEditState, initialFace: FaceAnalysis) async -> PhotoEditState {
        let baseAngle = initialFace.dominantLevelAngleDegrees
        guard abs(baseAngle) > 0.8 else { return state }

        var candidates: [PhotoEditState] = [state]
        let multipliers = [1.0, 0.9, 1.1, 0.72, 1.28, 0.54, 1.46]

        for multiplier in multipliers {
            var candidate = state
            candidate.rotationDegrees = clamped(
                candidate.rotationDegrees - baseAngle * multiplier,
                min: -20,
                max: 20
            )
            candidate.offset = boundedOffset(candidate.offset, scale: candidate.scale)
            candidates.append(candidate)
        }

        var bestState = state
        var bestAngle = abs(baseAngle)
        var bestScore = Int.min

        for (index, seed) in candidates.enumerated() {
            var candidate = seed
            if index > 0 {
                candidate = correctedFraming(candidate, face: initialFace, pass: 6)
            }

            let evaluation = await evaluateCandidate(candidate)
            let candidateAngle = abs(evaluation.analysis?.face?.dominantLevelAngleDegrees ?? baseAngle)
            let candidateScore = guideWeightedScore(for: evaluation.result, analysis: evaluation.analysis)

            let angleImproved = candidateAngle < bestAngle - 0.15
            let sameAngleBetterScore = abs(candidateAngle - bestAngle) <= 0.18 && candidateScore > bestScore

            if angleImproved || sameAngleBetterScore {
                bestState = candidate
                bestAngle = candidateAngle
                bestScore = candidateScore
            }

            if candidateAngle <= 0.9 {
                bestState = candidate
                break
            }
        }

        return bestState
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
    var showsMovementGuides: Bool = true
    var maxWidth: CGFloat = 300
    var maxHeight: CGFloat = 390
    var showsShadow: Bool = true
    var visualScaleMultiplier: CGFloat = 1
    var visualRotationDegrees: Double = 0
    var visualOffset: CGSize = .zero
    @State private var previewImage: UIImage?
    private let renderer = PhotoRenderer()

    var body: some View {
        ZStack {
            background.color
            if let image {
                Image(uiImage: previewImage ?? image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: previewSize.width, height: previewSize.height)
                    .scaleEffect(visualScaleMultiplier)
                    .rotationEffect(.degrees(visualRotationDegrees))
                    .offset(visualOffset)
                    .clipped()
                    .opacity(0.96)
            } else {
                PassportPhotoPlaceholderGuide(spec: spec)
            }

            if image != nil {
                guideOverlay
            }

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
            if let image {
                let previewScale = max(
                    previewSize.width / max(spec.pixelSize.width, 1),
                    previewSize.height / max(spec.pixelSize.height, 1),
                    0.35
                )
                previewImage = renderer.render(
                    image: image,
                    spec: spec,
                    background: background,
                    faceAnalysis: faceAnalysis,
                    editState: editState,
                    scale: previewScale
                )
            } else {
                previewImage = nil
            }
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
            String(format: "%.3f", editState.sharpness),
            String(format: "%.3f", editState.scale),
            String(format: "%.3f", editState.rotationDegrees),
            String(format: "%.1f", editState.offset.width),
            String(format: "%.1f", editState.offset.height),
            spec.id,
            background.rawValue
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
            let targetHeadRatio = guideBoundaryHeadRatio
            let headHeight = height * targetHeadRatio
            let headWidth = headHeight * 0.72
            let eyeRange = spec.complianceProfile.eyeHeightRange
            let eyeTargetRatio = (eyeRange.lowerBound + eyeRange.upperBound) / 2
            let guideTopRatio = guideTopRatioForEyeAlignedHead(
                headRatio: Double(targetHeadRatio),
                eyeTargetRatio: eyeTargetRatio
            )
            let guideCenterY = height * (guideTopRatio + Double(targetHeadRatio) / 2)
            let eyeBandTop = height * (1 - eyeRange.upperBound)
            let eyeBandBottom = height * (1 - eyeRange.lowerBound)
            let eyeBandHeight = max(eyeBandBottom - eyeBandTop, 4)
            let eyeTargetY = height * (1 - eyeTargetRatio)
            let centerBandWidth = max(width * 0.10, 18)

            ZStack {
                FivePercentGrid()
                    .stroke(AppTheme.officialBlue.opacity(0.115), lineWidth: 0.6)
                    .padding(18)

                FivePercentHorizontalLabels()
                    .padding(18)

                if showsMovementGuides, let faceAnalysis {
                    let faceRect = guideSubjectRect(for: faceAnalysis, in: proxy.size)
                    movementGuides(
                        faceAnalysis: faceAnalysis,
                        faceRect: faceRect,
                        canvasSize: proxy.size,
                        targetHeadHeight: headHeight,
                        targetCenterY: guideCenterY
                    )
                }

                Ellipse()
                    .stroke(AppTheme.officialBlue.opacity(0.38), style: StrokeStyle(lineWidth: 1.5, dash: [7, 6]))
                    .frame(width: headWidth, height: headHeight)
                    .position(x: width / 2, y: guideCenterY)

                RoundedRectangle(cornerRadius: 4)
                    .fill(AppTheme.officialBlue.opacity(0.055))
                    .frame(width: centerBandWidth, height: headHeight)
                    .position(x: width / 2, y: guideCenterY)

                Rectangle()
                    .fill(AppTheme.officialBlue.opacity(0.22))
                    .frame(width: 1, height: headHeight)
                    .position(x: width / 2, y: guideCenterY)

                Rectangle()
                    .fill(AppTheme.success.opacity(spec.complianceProfile.shouldCheckEyeHeightStrictly ? 0.13 : 0.08))
                    .frame(height: eyeBandHeight)
                    .padding(.horizontal, 24)
                    .position(x: width / 2, y: eyeBandTop + eyeBandHeight / 2)

                Rectangle()
                    .fill(AppTheme.success.opacity(spec.complianceProfile.shouldCheckEyeHeightStrictly ? 0.32 : 0.22))
                    .frame(height: 1)
                    .padding(.horizontal, 24)
                    .position(x: width / 2, y: eyeTargetY)

                Text(spec.complianceProfile.shouldCheckEyeHeightStrictly
                     ? L10n.text(en: "Eye height range", zh: "眼线合格范围")
                     : L10n.text(en: "Eye height guide", zh: "眼线参考范围"))
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(AppTheme.success.opacity(spec.complianceProfile.shouldCheckEyeHeightStrictly ? 0.88 : 0.72))
                    .padding(.horizontal, 6)
                    .frame(height: 18)
                    .background(AppTheme.cardBackground.opacity(0.92), in: Capsule())
                    .position(x: width - 74, y: max(eyeBandTop - 10, 12))

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
    private func movementGuides(faceAnalysis: FaceAnalysis, faceRect: CGRect, canvasSize: CGSize, targetHeadHeight: CGFloat, targetCenterY: CGFloat) -> some View {
        let targetCenter = CGPoint(x: canvasSize.width / 2, y: targetCenterY)
        let currentCenter = guideCenterlinePoint(for: faceAnalysis, fallbackRect: faceRect, in: canvasSize)
        let horizontalOffset = faceAnalysis.effectiveSignedCenterOffsetRatio
        let guideWidth = targetHeadHeight * 0.72
        let guideHeight = targetHeadHeight
        let allowedHorizontalDrift = max(guideWidth * 0.08, canvasSize.width * 0.045)
        let allowedVerticalDrift = max(guideHeight * 0.16, canvasSize.height * 0.055)
        let shouldPrioritizeHorizontalGuide = abs(currentCenter.x - targetCenter.x) > allowedHorizontalDrift
            && abs(horizontalOffset) > FaceAnalysis.strictCenterPassThreshold
        let verticalGuide = verticalAdjustmentInstruction(
            for: faceAnalysis,
            currentCenter: currentCenter,
            targetCenter: targetCenter,
            allowedVerticalDrift: allowedVerticalDrift
        )
        let scaleGuide = scaleAdjustmentDirection(for: faceAnalysis)

        ZStack {
            if shouldPrioritizeHorizontalGuide {
                let direction: GuideDirection = horizontalOffset < 0 ? .right : .left
                let intensity = guideIntensity(for: abs(horizontalOffset), moderateThreshold: 0.115, severeThreshold: 0.165)
                GuideArrowLine(
                    start: currentCenter,
                    end: CGPoint(x: targetCenter.x, y: currentCenter.y),
                    direction: direction,
                    label: direction == .right ? L10n.text(en: "Move right", zh: "向右移动") : L10n.text(en: "Move left", zh: "向左移动"),
                    intensity: intensity
                )
            }

            if !shouldPrioritizeHorizontalGuide, let verticalGuide {
                let endY = verticalGuide.direction == .up
                    ? min(currentCenter.y - max(abs(currentCenter.y - targetCenter.y), 34), canvasSize.height - 24)
                    : max(currentCenter.y + max(abs(currentCenter.y - targetCenter.y), 34), 24)
                GuideArrowLine(
                    start: currentCenter,
                    end: CGPoint(x: currentCenter.x, y: endY),
                    direction: verticalGuide.direction,
                    label: verticalGuideLabel(for: verticalGuide),
                    intensity: verticalGuide.intensity
                )
            }

            if let scaleGuide {
                GuideScaleBadge(
                    direction: scaleGuide,
                    intensity: scaleGuide.intensity,
                    targetHeadHeight: targetHeadHeight,
                    canvasSize: canvasSize
                )
            }
        }
    }

    private func guideCenterlinePoint(for faceAnalysis: FaceAnalysis, fallbackRect: CGRect, in size: CGSize) -> CGPoint {
        let x = (0.5 + faceAnalysis.effectiveSignedCenterOffsetRatio) * size.width
        let y = faceAnalysis.eyeHeightRatio.map { size.height * (1 - $0) } ?? fallbackRect.midY
        return CGPoint(x: x, y: y)
    }

    private func verticalAdjustmentInstruction(
        for faceAnalysis: FaceAnalysis,
        currentCenter: CGPoint,
        targetCenter: CGPoint,
        allowedVerticalDrift: CGFloat
    ) -> VerticalGuideInstruction? {
        let promptDeadZone = max(FaceAnalysis.strictVerticalCenterPassThreshold * 1.75, 0.052)
        let topGap = Double(strictTopMarginRatio) - faceAnalysis.effectiveTopMarginRatio
        let bottomGap = strictBottomMarginRatio - faceAnalysis.effectiveBottomMarginRatio
        let eyeRange = spec.complianceProfile.eyeHeightRange
        let eyeTargetRatio = (eyeRange.lowerBound + eyeRange.upperBound) / 2
        let eyeHeight = faceAnalysis.eyeHeightRatio ?? eyeTargetRatio
        let eyesAreAtOrBelowRangeMid = eyeHeight <= eyeTargetRatio + 0.010
        let eyesAreAtOrAboveRangeMid = eyeHeight >= eyeTargetRatio - 0.010
        let eyesAreNotClearlyHigh = eyeHeight <= eyeRange.upperBound + 0.010
        let eyesAreNotClearlyLow = eyeHeight >= eyeRange.lowerBound - 0.010
        let guideOffset = (Double(currentCenter.y) - Double(targetCenter.y)) / max(Double(max(spec.pixelSize.height, 1)), 1)
        let shouldShowFramingGuide = abs(currentCenter.y - targetCenter.y) > allowedVerticalDrift
            || abs(guideOffset) > FaceAnalysis.verticalCenterWarningThreshold
            || topGap > 0.018
            || bottomGap > 0.018
        let framingDirection: GuideDirection? =
            guideOffset > promptDeadZone ? .up :
            (guideOffset < -promptDeadZone ? .down :
                (topGap > 0.018 ? (eyesAreAtOrBelowRangeMid ? nil : .down) : (bottomGap > 0.018 ? (eyesAreAtOrAboveRangeMid ? nil : .up) : nil)))

        if spec.complianceProfile.shouldCheckEyeHeightStrictly, let detectedEyeHeight = faceAnalysis.eyeHeightRatio {
            let visualTolerance = 0.015
            let currentEyePercent = Int((detectedEyeHeight * 100).rounded())
            let lowerEyePercent = Int((eyeRange.lowerBound * 100).rounded())
            let upperEyePercent = Int((eyeRange.upperBound * 100).rounded())
            let eyeDirection: GuideDirection? =
                detectedEyeHeight < eyeRange.lowerBound - visualTolerance ? .up :
                (detectedEyeHeight > eyeRange.upperBound + visualTolerance ? .down : nil)
            if let eyeDirection {
                if let framingDirection, shouldShowFramingGuide, framingDirection != eyeDirection {
                    return nil
                }
                let eyeGap = eyeDirection == .up
                    ? eyeRange.lowerBound - detectedEyeHeight
                    : detectedEyeHeight - eyeRange.upperBound
                return VerticalGuideInstruction(
                    direction: eyeDirection,
                    reason: eyeDirection == .up ? .eyeLow : .eyeHigh,
                    intensity: guideIntensity(for: eyeGap, moderateThreshold: 0.040, severeThreshold: 0.075)
                )
            }
        }

        guard shouldShowFramingGuide, let framingDirection else { return nil }
        if topGap > 0.010 && bottomGap > 0.010 {
            return nil
        }
        if framingDirection == .down, (eyesAreAtOrBelowRangeMid || eyesAreNotClearlyHigh) {
            return nil
        }
        if framingDirection == .up, (eyesAreAtOrAboveRangeMid || eyesAreNotClearlyLow) {
            return nil
        }
        let verticalGap = max(
            abs(guideOffset) - promptDeadZone,
            topGap,
            bottomGap,
            0
        )
        return VerticalGuideInstruction(
            direction: framingDirection,
            reason: .framing,
            intensity: guideIntensity(for: verticalGap, moderateThreshold: 0.040, severeThreshold: 0.075)
        )
    }

    private func verticalGuideLabel(for instruction: VerticalGuideInstruction) -> String {
        switch instruction.reason {
        case .eyeLow:
            return L10n.text(en: "Eyes too low · move up", zh: "眼睛偏低，向上移动")
        case .eyeHigh:
            return L10n.text(en: "Eyes too high · move down", zh: "眼睛偏高，向下移动")
        case .framing:
            return instruction.direction == .up ? L10n.text(en: "Move up", zh: "向上移动") : L10n.text(en: "Move down", zh: "向下移动")
        }
    }

    private func scaleAdjustmentDirection(for faceAnalysis: FaceAnalysis) -> GuideScaleDirection? {
        let officialRangeBuffer = max((spec.maxHeadRatio - spec.minHeadRatio) * 0.035, 0.006)
        if faceAnalysis.effectiveHeadHeightRatio > spec.maxHeadRatio + officialRangeBuffer {
            return .zoomOut(intensity: guideIntensity(
                for: faceAnalysis.effectiveHeadHeightRatio - spec.maxHeadRatio,
                moderateThreshold: 0.040,
                severeThreshold: 0.075
            ))
        }
        if faceAnalysis.effectiveHeadHeightRatio < spec.minHeadRatio - officialRangeBuffer {
            return .zoomIn(intensity: guideIntensity(
                for: spec.minHeadRatio - faceAnalysis.effectiveHeadHeightRatio,
                moderateThreshold: 0.040,
                severeThreshold: 0.075
            ))
        }

        let profile = spec.complianceProfile
        let targetHeadRatio = profile.targetHeadRatio
        let tolerance = profile.headPassTolerance
        let officialRange = spec.minHeadRatio...spec.maxHeadRatio
        guard !officialRange.contains(faceAnalysis.effectiveHeadHeightRatio) else {
            return nil
        }
        if faceAnalysis.effectiveHeadHeightRatio < targetHeadRatio - tolerance {
            return .zoomIn(intensity: guideIntensity(
                for: targetHeadRatio - faceAnalysis.effectiveHeadHeightRatio,
                moderateThreshold: 0.040,
                severeThreshold: 0.075
            ))
        }
        if faceAnalysis.effectiveHeadHeightRatio > targetHeadRatio + tolerance {
            return .zoomOut(intensity: guideIntensity(
                for: faceAnalysis.effectiveHeadHeightRatio - targetHeadRatio,
                moderateThreshold: 0.040,
                severeThreshold: 0.075
            ))
        }
        return nil
    }

    private func guideIntensity(for normalizedGap: Double, moderateThreshold: Double, severeThreshold: Double) -> GuideIntensity {
        if normalizedGap >= severeThreshold {
            return .severe
        }
        if normalizedGap >= moderateThreshold {
            return .moderate
        }
        return .mild
    }

    private var strictTopMarginRatio: CGFloat {
        CGFloat(spec.complianceProfile.minimumTopMarginRatio)
    }

    private var strictBottomMarginRatio: Double {
        spec.complianceProfile.minimumBottomMarginRatio
    }

    private var guideBoundaryHeadRatio: CGFloat {
        CGFloat(max(spec.minHeadRatio, min(spec.maxHeadRatio, spec.complianceProfile.targetHeadRatio + spec.complianceProfile.headPassTolerance)))
    }

    private func guideTopRatioForEyeAlignedHead(headRatio: Double, eyeTargetRatio: Double) -> Double {
        GuideFramingCalculator.guideTopRatio(
            headRatio: headRatio,
            eyeTargetRatio: eyeTargetRatio,
            profile: spec.complianceProfile
        )
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
            var rect = previewRect(for: visualHeadRect, in: size)
            let stableCenterX = (0.5 + faceAnalysis.effectiveSignedCenterOffsetRatio) * size.width
            rect.origin.x = CGFloat(stableCenterX) - rect.width / 2
            return rect
        }
        var rect = previewRect(for: faceAnalysis.faceRect, in: size)
        let stableCenterX = (0.5 + faceAnalysis.effectiveSignedCenterOffsetRatio) * size.width
        rect.origin.x = CGFloat(stableCenterX) - rect.width / 2
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

private enum VerticalGuideReason {
    case eyeLow
    case eyeHigh
    case framing
}

private struct VerticalGuideInstruction {
    let direction: GuideDirection
    let reason: VerticalGuideReason
    let intensity: GuideIntensity
}

private enum GuideScaleDirection {
    case zoomIn(intensity: GuideIntensity)
    case zoomOut(intensity: GuideIntensity)

    var intensity: GuideIntensity {
        switch self {
        case let .zoomIn(intensity), let .zoomOut(intensity):
            return intensity
        }
    }

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

private enum GuideIntensity {
    case mild
    case moderate
    case severe

    var color: Color {
        switch self {
        case .mild:
            return AppTheme.warning
        case .moderate:
            return Color(red: 0.88, green: 0.30, blue: 0.05)
        case .severe:
            return AppTheme.danger
        }
    }

    var lineWidth: CGFloat {
        switch self {
        case .mild:
            return 1.3
        case .moderate:
            return 1.8
        case .severe:
            return 2.3
        }
    }

    var arrowSize: CGFloat {
        switch self {
        case .mild:
            return 20
        case .moderate:
            return 23
        case .severe:
            return 26
        }
    }

    var labelOpacity: Double {
        switch self {
        case .mild:
            return 0.90
        case .moderate:
            return 0.96
        case .severe:
            return 1.0
        }
    }
}

private struct GuideArrowLine: View {
    let start: CGPoint
    let end: CGPoint
    let direction: GuideDirection
    let label: String
    let intensity: GuideIntensity

    var body: some View {
        ZStack {
            Path { path in
                path.move(to: start)
                path.addLine(to: end)
            }
            .stroke(intensity.color.opacity(intensity.labelOpacity), style: StrokeStyle(lineWidth: intensity.lineWidth, lineCap: .round, dash: [7, 4]))

            Image(systemName: direction.systemImage)
                .font(.caption.weight(.black))
                .foregroundStyle(.white)
                .frame(width: intensity.arrowSize, height: intensity.arrowSize)
                .background(intensity.color.opacity(intensity.labelOpacity), in: Circle())
                .position(x: end.x, y: end.y)

            Text(label)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(intensity.color.opacity(intensity.labelOpacity), in: Capsule())
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
    let intensity: GuideIntensity
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
        .background(intensity.color.opacity(intensity.labelOpacity), in: Capsule())
        .position(x: canvasSize.width / 2, y: max((canvasSize.height * 0.51) - targetHeadHeight / 2 - 18, 20))
    }
}

private struct FivePercentGrid: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()

        for index in 1..<20 {
            let ratio = CGFloat(index) / 20
            let x = rect.minX + rect.width * ratio
            path.move(to: CGPoint(x: x, y: rect.minY))
            path.addLine(to: CGPoint(x: x, y: rect.maxY))

            let y = rect.minY + rect.height * ratio
            path.move(to: CGPoint(x: rect.minX, y: y))
            path.addLine(to: CGPoint(x: rect.maxX, y: y))
        }

        return path
    }
}

private struct FivePercentHorizontalLabels: View {
    var body: some View {
        GeometryReader { proxy in
            ForEach(1..<20, id: \.self) { index in
                let ratio = CGFloat(index) / 20
                Text("\((20 - index) * 5)")
                    .font(.system(size: 7, weight: .medium, design: .monospaced))
                    .foregroundStyle(AppTheme.officialBlue.opacity(0.34))
                    .frame(width: 18, alignment: .leading)
                    .position(x: 10, y: proxy.size.height * ratio)
            }
        }
    }
}

private struct PassportPhotoPlaceholderGuide: View {
    let spec: PhotoSpec

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let headWidth = min(width * 0.36, 108)
            let headHeight = headWidth * 1.3
            let centerX = width / 2
            let foreheadY = height * 0.32
            let eyeRange = spec.complianceProfile.eyeHeightRange
            let eyeTargetRatio = (eyeRange.lowerBound + eyeRange.upperBound) / 2
            let eyeY = height * (1 - eyeTargetRatio)
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
                eyeLineGuide(y: eyeY)
                guideLine(y: chinY, title: L10n.text(en: "Chin", zh: "下巴"), alignment: .leading)
            }
        }
        .padding(10)
    }

    private func eyeLineGuide(y: CGFloat) -> some View {
        GeometryReader { proxy in
            let labelWidth: CGFloat = 92

            ZStack {
                Rectangle()
                    .fill(AppTheme.success.opacity(0.70))
                    .frame(height: 2.4)
                    .padding(.horizontal, 28)
                    .position(x: proxy.size.width / 2, y: y)

                Text(L10n.text(en: "Eye line", zh: "眼线位置"))
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(AppTheme.success)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .frame(width: labelWidth, height: 18)
                    .background(AppTheme.cardBackground.opacity(0.94), in: Capsule())
                    .overlay {
                        Capsule()
                            .stroke(AppTheme.success.opacity(0.18), lineWidth: 1)
                    }
                    .position(x: proxy.size.width - labelWidth / 2 - 12, y: y - 18)

            }
        }
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
    let showsMovementGuides: Bool
    @Binding var editState: PhotoEditState
    let isProcessing: Bool
    @Binding var gestureStartScale: CGFloat?
    @Binding var gestureStartRotation: Double?
    var maxWidth: CGFloat = min(UIScreen.main.bounds.width - 48, 360)
    var maxHeight: CGFloat = 520
    @GestureState private var dragTranslation: CGSize = .zero
    @State private var isTransformingPhoto = false
    @State private var liveTransformScale: CGFloat?
    @State private var liveTransformRotation: Double?
    @State private var rotationHandleTranslation: CGFloat = 0
    @State private var rotationHandleBaseRotation: Double?
    @State private var rotationHandleTimer: Timer?

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            PhotoPreview(
                image: image,
                spec: spec,
                background: background,
                faceAnalysis: faceAnalysis,
                editState: liveEditState,
                isProcessing: isProcessing,
                showsMovementGuides: showsMovementGuides,
                maxWidth: previewWidth,
                maxHeight: maxHeight,
                visualScaleMultiplier: visualScaleMultiplier,
                visualRotationDegrees: visualRotationDelta,
                visualOffset: visualDragOffset
            )
            .contentShape(Rectangle())
            .coordinateSpace(name: "editablePhotoPreview")
            .gesture(dragGesture)
            .simultaneousGesture(transformGesture)
            .overlay(alignment: .bottomTrailing) {
                if image != nil {
                    rotationHandle
                        .padding(10)
                }
            }
            .overlay(alignment: .trailing) {
                if image != nil {
                    canvasZoomControls
                        .padding(.trailing, 10)
                        .padding(.bottom, 56)
                }
            }
        }
        .frame(width: previewWidth, alignment: .center)
        .onDisappear {
            stopRotationHandleTimer()
        }
    }

    private var previewWidth: CGFloat {
        let ratio = spec.pixelSize.height / max(spec.pixelSize.width, 1)
        let widthForFixedHeight = maxHeight / ratio
        return min(maxWidth, widthForFixedHeight)
    }

    private var previewHeight: CGFloat {
        let ratio = spec.pixelSize.height / max(spec.pixelSize.width, 1)
        return previewWidth * ratio
    }

    private var liveEditState: PhotoEditState {
        editState
    }

    private var visualDragOffset: CGSize {
        isTransformingPhoto ? .zero : dragTranslation
    }

    private var visualScaleMultiplier: CGFloat {
        guard let liveTransformScale else { return 1 }
        return liveTransformScale / max(editState.scale, 0.001)
    }

    private var visualRotationDelta: Double {
        guard let liveTransformRotation else { return 0 }
        return liveTransformRotation - editState.rotationDegrees
    }

    private var previewRenderScale: CGFloat {
        max(
            previewWidth / max(spec.pixelSize.width, 1),
            previewHeight / max(spec.pixelSize.height, 1),
            0.35
        )
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 4)
            .updating($dragTranslation) { value, state, _ in
                guard !isTransformingPhoto else { return }
                state = value.translation
            }
            .onEnded { value in
                guard !isTransformingPhoto else { return }
                editState.offset.width += value.translation.width / previewRenderScale
                editState.offset.height += value.translation.height / previewRenderScale
            }
    }

    private var transformGesture: some Gesture {
        SimultaneousGesture(MagnifyGesture(), RotateGesture())
            .onChanged { value in
                isTransformingPhoto = true
                let startScale = gestureStartScale ?? editState.scale
                let startRotation = gestureStartRotation ?? editState.rotationDegrees
                gestureStartScale = startScale
                gestureStartRotation = startRotation

                if let magnification = value.first?.magnification {
                    liveTransformScale = clamp(startScale * magnification, min: 0.65, max: 2.6)
                }

                if let rotation = value.second?.rotation.degrees {
                    liveTransformRotation = clamp(startRotation + rotation, min: -20, max: 20)
                }
            }
            .onEnded { _ in
                if let liveTransformScale {
                    editState.scale = liveTransformScale
                }
                if let liveTransformRotation {
                    editState.rotationDegrees = liveTransformRotation
                }
                liveTransformScale = nil
                liveTransformRotation = nil
                gestureStartScale = nil
                gestureStartRotation = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                    isTransformingPhoto = false
                }
            }
    }

    private var rotationHandle: some View {
        Image(systemName: "arrow.triangle.2.circlepath")
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 38, height: 38)
            .background(AppTheme.officialBlue.opacity(0.92), in: Circle())
            .overlay {
                Circle()
                    .stroke(.white.opacity(0.86), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.18), radius: 8, x: 0, y: 4)
            .accessibilityLabel(L10n.text(en: "Drag to rotate photo", zh: "拖动旋转照片"))
            .gesture(rotationHandleGesture)
    }

    private var canvasZoomControls: some View {
        VStack(spacing: 8) {
            canvasZoomButton(systemImage: "plus.magnifyingglass", accessibilityLabel: L10n.text(en: "Zoom in", zh: "放大")) {
                editState.scale = min(2.60, editState.scale + 0.03)
            }
            canvasZoomButton(systemImage: "minus.magnifyingglass", accessibilityLabel: L10n.text(en: "Zoom out", zh: "缩小")) {
                editState.scale = max(0.65, editState.scale - 0.03)
            }
        }
    }

    private func canvasZoomButton(systemImage: String, accessibilityLabel: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(AppTheme.officialBlue)
                .frame(width: 36, height: 34)
                .background(AppTheme.cardBackground.opacity(0.94), in: RoundedRectangle(cornerRadius: 9))
                .overlay {
                    RoundedRectangle(cornerRadius: 9)
                        .stroke(AppTheme.officialBlue.opacity(0.16), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 3)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }

    private var rotationHandleGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("editablePhotoPreview"))
            .onChanged { value in
                isTransformingPhoto = true
                rotationHandleTranslation = value.translation.width
                startRotationHandleTimerIfNeeded()
            }
            .onEnded { _ in
                stopRotationHandleTimer()
                if let liveTransformRotation {
                    editState.rotationDegrees = liveTransformRotation
                }
                liveTransformRotation = nil
                rotationHandleBaseRotation = nil
                withAnimation(.easeOut(duration: 0.12)) {
                    rotationHandleTranslation = 0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                    isTransformingPhoto = false
                }
            }
    }

    private func startRotationHandleTimerIfNeeded() {
        guard rotationHandleTimer == nil else { return }
        rotationHandleTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { _ in
            Task { @MainActor in
                let baseRotation = rotationHandleBaseRotation ?? editState.rotationDegrees
                rotationHandleBaseRotation = baseRotation
                let currentRotation = liveTransformRotation ?? baseRotation
                liveTransformRotation = clamp(currentRotation + rotationHandleStep(), min: -20, max: 20)
            }
        }
    }

    private func stopRotationHandleTimer() {
        rotationHandleTimer?.invalidate()
        rotationHandleTimer = nil
    }

    private func rotationHandleStep() -> Double {
        let x = Double(rotationHandleTranslation)
        let deadZone = 3.0
        guard abs(x) > deadZone else { return 0 }
        return min(max(x * 0.018, -0.75), 0.75)
    }

    private func clamp<T: Comparable>(_ value: T, min minValue: T, max maxValue: T) -> T {
        min(max(value, minValue), maxValue)
    }
}

private struct PrecisionAdjustSection: View {
    let spec: PhotoSpec
    @Binding var selectedBackground: PhotoBackground
    @Binding var editState: PhotoEditState
    @State var showsAdvancedTone: Bool
    @State private var selectedToneControl: ToneControl = .brightness

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            BackgroundAdjustStrip(spec: spec, selectedBackground: $selectedBackground, resetButton: AnyView(resetButton))
            DisclosureGroup(isExpanded: $showsAdvancedTone) {
                ToneAdjustStrip(editState: $editState, selectedControl: $selectedToneControl)
                    .padding(.top, 8)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.officialBlue)
                    Text(L10n.text(en: "Advanced editing", zh: "高级编辑", ar: "تحرير متقدم"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.ink)
                    Spacer(minLength: 0)
                    Text(L10n.text(en: "Light · contrast · sharpness", zh: "亮度 · 对比 · 清晰度", ar: "الإضاءة · التباين · الوضوح"))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(AppTheme.secondaryInk)
                        .lineLimit(1)
                        .minimumScaleFactor(0.74)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 9)
            .background(AppTheme.groupedBackground, in: RoundedRectangle(cornerRadius: 9))
        }
        .padding(10)
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(AppTheme.border, lineWidth: 1)
        }
    }

    private var resetButton: some View {
        Button {
            editState = .default
        } label: {
            Image(systemName: "arrow.counterclockwise")
                .font(.caption.weight(.bold))
                .frame(width: 28, height: 24)
        }
        .buttonStyle(.plain)
        .foregroundStyle(editState == .default ? AppTheme.secondaryInk.opacity(0.4) : AppTheme.officialBlue)
        .background(AppTheme.groupedBackground, in: RoundedRectangle(cornerRadius: 7))
        .disabled(editState == .default)
        .accessibilityLabel(L10n.text(en: "Reset adjustments", zh: "重置调整"))
    }

    private func squareToolButton(systemImage: String, accessibilityLabel: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .bold))
            .foregroundStyle(AppTheme.officialBlue)
            .frame(width: 44, height: 34)
            .background(AppTheme.groupedBackground, in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(AppTheme.border.opacity(0.72), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}

private struct BackgroundAdjustStrip: View {
    let spec: PhotoSpec
    @Binding var selectedBackground: PhotoBackground
    let resetButton: AnyView

    var body: some View {
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

            resetButton
        }
        .padding(.horizontal, 8)
        .frame(height: 34)
        .background(AppTheme.groupedBackground, in: RoundedRectangle(cornerRadius: 9))
    }
}

private struct PositionJoystick: View {
    @Binding var offset: CGSize
    var controlSize: CGFloat = 76
    @State private var knobTranslation: CGSize = .zero
    @State private var movementTimer: Timer?

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let limited = limitedTranslation(knobTranslation, in: size)

            ZStack {
                Circle()
                    .fill(AppTheme.cardBackground)
                    .overlay {
                        Circle()
                            .stroke(AppTheme.border.opacity(0.72), lineWidth: 1)
                    }
                    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)

                DirectionTriangle(direction: .up)
                    .position(x: center.x, y: 12)
                DirectionTriangle(direction: .left)
                    .position(x: 12, y: center.y)
                DirectionTriangle(direction: .right)
                    .position(x: size.width - 12, y: center.y)
                DirectionTriangle(direction: .down)
                    .position(x: center.x, y: size.height - 12)

                Circle()
                    .fill(AppTheme.officialBlue.opacity(0.13))
                    .frame(width: 28, height: 28)
                    .overlay {
                        Circle()
                            .stroke(AppTheme.officialBlue.opacity(0.08), lineWidth: 1)
                    }
                    .position(x: center.x + limited.width, y: center.y + limited.height)
            }
        }
        .frame(width: controlSize, height: controlSize)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    knobTranslation = value.translation
                    startMovementTimerIfNeeded()
                }
                .onEnded { _ in
                    stopMovementTimer()
                    withAnimation(.easeOut(duration: 0.12)) {
                        knobTranslation = .zero
                    }
                }
        )
        .onDisappear {
            stopMovementTimer()
        }
        .accessibilityLabel(L10n.text(en: "Drag to move photo", zh: "拖动移动照片"))
    }

    private func limitedTranslation(_ translation: CGSize, in size: CGSize) -> CGSize {
        let radius = max(min(size.width, size.height) / 2 - 18, 4)
        let length = sqrt(translation.width * translation.width + translation.height * translation.height)
        guard length > radius, length > 0 else { return translation }
        let scale = radius / length
        return CGSize(
            width: translation.width * scale,
            height: translation.height * scale
        )
    }

    private func startMovementTimerIfNeeded() {
        guard movementTimer == nil else { return }
        movementTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { _ in
            let movement = joystickMovement()
            offset.width += movement.width
            offset.height += movement.height
        }
    }

    private func stopMovementTimer() {
        movementTimer?.invalidate()
        movementTimer = nil
    }

    private func joystickMovement() -> CGSize {
        let x = Double(knobTranslation.width)
        let y = Double(knobTranslation.height)
        let deadZone = 3.0
        let xStep = abs(x) <= deadZone ? 0 : x * 0.052
        let yStep = abs(y) <= deadZone ? 0 : y * 0.052
        return CGSize(
            width: min(max(xStep, -2.8), 2.8),
            height: min(max(yStep, -2.8), 2.8)
        )
    }
}

private enum DirectionTriangleDirection {
    case up
    case down
    case left
    case right

    var rotation: Double {
        switch self {
        case .up:
            0
        case .right:
            90
        case .down:
            180
        case .left:
            -90
        }
    }
}

private struct DirectionTriangle: View {
    let direction: DirectionTriangleDirection

    var body: some View {
        Image(systemName: "triangle.fill")
            .font(.system(size: 8, weight: .bold))
            .foregroundStyle(AppTheme.secondaryInk.opacity(0.50))
            .rotationEffect(.degrees(direction.rotation))
            .frame(width: 12, height: 12)
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

private enum ToneControl: CaseIterable, Identifiable {
    case brightness
    case contrast
    case shadows
    case warmth
    case sharpness

    var id: String { title }

    var title: String {
        switch self {
        case .brightness:
            L10n.text(en: "Bright", zh: "亮度")
        case .contrast:
            L10n.text(en: "Contrast", zh: "对比")
        case .shadows:
            L10n.text(en: "Shadow", zh: "阴影")
        case .warmth:
            L10n.text(en: "Warmth", zh: "色温")
        case .sharpness:
            L10n.text(en: "Sharp", zh: "锐化")
        }
    }

    var systemImage: String {
        switch self {
        case .brightness:
            "sun.max"
        case .contrast:
            "circle.lefthalf.filled"
        case .shadows:
            "circle.righthalf.filled"
        case .warmth:
            "thermometer.sun"
        case .sharpness:
            "wand.and.stars"
        }
    }

    var range: ClosedRange<Double> {
        switch self {
        case .brightness:
            -0.42...0.42
        case .contrast:
            0.62...1.58
        case .shadows:
            -0.42...0.46
        case .warmth:
            -0.70...0.70
        case .sharpness:
            0...1.65
        }
    }

    var step: Double {
        self == .sharpness ? 0.03 : 0.01
    }

}

private struct ToneAdjustStrip: View {
    @Binding var editState: PhotoEditState
    @Binding var selectedControl: ToneControl

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                ForEach(ToneControl.allCases) { control in
                    Button {
                        selectedControl = control
                    } label: {
                        VStack(spacing: 3) {
                            Image(systemName: control.systemImage)
                                .font(.system(size: 14, weight: .semibold))
                                .frame(width: 30, height: 30)
                                .foregroundStyle(selectedControl == control ? .white : AppTheme.ink)
                                .background(selectedControl == control ? AppTheme.officialBlue : AppTheme.cardBackground, in: Circle())
                                .overlay {
                                    Circle()
                                        .stroke(selectedControl == control ? AppTheme.officialBlue.opacity(0) : AppTheme.border, lineWidth: 1)
                                }
                            Text(control.title)
                                .font(.system(size: 8.5, weight: .semibold))
                                .foregroundStyle(selectedControl == control ? AppTheme.officialBlue : AppTheme.secondaryInk)
                                .lineLimit(1)
                                .minimumScaleFactor(0.72)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(spacing: 10) {
                Text(formattedValue)
                    .font(.caption2.monospacedDigit().weight(.semibold))
                    .foregroundStyle(AppTheme.ink)
                    .frame(width: 42)
                Slider(value: selectedValue, in: selectedControl.range, step: selectedControl.step)
                    .tint(AppTheme.officialBlue)
            }
            .frame(height: 28)
        }
        .padding(8)
        .background(AppTheme.groupedBackground, in: RoundedRectangle(cornerRadius: 9))
    }

    private var selectedValue: Binding<Double> {
        switch selectedControl {
        case .brightness:
            $editState.brightness
        case .contrast:
            $editState.contrast
        case .shadows:
            $editState.shadows
        case .warmth:
            $editState.warmth
        case .sharpness:
            $editState.sharpness
        }
    }

    private var formattedValue: String {
        String(format: selectedControl == .sharpness ? "%.1f" : "%.2f", selectedValue.wrappedValue)
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
        case .background, .headSize, .faceCentered, .headTilt, .eyeHeight, .topMargin, .bottomMargin, .headGuideAlignment, .lighting, .sharpness, .backgroundShadows, .format:
            return true
        case .glasses, .resolution, .singlePerson, .eyesVisible, .eyesOpen, .headCover, .expression, .faceDetection, .fileSize, .none:
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
        case .headSize, .format, .faceCentered, .headTilt, .eyeHeight, .topMargin, .bottomMargin, .headGuideAlignment:
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
