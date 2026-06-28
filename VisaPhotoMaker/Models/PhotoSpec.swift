import SwiftUI

enum SpecCategory: String, CaseIterable, Identifiable, Codable {
    case passport = "Passport"
    case visa = "Visa"
    case immigration = "Immigration"
    case print = "Print"

    var id: String { rawValue }

    var localizedTitle: String {
        if L10n.isChinese {
            switch self {
            case .passport: return "护照"
            case .visa: return "签证"
            case .immigration: return "移民"
            case .print: return "打印"
            }
        }
        if L10n.isArabic {
            switch self {
            case .passport: return "جواز السفر"
            case .visa: return "تأشيرة"
            case .immigration: return "الإقامة"
            case .print: return "طباعة"
            }
        }
        return rawValue
    }
}

struct PhotoSpec: Identifiable, Hashable {
    let id: String
    let country: String
    let localizedCountry: String?
    let arabicCountry: String?
    let title: String
    let localizedTitle: String?
    let arabicTitle: String?
    let category: SpecCategory
    let widthMM: Double
    let heightMM: Double
    let pixelSize: CGSize
    let minHeadRatio: Double
    let maxHeadRatio: Double
    let background: [PhotoBackground]
    let maxFileKB: Int?
    let sourceURL: URL?
    let notes: [String]
    let localizedNotes: [String]?
    let arabicNotes: [String]?

    init(
        id: String,
        country: String,
        localizedCountry: String? = nil,
        arabicCountry: String? = nil,
        title: String,
        localizedTitle: String? = nil,
        arabicTitle: String? = nil,
        category: SpecCategory,
        widthMM: Double,
        heightMM: Double,
        pixelSize: CGSize,
        minHeadRatio: Double,
        maxHeadRatio: Double,
        background: [PhotoBackground],
        maxFileKB: Int?,
        sourceURL: URL?,
        notes: [String],
        localizedNotes: [String]? = nil,
        arabicNotes: [String]? = nil
    ) {
        self.id = id
        self.country = country
        self.localizedCountry = localizedCountry
        self.arabicCountry = arabicCountry
        self.title = title
        self.localizedTitle = localizedTitle
        self.arabicTitle = arabicTitle
        self.category = category
        self.widthMM = widthMM
        self.heightMM = heightMM
        self.pixelSize = pixelSize
        self.minHeadRatio = minHeadRatio
        self.maxHeadRatio = maxHeadRatio
        self.background = background
        self.maxFileKB = maxFileKB
        self.sourceURL = sourceURL
        self.notes = notes
        self.localizedNotes = localizedNotes
        self.arabicNotes = arabicNotes
    }

    var displaySize: String {
        "\(Int(widthMM)) x \(Int(heightMM)) mm"
    }

    var displayPixels: String {
        "\(Int(pixelSize.width)) x \(Int(pixelSize.height)) px"
    }

    var displayCountry: String {
        if L10n.isChinese {
            return localizedCountry ?? country
        }
        if L10n.isArabic {
            return arabicCountry ?? PhotoSpec.arabicCountryName(for: country) ?? country
        }
        return country
    }

    var displayTitle: String {
        if L10n.isChinese {
            return localizedTitle ?? title
        }
        if L10n.isArabic {
            return arabicTitle ?? PhotoSpec.generatedArabicTitle(for: self) ?? title
        }
        return title
    }

    var displayNotes: [String] {
        if L10n.isChinese {
            return localizedNotes ?? notes
        }
        if L10n.isArabic {
            return arabicNotes ?? notes
        }
        return notes
    }

    var searchableText: String {
        var tokens = [id, country, title] + notes
        if let localizedCountry { tokens.append(localizedCountry) }
        if let localizedTitle { tokens.append(localizedTitle) }
        tokens.append(contentsOf: localizedNotes ?? [])
        if let arabicCountry { tokens.append(arabicCountry) }
        if let arabicTitle { tokens.append(arabicTitle) }
        tokens.append(contentsOf: arabicNotes ?? [])
        return tokens.joined(separator: " ").lowercased()
    }

    var complianceProfile: PhotoComplianceProfile {
        PhotoComplianceProfile(spec: self)
    }
}

struct PhotoComplianceProfile: Hashable {
    let glassesPolicy: GlassesPolicy
    let isUSSquareStyle: Bool
    let framingWeights: FramingWeights
    let targetHeadRatio: Double
    let headPassTolerance: Double
    let headWarningTolerance: Double
    let eyeHeightRange: ClosedRange<Double>
    let eyeHeightWarningRange: ClosedRange<Double>
    let minimumTopMarginRatio: Double
    let minimumBottomMarginRatio: Double
    let viableTopMarginRatio: Double
    let viableBottomMarginRatio: Double
    let viableEyeHeightRange: ClosedRange<Double>
    let strictTopMargin: Bool
    let strictBottomMargin: Bool

    var shouldDriveEyeHeightAutoFix: Bool {
        framingWeights.eyeHeight >= 0.70
    }

    var shouldCheckEyeHeightStrictly: Bool {
        framingWeights.eyeHeight >= 0.85
    }

    var shouldWarnHeadGuideAlignment: Bool {
        framingWeights.guide >= 0.22
    }

    init(spec: PhotoSpec) {
        let headRange = max(spec.maxHeadRatio - spec.minHeadRatio, 0.02)
        let midpoint = (spec.minHeadRatio + spec.maxHeadRatio) / 2
        let countryKey = spec.country.lowercased()
        let titleKey = spec.title.lowercased()
        let aspectRatio = spec.heightMM / max(spec.widthMM, 1)
        let isSchengenLike = FramingClassifiers.isSchengenLike(countryKey: countryKey, titleKey: titleKey)
        let isAsian = FramingClassifiers.isAsian(countryKey: countryKey)
        let isOfficialDocument = spec.category != .print
        let isLongDocument = aspectRatio >= 1.32
        let isSquareUSStyle = spec.widthMM == spec.heightMM
            && spec.minHeadRatio <= 0.52
            && spec.maxHeadRatio >= 0.68
            && (countryKey.contains("united states")
                || titleKey.contains("2 x 2")
                || titleKey.contains("square digital"))

        if countryKey.contains("united states") || titleKey.contains("uscis") || titleKey.contains("dv lottery") {
            glassesPolicy = .disallow
        } else if countryKey.contains("australia") {
            glassesPolicy = .disallow
        } else if countryKey.contains("united kingdom") {
            glassesPolicy = .discourage
        } else if countryKey.contains("canada") {
            glassesPolicy = .allowIfClear
        } else if countryKey.contains("japan") {
            glassesPolicy = .allowIfClear
        } else if countryKey.contains("schengen") || countryKey.contains("european union") || countryKey.contains("china") || countryKey.contains("india") {
            glassesPolicy = .allowIfClear
        } else {
            glassesPolicy = .unknown
        }

        isUSSquareStyle = isSquareUSStyle
        framingWeights = FramingWeights(spec: spec, isUSSquareStyle: isSquareUSStyle)
        let eyeLineRule = EyeLineRule(spec: spec, isUSSquareStyle: isSquareUSStyle)

        if isSquareUSStyle {
            targetHeadRatio = 0.62
            eyeHeightRange = eyeLineRule.passRange
            eyeHeightWarningRange = eyeLineRule.warningRange
            minimumTopMarginRatio = 0.08
            minimumBottomMarginRatio = 0.14
            viableTopMarginRatio = 0.055
            viableBottomMarginRatio = 0.105
            viableEyeHeightRange = eyeLineRule.viableRange
            strictTopMargin = true
            strictBottomMargin = true
        } else {
            targetHeadRatio = min(max(midpoint, spec.minHeadRatio + 0.015), spec.maxHeadRatio - 0.015)
            eyeHeightRange = eyeLineRule.passRange
            eyeHeightWarningRange = eyeLineRule.warningRange
            let marginRule = MarginRule(spec: spec)
            minimumTopMarginRatio = marginRule.top
            minimumBottomMarginRatio = marginRule.bottom
            viableTopMarginRatio = max(minimumTopMarginRatio * 0.72, 0.025)
            viableBottomMarginRatio = max(minimumBottomMarginRatio * 0.70, 0.055)
            viableEyeHeightRange = eyeLineRule.viableRange
            strictTopMargin = isOfficialDocument && (framingWeights.margins >= 1.08 || isLongDocument || isSchengenLike || isAsian)
            strictBottomMargin = isOfficialDocument && (framingWeights.margins >= 1.08 || isLongDocument || countryKey.contains("canada"))
        }

        headPassTolerance = max(headRange * 0.24, 0.018)
        headWarningTolerance = max(headRange * 0.46, 0.040)
    }
}

struct EyeLineRule: Hashable {
    let targetRatio: Double
    let tolerance: Double

    var passRange: ClosedRange<Double> {
        clampedRange(center: targetRatio, tolerance: tolerance)
    }

    var warningRange: ClosedRange<Double> {
        clampedRange(center: targetRatio, tolerance: tolerance * 1.85)
    }

    var viableRange: ClosedRange<Double> {
        clampedRange(center: targetRatio, tolerance: tolerance * 2.4)
    }

    init(spec: PhotoSpec, isUSSquareStyle: Bool) {
        let countryKey = spec.country.lowercased()
        let titleKey = spec.title.lowercased()
        let aspectRatio = spec.heightMM / max(spec.widthMM, 1)
        let headRange = max(spec.maxHeadRatio - spec.minHeadRatio, 0.02)
        let isSchengenLike = FramingClassifiers.isSchengenLike(countryKey: countryKey, titleKey: titleKey)
        let isAsian = FramingClassifiers.isAsian(countryKey: countryKey)

        if isUSSquareStyle {
            targetRatio = 0.605
            tolerance = 0.030
        } else if isSchengenLike {
            targetRatio = 0.555
            tolerance = 0.035
        } else if countryKey.contains("united kingdom")
                    || countryKey.contains("australia")
                    || countryKey.contains("new zealand") {
            targetRatio = 0.565
            tolerance = 0.040
        } else if countryKey.contains("canada") {
            targetRatio = 0.545
            tolerance = 0.028
        } else if isAsian {
            targetRatio = aspectRatio >= 1.35 ? 0.550 : 0.560
            tolerance = 0.042
        } else if spec.category == .print {
            targetRatio = aspectRatio > 1.25 ? 0.550 : 0.585
            tolerance = 0.045
        } else {
            let ratioBias = min(max((aspectRatio - 1.0) * 0.055, 0.0), 0.050)
            targetRatio = min(max(0.575 - ratioBias, 0.535), 0.590)
            tolerance = max(0.032, min(0.045, headRange * 0.22))
        }
    }

    private func clampedRange(center: Double, tolerance: Double) -> ClosedRange<Double> {
        max(0.48, center - tolerance)...min(0.68, center + tolerance)
    }
}

private struct MarginRule: Hashable {
    let top: Double
    let bottom: Double

    init(spec: PhotoSpec) {
        let countryKey = spec.country.lowercased()
        let titleKey = spec.title.lowercased()
        let aspectRatio = spec.heightMM / max(spec.widthMM, 1)
        let baseTop = min(max((1 - spec.maxHeadRatio) * 0.22, 0.035), 0.075)
        let baseBottom = min(max((1 - spec.maxHeadRatio) * 0.42, 0.08), 0.16)
        let isSchengenLike = FramingClassifiers.isSchengenLike(countryKey: countryKey, titleKey: titleKey)
        let isAsian = FramingClassifiers.isAsian(countryKey: countryKey)

        if countryKey.contains("canada") && spec.heightMM >= 65 {
            top = 0.075
            bottom = 0.18
        } else if isSchengenLike || countryKey.contains("european union") {
            top = 0.035
            bottom = 0.090
        } else if countryKey.contains("united kingdom")
                    || countryKey.contains("australia")
                    || countryKey.contains("new zealand") {
            top = 0.065
            bottom = 0.095
        } else if countryKey.contains("china") || titleKey.contains("33 x 48") {
            top = 0.045
            bottom = 0.105
        } else if isAsian {
            top = 0.045
            bottom = aspectRatio >= 1.35 ? 0.115 : 0.095
        } else if aspectRatio >= 1.42 {
            top = max(baseTop, 0.050)
            bottom = max(baseBottom, 0.115)
        } else if aspectRatio <= 1.05 {
            top = max(baseTop, 0.052)
            bottom = max(baseBottom, 0.115)
        } else {
            top = baseTop
            bottom = baseBottom
        }
    }
}

private enum FramingClassifiers {
    static func isSchengenLike(countryKey: String, titleKey: String) -> Bool {
        countryKey.contains("schengen")
            || countryKey.contains("european union")
            || countryKey.contains("germany")
            || countryKey.contains("france")
            || countryKey.contains("italy")
            || countryKey.contains("spain")
            || countryKey.contains("netherlands")
            || countryKey.contains("switzerland")
            || countryKey.contains("sweden")
            || countryKey.contains("norway")
            || countryKey.contains("denmark")
            || countryKey.contains("finland")
            || countryKey.contains("austria")
            || countryKey.contains("belgium")
            || countryKey.contains("portugal")
            || countryKey.contains("poland")
            || countryKey.contains("czech")
            || countryKey.contains("greece")
            || titleKey.contains("schengen")
            || titleKey.contains("eu ")
    }

    static func isAsian(countryKey: String) -> Bool {
        countryKey.contains("china")
            || countryKey.contains("japan")
            || countryKey.contains("south korea")
            || countryKey.contains("singapore")
            || countryKey.contains("india")
    }
}

struct FramingWeights: Hashable {
    let headSize: Double
    let margins: Double
    let eyeHeight: Double
    let center: Double
    let tilt: Double
    let visualAgreement: Double
    let guide: Double

    init(
        headSize: Double,
        margins: Double,
        eyeHeight: Double,
        center: Double,
        tilt: Double,
        visualAgreement: Double,
        guide: Double
    ) {
        self.headSize = headSize
        self.margins = margins
        self.eyeHeight = eyeHeight
        self.center = center
        self.tilt = tilt
        self.visualAgreement = visualAgreement
        self.guide = guide
    }

    init(spec: PhotoSpec, isUSSquareStyle: Bool) {
        let countryKey = spec.country.lowercased()
        let titleKey = spec.title.lowercased()
        let isPrintTemplate = spec.category == .print
        let isNorthAmerican = countryKey.contains("canada")
            || countryKey.contains("mexico")
        let isUKOrOceania = countryKey.contains("united kingdom")
            || countryKey.contains("australia")
            || countryKey.contains("new zealand")
        let isSchengenLike = FramingClassifiers.isSchengenLike(countryKey: countryKey, titleKey: titleKey)
        let isAsian = FramingClassifiers.isAsian(countryKey: countryKey)

        if isUSSquareStyle {
            self.init(
                headSize: 1.35,
                margins: 1.28,
                eyeHeight: 1.10,
                center: 1.00,
                tilt: 1.00,
                visualAgreement: 1.00,
                guide: 0.18
            )
        } else if isPrintTemplate {
            let squareOfficialStyle = spec.widthMM == spec.heightMM && spec.maxHeadRatio >= 0.68
            self.init(
                headSize: 1.00,
                margins: 0.92,
                eyeHeight: squareOfficialStyle ? 0.86 : 0.52,
                center: 0.92,
                tilt: 0.90,
                visualAgreement: 0.88,
                guide: 0.10
            )
        } else if isNorthAmerican {
            self.init(
                headSize: 1.24,
                margins: countryKey.contains("canada") ? 1.34 : 1.20,
                eyeHeight: countryKey.contains("canada") ? 0.92 : 0.60,
                center: 1.05,
                tilt: 0.96,
                visualAgreement: 0.92,
                guide: 0.14
            )
        } else if isUKOrOceania {
            self.init(
                headSize: 1.24,
                margins: 1.10,
                eyeHeight: 0.78,
                center: 0.96,
                tilt: 0.96,
                visualAgreement: 0.92,
                guide: 0.15
            )
        } else if isSchengenLike {
            self.init(
                headSize: 1.22,
                margins: 1.00,
                eyeHeight: 1.08,
                center: 0.86,
                tilt: 0.94,
                visualAgreement: 0.90,
                guide: 0.16
            )
        } else if isAsian {
            self.init(
                headSize: 1.06,
                margins: 1.25,
                eyeHeight: 0.58,
                center: 1.10,
                tilt: 0.96,
                visualAgreement: 0.95,
                guide: 0.16
            )
        } else if spec.category == .passport {
            self.init(
                headSize: 1.18,
                margins: 1.08,
                eyeHeight: 0.76,
                center: 0.96,
                tilt: 0.96,
                visualAgreement: 0.92,
                guide: 0.16
            )
        } else {
            self.init(
                headSize: 1.05,
                margins: 1.00,
                eyeHeight: 0.86,
                center: 0.92,
                tilt: 0.92,
                visualAgreement: 0.90,
                guide: 0.14
            )
        }
    }
}

enum GlassesPolicy: Hashable {
    case disallow
    case discourage
    case allowIfClear
    case unknown
}

enum PhotoBackground: String, CaseIterable, Identifiable {
    case white = "White"
    case offWhite = "Off-white"
    case lightGray = "Light gray"
    case blue = "Blue"

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .white:
            return .white
        case .offWhite:
            return Color(red: 0.96, green: 0.95, blue: 0.91)
        case .lightGray:
            return Color(red: 0.88, green: 0.89, blue: 0.90)
        case .blue:
            return Color(red: 0.56, green: 0.73, blue: 0.92)
        }
    }

    var localizedName: String {
        if L10n.isChinese {
            switch self {
            case .white: return "白色"
            case .offWhite: return "米白色"
            case .lightGray: return "浅灰色"
            case .blue: return "蓝色"
            }
        }
        if L10n.isArabic {
            switch self {
            case .white: return "أبيض"
            case .offWhite: return "أبيض مائل"
            case .lightGray: return "رمادي فاتح"
            case .blue: return "أزرق"
            }
        }
        return rawValue
    }
}

extension PhotoSpec {
    static let catalog: [PhotoSpec] = popularSpecs + passportSpecs + visaSpecs + immigrationSpecs + printSpecs

    fileprivate static func arabicCountryName(for country: String) -> String? {
        arabicCountryNames[country]
    }

    fileprivate static func generatedArabicTitle(for spec: PhotoSpec) -> String? {
        if spec.country == "Print" {
            return arabicPrintTitle(for: spec.title)
        }

        guard let country = arabicCountryName(for: spec.country) else { return nil }
        switch spec.category {
        case .passport:
            return "صورة جواز سفر \(country)"
        case .visa:
            return "صورة تأشيرة \(country)"
        case .immigration:
            return "صورة إقامة \(country)"
        case .print:
            return arabicPrintTitle(for: spec.title)
        }
    }

    private static func arabicPrintTitle(for title: String) -> String? {
        if title.contains("2 x 2") { return "صورة 2 x 2 بوصة" }
        if title.contains("1 x 1") { return "صورة 1 x 1 بوصة" }
        if title.contains("35 x 45") { return "صورة 35 x 45 مم" }
        if title.contains("33 x 48") { return "صورة 33 x 48 مم" }
        if title.contains("40 x 50") { return "صورة 40 x 50 مم" }
        if title.contains("50 x 70") { return "صورة 50 x 70 مم" }
        if title.contains("Square Digital") { return "ملف رقمي مربع" }
        if title.contains("Profile Headshot") { return "صورة شخصية نظيفة" }
        return nil
    }

    private static let arabicCountryNames: [String: String] = [
        "Argentina": "الأرجنتين",
        "Australia": "أستراليا",
        "Austria": "النمسا",
        "Bahrain": "البحرين",
        "Belgium": "بلجيكا",
        "Brazil": "البرازيل",
        "Bulgaria": "بلغاريا",
        "Canada": "كندا",
        "Chile": "تشيلي",
        "China": "الصين",
        "Colombia": "كولومبيا",
        "Croatia": "كرواتيا",
        "Czech Republic": "التشيك",
        "Denmark": "الدنمارك",
        "Estonia": "إستونيا",
        "European Union": "الاتحاد الأوروبي",
        "Finland": "فنلندا",
        "France": "فرنسا",
        "Germany": "ألمانيا",
        "Greece": "اليونان",
        "Hong Kong": "هونغ كونغ",
        "Hungary": "المجر",
        "Iceland": "آيسلندا",
        "India": "الهند",
        "Indonesia": "إندونيسيا",
        "Ireland": "أيرلندا",
        "Israel": "إسرائيل",
        "Italy": "إيطاليا",
        "Japan": "اليابان",
        "Kuwait": "الكويت",
        "Latvia": "لاتفيا",
        "Lithuania": "ليتوانيا",
        "Malaysia": "ماليزيا",
        "Mexico": "المكسيك",
        "Netherlands": "هولندا",
        "New Zealand": "نيوزيلندا",
        "Norway": "النرويج",
        "Oman": "عُمان",
        "Peru": "بيرو",
        "Philippines": "الفلبين",
        "Poland": "بولندا",
        "Portugal": "البرتغال",
        "Print": "طباعة",
        "Qatar": "قطر",
        "Romania": "رومانيا",
        "Russia": "روسيا",
        "Saudi Arabia": "السعودية",
        "Schengen Area": "منطقة شنغن",
        "Singapore": "سنغافورة",
        "Slovakia": "سلوفاكيا",
        "Slovenia": "سلوفينيا",
        "South Africa": "جنوب أفريقيا",
        "South Korea": "كوريا الجنوبية",
        "Spain": "إسبانيا",
        "Sweden": "السويد",
        "Switzerland": "سويسرا",
        "Taiwan": "تايوان",
        "Thailand": "تايلاند",
        "Turkey": "تركيا",
        "Ukraine": "أوكرانيا",
        "United Arab Emirates": "الإمارات",
        "United Kingdom": "المملكة المتحدة",
        "United States": "الولايات المتحدة",
        "Vietnam": "فيتنام"
    ]

    private static let popularSpecs: [PhotoSpec] = [
        makeSpec(
            id: "us-passport",
            country: "United States",
            localizedCountry: "美国",
            title: "U.S. Passport",
            localizedTitle: "美国护照",
            category: .passport,
            widthMM: 51,
            heightMM: 51,
            pixelSize: CGSize(width: 600, height: 600),
            minHeadRatio: 0.50,
            maxHeadRatio: 0.69,
            backgrounds: [.white, .offWhite],
            source: "https://travel.state.gov/content/travel/en/passports/how-apply/photos.html",
            notes: ["Square 2 x 2 in photo", "Plain white or off-white background", "Neutral expression, both eyes open"],
            zhNotes: ["2 x 2 英寸正方形照片", "白色或米白色纯色背景", "自然表情，双眼清晰睁开"]
        ),
        makeSpec(
            id: "us-visa",
            country: "United States",
            localizedCountry: "美国",
            title: "U.S. Visa",
            localizedTitle: "美国签证",
            category: .visa,
            widthMM: 51,
            heightMM: 51,
            pixelSize: CGSize(width: 600, height: 600),
            minHeadRatio: 0.50,
            maxHeadRatio: 0.69,
            backgrounds: [.white, .offWhite],
            maxFileKB: 240,
            source: "https://travel.state.gov/content/travel/en/us-visas/visa-information-resources/photos.html",
            notes: ["Digital upload commonly uses 600 x 600 px", "Keep file under the portal limit", "No shadows on face or background"],
            zhNotes: ["电子上传常用 600 x 600 像素", "文件大小需低于申请入口限制", "面部和背景不要有明显阴影"]
        ),
        makeSpec(
            id: "uk-passport",
            country: "United Kingdom",
            localizedCountry: "英国",
            title: "UK Passport",
            localizedTitle: "英国护照",
            category: .passport,
            widthMM: 35,
            heightMM: 45,
            pixelSize: CGSize(width: 600, height: 750),
            minHeadRatio: 0.64,
            maxHeadRatio: 0.80,
            backgrounds: [.lightGray, .offWhite],
            source: "https://www.gov.uk/photos-for-passports/photo-requirements",
            notes: ["35 x 45 mm print size", "Plain light grey or cream background", "Head height usually 29-34 mm"],
            zhNotes: ["35 x 45 毫米打印尺寸", "浅灰或米色纯色背景", "头部高度通常为 29-34 毫米"]
        ),
        makeSpec(
            id: "canada-passport",
            country: "Canada",
            localizedCountry: "加拿大",
            title: "Canada Passport",
            localizedTitle: "加拿大护照",
            category: .passport,
            widthMM: 50,
            heightMM: 70,
            pixelSize: CGSize(width: 600, height: 840),
            minHeadRatio: 0.44,
            maxHeadRatio: 0.52,
            backgrounds: [.white, .offWhite],
            source: "https://www.canada.ca/en/immigration-refugees-citizenship/services/canadian-passports/photos.html",
            notes: ["50 x 70 mm print size", "Face height guideline is narrower than U.S. photos", "Use even lighting"],
            zhNotes: ["50 x 70 毫米打印尺寸", "面部高度要求比美国照片更窄", "使用均匀正面光线"]
        ),
        makeSpec(
            id: "schengen-visa",
            country: "Schengen Area",
            localizedCountry: "申根区",
            title: "Schengen Visa",
            localizedTitle: "申根签证",
            category: .visa,
            widthMM: 35,
            heightMM: 45,
            pixelSize: CGSize(width: 413, height: 531),
            minHeadRatio: 0.70,
            maxHeadRatio: 0.80,
            backgrounds: [.white, .lightGray],
            notes: ["35 x 45 mm photo", "Face should take most of the frame", "Background must be plain and light"],
            zhNotes: ["35 x 45 毫米照片", "面部应占画面较大比例", "背景需为纯色浅色"]
        ),
        makeSpec(
            id: "australia-passport",
            country: "Australia",
            localizedCountry: "澳大利亚",
            title: "Australia Passport",
            localizedTitle: "澳大利亚护照",
            category: .passport,
            widthMM: 35,
            heightMM: 45,
            pixelSize: CGSize(width: 420, height: 540),
            minHeadRatio: 0.64,
            maxHeadRatio: 0.80,
            backgrounds: [.white, .offWhite],
            source: "https://www.passports.gov.au/getting-passport-how-it-works/photo-guidelines",
            notes: commonNotes("35 x 45 mm", background: "plain white or light background"),
            zhNotes: commonZhNotes("35 x 45 毫米", background: "白色或浅色纯色背景")
        ),
        makeSpec(
            id: "china-visa",
            country: "China",
            localizedCountry: "中国",
            title: "China Visa",
            localizedTitle: "中国签证",
            category: .visa,
            widthMM: 33,
            heightMM: 48,
            pixelSize: CGSize(width: 390, height: 567),
            minHeadRatio: 0.58,
            maxHeadRatio: 0.69,
            backgrounds: [.white],
            source: "https://www.visaforchina.cn/",
            notes: ["33 x 48 mm photo", "White or near-white background", "Head height is commonly checked strictly"],
            zhNotes: ["33 x 48 毫米照片", "白色或接近白色背景", "头部高度通常检查较严格"]
        ),
        makeSpec(
            id: "india-visa",
            country: "India",
            localizedCountry: "印度",
            title: "India Visa",
            localizedTitle: "印度签证",
            category: .visa,
            widthMM: 51,
            heightMM: 51,
            pixelSize: CGSize(width: 350, height: 350),
            minHeadRatio: 0.50,
            maxHeadRatio: 0.69,
            backgrounds: [.white, .offWhite],
            maxFileKB: 1024,
            source: "https://indianvisaonline.gov.in/",
            notes: ["Square photo", "Plain light background", "Keep the face centered"],
            zhNotes: ["正方形照片", "浅色纯色背景", "面部保持居中"]
        )
    ]

    private static let passportSpecs: [PhotoSpec] = [
        passport("eu-passport", "European Union", "欧盟", 35, 45, CGSize(width: 413, height: 531), 0.70, 0.80, [.white, .lightGray]),
        passport("germany-passport", "Germany", "德国", 35, 45, CGSize(width: 413, height: 531), 0.70, 0.80, [.white, .lightGray]),
        passport("france-passport", "France", "法国", 35, 45, CGSize(width: 413, height: 531), 0.70, 0.80, [.white, .lightGray]),
        passport("italy-passport", "Italy", "意大利", 35, 45, CGSize(width: 413, height: 531), 0.70, 0.80, [.white, .lightGray]),
        passport("spain-passport", "Spain", "西班牙", 35, 45, CGSize(width: 413, height: 531), 0.70, 0.80, [.white, .lightGray]),
        passport("netherlands-passport", "Netherlands", "荷兰", 35, 45, CGSize(width: 413, height: 531), 0.70, 0.80, [.white, .lightGray]),
        passport("ireland-passport", "Ireland", "爱尔兰", 35, 45, CGSize(width: 413, height: 531), 0.64, 0.80, [.white, .lightGray]),
        passport("switzerland-passport", "Switzerland", "瑞士", 35, 45, CGSize(width: 413, height: 531), 0.70, 0.80, [.white, .lightGray]),
        passport("sweden-passport", "Sweden", "瑞典", 35, 45, CGSize(width: 413, height: 531), 0.70, 0.80, [.white, .lightGray]),
        passport("norway-passport", "Norway", "挪威", 35, 45, CGSize(width: 413, height: 531), 0.70, 0.80, [.white, .lightGray]),
        passport("denmark-passport", "Denmark", "丹麦", 35, 45, CGSize(width: 413, height: 531), 0.70, 0.80, [.white, .lightGray]),
        passport("finland-passport", "Finland", "芬兰", 36, 47, CGSize(width: 425, height: 555), 0.68, 0.80, [.white, .lightGray]),
        passport("austria-passport", "Austria", "奥地利", 35, 45, CGSize(width: 413, height: 531), 0.70, 0.80, [.white, .lightGray]),
        passport("belgium-passport", "Belgium", "比利时", 35, 45, CGSize(width: 413, height: 531), 0.70, 0.80, [.white, .lightGray]),
        passport("portugal-passport", "Portugal", "葡萄牙", 35, 45, CGSize(width: 413, height: 531), 0.70, 0.80, [.white, .lightGray]),
        passport("poland-passport", "Poland", "波兰", 35, 45, CGSize(width: 413, height: 531), 0.70, 0.80, [.white, .lightGray]),
        passport("czech-passport", "Czech Republic", "捷克", 35, 45, CGSize(width: 413, height: 531), 0.70, 0.80, [.white, .lightGray]),
        passport("greece-passport", "Greece", "希腊", 40, 60, CGSize(width: 472, height: 709), 0.56, 0.68, [.white, .lightGray]),
        passport("turkey-passport", "Turkey", "土耳其", 50, 60, CGSize(width: 590, height: 709), 0.56, 0.70, [.white]),
        passport("russia-passport", "Russia", "俄罗斯", 35, 45, CGSize(width: 413, height: 531), 0.64, 0.78, [.white, .lightGray]),
        passport("ukraine-passport", "Ukraine", "乌克兰", 35, 45, CGSize(width: 413, height: 531), 0.64, 0.78, [.white, .lightGray]),
        passport("romania-passport", "Romania", "罗马尼亚", 35, 45, CGSize(width: 413, height: 531), 0.70, 0.80, [.white, .lightGray]),
        passport("hungary-passport", "Hungary", "匈牙利", 35, 45, CGSize(width: 413, height: 531), 0.70, 0.80, [.white, .lightGray]),
        passport("iceland-passport", "Iceland", "冰岛", 35, 45, CGSize(width: 413, height: 531), 0.70, 0.80, [.white, .lightGray]),
        passport("croatia-passport", "Croatia", "克罗地亚", 35, 45, CGSize(width: 413, height: 531), 0.70, 0.80, [.white, .lightGray]),
        passport("slovenia-passport", "Slovenia", "斯洛文尼亚", 35, 45, CGSize(width: 413, height: 531), 0.70, 0.80, [.white, .lightGray]),
        passport("slovakia-passport", "Slovakia", "斯洛伐克", 35, 45, CGSize(width: 413, height: 531), 0.70, 0.80, [.white, .lightGray]),
        passport("estonia-passport", "Estonia", "爱沙尼亚", 35, 45, CGSize(width: 413, height: 531), 0.70, 0.80, [.white, .lightGray]),
        passport("latvia-passport", "Latvia", "拉脱维亚", 35, 45, CGSize(width: 413, height: 531), 0.70, 0.80, [.white, .lightGray]),
        passport("lithuania-passport", "Lithuania", "立陶宛", 35, 45, CGSize(width: 413, height: 531), 0.70, 0.80, [.white, .lightGray]),
        passport("bulgaria-passport", "Bulgaria", "保加利亚", 35, 45, CGSize(width: 413, height: 531), 0.70, 0.80, [.white, .lightGray]),
        passport("mexico-passport", "Mexico", "墨西哥", 35, 45, CGSize(width: 413, height: 531), 0.64, 0.78, [.white]),
        passport("brazil-passport", "Brazil", "巴西", 50, 70, CGSize(width: 591, height: 827), 0.44, 0.60, [.white]),
        passport("argentina-passport", "Argentina", "阿根廷", 40, 40, CGSize(width: 472, height: 472), 0.50, 0.70, [.white, .lightGray]),
        passport("chile-passport", "Chile", "智利", 45, 45, CGSize(width: 531, height: 531), 0.50, 0.70, [.white, .lightGray]),
        passport("colombia-passport", "Colombia", "哥伦比亚", 40, 50, CGSize(width: 472, height: 591), 0.52, 0.72, [.white]),
        passport("peru-passport", "Peru", "秘鲁", 35, 43, CGSize(width: 413, height: 508), 0.58, 0.75, [.white]),
        passport("japan-passport", "Japan", "日本", 35, 45, CGSize(width: 413, height: 531), 0.60, 0.75, [.white], source: "https://www.mofa.go.jp/j_info/visit/visa/index.html"),
        passport("south-korea-passport", "South Korea", "韩国", 35, 45, CGSize(width: 413, height: 531), 0.60, 0.75, [.white]),
        passport("singapore-passport", "Singapore", "新加坡", 35, 45, CGSize(width: 413, height: 531), 0.64, 0.78, [.white, .lightGray]),
        passport("malaysia-passport", "Malaysia", "马来西亚", 35, 50, CGSize(width: 413, height: 591), 0.50, 0.68, [.white, .blue]),
        passport("thailand-passport", "Thailand", "泰国", 35, 45, CGSize(width: 413, height: 531), 0.60, 0.75, [.white, .lightGray]),
        passport("vietnam-passport", "Vietnam", "越南", 40, 60, CGSize(width: 472, height: 709), 0.52, 0.70, [.white]),
        passport("indonesia-passport", "Indonesia", "印度尼西亚", 40, 60, CGSize(width: 472, height: 709), 0.52, 0.70, [.white, .blue]),
        passport("philippines-passport", "Philippines", "菲律宾", 35, 45, CGSize(width: 413, height: 531), 0.60, 0.75, [.white, .offWhite]),
        passport("taiwan-passport", "Taiwan", "中国台湾", 35, 45, CGSize(width: 413, height: 531), 0.60, 0.75, [.white]),
        passport("hong-kong-passport", "Hong Kong", "中国香港", 40, 50, CGSize(width: 472, height: 591), 0.56, 0.74, [.white]),
        passport("uae-passport", "United Arab Emirates", "阿联酋", 40, 60, CGSize(width: 472, height: 709), 0.52, 0.70, [.white]),
        passport("saudi-passport", "Saudi Arabia", "沙特阿拉伯", 40, 60, CGSize(width: 472, height: 709), 0.52, 0.70, [.white]),
        passport("qatar-passport", "Qatar", "卡塔尔", 40, 60, CGSize(width: 472, height: 709), 0.52, 0.70, [.white]),
        passport("kuwait-passport", "Kuwait", "科威特", 40, 60, CGSize(width: 472, height: 709), 0.52, 0.70, [.white]),
        passport("oman-passport", "Oman", "阿曼", 40, 60, CGSize(width: 472, height: 709), 0.52, 0.70, [.white]),
        passport("bahrain-passport", "Bahrain", "巴林", 40, 60, CGSize(width: 472, height: 709), 0.52, 0.70, [.white]),
        passport("israel-passport", "Israel", "以色列", 35, 45, CGSize(width: 413, height: 531), 0.60, 0.75, [.white, .lightGray]),
        passport("south-africa-passport", "South Africa", "南非", 35, 45, CGSize(width: 413, height: 531), 0.60, 0.75, [.white, .lightGray]),
        passport("new-zealand-passport", "New Zealand", "新西兰", 35, 45, CGSize(width: 420, height: 540), 0.64, 0.80, [.white, .offWhite])
    ]

    private static let visaSpecs: [PhotoSpec] = [
        visa("uk-visa", "United Kingdom", "英国", 35, 45, CGSize(width: 600, height: 750), 0.64, 0.80, [.lightGray, .offWhite], maxFileKB: 500, source: "https://www.gov.uk/photos-for-passports/photo-requirements"),
        visa("canada-visa", "Canada", "加拿大", 35, 45, CGSize(width: 420, height: 540), 0.60, 0.75, [.white, .offWhite], maxFileKB: 240),
        visa("australia-visa", "Australia", "澳大利亚", 35, 45, CGSize(width: 420, height: 540), 0.64, 0.80, [.white, .offWhite], maxFileKB: 500, source: "https://immi.homeaffairs.gov.au/help-support/departmental-forms/online-forms/photo-requirements"),
        visa("new-zealand-visa", "New Zealand", "新西兰", 35, 45, CGSize(width: 420, height: 540), 0.64, 0.80, [.white, .offWhite], maxFileKB: 500),
        visa("japan-visa", "Japan", "日本", 35, 45, CGSize(width: 413, height: 531), 0.60, 0.75, [.white], source: "https://www.mofa.go.jp/j_info/visit/visa/index.html"),
        visa("south-korea-visa", "South Korea", "韩国", 35, 45, CGSize(width: 413, height: 531), 0.60, 0.75, [.white], maxFileKB: 500),
        visa("singapore-visa", "Singapore", "新加坡", 35, 45, CGSize(width: 413, height: 531), 0.64, 0.78, [.white, .lightGray], maxFileKB: 500),
        visa("malaysia-visa", "Malaysia", "马来西亚", 35, 50, CGSize(width: 413, height: 591), 0.50, 0.68, [.white, .blue], maxFileKB: 500),
        visa("thailand-visa", "Thailand", "泰国", 35, 45, CGSize(width: 413, height: 531), 0.60, 0.75, [.white, .lightGray], maxFileKB: 500),
        visa("vietnam-visa", "Vietnam", "越南", 40, 60, CGSize(width: 472, height: 709), 0.52, 0.70, [.white], maxFileKB: 1024),
        visa("indonesia-visa", "Indonesia", "印度尼西亚", 40, 60, CGSize(width: 472, height: 709), 0.52, 0.70, [.white, .blue], maxFileKB: 500),
        visa("philippines-visa", "Philippines", "菲律宾", 35, 45, CGSize(width: 413, height: 531), 0.60, 0.75, [.white, .offWhite], maxFileKB: 500),
        visa("taiwan-visa", "Taiwan", "中国台湾", 35, 45, CGSize(width: 413, height: 531), 0.60, 0.75, [.white], maxFileKB: 500),
        visa("hong-kong-visa", "Hong Kong", "中国香港", 40, 50, CGSize(width: 472, height: 591), 0.56, 0.74, [.white], maxFileKB: 500),
        visa("turkey-visa", "Turkey", "土耳其", 50, 60, CGSize(width: 590, height: 709), 0.56, 0.70, [.white], maxFileKB: 500),
        visa("uae-visa", "United Arab Emirates", "阿联酋", 40, 60, CGSize(width: 472, height: 709), 0.52, 0.70, [.white], maxFileKB: 500),
        visa("saudi-visa", "Saudi Arabia", "沙特阿拉伯", 40, 60, CGSize(width: 472, height: 709), 0.52, 0.70, [.white], maxFileKB: 500),
        visa("qatar-visa", "Qatar", "卡塔尔", 40, 60, CGSize(width: 472, height: 709), 0.52, 0.70, [.white], maxFileKB: 500),
        visa("kuwait-visa", "Kuwait", "科威特", 40, 60, CGSize(width: 472, height: 709), 0.52, 0.70, [.white], maxFileKB: 500),
        visa("oman-visa", "Oman", "阿曼", 40, 60, CGSize(width: 472, height: 709), 0.52, 0.70, [.white], maxFileKB: 500),
        visa("bahrain-visa", "Bahrain", "巴林", 40, 60, CGSize(width: 472, height: 709), 0.52, 0.70, [.white], maxFileKB: 500),
        visa("brazil-visa", "Brazil", "巴西", 50, 70, CGSize(width: 591, height: 827), 0.44, 0.60, [.white], maxFileKB: 1024),
        visa("mexico-visa", "Mexico", "墨西哥", 35, 45, CGSize(width: 413, height: 531), 0.64, 0.78, [.white], maxFileKB: 500),
        visa("russia-visa", "Russia", "俄罗斯", 35, 45, CGSize(width: 413, height: 531), 0.64, 0.78, [.white, .lightGray], maxFileKB: 500),
        visa("france-visa", "France", "法国", 35, 45, CGSize(width: 413, height: 531), 0.70, 0.80, [.white, .lightGray], maxFileKB: 500),
        visa("germany-visa", "Germany", "德国", 35, 45, CGSize(width: 413, height: 531), 0.70, 0.80, [.white, .lightGray], maxFileKB: 500),
        visa("italy-visa", "Italy", "意大利", 35, 45, CGSize(width: 413, height: 531), 0.70, 0.80, [.white, .lightGray], maxFileKB: 500),
        visa("spain-visa", "Spain", "西班牙", 35, 45, CGSize(width: 413, height: 531), 0.70, 0.80, [.white, .lightGray], maxFileKB: 500)
    ]

    private static let immigrationSpecs: [PhotoSpec] = [
        makeSpec(id: "us-green-card", country: "United States", localizedCountry: "美国", title: "Green Card / USCIS", localizedTitle: "美国绿卡 / USCIS", category: .immigration, widthMM: 51, heightMM: 51, pixelSize: CGSize(width: 600, height: 600), minHeadRatio: 0.50, maxHeadRatio: 0.69, backgrounds: [.white, .offWhite], source: "https://travel.state.gov/content/travel/en/us-visas/visa-information-resources/photos.html", notes: ["Uses U.S. passport-style photo", "2 x 2 in square format", "Head centered with a plain background"], zhNotes: ["使用美国护照照片规格", "2 x 2 英寸正方形", "头部居中，背景纯净"]),
        makeSpec(id: "dv-lottery", country: "United States", localizedCountry: "美国", title: "DV Lottery", localizedTitle: "美国 DV 抽签", category: .immigration, widthMM: 51, heightMM: 51, pixelSize: CGSize(width: 600, height: 600), minHeadRatio: 0.50, maxHeadRatio: 0.69, backgrounds: [.white, .offWhite], maxFileKB: 240, source: "https://dvprogram.state.gov/", notes: ["Square digital photo", "600 x 600 px recommended", "Avoid retouched or filtered photos"], zhNotes: ["正方形电子照片", "建议 600 x 600 像素", "避免明显修图或滤镜"]),
        makeSpec(id: "uscis-ead", country: "United States", localizedCountry: "美国", title: "USCIS EAD / OPT", localizedTitle: "美国 EAD / OPT", category: .immigration, widthMM: 51, heightMM: 51, pixelSize: CGSize(width: 600, height: 600), minHeadRatio: 0.50, maxHeadRatio: 0.69, backgrounds: [.white, .offWhite], maxFileKB: 240, notes: commonNotes("2 x 2 in", background: "white or off-white background"), zhNotes: commonZhNotes("2 x 2 英寸", background: "白色或米白色背景")),
        makeSpec(id: "canada-pr", country: "Canada", localizedCountry: "加拿大", title: "Canada PR Card", localizedTitle: "加拿大枫叶卡", category: .immigration, widthMM: 50, heightMM: 70, pixelSize: CGSize(width: 600, height: 840), minHeadRatio: 0.44, maxHeadRatio: 0.52, backgrounds: [.white, .offWhite], maxFileKB: 500, notes: commonNotes("50 x 70 mm", background: "white or light background"), zhNotes: commonZhNotes("50 x 70 毫米", background: "白色或浅色背景")),
        makeSpec(id: "uk-immigration", country: "United Kingdom", localizedCountry: "英国", title: "UK Immigration Photo", localizedTitle: "英国移民照片", category: .immigration, widthMM: 35, heightMM: 45, pixelSize: CGSize(width: 600, height: 750), minHeadRatio: 0.64, maxHeadRatio: 0.80, backgrounds: [.lightGray, .offWhite], maxFileKB: 500, notes: commonNotes("35 x 45 mm", background: "light grey or cream background"), zhNotes: commonZhNotes("35 x 45 毫米", background: "浅灰或米色背景")),
        makeSpec(id: "australia-immigration", country: "Australia", localizedCountry: "澳大利亚", title: "Australia Immigration Photo", localizedTitle: "澳大利亚移民照片", category: .immigration, widthMM: 35, heightMM: 45, pixelSize: CGSize(width: 420, height: 540), minHeadRatio: 0.64, maxHeadRatio: 0.80, backgrounds: [.white, .offWhite], maxFileKB: 500, notes: commonNotes("35 x 45 mm", background: "plain light background"), zhNotes: commonZhNotes("35 x 45 毫米", background: "浅色纯色背景")),
        makeSpec(id: "eu-residence-permit", country: "European Union", localizedCountry: "欧盟", title: "EU Residence Permit", localizedTitle: "欧盟居留许可", category: .immigration, widthMM: 35, heightMM: 45, pixelSize: CGSize(width: 413, height: 531), minHeadRatio: 0.70, maxHeadRatio: 0.80, backgrounds: [.white, .lightGray], maxFileKB: 500, notes: commonNotes("35 x 45 mm", background: "plain light background"), zhNotes: commonZhNotes("35 x 45 毫米", background: "浅色纯色背景")),
        makeSpec(id: "saudi-iqama", country: "Saudi Arabia", localizedCountry: "沙特阿拉伯", title: "Saudi Iqama", localizedTitle: "沙特 Iqama 居留证", arCountry: "السعودية", arTitle: "صورة الإقامة السعودية", category: .immigration, widthMM: 40, heightMM: 60, pixelSize: CGSize(width: 472, height: 709), minHeadRatio: 0.52, maxHeadRatio: 0.70, backgrounds: [.white], maxFileKB: 500, notes: gccNotes(document: "Iqama", size: "4 x 6 cm"), zhNotes: ["4 x 6 厘米居留证照片模板", "白色纯色背景", "适合 Saudi Iqama / 居留证照片工作流", "最终提交前请核对 Absher、Muqeem 或办理渠道要求"], arNotes: gccArabicNotes(document: "الإقامة السعودية", size: "4 x 6 سم")),
        makeSpec(id: "uae-emirates-id", country: "United Arab Emirates", localizedCountry: "阿联酋", title: "UAE Emirates ID", localizedTitle: "阿联酋 Emirates ID", arCountry: "الإمارات", arTitle: "صورة الهوية الإماراتية", category: .immigration, widthMM: 40, heightMM: 60, pixelSize: CGSize(width: 472, height: 709), minHeadRatio: 0.52, maxHeadRatio: 0.70, backgrounds: [.white], maxFileKB: 500, notes: gccNotes(document: "Emirates ID", size: "4 x 6 cm"), zhNotes: ["4 x 6 厘米 Emirates ID 照片模板", "白色纯色背景", "适合阿联酋 Emirates ID / 居留相关照片工作流", "最终提交前请核对 ICP 或办理渠道要求"], arNotes: gccArabicNotes(document: "الهوية الإماراتية", size: "4 x 6 سم")),
        makeSpec(id: "qatar-residence-permit", country: "Qatar", localizedCountry: "卡塔尔", title: "Qatar Residence Permit", localizedTitle: "卡塔尔居留证", arCountry: "قطر", arTitle: "صورة الإقامة القطرية", category: .immigration, widthMM: 40, heightMM: 60, pixelSize: CGSize(width: 472, height: 709), minHeadRatio: 0.52, maxHeadRatio: 0.70, backgrounds: [.white], maxFileKB: 500, notes: gccNotes(document: "Qatar residence permit", size: "4 x 6 cm"), zhNotes: ["4 x 6 厘米卡塔尔居留照片模板", "白色纯色背景", "适合 Qatar Residence Permit / 居留证照片工作流", "最终提交前请核对 Metrash 或办理渠道要求"], arNotes: gccArabicNotes(document: "الإقامة القطرية", size: "4 x 6 سم")),
        makeSpec(id: "kuwait-civil-id", country: "Kuwait", localizedCountry: "科威特", title: "Kuwait Civil ID", localizedTitle: "科威特 Civil ID", arCountry: "الكويت", arTitle: "صورة البطاقة المدنية الكويتية", category: .immigration, widthMM: 40, heightMM: 60, pixelSize: CGSize(width: 472, height: 709), minHeadRatio: 0.52, maxHeadRatio: 0.70, backgrounds: [.white], maxFileKB: 500, notes: gccNotes(document: "Kuwait Civil ID", size: "4 x 6 cm"), zhNotes: ["4 x 6 厘米科威特 Civil ID 照片模板", "白色纯色背景", "适合 Kuwait Civil ID / 居留身份照片工作流", "最终提交前请核对 PACI 或办理渠道要求"], arNotes: gccArabicNotes(document: "البطاقة المدنية الكويتية", size: "4 x 6 سم")),
        makeSpec(id: "oman-residence-card", country: "Oman", localizedCountry: "阿曼", title: "Oman Residence Card", localizedTitle: "阿曼居留卡", arCountry: "عُمان", arTitle: "صورة بطاقة الإقامة العمانية", category: .immigration, widthMM: 40, heightMM: 60, pixelSize: CGSize(width: 472, height: 709), minHeadRatio: 0.52, maxHeadRatio: 0.70, backgrounds: [.white], maxFileKB: 500, notes: gccNotes(document: "Oman residence card", size: "4 x 6 cm"), zhNotes: ["4 x 6 厘米阿曼居留卡照片模板", "白色纯色背景", "适合 Oman Residence Card / 居留卡照片工作流", "最终提交前请核对 Royal Oman Police 或办理渠道要求"], arNotes: gccArabicNotes(document: "بطاقة الإقامة العمانية", size: "4 x 6 سم")),
        makeSpec(id: "bahrain-cpr", country: "Bahrain", localizedCountry: "巴林", title: "Bahrain CPR / Residence Permit", localizedTitle: "巴林 CPR / 居留许可", arCountry: "البحرين", arTitle: "صورة بطاقة البحرين CPR", category: .immigration, widthMM: 40, heightMM: 60, pixelSize: CGSize(width: 472, height: 709), minHeadRatio: 0.52, maxHeadRatio: 0.70, backgrounds: [.white], maxFileKB: 500, notes: gccNotes(document: "Bahrain CPR or residence permit", size: "4 x 6 cm"), zhNotes: ["4 x 6 厘米巴林 CPR / 居留照片模板", "白色纯色背景", "适合 Bahrain CPR 或居留许可照片工作流", "最终提交前请核对办理渠道要求"], arNotes: gccArabicNotes(document: "بطاقة البحرين CPR أو الإقامة", size: "4 x 6 سم"))
    ]

    private static let printSpecs: [PhotoSpec] = [
        makeSpec(id: "print-us-2x2", country: "Print", localizedCountry: "打印", title: "2 x 2 in Photo", localizedTitle: "2 x 2 英寸照片", category: .print, widthMM: 51, heightMM: 51, pixelSize: CGSize(width: 600, height: 600), minHeadRatio: 0.50, maxHeadRatio: 0.69, backgrounds: [.white, .offWhite], notes: commonNotes("2 x 2 in", background: "plain white or off-white background"), zhNotes: commonZhNotes("2 x 2 英寸", background: "白色或米白色背景")),
        makeSpec(id: "print-1x1", country: "Print", localizedCountry: "打印", title: "1 x 1 in Photo", localizedTitle: "1 x 1 英寸照片", category: .print, widthMM: 25, heightMM: 25, pixelSize: CGSize(width: 300, height: 300), minHeadRatio: 0.50, maxHeadRatio: 0.70, backgrounds: [.white, .offWhite], notes: commonNotes("1 x 1 in", background: "plain light background"), zhNotes: commonZhNotes("1 x 1 英寸", background: "浅色纯色背景")),
        makeSpec(id: "print-35x45", country: "Print", localizedCountry: "打印", title: "35 x 45 mm Photo", localizedTitle: "35 x 45 毫米照片", category: .print, widthMM: 35, heightMM: 45, pixelSize: CGSize(width: 413, height: 531), minHeadRatio: 0.64, maxHeadRatio: 0.80, backgrounds: [.white, .lightGray], notes: commonNotes("35 x 45 mm", background: "plain light background"), zhNotes: commonZhNotes("35 x 45 毫米", background: "浅色纯色背景")),
        makeSpec(id: "print-33x48", country: "Print", localizedCountry: "打印", title: "33 x 48 mm Photo", localizedTitle: "33 x 48 毫米照片", category: .print, widthMM: 33, heightMM: 48, pixelSize: CGSize(width: 390, height: 567), minHeadRatio: 0.58, maxHeadRatio: 0.69, backgrounds: [.white], notes: commonNotes("33 x 48 mm", background: "plain white background"), zhNotes: commonZhNotes("33 x 48 毫米", background: "白色纯色背景")),
        makeSpec(id: "print-40x50", country: "Print", localizedCountry: "打印", title: "40 x 50 mm Photo", localizedTitle: "40 x 50 毫米照片", category: .print, widthMM: 40, heightMM: 50, pixelSize: CGSize(width: 472, height: 591), minHeadRatio: 0.56, maxHeadRatio: 0.74, backgrounds: [.white, .lightGray], notes: commonNotes("40 x 50 mm", background: "plain light background"), zhNotes: commonZhNotes("40 x 50 毫米", background: "浅色纯色背景")),
        makeSpec(id: "print-50x70", country: "Print", localizedCountry: "打印", title: "50 x 70 mm Photo", localizedTitle: "50 x 70 毫米照片", category: .print, widthMM: 50, heightMM: 70, pixelSize: CGSize(width: 600, height: 840), minHeadRatio: 0.44, maxHeadRatio: 0.60, backgrounds: [.white, .offWhite], notes: commonNotes("50 x 70 mm", background: "white or off-white background"), zhNotes: commonZhNotes("50 x 70 毫米", background: "白色或米白色背景")),
        makeSpec(id: "print-square-digital", country: "Print", localizedCountry: "打印", title: "Square Digital Upload", localizedTitle: "正方形电子上传", category: .print, widthMM: 51, heightMM: 51, pixelSize: CGSize(width: 600, height: 600), minHeadRatio: 0.50, maxHeadRatio: 0.69, backgrounds: [.white, .offWhite], maxFileKB: 240, notes: ["Square digital file", "Useful for portals that request 600 x 600 px", "Compress under the portal limit before submitting"], zhNotes: ["正方形电子文件", "适用于要求 600 x 600 像素的入口", "提交前按入口限制压缩文件大小"]),
        makeSpec(id: "print-linkedin-headshot", country: "Print", localizedCountry: "打印", title: "Clean Profile Headshot", localizedTitle: "清爽头像照", category: .print, widthMM: 51, heightMM: 51, pixelSize: CGSize(width: 1200, height: 1200), minHeadRatio: 0.38, maxHeadRatio: 0.62, backgrounds: [.white, .offWhite, .lightGray, .blue], notes: ["Not for official documents", "Useful for profiles and application forms", "Keep retouching natural"], zhNotes: ["不适用于官方证件", "适合资料页和申请表头像", "修复保持自然"])
    ]

    private static func passport(_ id: String, _ country: String, _ countryZh: String, _ widthMM: Double, _ heightMM: Double, _ pixels: CGSize, _ minHeadRatio: Double, _ maxHeadRatio: Double, _ backgrounds: [PhotoBackground], source: String? = nil) -> PhotoSpec {
        makeSpec(
            id: id,
            country: country,
            localizedCountry: countryZh,
            title: "\(country) Passport",
            localizedTitle: "\(countryZh)护照",
            category: .passport,
            widthMM: widthMM,
            heightMM: heightMM,
            pixelSize: pixels,
            minHeadRatio: minHeadRatio,
            maxHeadRatio: maxHeadRatio,
            backgrounds: backgrounds,
            source: source,
            notes: commonNotes("\(Int(widthMM)) x \(Int(heightMM)) mm", background: "plain official background"),
            zhNotes: commonZhNotes("\(Int(widthMM)) x \(Int(heightMM)) 毫米", background: "官方要求的纯色背景")
        )
    }

    private static func visa(_ id: String, _ country: String, _ countryZh: String, _ widthMM: Double, _ heightMM: Double, _ pixels: CGSize, _ minHeadRatio: Double, _ maxHeadRatio: Double, _ backgrounds: [PhotoBackground], maxFileKB: Int? = nil, source: String? = nil) -> PhotoSpec {
        makeSpec(
            id: id,
            country: country,
            localizedCountry: countryZh,
            title: "\(country) Visa",
            localizedTitle: "\(countryZh)签证",
            category: .visa,
            widthMM: widthMM,
            heightMM: heightMM,
            pixelSize: pixels,
            minHeadRatio: minHeadRatio,
            maxHeadRatio: maxHeadRatio,
            backgrounds: backgrounds,
            maxFileKB: maxFileKB,
            source: source,
            notes: commonNotes("\(Int(widthMM)) x \(Int(heightMM)) mm", background: "plain light background"),
            zhNotes: commonZhNotes("\(Int(widthMM)) x \(Int(heightMM)) 毫米", background: "浅色纯色背景")
        )
    }

    private static func makeSpec(
        id: String,
        country: String,
        localizedCountry: String,
        title: String,
        localizedTitle: String,
        arCountry: String? = nil,
        arTitle: String? = nil,
        category: SpecCategory,
        widthMM: Double,
        heightMM: Double,
        pixelSize: CGSize,
        minHeadRatio: Double,
        maxHeadRatio: Double,
        backgrounds: [PhotoBackground],
        maxFileKB: Int? = nil,
        source: String? = nil,
        notes: [String],
        zhNotes: [String],
        arNotes: [String]? = nil
    ) -> PhotoSpec {
        PhotoSpec(
            id: id,
            country: country,
            localizedCountry: localizedCountry,
            arabicCountry: arCountry,
            title: title,
            localizedTitle: localizedTitle,
            arabicTitle: arTitle,
            category: category,
            widthMM: widthMM,
            heightMM: heightMM,
            pixelSize: pixelSize,
            minHeadRatio: minHeadRatio,
            maxHeadRatio: maxHeadRatio,
            background: backgrounds,
            maxFileKB: maxFileKB,
            sourceURL: source.flatMap(URL.init(string:)),
            notes: notes,
            localizedNotes: zhNotes,
            arabicNotes: arNotes
        )
    }

    private static func commonNotes(_ size: String, background: String) -> [String] {
        [
            "\(size) photo preset",
            "Use a \(background)",
            "Check the official source before final submission"
        ]
    }

    private static func commonZhNotes(_ size: String, background: String) -> [String] {
        [
            "\(size)照片模板",
            "使用\(background)",
            "最终提交前请核对官方要求"
        ]
    }

    private static func gccNotes(document: String, size: String) -> [String] {
        [
            "\(size) GCC document photo preset",
            "Plain white background",
            "Designed for \(document) photo workflows",
            "Review the receiving government portal or service center before final submission"
        ]
    }

    private static func gccArabicNotes(document: String, size: String) -> [String] {
        [
            "قالب صورة \(document) بمقاس \(size)",
            "خلفية بيضاء سادة",
            "مخصص لسير عمل صور الهوية والإقامة في الخليج",
            "راجع البوابة الحكومية أو مركز الخدمة قبل التقديم النهائي"
        ]
    }
}
