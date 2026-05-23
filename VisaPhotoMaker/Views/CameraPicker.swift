import SwiftUI
import UIKit

struct CameraPicker: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    let spec: PhotoSpec
    @Binding var image: UIImage?

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        picker.cameraCaptureMode = .photo
        if picker.sourceType == .camera {
            picker.showsCameraControls = true
            picker.cameraOverlayView = CameraGuideOverlay(spec: spec)
        }
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: CameraPicker

        init(_ parent: CameraPicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            let capturedImage = (info[.editedImage] as? UIImage) ?? (info[.originalImage] as? UIImage)
            parent.image = capturedImage?.preparedForIDPhotoProcessing()
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

private final class CameraGuideOverlay: UIView {
    private let spec: PhotoSpec

    init(spec: PhotoSpec) {
        self.spec = spec
        super.init(frame: UIScreen.main.bounds)
        backgroundColor = .clear
        isUserInteractionEnabled = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }

        let safeRect = bounds.insetBy(dx: 34, dy: 110)
        let targetRatio = spec.pixelSize.width / max(spec.pixelSize.height, 1)
        var frame = safeRect
        if safeRect.width / safeRect.height > targetRatio {
            frame.size.width = safeRect.height * targetRatio
            frame.origin.x = bounds.midX - frame.width / 2
        } else {
            frame.size.height = safeRect.width / targetRatio
            frame.origin.y = bounds.midY - frame.height / 2
        }

        context.setFillColor(UIColor.black.withAlphaComponent(0.28).cgColor)
        context.fill(bounds)
        context.clear(frame)

        UIColor.white.withAlphaComponent(0.9).setStroke()
        let border = UIBezierPath(roundedRect: frame, cornerRadius: 10)
        border.lineWidth = 2
        border.stroke()

        let headHeight = frame.height * ((spec.minHeadRatio + spec.maxHeadRatio) / 2)
        let headWidth = headHeight * 0.72
        let headRect = CGRect(
            x: frame.midX - headWidth / 2,
            y: frame.minY + frame.height * 0.47 - headHeight / 2,
            width: headWidth,
            height: headHeight
        )
        let headPath = UIBezierPath(ovalIn: headRect)
        headPath.setLineDash([8, 6], count: 2, phase: 0)
        headPath.lineWidth = 2
        UIColor.systemGreen.withAlphaComponent(0.95).setStroke()
        headPath.stroke()

        drawLabel(in: frame)
    }

    private func drawLabel(in frame: CGRect) {
        let text = L10n.isChinese
            ? "正对镜头 · 均匀光线 · 纯色背景"
            : "Face forward · Even light · Plain background"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 15, weight: .semibold),
            .foregroundColor: UIColor.white
        ]
        let size = text.size(withAttributes: attributes)
        let labelRect = CGRect(
            x: frame.midX - size.width / 2 - 12,
            y: max(frame.minY - size.height - 24, safeAreaInsets.top + 12),
            width: size.width + 24,
            height: size.height + 12
        )
        let background = UIBezierPath(roundedRect: labelRect, cornerRadius: 16)
        UIColor.black.withAlphaComponent(0.48).setFill()
        background.fill()
        text.draw(
            in: CGRect(x: labelRect.minX + 12, y: labelRect.minY + 6, width: size.width, height: size.height),
            withAttributes: attributes
        )
    }
}
