import UIKit

struct ComplianceService {
    private enum VerticalGuidanceDirection {
        case up
        case down
    }

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
            let profile = spec.complianceProfile
            let headRatio = faceAnalysis.effectiveHeadHeightRatio
            let minimumTopMargin = profile.minimumTopMarginRatio
            let minimumBottomMargin = profile.minimumBottomMarginRatio
            let headTilt = abs(faceAnalysis.rollDegrees)
            let verticalGuideDirection = resolvedVerticalGuidanceDirection(
                faceAnalysis: faceAnalysis,
                profile: profile,
                minimumTopMargin: minimumTopMargin,
                minimumBottomMargin: minimumBottomMargin
            )
            let headTiltSeverity: ComplianceSeverity = if headTilt <= 3.5 {
                .pass
            } else if headTilt <= 9 {
                .warning
            } else {
                .fail
            }
            let headDelta = abs(headRatio - profile.targetHeadRatio)
            let requiresStrictHeadFraming = profile.framingWeights.headSize >= 1.20 || spec.heightMM / max(spec.widthMM, 1) >= 1.32
            let isInsideOfficialHeadRange = headRatio >= spec.minHeadRatio && headRatio <= spec.maxHeadRatio
            let headSeverity: ComplianceSeverity = if isInsideOfficialHeadRange {
                .pass
            } else if !requiresStrictHeadFraming && headDelta <= profile.headWarningTolerance {
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
            let centerlineGap = faceAnalysis.eyeNoseCenterlineGapRatio ?? 0
            let centerlineIsStable = centerlineGap <= 0.045
            let centerSeverity: ComplianceSeverity = if faceAnalysis.isCentered && centerlineIsStable {
                .pass
            } else if centerOffset <= FaceAnalysis.centerWarningThreshold && centerlineGap <= 0.070 {
                .warning
            } else {
                .fail
            }
            let centerDirection = faceAnalysis.effectiveSignedCenterOffsetRatio < 0
                ? L10n.text(en: "left", zh: "左侧")
                : L10n.text(en: "right", zh: "右侧")
            let centerMessage: String = if centerSeverity == .pass {
                L10n.text(en: "Face centerline is aligned in the frame.", zh: "双眼中心和鼻梁中心线位于画面中央。")
            } else if !centerlineIsStable {
                L10n.isChinese
                    ? "双眼中心和鼻梁中心线相差约 \(Int((centerlineGap * 100).rounded()))%，请保持正脸并让中心线进入中间范围。"
                    : "Eye center and nose center differ by about \(Int((centerlineGap * 100).rounded()))%; face forward and keep the centerline in the middle range."
            } else {
                L10n.isChinese
                    ? "面部中心线偏向\(centerDirection)，偏移约 \(Int((centerOffset * 100).rounded()))%，需要进入中间范围。"
                    : "Face centerline is shifted to the \(centerDirection) by about \(Int((centerOffset * 100).rounded()))%; keep it in the middle range."
            }
            checks.append(ComplianceCheck(
                title: L10n.text(en: "Face centered", zh: "面部居中"),
                message: centerMessage,
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

            let glassesCheck = makeGlassesCheck(policy: profile.glassesPolicy, faceAnalysis: faceAnalysis)
            if let glassesCheck {
                checks.append(glassesCheck)
            }

            if let eyesOpenScore = faceAnalysis.eyesOpenScore {
                let severity: ComplianceSeverity = if eyesOpenScore >= 0.18 {
                    .pass
                } else if eyesOpenScore >= 0.12 {
                    .warning
                } else {
                    .fail
                }
                checks.append(ComplianceCheck(
                    title: L10n.text(en: "Eyes open", zh: "双眼睁开"),
                    message: severity == .pass
                        ? L10n.text(en: "Eyes appear open enough for a passport photo.", zh: "双眼睁开程度基本符合证件照要求。")
                        : L10n.text(en: "Eyes may look partially closed or squinting.", zh: "双眼可能偏眯，或有闭眼风险。"),
                    severity: severity,
                    action: severity == .pass ? nil : L10n.text(en: "Retake with both eyes fully open and looking straight at the camera.", zh: "请双眼自然睁开，正视镜头后重拍。"),
                    kind: .eyesOpen
                ))
            }

            checks.append(ComplianceCheck(
                title: L10n.text(en: "Head covering", zh: "头顶遮挡"),
                message: faceAnalysis.hasHeadCoveringRisk
                    ? L10n.text(en: "The top of the head may be covered by a hat, hood, or headscarf.", zh: "头顶可能存在帽子、头巾或其他遮挡。")
                    : L10n.text(en: "No obvious head covering detected.", zh: "未检测到明显头顶遮挡。"),
                severity: faceAnalysis.hasHeadCoveringRisk ? .warning : .pass,
                action: faceAnalysis.hasHeadCoveringRisk ? L10n.text(en: "Remove hats, headscarves, or anything covering the top of the head unless officially required.", zh: "如非官方必须，请去掉帽子、头巾或头顶遮挡物。") : nil,
                kind: .headCover
            ))

            if let eyeHeight = faceAnalysis.eyeHeightRatio {
                let eyePassTolerance = profile.shouldCheckEyeHeightStrictly ? 0.006 : 0.010
                let currentEyePercent = Int((eyeHeight * 100).rounded())
                let targetEyeLowerPercent = Int((profile.eyeHeightRange.lowerBound * 100).rounded())
                let targetEyeUpperPercent = Int((profile.eyeHeightRange.upperBound * 100).rounded())
                let isEyeInsideOfficialRange = eyeHeight >= profile.eyeHeightRange.lowerBound
                    && eyeHeight <= profile.eyeHeightRange.upperBound
                let isEyeInsidePassRange = eyeHeight >= profile.eyeHeightRange.lowerBound - eyePassTolerance
                    && eyeHeight <= profile.eyeHeightRange.upperBound + eyePassTolerance
                let isEyeInsideWarningRange = eyeHeight >= profile.eyeHeightWarningRange.lowerBound
                    && eyeHeight <= profile.eyeHeightWarningRange.upperBound
                let eyeHeightGuideAligned =
                    abs(faceAnalysis.effectiveVerticalCenterOffsetRatio) <= FaceAnalysis.verticalCenterWarningThreshold * 0.72
                    && topMarginForCompliance(faceAnalysis: faceAnalysis) >= minimumTopMargin * 0.92
                    && faceAnalysis.effectiveBottomMarginRatio >= minimumBottomMargin * 0.92
                let eyeDirection = currentEyePercent < targetEyeLowerPercent ? VerticalGuidanceDirection.up
                    : (currentEyePercent > targetEyeUpperPercent ? .down : nil)
                let eyeHeightSeverity: ComplianceSeverity = if isEyeInsideOfficialRange || isEyeInsidePassRange {
                    .pass
                } else if isEyeInsideWarningRange
                            && eyeHeightGuideAligned
                            && profile.framingWeights.eyeHeight < 0.90 {
                    .pass
                } else if isEyeInsideWarningRange {
                    .warning
                } else if profile.shouldCheckEyeHeightStrictly {
                    .fail
                } else {
                    .warning
                }
                let eyeAction: String? = if eyeHeightSeverity == .pass {
                    nil
                } else if currentEyePercent < targetEyeLowerPercent {
                    L10n.text(en: "Move the photo upward so the eyes sit higher in the frame.", zh: "请把照片向上移动，让眼睛位置更高一些。")
                } else {
                    L10n.text(en: "Move the photo downward so the eyes sit lower in the frame.", zh: "请把照片向下移动，让眼睛位置更低一些。")
                }
                let eyeRangeKind = profile.shouldCheckEyeHeightStrictly
                    ? L10n.text(en: "target", zh: "目标")
                    : L10n.text(en: "reference", zh: "参考")
                let eyeHeightMessage = L10n.isChinese
                    ? "当前眼线约 \(currentEyePercent)%，\(eyeRangeKind)范围 \(targetEyeLowerPercent)-\(targetEyeUpperPercent)%；按最终整张证件照画布高度计算。"
                    : "Current eye line is about \(currentEyePercent)%; \(eyeRangeKind) range is \(targetEyeLowerPercent)-\(targetEyeUpperPercent)%, measured against the final full photo canvas."
                checks.append(ComplianceCheck(
                    title: L10n.text(en: "Eye height", zh: "眼线高度"),
                    message: eyeHeightMessage,
                    severity: eyeHeightSeverity,
                    action: eyeAction,
                    kind: .eyeHeight
                ))
            }

            let topMargin = topMarginForCompliance(faceAnalysis: faceAnalysis)
            let topMarginPercent = Int((topMargin * 100).rounded())
            let minimumTopMarginPercent = Int((minimumTopMargin * 100).rounded())
            let idealTopMarginUpper = min(max(minimumTopMargin + 0.035, (1 - spec.maxHeadRatio) * 0.72), 0.18)
            let idealTopMarginUpperPercent = Int((idealTopMarginUpper * 100).rounded())
            let viableTopMarginPercent = Int((profile.viableTopMarginRatio * 100).rounded())
            let topRangeKind = profile.strictTopMargin
                ? L10n.text(en: "target", zh: "目标")
                : L10n.text(en: "reference", zh: "参考")
            let topMarginSeverity: ComplianceSeverity = if topMarginPercent >= minimumTopMarginPercent {
                .pass
            } else if topMarginPercent >= max(minimumTopMarginPercent - 2, 0) {
                .warning
            } else if profile.strictTopMargin {
                .fail
            } else {
                .warning
            }
            checks.append(ComplianceCheck(
                title: L10n.text(en: "Top margin", zh: "头顶留白"),
                message: L10n.isChinese
                    ? "当前头顶留白约 \(topMarginPercent)%，\(topRangeKind)范围 \(minimumTopMarginPercent)-\(idealTopMarginUpperPercent)%；最低可接受约 \(viableTopMarginPercent)%。按当前国家和证件规格计算。"
                    : "Current top margin is about \(topMarginPercent)%; \(topRangeKind) range is \(minimumTopMarginPercent)-\(idealTopMarginUpperPercent)%, with about \(viableTopMarginPercent)% as the lowest acceptable reference for this document type.",
                severity: topMarginSeverity,
                action: topMarginSeverity == .pass ? nil : (L10n.text(en: "Zoom out or move the photo downward so the full head has clear space above it.", zh: "请缩小或向下移动照片，确保完整头部上方有清晰留白。")),
                kind: .topMargin
            ))

            let bottomMargin = faceAnalysis.effectiveBottomMarginRatio
            let bottomMarginSeverity: ComplianceSeverity = if bottomMargin >= minimumBottomMargin {
                .pass
            } else if bottomMargin >= minimumBottomMargin * 0.70 {
                .warning
            } else if profile.strictBottomMargin {
                .fail
            } else {
                .warning
            }
            checks.append(ComplianceCheck(
                title: L10n.text(en: "Vertical position", zh: "垂直位置"),
                message: bottomMarginSeverity == .pass
                    ? (L10n.text(en: "The head is not pushed too low in the frame.", zh: "头像没有明显偏向底部。"))
                    : (L10n.isChinese ? "下方留白约 \(Int(bottomMargin * 100))%，建议至少 \(Int(minimumBottomMargin * 100))%。" : "Bottom margin is about \(Int(bottomMargin * 100))%; recommended minimum is \(Int(minimumBottomMargin * 100))%."),
                severity: bottomMarginSeverity,
                action: bottomMarginSeverity == .pass ? nil : (L10n.text(en: "Move the photo upward or use smart fix to recenter the head.", zh: "请把照片向上移动，或使用智能修复让头像重新居中。")),
                kind: .bottomMargin
            ))

            let verticalCenterOffset = guideAlignmentOffset(faceAnalysis: faceAnalysis, profile: profile)
            let relaxedVerticalOffset = verticalCenterOffset
            let verticalCenterSeverity: ComplianceSeverity = if !profile.shouldWarnHeadGuideAlignment {
                .pass
            } else if abs(relaxedVerticalOffset) <= FaceAnalysis.strictVerticalCenterPassThreshold {
                .pass
            } else if abs(relaxedVerticalOffset) <= FaceAnalysis.verticalCenterWarningThreshold {
                .warning
            } else {
                .fail
            }
            checks.append(ComplianceCheck(
                title: L10n.text(en: "Head guide alignment", zh: "头部引导框对齐"),
                message: verticalCenterSeverity == .pass
                    ? L10n.text(en: "Full head position matches the guide oval.", zh: "完整头部位置已贴合参考虚线框。")
                    : (relaxedVerticalOffset > 0
                       ? L10n.text(en: "The full head sits too low compared with the guide oval.", zh: "完整头部相对参考虚线框偏低。")
                       : L10n.text(en: "The full head sits too high compared with the guide oval.", zh: "完整头部相对参考虚线框偏高。")),
                severity: verticalCenterSeverity,
                action: verticalCenterSeverity == .pass ? nil : (relaxedVerticalOffset > 0
                    ? L10n.text(en: "Move the photo upward until the head is centered in the guide.", zh: "请把照片向上移动，让完整头部进入虚线框中心。")
                    : L10n.text(en: "Move the photo downward until the head is centered in the guide.", zh: "请把照片向下移动，让完整头部进入虚线框中心。")),
                kind: .headGuideAlignment
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
        spec.complianceProfile.minimumTopMarginRatio
    }

    private func guideAlignmentOffset(faceAnalysis: FaceAnalysis, profile: PhotoComplianceProfile) -> Double {
        let eyeTargetRatio = (profile.eyeHeightRange.lowerBound + profile.eyeHeightRange.upperBound) / 2
        let targetTop = guideTopRatioForEyeAlignedHead(profile: profile, eyeTargetRatio: eyeTargetRatio)
        let targetCenter = targetTop + profile.targetHeadRatio / 2
        let actualCenter = topMarginForCompliance(faceAnalysis: faceAnalysis) + faceAnalysis.effectiveHeadHeightRatio / 2
        return actualCenter - targetCenter
    }

    private func topMarginForCompliance(faceAnalysis: FaceAnalysis) -> Double {
        guard let eyeHeight = faceAnalysis.eyeHeightRatio else {
            return faceAnalysis.effectiveTopMarginRatio
        }
        let normalEyePositionWithinHead = GuideFramingCalculator.eyePositionWithinHead
        let inferredTopMargin = (1 - eyeHeight) - faceAnalysis.effectiveHeadHeightRatio * normalEyePositionWithinHead
        return max(faceAnalysis.effectiveTopMarginRatio, min(max(inferredTopMargin, 0), 1))
    }

    private func guideTopRatioForEyeAlignedHead(profile: PhotoComplianceProfile, eyeTargetRatio: Double) -> Double {
        GuideFramingCalculator.guideTopRatio(
            headRatio: profile.targetHeadRatio,
            eyeTargetRatio: eyeTargetRatio,
            profile: profile
        )
    }

    private func resolvedVerticalGuidanceDirection(
        faceAnalysis: FaceAnalysis,
        profile: PhotoComplianceProfile,
        minimumTopMargin: Double,
        minimumBottomMargin: Double
    ) -> VerticalGuidanceDirection? {
        let relaxedVerticalOffset = guideAlignmentOffset(faceAnalysis: faceAnalysis, profile: profile)
        let topGap = minimumTopMargin - topMarginForCompliance(faceAnalysis: faceAnalysis)
        let bottomGap = minimumBottomMargin - faceAnalysis.effectiveBottomMarginRatio

        if relaxedVerticalOffset > FaceAnalysis.verticalCenterWarningThreshold {
            return .up
        }
        if relaxedVerticalOffset < -FaceAnalysis.verticalCenterWarningThreshold {
            return .down
        }
        if topGap > 0.018 {
            return .down
        }
        if bottomGap > 0.018 {
            return .up
        }

        guard
            profile.shouldDriveEyeHeightAutoFix,
            let eyeHeight = faceAnalysis.eyeHeightRatio
        else {
            return nil
        }

        if eyeHeight < profile.eyeHeightRange.lowerBound - 0.026 {
            return .up
        }
        if eyeHeight > profile.eyeHeightRange.upperBound + 0.026 {
            return .down
        }
        return nil
    }

    private func makeGlassesCheck(policy: GlassesPolicy, faceAnalysis: FaceAnalysis) -> ComplianceCheck? {
        switch policy {
        case .disallow:
            guard faceAnalysis.hasGlassesRisk && faceAnalysis.hasGlareRisk else { return nil }
            return ComplianceCheck(
                title: L10n.text(en: "Glasses", zh: "眼镜"),
                message: L10n.text(en: "Possible glasses and lens glare were detected around the eyes.", zh: "眼部附近可能存在眼镜和镜片反光。"),
                severity: .warning,
                action: L10n.text(en: "If you are wearing glasses, retake without glasses. If not, ignore this warning.", zh: "如果确实佩戴眼镜，请摘掉重拍；如果没有佩戴，可忽略此提示。"),
                kind: .glasses
            )
        case .discourage:
            guard faceAnalysis.hasGlassesRisk && faceAnalysis.hasGlareRisk else { return nil }
            return ComplianceCheck(
                title: L10n.text(en: "Glasses", zh: "眼镜"),
                message: L10n.text(en: "Possible glasses glare was detected around the eyes.", zh: "眼部附近可能存在眼镜反光。"),
                severity: .warning,
                action: L10n.text(en: "Retake without glasses, or ensure the eyes are fully visible with no glare.", zh: "建议摘掉眼镜重拍，或确保双眼无遮挡且没有反光。"),
                kind: .glasses
            )
        case .allowIfClear:
            guard faceAnalysis.hasGlassesRisk && faceAnalysis.hasGlareRisk else { return nil }
            return ComplianceCheck(
                title: L10n.text(en: "Glasses / glare", zh: "眼镜/反光"),
                message: L10n.text(en: "Possible glasses glare was detected around the eyes.", zh: "眼部附近可能存在眼镜反光。"),
                severity: .warning,
                action: L10n.text(en: "Reduce glare, avoid tinted lenses, and keep both eyes fully visible.", zh: "请减少反光，避免有色镜片，并确保双眼完全可见。"),
                kind: .glasses
            )
        case .unknown:
            return nil
        }
    }
}
