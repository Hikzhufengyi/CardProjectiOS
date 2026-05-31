@preconcurrency import AVFoundation
import AudioToolbox
import SwiftUI
import UIKit
import Vision

private func eyeAlignedHeadTopRatio(for profile: PhotoComplianceProfile) -> Double {
    let eyeTargetRatio = (profile.eyeHeightRange.lowerBound + profile.eyeHeightRange.upperBound) / 2
    return GuideFramingCalculator.guideTopRatio(
        headRatio: profile.targetHeadRatio,
        eyeTargetRatio: eyeTargetRatio,
        profile: profile
    )
}

struct CameraPicker: View {
    @Environment(\.dismiss) private var dismiss
    let spec: PhotoSpec
    @Binding var image: UIImage?
    var onCapturePrepared: ((UIImage) async -> Void)? = nil

    @StateObject private var camera: CameraCaptureController

    init(spec: PhotoSpec, image: Binding<UIImage?>, onCapturePrepared: ((UIImage) async -> Void)? = nil) {
        self.spec = spec
        self._image = image
        self.onCapturePrepared = onCapturePrepared
        _camera = StateObject(wrappedValue: CameraCaptureController(spec: spec))
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black.ignoresSafeArea()

                if camera.isAuthorized {
                    CameraPreviewContainer(session: camera.session)
                        .ignoresSafeArea()

                    CameraLiveGuideOverlay(
                        spec: spec,
                        faceObservation: camera.faceObservation,
                        eyeLine: camera.eyeLine,
                        analysisHint: camera.analysisHint,
                        captureState: camera.captureState
                    )
                    .ignoresSafeArea()

                    VStack(spacing: 0) {
                        topBar(topInset: proxy.safeAreaInsets.top)
                        Spacer()
                        bottomControls(bottomInset: proxy.safeAreaInsets.bottom)
                    }

                    if camera.captureState == .capturing || camera.captureState == .optimizing {
                        captureFeedbackOverlay
                    }
                } else {
                    permissionView
                }
            }
        }
        .task {
            await camera.prepareSession()
        }
        .onDisappear {
            camera.stopSession()
        }
        .onChange(of: camera.capturedImage) { _, newImage in
            guard let newImage else { return }
            let prepared = newImage.preparedForIDPhotoProcessing(maxPixelLength: 3200)
            Task {
                await MainActor.run {
                    camera.captureState = .optimizing
                }
                await onCapturePrepared?(prepared)
                await MainActor.run {
                    camera.captureState = .ready
                    image = prepared
                    dismiss()
                }
            }
        }
        .alert(
            L10n.text(en: "Camera Unavailable", zh: "无法使用相机"),
            isPresented: Binding(
                get: { camera.errorMessage != nil },
                set: { if !$0 { camera.errorMessage = nil } }
            )
        ) {
            Button(L10n.text(en: "OK", zh: "知道了"), role: .cancel) {}
        } message: {
            Text(camera.errorMessage ?? "")
        }
    }

    private func topBar(topInset: CGFloat) -> some View {
        HStack(spacing: 12) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(Color.black.opacity(0.36), in: Circle())
            }
            .buttonStyle(.plain)

            Spacer(minLength: 12)

            VStack(spacing: 4) {
                Text(spec.displayTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                Text(L10n.text(en: "Live passport photo alignment", zh: "实时证件照取景"))
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.white.opacity(0.88))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .frame(maxWidth: 180)

            Spacer(minLength: 12)

            Button {
                camera.toggleCamera()
            } label: {
                Image(systemName: "arrow.triangle.2.circlepath.camera")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(Color.black.opacity(0.36), in: Circle())
            }
            .buttonStyle(.plain)
            .disabled(!camera.canSwitchCamera)
            .opacity(camera.canSwitchCamera ? 1 : 0.45)
        }
        .padding(.horizontal, 18)
        .padding(.top, max(topInset + 22, 36))
        .padding(.bottom, 8)
    }

    private func bottomControls(bottomInset: CGFloat) -> some View {
        VStack(spacing: 14) {
            statusPill

            HStack(spacing: 18) {
                Spacer()

                Button {
                    camera.capturePhoto()
                } label: {
                    ZStack {
                        Circle()
                            .fill(camera.captureState == .locked ? AppTheme.success.opacity(0.22) : Color.white.opacity(0.18))
                            .frame(width: 84, height: 84)
                        Circle()
                            .stroke(camera.captureState == .locked ? AppTheme.success.opacity(0.82) : Color.white.opacity(0.42), lineWidth: 2.4)
                            .frame(width: 74, height: 74)
                        Circle()
                            .fill((camera.captureState == .ready || camera.captureState == .locked) ? Color.white : Color.white.opacity(0.82))
                            .frame(width: 62, height: 62)
                        if camera.captureState == .capturing || camera.captureState == .optimizing {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .tint(AppTheme.officialBlue)
                                .scaleEffect(0.9)
                        } else if camera.captureState == .locked {
                            Image(systemName: "checkmark")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(AppTheme.success)
                        }
                    }
                }
                .buttonStyle(.plain)
                .disabled(camera.captureState == .capturing || camera.captureState == .optimizing)

                Spacer()
            }
            .padding(.bottom, max(bottomInset, 10))
        }
        .padding(.horizontal, 18)
        .background(
            LinearGradient(
                colors: [Color.black.opacity(0), Color.black.opacity(0.18), Color.black.opacity(0.42)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .bottom)
        )
    }

    private var statusPill: some View {
        HStack(spacing: 8) {
            if camera.captureState == .capturing || camera.captureState == .optimizing {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(camera.captureState.color)
                    .scaleEffect(0.72)
            } else {
                Image(systemName: camera.captureState.icon)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(camera.captureState.color)
            }
            Text(camera.captureState.message)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background((camera.captureState == .locked ? AppTheme.success.opacity(0.22) : Color.black.opacity(0.42)), in: Capsule())
    }

    private var captureFeedbackOverlay: some View {
        VStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(.white)
                .scaleEffect(1.1)
            Text(camera.captureState.message)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color.black.opacity(0.62), in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        }
        .transition(.opacity)
        .allowsHitTesting(false)
    }

    private var permissionView: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 52, weight: .semibold))
                .foregroundStyle(.white)
            Text(L10n.text(en: "Allow Camera Access", zh: "允许访问相机"))
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)
            Text(L10n.text(en: "Use the front camera with live face guidance for better passport photo framing.", zh: "开启前置相机和实时引导，提升证件照构图准确率。"))
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.88))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Button {
                camera.openSettings()
            } label: {
                Text(L10n.text(en: "Open Settings", zh: "打开设置"))
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.black)
                    .frame(height: 50)
                    .frame(maxWidth: 240)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
        }
    }
}

private struct CameraPreviewContainer: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> CameraPreviewView {
        let view = CameraPreviewView()
        view.previewLayer.session = session
        return view
    }

    func updateUIView(_ uiView: CameraPreviewView, context: Context) {
        uiView.previewLayer.session = session
    }
}

private final class CameraPreviewView: UIView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.connection?.videoRotationAngle = 90
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer.frame = bounds
        previewLayer.connection?.videoRotationAngle = 90
    }
}

private final class CameraCaptureController: NSObject, ObservableObject, @unchecked Sendable {
    @Published var capturedImage: UIImage?
    @Published var faceObservation: VNFaceObservation?
    @Published var eyeLine: EyeLineObservation?
    @Published var analysisHint: LiveAnalysisHint = .noFace
    @Published var captureState: CaptureState = .positionFace
    @Published var isAuthorized = false
    @Published var errorMessage: String?

    private let spec: PhotoSpec
    let session = AVCaptureSession()
    var canSwitchCamera: Bool {
        AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) != nil &&
        AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) != nil
    }

    private let sessionQueue = DispatchQueue(label: "CameraCaptureController.session")
    private let videoOutput = AVCaptureVideoDataOutput()
    private let photoOutput = AVCapturePhotoOutput()
    private var currentInput: AVCaptureDeviceInput?
    private var currentPosition: AVCaptureDevice.Position = .front
    private var lastObservationUpdate = CACurrentMediaTime()
    private let observationLock = NSLock()
    private var isConfigured = false
    private var stableHint: LiveAnalysisHint = .noFace
    private var stableCaptureState: CaptureState = .positionFace
    private var pendingHint: LiveAnalysisHint?
    private var pendingCaptureState: CaptureState?
    private var pendingHintCount = 0

    init(spec: PhotoSpec) {
        self.spec = spec
        super.init()
    }

    func prepareSession() async {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            await MainActor.run { [weak self] in
                self?.isAuthorized = true
            }
            configureAndStartIfNeeded()
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            await MainActor.run { [weak self] in
                self?.isAuthorized = granted
            }
            if granted {
                configureAndStartIfNeeded()
            }
        default:
            await MainActor.run { [weak self] in
                self?.isAuthorized = false
            }
        }
    }

    func stopSession() {
        sessionQueue.async {
            guard self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }

    @MainActor
    func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    func toggleCamera() {
        guard canSwitchCamera else { return }
        currentPosition = currentPosition == .front ? .back : .front
        sessionQueue.async {
            self.reconfigureInput()
        }
    }

    func capturePhoto() {
        guard captureState != .capturing, captureState != .optimizing else { return }
        captureState = .capturing
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        AudioServicesPlaySystemSound(1108)
        let settings = AVCapturePhotoSettings()
        settings.flashMode = .off
        settings.photoQualityPrioritization = .quality
        if photoOutput.maxPhotoDimensions.width > 0 {
            settings.maxPhotoDimensions = photoOutput.maxPhotoDimensions
        }
        sessionQueue.async {
            self.photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    private func configureAndStartIfNeeded() {
        sessionQueue.async {
            if !self.isConfigured {
                self.configureSession()
                self.isConfigured = true
            }
            guard !self.session.isRunning else { return }
            self.session.startRunning()
        }
    }

    private func configureSession() {
        session.beginConfiguration()
        session.sessionPreset = .photo

        guard let device = bestDevice(for: currentPosition),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            Task { @MainActor [weak self] in
                self?.errorMessage = L10n.text(en: "The camera could not be started on this device.", zh: "当前设备无法启动相机。")
            }
            session.commitConfiguration()
            return
        }

        session.addInput(input)
        currentInput = input

        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        videoOutput.setSampleBufferDelegate(self, queue: sessionQueue)
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
            videoOutput.connection(with: .video)?.videoRotationAngle = 90
            videoOutput.connection(with: .video)?.isVideoMirrored = currentPosition == .front
        }

        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
            photoOutput.maxPhotoQualityPrioritization = .quality
            photoOutput.connection(with: .video)?.videoRotationAngle = 90
            photoOutput.connection(with: .video)?.isVideoMirrored = currentPosition == .front
        }

        session.commitConfiguration()
    }

    private func reconfigureInput() {
        session.beginConfiguration()
        if let currentInput {
            session.removeInput(currentInput)
        }

        guard let device = bestDevice(for: currentPosition),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            session.commitConfiguration()
            return
        }

        session.addInput(input)
        currentInput = input
        videoOutput.connection(with: .video)?.videoRotationAngle = 90
        videoOutput.connection(with: .video)?.isVideoMirrored = currentPosition == .front
        photoOutput.connection(with: .video)?.videoRotationAngle = 90
        photoOutput.connection(with: .video)?.isVideoMirrored = currentPosition == .front
        session.commitConfiguration()
    }

    private func bestDevice(for position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position)
    }

    private func updateHint(with observation: VNFaceObservation?, eyeLineObservation: EyeLineObservation? = nil) {
        faceObservation = observation

        guard let observation else {
            eyeLine = nil
            applyStableHint(.noFace, state: .positionFace, requiredCount: 2)
            return
        }

        let rect = observation.boundingBox
        let centerX = rect.midX
        let centerY = rect.midY
        let size = rect.height

        let yaw = observation.yaw?.doubleValue ?? 0
        let roll = observation.roll?.doubleValue ?? 0
        let eyeLineAngle = eyeLineObservation.map(Self.eyeLineDegrees(from:)) ?? 0
        let eyesOpenScore = Self.eyesOpenScore(from: observation)
        let headCoverRisk = Self.hasHeadCoverRisk(from: observation)
        let profile = spec.complianceProfile
        let headTolerance = max((spec.maxHeadRatio - spec.minHeadRatio) * 0.34, 0.055)
        let minSize = max(spec.minHeadRatio - headTolerance, 0.24)
        let maxSize = min(spec.maxHeadRatio + headTolerance, 0.84)
        let minCenterX = 0.5 - max(0.055, min(0.085, (1 - profile.targetHeadRatio) * 0.22))
        let maxCenterX = 0.5 + max(0.055, min(0.085, (1 - profile.targetHeadRatio) * 0.22))
        let targetCenterY = 1 - eyeAlignedHeadTopRatio(for: profile) - profile.targetHeadRatio / 2
        let centerYTolerance = max(0.060, min(0.095, (1 - profile.targetHeadRatio) * 0.30))
        let minCenterY = targetCenterY - centerYTolerance
        let maxCenterY = targetCenterY + centerYTolerance

        if size < minSize {
            applyStableHint(.moveCloser, state: .adjust(L10n.text(en: "Move closer", zh: "请靠近一些")))
            return
        }
        if size > maxSize {
            applyStableHint(.moveFarther, state: .adjust(L10n.text(en: "Move farther", zh: "请离远一些")))
            return
        }
        if centerX < minCenterX {
            applyStableHint(.moveRight, state: .adjust(L10n.text(en: "Move right", zh: "请向右移动")))
            return
        }
        if centerX > maxCenterX {
            applyStableHint(.moveLeft, state: .adjust(L10n.text(en: "Move left", zh: "请向左移动")))
            return
        }
        if centerY < minCenterY {
            applyStableHint(.moveUp, state: .adjust(L10n.text(en: "Raise the phone slightly", zh: "请稍微向上调整")))
            return
        }
        if centerY > maxCenterY {
            applyStableHint(.moveDown, state: .adjust(L10n.text(en: "Lower the phone slightly", zh: "请稍微向下调整")))
            return
        }
        if abs(yaw) > 0.11 {
            applyStableHint(
                yaw > 0 ? .turnLeft : .turnRight,
                state: .adjust(yaw > 0 ? L10n.text(en: "Turn slightly left", zh: "请稍微向左转") : L10n.text(en: "Turn slightly right", zh: "请稍微向右转"))
            )
            return
        }
        if abs(eyeLineAngle) > 1.8 {
            applyStableHint(
                eyeLineAngle > 0 ? .levelLeft : .levelRight,
                state: .adjust(eyeLineAngle > 0 ? L10n.text(en: "Level your head left", zh: "头部向左回正") : L10n.text(en: "Level your head right", zh: "头部向右回正"))
            )
            return
        }
        if abs(roll) > 0.055 {
            applyStableHint(
                roll > 0 ? .levelLeft : .levelRight,
                state: .adjust(roll > 0 ? L10n.text(en: "Level your head left", zh: "头部向左回正") : L10n.text(en: "Level your head right", zh: "头部向右回正"))
            )
            return
        }
        if let eyesOpenScore, eyesOpenScore < 0.12 {
            applyStableHint(.openEyes, state: .adjust(L10n.text(en: "Open both eyes naturally", zh: "请自然睁开双眼")))
            return
        }
        if headCoverRisk {
            applyStableHint(.removeHeadCover, state: .adjust(L10n.text(en: "Remove hats or head coverings", zh: "请去掉帽子或头顶遮挡")))
            return
        }

        let lockedMinSize = max(profile.targetHeadRatio - profile.headPassTolerance * 1.8, spec.minHeadRatio * 0.94)
        let lockedMaxSize = min(profile.targetHeadRatio + profile.headPassTolerance * 1.8, spec.maxHeadRatio * 1.06)
        let lockedCenterXTolerance = 0.022
        let lockedCenterYTolerance = 0.032
        let isLocked =
            size >= lockedMinSize &&
            size <= lockedMaxSize &&
            abs(centerX - 0.5) <= lockedCenterXTolerance &&
            abs(centerY - targetCenterY) <= lockedCenterYTolerance &&
            abs(yaw) <= 0.055 &&
            abs(eyeLineAngle) <= 1.0 &&
            abs(roll) <= 0.035

        if isLocked {
            applyStableHint(.locked, state: .locked, requiredCount: 2)
            return
        }

        applyStableHint(.good, state: .ready, requiredCount: 2)
    }

    private func applyStableHint(_ hint: LiveAnalysisHint, state: CaptureState, requiredCount: Int = 3) {
        guard captureState != .capturing, captureState != .optimizing else { return }

        if hint == stableHint {
            pendingHint = nil
            pendingCaptureState = nil
            pendingHintCount = 0
            if analysisHint != hint || captureState != state {
                analysisHint = hint
                captureState = state
                stableCaptureState = state
            }
            return
        }

        if pendingHint == hint && pendingCaptureState == state {
            pendingHintCount += 1
        } else {
            pendingHint = hint
            pendingCaptureState = state
            pendingHintCount = 1
        }

        guard pendingHintCount >= requiredCount else {
            analysisHint = stableHint
            captureState = stableCaptureState
            return
        }

        stableHint = hint
        stableCaptureState = state
        analysisHint = hint
        captureState = state
        pendingHint = nil
        pendingCaptureState = nil
        pendingHintCount = 0
    }
}

extension CameraCaptureController: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let now = CACurrentMediaTime()
        observationLock.lock()
        defer { observationLock.unlock() }
        guard now - lastObservationUpdate > 0.10 else { return }
        lastObservationUpdate = now

        let request = VNDetectFaceLandmarksRequest()
        request.revision = VNDetectFaceLandmarksRequestRevision3
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .leftMirrored)

        do {
            try handler.perform([request])
            let bestFace = (request.results ?? []).max(by: { $0.boundingBox.width * $0.boundingBox.height < $1.boundingBox.width * $1.boundingBox.height })
            let currentEyeLine = bestFace.flatMap(Self.extractEyeLine(from:))
            Task { @MainActor [weak self] in
                self?.eyeLine = currentEyeLine
                self?.updateHint(with: bestFace, eyeLineObservation: currentEyeLine)
            }
        } catch {
            Task { @MainActor [weak self] in
                self?.eyeLine = nil
                self?.applyStableHint(.noFace, state: .positionFace, requiredCount: 2)
            }
        }
    }
}

extension CameraCaptureController: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error {
            Task { @MainActor [weak self] in
                self?.captureState = .positionFace
                self?.errorMessage = error.localizedDescription
            }
            return
        }

        guard let data = photo.fileDataRepresentation(),
              let captured = UIImage(data: data) else {
            Task { @MainActor [weak self] in
                self?.captureState = .positionFace
                self?.errorMessage = L10n.text(en: "Photo capture failed. Please try again.", zh: "拍照失败，请重试。")
            }
            return
        }

        Task { @MainActor [weak self] in
            self?.capturedImage = captured
            self?.captureState = .ready
        }
    }
}

private struct CameraLiveGuideOverlay: View {
    let spec: PhotoSpec
    let faceObservation: VNFaceObservation?
    let eyeLine: EyeLineObservation?
    let analysisHint: LiveAnalysisHint
    let captureState: CameraCaptureController.CaptureState

    var body: some View {
        GeometryReader { proxy in
            let frameRect = framingRect(in: proxy.size)
            let headGuideRect = headGuideRect(in: frameRect)
            let faceRect = faceObservation.map { previewRect(for: $0.boundingBox, in: frameRect) }

            ZStack {
                Path { path in
                    path.addRect(CGRect(origin: .zero, size: proxy.size))
                    path.addRoundedRect(in: frameRect, cornerSize: CGSize(width: 18, height: 18))
                }
                .fill(Color.black.opacity(0.36), style: FillStyle(eoFill: true))

                RoundedRectangle(cornerRadius: 18)
                    .stroke(Color.white.opacity(0.92), lineWidth: 2)
                    .frame(width: frameRect.width, height: frameRect.height)
                    .position(x: frameRect.midX, y: frameRect.midY)

                Ellipse()
                    .stroke(analysisHint.guideColor, style: StrokeStyle(lineWidth: 3, dash: [9, 6]))
                    .frame(width: headGuideRect.width, height: headGuideRect.height)
                    .position(x: headGuideRect.midX, y: headGuideRect.midY)

                if captureState == .locked {
                    Ellipse()
                        .fill(AppTheme.success.opacity(0.10))
                        .frame(width: headGuideRect.width - 6, height: headGuideRect.height - 6)
                        .position(x: headGuideRect.midX, y: headGuideRect.midY)
                }

                Rectangle()
                    .fill(Color.red.opacity(0.52))
                    .frame(width: frameRect.width - 18, height: 1)
                    .position(x: frameRect.midX, y: max(frameRect.minY + frameRect.height * strictTopMarginRatio, 8))

                if let faceRect {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(analysisHint.faceColor, lineWidth: 2.5)
                        .frame(width: faceRect.width, height: faceRect.height)
                        .position(x: faceRect.midX, y: faceRect.midY)
                }

                if let eyeLine {
                    let left = previewPoint(for: eyeLine.leftEye, in: frameRect)
                    let right = previewPoint(for: eyeLine.rightEye, in: frameRect)
                    Path { path in
                        path.move(to: left)
                        path.addLine(to: right)
                    }
                    .stroke(analysisHint.faceColor.opacity(0.96), style: StrokeStyle(lineWidth: 2.5, dash: [6, 4]))

                    let levelY = (left.y + right.y) / 2
                    Path { path in
                        path.move(to: CGPoint(x: frameRect.minX + 10, y: levelY))
                        path.addLine(to: CGPoint(x: frameRect.maxX - 10, y: levelY))
                    }
                    .stroke(Color.white.opacity(0.32), style: StrokeStyle(lineWidth: 1.4, dash: [4, 4]))
                }

                VStack(spacing: 10) {
                    guideHeader
                    Spacer()
                }
                .padding(.top, proxy.safeAreaInsets.top + 96)
                .padding(.bottom, proxy.safeAreaInsets.bottom + 156)
                .padding(.horizontal, 20)
            }
        }
        .allowsHitTesting(false)
    }

    private var guideHeader: some View {
        VStack(spacing: 6) {
            Text(L10n.text(en: "Align face inside the guide", zh: "请把面部放进引导区"))
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.82)
            Text(L10n.text(en: "Keep eyes level, face forward, and leave space above the head", zh: "保持双眼水平、正对镜头，并给头顶留出空间"))
                .font(.caption.weight(.medium))
                .foregroundStyle(.white.opacity(0.88))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.82)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.42), in: RoundedRectangle(cornerRadius: 18))
    }
    private func framingRect(in size: CGSize) -> CGRect {
        let topInset = size.height * 0.16
        let bottomInset = size.height * 0.24
        let horizontalInset: CGFloat = 24
        let safeRect = CGRect(
            x: horizontalInset,
            y: topInset,
            width: max(size.width - horizontalInset * 2, 120),
            height: max(size.height - topInset - bottomInset, 220)
        )

        let targetRatio = spec.pixelSize.width / max(spec.pixelSize.height, 1)
        var frame = safeRect
        if safeRect.width / safeRect.height > targetRatio {
            frame.size.width = safeRect.height * targetRatio
            frame.origin.x = safeRect.midX - frame.width / 2
        } else {
            frame.size.height = safeRect.width / targetRatio
            frame.origin.y = safeRect.midY - frame.height / 2
        }
        return frame
    }

    private func headGuideRect(in frameRect: CGRect) -> CGRect {
        let profile = spec.complianceProfile
        let headHeight = frameRect.height * profile.targetHeadRatio
        let headWidth = headHeight * 0.72
        let topRatio = eyeAlignedHeadTopRatio(for: profile)
        return CGRect(
            x: frameRect.midX - headWidth / 2,
            y: frameRect.minY + frameRect.height * topRatio,
            width: headWidth,
            height: headHeight
        )
    }

    private func previewRect(for normalizedRect: CGRect, in frameRect: CGRect) -> CGRect {
        CGRect(
            x: frameRect.minX + normalizedRect.minX * frameRect.width,
            y: frameRect.minY + (1 - normalizedRect.maxY) * frameRect.height,
            width: normalizedRect.width * frameRect.width,
            height: normalizedRect.height * frameRect.height
        )
    }

    private func previewPoint(for normalizedPoint: CGPoint, in frameRect: CGRect) -> CGPoint {
        CGPoint(
            x: frameRect.minX + normalizedPoint.x * frameRect.width,
            y: frameRect.minY + (1 - normalizedPoint.y) * frameRect.height
        )
    }

    private var strictTopMarginRatio: CGFloat {
        CGFloat(spec.complianceProfile.minimumTopMarginRatio)
    }
}

extension CameraCaptureController {
    nonisolated private static func extractEyeLine(from observation: VNFaceObservation) -> EyeLineObservation? {
        guard
            let landmarks = observation.landmarks,
            let leftEye = featureCenter(landmarks.leftEye?.normalizedPoints),
            let rightEye = featureCenter(landmarks.rightEye?.normalizedPoints)
        else {
            return nil
        }
        return EyeLineObservation(leftEye: leftEye, rightEye: rightEye)
    }

    nonisolated private static func featureCenter(_ points: [CGPoint]?) -> CGPoint? {
        guard let points, !points.isEmpty else { return nil }
        let sum = points.reduce(CGPoint.zero) { partial, point in
            CGPoint(x: partial.x + point.x, y: partial.y + point.y)
        }
        let count = CGFloat(points.count)
        return CGPoint(x: sum.x / count, y: sum.y / count)
    }

    nonisolated private static func eyeLineDegrees(from eyeLine: EyeLineObservation) -> Double {
        let dx = Double(eyeLine.rightEye.x - eyeLine.leftEye.x)
        let dy = Double(eyeLine.rightEye.y - eyeLine.leftEye.y)
        guard abs(dx) > 0.0001 else { return 0 }
        return atan2(dy, dx) * 180 / .pi
    }

    nonisolated private static func eyesOpenScore(from observation: VNFaceObservation) -> Double? {
        let left = eyeOpenRatio(points: observation.landmarks?.leftEye?.normalizedPoints)
        let right = eyeOpenRatio(points: observation.landmarks?.rightEye?.normalizedPoints)
        switch (left, right) {
        case let (l?, r?): return (l + r) / 2
        case let (l?, nil): return l
        case let (nil, r?): return r
        default: return nil
        }
    }

    nonisolated private static func eyeOpenRatio(points: [CGPoint]?) -> Double? {
        guard let points, points.count >= 4 else { return nil }
        let xs = points.map(\.x)
        let ys = points.map(\.y)
        let width = (xs.max() ?? 0) - (xs.min() ?? 0)
        let height = (ys.max() ?? 0) - (ys.min() ?? 0)
        guard width > 0.0001 else { return nil }
        return Double(height / width)
    }

    nonisolated private static func hasHeadCoverRisk(from observation: VNFaceObservation) -> Bool {
        let topGap = 1 - observation.boundingBox.maxY
        let faceHeight = observation.boundingBox.height
        let veryTightTop = topGap < max(faceHeight * 0.06, 0.02)
        let lacksHairContour = observation.landmarks?.leftEyebrow == nil && observation.landmarks?.rightEyebrow == nil
        return veryTightTop && lacksHairContour
    }
}

struct EyeLineObservation: Equatable {
    let leftEye: CGPoint
    let rightEye: CGPoint
}

private enum LiveAnalysisHint {
    case noFace
    case moveCloser
    case moveFarther
    case moveLeft
    case moveRight
    case moveUp
    case moveDown
    case turnLeft
    case turnRight
    case levelLeft
    case levelRight
    case openEyes
    case removeHeadCover
    case good
    case locked

    var message: String {
        switch self {
        case .noFace:
            return L10n.text(en: "Center your face in the guide", zh: "请把脸放到引导框中央")
        case .moveCloser:
            return L10n.text(en: "Move closer to fill more of the guide", zh: "请靠近一些，让头像更大")
        case .moveFarther:
            return L10n.text(en: "Move farther to leave more head margin", zh: "请离远一些，留出更多头顶空间")
        case .moveLeft:
            return L10n.text(en: "Move slightly left", zh: "请稍微向左移动")
        case .moveRight:
            return L10n.text(en: "Move slightly right", zh: "请稍微向右移动")
        case .moveUp:
            return L10n.text(en: "Raise the phone slightly", zh: "请稍微向上调整")
        case .moveDown:
            return L10n.text(en: "Lower the phone slightly", zh: "请稍微向下调整")
        case .turnLeft:
            return L10n.text(en: "Turn slightly left", zh: "请稍微向左转")
        case .turnRight:
            return L10n.text(en: "Turn slightly right", zh: "请稍微向右转")
        case .levelLeft:
            return L10n.text(en: "Level your head left", zh: "头部向左回正")
        case .levelRight:
            return L10n.text(en: "Level your head right", zh: "头部向右回正")
        case .openEyes:
            return L10n.text(en: "Open both eyes naturally", zh: "请自然睁开双眼")
        case .removeHeadCover:
            return L10n.text(en: "Remove hats or head coverings", zh: "请去掉帽子或头顶遮挡")
        case .good:
            return L10n.text(en: "Looks good. Tap capture now", zh: "当前构图不错，可以拍照")
        case .locked:
            return L10n.text(en: "Locked. Best framing for capture", zh: "已锁定，当前构图最适合拍照")
        }
    }

    var guideColor: Color {
        switch self {
        case .good, .locked:
            return AppTheme.success
        default:
            return AppTheme.officialBlue
        }
    }

    var faceColor: Color {
        switch self {
        case .good, .locked:
            return AppTheme.success
        default:
            return AppTheme.warning
        }
    }
}

extension CameraCaptureController {
    enum CaptureState: Equatable {
        case positionFace
        case adjust(String)
        case ready
        case locked
        case capturing
        case optimizing

        var message: String {
            switch self {
            case .positionFace:
                return L10n.text(en: "Position your face inside the guide", zh: "请把面部对准引导区")
            case .adjust(let text):
                return text
            case .ready:
                return L10n.text(en: "Ready to capture", zh: "可以拍照了")
            case .locked:
                return L10n.text(en: "Framing locked", zh: "构图已锁定")
            case .capturing:
                return L10n.text(en: "Capturing photo...", zh: "正在拍照...")
            case .optimizing:
                return L10n.text(en: "Optimizing framing...", zh: "正在自动校准构图...")
            }
        }

        var icon: String {
            switch self {
            case .positionFace:
                return "viewfinder"
            case .adjust:
                return "arrow.up.left.and.arrow.down.right"
            case .ready:
                return "checkmark.circle.fill"
            case .locked:
                return "scope"
            case .capturing:
                return "camera.aperture"
            case .optimizing:
                return "wand.and.stars"
            }
        }

        var color: Color {
            switch self {
            case .ready:
                return AppTheme.success
            case .locked:
                return AppTheme.success
            case .capturing, .optimizing:
                return AppTheme.officialBlue
            case .positionFace, .adjust:
                return AppTheme.warning
            }
        }
    }
}
