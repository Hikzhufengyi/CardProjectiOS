import Foundation

enum L10n {
    enum AppLanguage: String {
        case english = "en"
        case chineseSimplified = "zh-Hans"
        case spanish = "es"
        case french = "fr"
        case german = "de"
        case japanese = "ja"
        case korean = "ko"
        case portuguese = "pt"
        case arabic = "ar"

        static var current: AppLanguage {
            let preferred = Locale.preferredLanguages.first ?? "en"
            if preferred.hasPrefix("zh") { return .chineseSimplified }
            if preferred.hasPrefix("es") { return .spanish }
            if preferred.hasPrefix("fr") { return .french }
            if preferred.hasPrefix("de") { return .german }
            if preferred.hasPrefix("ja") { return .japanese }
            if preferred.hasPrefix("ko") { return .korean }
            if preferred.hasPrefix("pt") { return .portuguese }
            if preferred.hasPrefix("ar") { return .arabic }
            return .english
        }
    }

    static var isChinese: Bool {
        AppLanguage.current == .chineseSimplified
    }

    static func text(_ key: Key) -> String {
        key.value(for: AppLanguage.current)
    }

    static func text(
        en: String,
        zh: String,
        es: String? = nil,
        fr: String? = nil,
        de: String? = nil,
        ja: String? = nil,
        ko: String? = nil,
        pt: String? = nil,
        ar: String? = nil
    ) -> String {
        Key(en: en, zh: zh, es: es, fr: fr, de: de, ja: ja, ko: ko, pt: pt, ar: ar).value(for: AppLanguage.current)
    }

    struct Key {
        let en: String
        let zh: String
        let es: String?
        let fr: String?
        let de: String?
        let ja: String?
        let ko: String?
        let pt: String?
        let ar: String?

        init(
            en: String,
            zh: String,
            es: String? = nil,
            fr: String? = nil,
            de: String? = nil,
            ja: String? = nil,
            ko: String? = nil,
            pt: String? = nil,
            ar: String? = nil
        ) {
            self.en = en
            self.zh = zh
            self.es = es
            self.fr = fr
            self.de = de
            self.ja = ja
            self.ko = ko
            self.pt = pt
            self.ar = ar
        }

        func value(for language: AppLanguage) -> String {
            switch language {
            case .english: return en
            case .chineseSimplified: return zh
            case .spanish: return es ?? en
            case .french: return fr ?? en
            case .german: return de ?? en
            case .japanese: return ja ?? en
            case .korean: return ko ?? en
            case .portuguese: return pt ?? en
            case .arabic: return ar ?? en
            }
        }
    }

    static let appName = Key(en: "IDPhoto Pro", zh: "IDPhoto Pro")
    static let createTab = Key(en: "Create", zh: "制作", es: "Crear", fr: "Créer", de: "Erstellen", ja: "作成", ko: "제작", pt: "Criar", ar: "إنشاء")
    static let profileTab = Key(en: "Me", zh: "我的", es: "Yo", fr: "Moi", de: "Ich", ja: "マイ", ko: "내 정보", pt: "Eu", ar: "حسابي")
    static let fullName = Key(en: "IDPhoto Pro", zh: "IDPhoto Pro")
    static let subtitle = Key(
        en: "Create compliant passport and visa photos with on-device checks, official backgrounds, 300 DPI export, and print layouts.",
        zh: "制作合规护照和签证照片，支持本地检测、官方背景、300 DPI 导出和打印排版。",
        es: "Fotos oficiales de pasaporte y visa con comprobaciones en el dispositivo, exportación 300 DPI y diseños de impresión.",
        fr: "Photos de passeport et visa aux formats officiels avec contrôles sur l'appareil, export 300 DPI et mises en page d'impression.",
        de: "Pass- und Visafotos in offizieller Größe mit Prüfungen auf dem Gerät, 300-DPI-Export und Drucklayouts.",
        ja: "公式サイズのパスポート・ビザ写真を端末内チェック、300 DPI書き出し、印刷レイアウトで作成。",
        ko: "공식 규격 여권 및 비자 사진을 기기 내 검사, 300 DPI 내보내기, 인쇄 레이아웃으로 제작합니다.",
        pt: "Fotos oficiais para passaporte e visto com verificações no dispositivo, exportação em 300 DPI e layouts de impressão.",
        ar: "صور جوازات وتأشيرات بالمقاسات الرسمية مع فحص على الجهاز وتصدير 300 DPI وتخطيطات للطباعة."
    )
    static let getStarted = Key(en: "Get Started", zh: "开始使用", es: "Comenzar", fr: "Commencer", de: "Loslegen", ja: "始める", ko: "시작하기", pt: "Começar", ar: "ابدأ")
    static let next = Key(en: "Next", zh: "下一步", es: "Siguiente", fr: "Suivant", de: "Weiter", ja: "次へ", ko: "다음", pt: "Avançar", ar: "التالي")
    static let skip = Key(en: "Skip", zh: "跳过", es: "Omitir", fr: "Ignorer", de: "Überspringen", ja: "スキップ", ko: "건너뛰기", pt: "Ignorar", ar: "تخطي")
    static let document = Key(en: "Document", zh: "证件类型", es: "Documento", fr: "Document", de: "Dokument", ja: "書類", ko: "문서", pt: "Documento", ar: "المستند")
    static let photo = Key(en: "Photo", zh: "照片", es: "Foto", fr: "Photo", de: "Foto", ja: "写真", ko: "사진", pt: "Foto", ar: "الصورة")
    static let enhance = Key(en: "Enhance", zh: "增强", es: "Mejorar", fr: "Améliorer", de: "Optimieren", ja: "補正", ko: "보정", pt: "Melhorar", ar: "تحسين")
    static let background = Key(en: "Background", zh: "背景", es: "Fondo", fr: "Fond", de: "Hintergrund", ja: "背景", ko: "배경", pt: "Fundo", ar: "الخلفية")
    static let importPhoto = Key(en: "Import", zh: "导入", es: "Importar", fr: "Importer", de: "Importieren", ja: "読み込み", ko: "가져오기", pt: "Importar", ar: "استيراد")
    static let camera = Key(en: "Camera", zh: "拍照", es: "Cámara", fr: "Appareil photo", de: "Kamera", ja: "カメラ", ko: "카메라", pt: "Câmera", ar: "الكاميرا")
    static let adjust = Key(en: "Precision Crop, Zoom & Rotation", zh: "精确裁剪、缩放和旋转", es: "Recorte, zoom y rotación precisos", fr: "Recadrage, zoom et rotation précis", de: "Präziser Zuschnitt, Zoom und Drehung", ja: "精密な切り抜き、ズーム、回転", ko: "정밀 자르기, 확대/축소 및 회전", pt: "Corte, zoom e rotação precisos", ar: "قص وتكبير وتدوير بدقة")
    static let lightRepair = Key(en: "Light repair", zh: "轻度修复", es: "Retoque ligero", fr: "Retouche légère", de: "Leichte Korrektur", ja: "軽い補正", ko: "가벼운 보정", pt: "Retoque leve", ar: "تصحيح خفيف")
    static let repairWarning = Key(en: "Use repair lightly. Some official documents may reject heavily edited or digitally altered photos.", zh: "请谨慎使用修复，部分官方证件可能拒绝明显编辑过的照片。", es: "Usa el retoque con moderación. Algunos documentos oficiales pueden rechazar fotos muy editadas.", fr: "Utilisez la retouche avec modération. Certains documents officiels peuvent refuser les photos trop modifiées.", de: "Korrekturen sparsam verwenden. Manche Behörden lehnen stark bearbeitete Fotos ab.", ja: "補正は控えめに使用してください。大きく加工された写真は拒否される場合があります。", ko: "보정은 가볍게 사용하세요. 과도하게 편집된 사진은 거부될 수 있습니다.", pt: "Use o retoque com moderação. Alguns documentos oficiais podem rejeitar fotos muito editadas.", ar: "استخدم التصحيح بحذر. قد ترفض بعض الجهات الرسمية الصور المعدلة بشكل مفرط.")
    static let export = Key(en: "Export 300 DPI Digital & Print Files", zh: "导出 300 DPI 电子版与打印版", es: "Exportar archivos digitales e impresión 300 DPI", fr: "Exporter fichiers numériques et impression 300 DPI", de: "300-DPI-Dateien und Drucklayouts exportieren", ja: "300 DPIのデジタル・印刷ファイルを書き出し", ko: "300 DPI 디지털 및 인쇄 파일 내보내기", pt: "Exportar arquivos digitais e impressão 300 DPI", ar: "تصدير ملفات رقمية وطباعة 300 DPI")
    static let ready = Key(en: "Ready to Export", zh: "可以导出", es: "Listo para exportar", fr: "Prêt à exporter", de: "Bereit zum Export", ja: "書き出し可能", ko: "내보내기 준비됨", pt: "Pronto para exportar", ar: "جاهز للتصدير")
    static let needsAttention = Key(en: "Needs Attention", zh: "需要处理", es: "Requiere atención", fr: "À vérifier", de: "Prüfung nötig", ja: "確認が必要", ko: "확인 필요", pt: "Requer atenção", ar: "يحتاج إلى مراجعة")
    static let readyDetail = Key(en: "All blocking checks passed. Review warnings before submission.", zh: "关键检查已通过，提交前请再次确认提示项。", es: "Todas las comprobaciones críticas pasaron. Revisa las advertencias antes de enviar.", fr: "Tous les contrôles bloquants sont validés. Vérifiez les alertes avant l'envoi.", de: "Alle wichtigen Prüfungen bestanden. Warnungen vor dem Einreichen prüfen.", ja: "重要なチェックは通過しました。提出前に警告を確認してください。", ko: "필수 검사를 통과했습니다. 제출 전 경고를 확인하세요.", pt: "Todas as verificações críticas passaram. Revise os avisos antes de enviar.", ar: "اجتازت الصورة الفحوصات الأساسية. راجع التنبيهات قبل الإرسال.")
    static let attentionDetail = Key(en: "Fix failed checks before exporting a final photo.", zh: "请先修复未通过的检查项再导出最终照片。", es: "Corrige las comprobaciones fallidas antes de exportar.", fr: "Corrigez les contrôles échoués avant l'export final.", de: "Beheben Sie fehlgeschlagene Prüfungen vor dem Export.", ja: "最終書き出し前に不合格項目を修正してください。", ko: "최종 내보내기 전에 실패한 항목을 수정하세요.", pt: "Corrija as verificações reprovadas antes de exportar.", ar: "أصلح الفحوصات غير الناجحة قبل التصدير النهائي.")
    static let privacyTitle = Key(en: "Privacy, Security & Disclaimer", zh: "隐私、安全与免责声明", es: "Privacidad, seguridad y aviso", fr: "Confidentialité, sécurité et avis", de: "Datenschutz, Sicherheit und Hinweis", ja: "プライバシー・安全性・免責事項", ko: "개인정보, 보안 및 고지", pt: "Privacidade, segurança e aviso", ar: "الخصوصية والأمان وإخلاء المسؤولية")
    static let records = Key(en: "Creation Records", zh: "制作记录", es: "Historial", fr: "Historique", de: "Verlauf", ja: "作成履歴", ko: "제작 기록", pt: "Histórico", ar: "السجل")
    static let localLogin = Key(en: "Local Login", zh: "本地登录", es: "Inicio local", fr: "Connexion locale", de: "Lokale Anmeldung", ja: "ローカルログイン", ko: "로컬 로그인", pt: "Login local", ar: "تسجيل محلي")
    static let username = Key(en: "Username", zh: "用户名称", es: "Nombre de usuario", fr: "Nom d'utilisateur", de: "Benutzername", ja: "ユーザー名", ko: "사용자 이름", pt: "Nome de usuário", ar: "اسم المستخدم")
    static let avatar = Key(en: "Avatar", zh: "头像", es: "Avatar", fr: "Avatar", de: "Avatar", ja: "アバター", ko: "아바타", pt: "Avatar", ar: "الصورة الشخصية")
}
