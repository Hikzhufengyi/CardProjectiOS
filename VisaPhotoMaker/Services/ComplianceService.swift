import UIKit

struct ComplianceService {
    func evaluate(image: UIImage?, spec: PhotoSpec, selectedBackground: PhotoBackground, analysis: PhotoAnalysis?) -> ComplianceResult {
        var checks: [ComplianceCheck] = []

        guard let image else {
            return ComplianceResult(checks: [
                ComplianceCheck(
                    title: L10n.text(en: "Photo required", zh: "需要照片"),
                    message: L10n.text(en: "Take, import, or choose a file photo to start checking requirements.", zh: "请拍摄、导入或从文件选择一张照片后开始检测。"),
                    severity: .fail,
                    action: L10n.text(en: "Use a clear, front-facing photo with no obstruction.", zh: "使用正面、清晰、无遮挡的照片。"),
                    kind: .faceDetection
                )
            ])
        }

        let ratio = image.size.width / max(image.size.height, 1)
        let targetRatio = spec.pixelSize.width / spec.pixelSize.height
        let ratioDelta = abs(ratio - targetRatio)

        checks.append(ComplianceCheck(
            title: L10n.text(en: "Format", zh: "画幅比例"),
            message: ratioDelta < 0.08
                ? (L10n.text(en: "The photo can be cropped to \(spec.displayPixels).", zh: "照片可以裁切为 \(spec.displayPixels)。"))
                : (L10n.text(en: "Crop is needed to match \(spec.displaySize).", zh: "需要调整裁剪以匹配 \(spec.displaySize)。")),
            severity: ratioDelta < 0.08 ? .pass : .warning,
            action: ratioDelta < 0.08 ? nil : (L10n.text(en: "Use zoom, rotate, and move controls until the face sits inside the guide.", zh: "使用缩放、旋转和移动控制让脸部位于参考框内。")),
            kind: .format
        ))

        let shortestSide = min(image.size.width, image.size.height)
        checks.append(ComplianceCheck(
            title: L10n.text(en: "Resolution", zh: "分辨率"),
            message: shortestSide >= min(spec.pixelSize.width, spec.pixelSize.height)
                ? (L10n.text(en: "Image resolution is high enough for digital export.", zh: "分辨率足够用于电子版导出。"))
                : (L10n.text(en: "Use a sharper image for better submission quality.", zh: "原图偏小，建议换一张更清晰的照片。")),
            severity: shortestSide >= min(spec.pixelSize.width, spec.pixelSize.height) ? .pass : .warning,
            action: shortestSide >= min(spec.pixelSize.width, spec.pixelSize.height) ? nil : (L10n.text(en: "Retake or import a higher-resolution photo.", zh: "重新拍摄或选择更高分辨率照片。")),
            kind: .resolution
        ))

        checks.append(ComplianceCheck(
            title: L10n.text(en: "Background", zh: "背景"),
            message: spec.background.contains(selectedBackground)
                ? (L10n.text(en: "\(selectedBackground.rawValue) matches this document's background guidance.", zh: "\(selectedBackground.localizedName)适用于该证件。"))
                : (L10n.text(en: "Choose one of the accepted background colors.", zh: "请选择该证件允许的背景颜色。")),
            severity: spec.background.contains(selectedBackground) ? .pass : .fail,
            action: spec.background.contains(selectedBackground) ? nil : (L10n.text(en: "Switch to one of the accepted colors shown in the spec card.", zh: "切换到规格卡片中显示的可用背景色。")),
            kind: .background
        ))

        if let analysis, analysis.faceCount > 1 {
            checks.append(ComplianceCheck(
                title: L10n.text(en: "Single person", zh: "单人照片"),
                message: L10n.text(en: "Multiple faces were detected. Official photos usually allow only one applicant.", zh: "检测到多张人脸，证件照通常只允许一个申请人。"),
                severity: .fail,
                action: L10n.text(en: "Retake with only the applicant in frame.", zh: "重新拍摄，确保画面里只有申请人本人。"),
                kind: .singlePerson
            ))
        }

        if let faceAnalysis = analysis?.face {
            let headRatio = faceAnalysis.effectiveHeadHeightRatio
            let minimumTopMargin = strictTopMarginRatio(for: spec)
            let headTilt = abs(faceAnalysis.rollDegrees)
            let headTiltSeverity: ComplianceSeverity = if headTilt <= 3.5 {
                .pass
            } else if headTilt <= 9 {
                .warning
            } else {
                .fail
            }
            let targetHeadRatio = (spec.minHeadRatio + spec.maxHeadRatio) / 2
            let strictHeadTolerance = max((spec.maxHeadRatio - spec.minHeadRatio) * 0.32, 0.025)
            let warningHeadTolerance = max((spec.maxHeadRatio - spec.minHeadRatio) * 0.50, 0.045)
            let headDelta = abs(headRatio - targetHeadRatio)
            let headSeverity: ComplianceSeverity = if headDelta <= strictHeadTolerance {
                .pass
            } else if headDelta <= warningHeadTolerance || (headRatio >= spec.minHeadRatio && headRatio <= spec.maxHeadRatio) {
                .warning
            } else {
                .fail
            }
            checks.append(ComplianceCheck(
                title: L10n.text(en: "Head size", zh: "头部比例"),
                message: L10n.isChinese
                    ? "检测头部高度约 \(Int(headRatio * 100))%；目标为 \(Int(spec.minHeadRatio * 100))-\(Int(spec.maxHeadRatio * 100))%。"
                    : "Detected head height is \(Int(headRatio * 100))%; target is \(Int(spec.minHeadRatio * 100))-\(Int(spec.maxHeadRatio * 100))%.",
                severity: headSeverity,
                action: headSeverity == .pass ? nil : (headRatio < spec.minHeadRatio ? (L10n.text(en: "Zoom in so the head better matches the guide oval.", zh: "放大照片，让头部更接近参考椭圆。")) : (L10n.text(en: "Zoom out to leave more space above the head and under the chin.", zh: "缩小照片，给头顶和下巴留出空间。"))),
                kind: .headSize
            ))

            let centerOffset = faceAnalysis.effectiveCenterOffsetRatio
            let centerSeverity: ComplianceSeverity = if faceAnalysis.isCentered {
                .pass
            } else if centerOffset <= FaceAnalysis.centerWarningThreshold && faceAnalysis.visualAndFaceCentersAgree {
                .warning
            } else {
                .fail
            }
            let centerDirection = faceAnalysis.effectiveSignedCenterOffsetRatio < 0
                ? L10n.text(en: "left", zh: "左侧")
                : L10n.text(en: "right", zh: "右侧")
            checks.append(ComplianceCheck(
                title: L10n.text(en: "Face centered", zh: "面部居中"),
                message: centerSeverity == .pass
                    ? (L10n.text(en: "Face is centered in the frame.", zh: "面部位于画面中央。"))
                    : (L10n.isChinese ? "头像或面部偏向\(centerDirection)，偏移约 \(Int((centerOffset * 100).rounded()))%，需要进入虚线框中心区域。" : "Head or face is shifted to the \(centerDirection) by about \(Int((centerOffset * 100).rounded()))%; keep it inside the center guide."),
                severity: centerSeverity,
                action: centerSeverity == .pass ? nil : (faceAnalysis.effectiveSignedCenterOffsetRatio < 0
                    ? L10n.text(en: "Move the photo to the right or use smart fix to center the face.", zh: "请把照片向右移动，或使用智能修复让面部居中。")
                    : L10n.text(en: "Move the photo to the left or use smart fix to center the face.", zh: "请把照片向左移动，或使用智能修复让面部居中。")),
                kind: .faceCentered
            ))

            checks.append(ComplianceCheck(
                title: L10n.text(en: "Head tilt", zh: "头部倾斜"),
                message: headTiltSeverity == .pass
                    ? (L10n.text(en: "Head tilt looks straight.", zh: "头部角度看起来端正。"))
                    : (L10n.isChinese ? "头部倾斜约 \(Int(headTilt.rounded()))°，建议保持在 3° 以内。" : "Head tilt is about \(Int(headTilt.rounded())) degrees; keep it within 3 degrees."),
                severity: headTiltSeverity,
                action: headTiltSeverity == .pass ? nil : (L10n.text(en: "Use smart fix or rotate slightly until the eyes are level.", zh: "使用智能修复，或轻微旋转直到双眼基本水平。")),
                kind: .headTilt
            ))

            checks.append(ComplianceCheck(
                title: L10n.text(en: "Eyes visible", zh: "双眼可见"),
                message: faceAnalysis.hasBothEyes ? (L10n.text(en: "Both eyes were detected.", zh: "已检测到双眼。")) : (L10n.text(en: "Eyes were not clearly detected. Remove glare, hair, or glasses obstruction.", zh: "双眼不够清晰，可能有反光、头发或眼镜遮挡。")),
                severity: faceAnalysis.hasBothEyes ? .pass : .warning,
                action: faceAnalysis.hasBothEyes ? nil : (L10n.text(en: "Move hair away, remove glare, or retake without obstructive glasses.", zh: "整理头发、摘掉反光眼镜后重拍。")),
                kind: .eyesVisible
            ))

            if let eyeHeight = faceAnalysis.eyeHeightRatio {
                let eyeHeightSeverity: ComplianceSeverity = if eyeHeight >= 0.535 && eyeHeight <= 0.585 {
                    .pass
                } else if eyeHeight >= 0.50 && eyeHeight <= 0.62 {
                    .warning
                } else {
                    .fail
                }
                let eyeAction: String? = if eyeHeightSeverity == .pass {
                    nil
                } else if eyeHeight < 0.535 {
                    L10n.text(en: "Move the photo upward so the eyes sit higher in the frame.", zh: "请把照片向上移动，让眼睛位置更高一些。")
                } else {
                    L10n.text(en: "Move the photo downward so the eyes sit lower in the frame.", zh: "请把照片向下移动，让眼睛位置更低一些。")
                }
                checks.append(ComplianceCheck(
                    title: L10n.text(en: "Eye height", zh: "眼线高度"),
                    message: L10n.text(en: "Eye line is around \(Int(eyeHeight * 100))% from the bottom of the frame.", zh: "眼线约位于画面底部向上 \(Int(eyeHeight * 100))% 处。"),
                    severity: eyeHeightSeverity,
                    action: eyeAction,
                    kind: .eyeHeight
                ))
            }

            let topMargin = faceAnalysis.effectiveTopMarginRatio
            let topMarginSeverity: ComplianceSeverity = if topMargin >= minimumTopMargin {
                .pass
            } else if topMargin >= minimumTopMargin * 0.75 {
                .warning
            } else {
                .fail
            }
            checks.append(ComplianceCheck(
                title: L10n.text(en: "Top margin", zh: "头顶留白"),
                message: topMarginSeverity == .pass
                    ? (L10n.text(en: "Top margin is within the expected range.", zh: "头顶留白在合理范围内。"))
                    : (L10n.isChinese ? "头顶留白约 \(Int(topMargin * 100))%；建议至少 \(Int(minimumTopMargin * 100))%。" : "Top margin is about \(Int(topMargin * 100))%; recommended minimum is \(Int(minimumTopMargin * 100))%."),
                severity: topMarginSeverity,
                action: topMarginSeverity == .pass ? nil : (L10n.text(en: "Zoom out or move the photo downward so the full head has clear space above it.", zh: "请缩小或向下移动照片，确保完整头部上方有清晰留白。")),
                kind: .topMargin
            ))

            let bottomMargin = faceAnalysis.effectiveBottomMarginRatio
            let bottomMarginSeverity: ComplianceSeverity = if bottomMargin >= 0.10 {
                .pass
            } else if bottomMargin >= 0.065 {
                .warning
            } else {
                .fail
            }
            checks.append(ComplianceCheck(
                title: L10n.text(en: "Vertical position", zh: "垂直位置"),
                message: bottomMarginSeverity == .pass
                    ? (L10n.text(en: "The head is not pushed too low in the frame.", zh: "头像没有明显偏向底部。"))
                    : (L10n.isChinese ? "下方留白约 \(Int(bottomMargin * 100))%，头像明显偏底部。" : "Bottom margin is about \(Int(bottomMargin * 100))%; the head is too low in the frame."),
                severity: bottomMarginSeverity,
                action: bottomMarginSeverity == .pass ? nil : (L10n.text(en: "Move the photo upward or use smart fix to recenter the head.", zh: "请把照片向上移动，或使用智能修复让头像重新居中。")),
                kind: .eyeHeight
            ))

            let verticalCenterOffset = faceAnalysis.effectiveVerticalCenterOffsetRatio
            let verticalCenterSeverity: ComplianceSeverity = if faceAnalysis.isVerticallyCenteredInGuide {
                .pass
            } else if abs(verticalCenterOffset) <= FaceAnalysis.verticalCenterWarningThreshold {
                .warning
            } else {
                .fail
            }
            checks.append(ComplianceCheck(
                title: L10n.text(en: "Head guide alignment", zh: "头部引导框对齐"),
                message: verticalCenterSeverity == .pass
                    ? L10n.text(en: "Full head position matches the guide oval.", zh: "完整头部位置已贴合参考虚线框。")
                    : (verticalCenterOffset > 0
                       ? L10n.text(en: "The full head sits too low compared with the guide oval.", zh: "完整头部相对参考虚线框偏低。")
                       : L10n.text(en: "The full head sits too high compared with the guide oval.", zh: "完整头部相对参考虚线框偏高。")),
                severity: verticalCenterSeverity,
                action: verticalCenterSeverity == .pass ? nil : (verticalCenterOffset > 0
                    ? L10n.text(en: "Move the photo upward until the head is centered in the guide.", zh: "请把照片向上移动，让完整头部进入虚线框中心。")
                    : L10n.text(en: "Move the photo downward until the head is centered in the guide.", zh: "请把照片向下移动，让完整头部进入虚线框中心。")),
                kind: .topMargin
            ))

            checks.append(ComplianceCheck(
                title: L10n.text(en: "Mouth / expression", zh: "嘴部/表情"),
                message: faceAnalysis.hasMouth ? (L10n.text(en: "Mouth area is visible. Keep a neutral expression.", zh: "嘴部区域可见，请保持自然中性表情。")) : (L10n.text(en: "Mouth was not clearly detected. Use a straight-on photo.", zh: "嘴部不够清晰，请使用正面照片。")),
                severity: faceAnalysis.hasMouth ? .pass : .warning,
                action: faceAnalysis.hasMouth ? nil : (L10n.text(en: "Retake straight-on and avoid covering the mouth.", zh: "正对镜头重拍，避免遮挡嘴部。")),
                kind: .expression
            ))
        } else {
            checks.append(ComplianceCheck(
                title: L10n.text(en: "Face detection", zh: "人脸检测"),
                message: L10n.text(en: "No face detected. Use a clear, front-facing photo with even lighting.", zh: "未检测到人脸，请使用光线均匀的正面清晰照片。"),
                severity: .fail,
                action: L10n.text(en: "Retake or import an unobstructed headshot.", zh: "重新拍摄或选择无遮挡的头像照片。"),
                kind: .faceDetection
            ))
        }

        if let quality = analysis?.quality {
            let brightnessPercent = Int((quality.brightness * 100).rounded())
            let lightingMessage: String
            let lightingAction: String?
            if quality.isWellLit {
                lightingMessage = L10n.text(
                    en: "Face brightness looks balanced at about \(brightnessPercent)%.",
                    zh: "脸部亮度约 \(brightnessPercent)%，看起来比较均衡。"
                )
                lightingAction = nil
            } else if quality.isTooDark {
                lightingMessage = L10n.text(
                    en: "Face area is too dark at about \(brightnessPercent)%.",
                    zh: "脸部偏暗，当前约 \(brightnessPercent)% 亮度。"
                )
                lightingAction = L10n.text(
                    en: "Increase Bright or Shadows slightly. Retake if the face has heavy shadows.",
                    zh: "请稍微调高亮度或阴影；如果脸部阴影很重，建议重拍。"
                )
            } else {
                lightingMessage = L10n.text(
                    en: "Face area is too bright at about \(brightnessPercent)%.",
                    zh: "脸部偏亮，当前约 \(brightnessPercent)% 亮度。"
                )
                lightingAction = L10n.text(
                    en: "Lower Bright slightly and avoid strong repair. Retake if facial details are washed out.",
                    zh: "请稍微降低亮度，并避免过强修复；如果脸部细节发白，建议重拍。"
                )
            }

            checks.append(ComplianceCheck(
                title: L10n.text(en: "Lighting", zh: "光线"),
                message: lightingMessage,
                severity: quality.isWellLit ? .pass : .warning,
                action: lightingAction,
                kind: .lighting
            ))

            checks.append(ComplianceCheck(
                title: L10n.text(en: "Sharpness", zh: "清晰度"),
                message: quality.isSharp ? (L10n.text(en: "Image sharpness looks acceptable.", zh: "图像清晰度看起来可接受。")) : (L10n.text(en: "Photo may be blurry.", zh: "照片可能偏模糊。")),
                severity: quality.isSharp ? .pass : .warning,
                action: quality.isSharp ? nil : (L10n.text(en: "A small sharpness boost may help; retake if the photo is badly blurred.", zh: "轻微锐化可能有帮助，但严重模糊建议重拍。")),
                kind: .sharpness
            ))

            checks.append(ComplianceCheck(
                title: L10n.text(en: "Background shadows", zh: "背景阴影"),
                message: quality.hasEvenBackground ? (L10n.text(en: "Background edge lighting looks even.", zh: "背景边缘光线较均匀。")) : (L10n.text(en: "Background may have shadows or uneven lighting.", zh: "背景可能有阴影或光线不均。")),
                severity: quality.hasEvenBackground ? .pass : .warning,
                action: quality.hasEvenBackground ? nil : (L10n.text(en: "Use background replacement or retake near a plain wall.", zh: "使用换背景功能，或靠近纯色墙面重新拍摄。")),
                kind: .backgroundShadows
            ))
        } else {
            checks.append(ComplianceCheck(
                title: L10n.text(en: "Lighting", zh: "光线"),
                message: L10n.text(en: "Use a plain wall and even front lighting. Remove shadows before final export.", zh: "请使用纯色墙面和均匀正面光，导出前去除阴影。"),
                severity: .warning,
                action: L10n.text(en: "Avoid backlight and harsh shadows on the face.", zh: "拍摄时不要背光，脸部不要有硬阴影。"),
                kind: .lighting
            ))
        }

        if let maxFileKB = spec.maxFileKB {
            checks.append(ComplianceCheck(
                title: L10n.text(en: "File size", zh: "文件大小"),
                message: L10n.text(en: "Export can compress the final file under \(maxFileKB) KB.", zh: "导出时可将最终文件压缩到 \(maxFileKB) KB 以下。"),
                severity: .pass,
                kind: .fileSize
            ))
        }

        return ComplianceResult(checks: checks)
    }

    private func strictTopMarginRatio(for spec: PhotoSpec) -> Double {
        let isUSPassport = spec.country.lowercased().contains("united states")
            && spec.title.lowercased().contains("passport")
        return isUSPassport ? 0.06 : 0.045
    }
}
