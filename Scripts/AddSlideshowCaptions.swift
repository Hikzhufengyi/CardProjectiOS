import AVFoundation
import AppKit
import Foundation
import QuartzCore

struct Caption {
    let start: Double
    let end: Double
    let title: String
    let subtitle: String
}

guard CommandLine.arguments.count >= 3 else {
    fputs("Usage: swift AddSlideshowCaptions.swift input.mp4 output.mp4\n", stderr)
    exit(2)
}

let inputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let outputURL = URL(fileURLWithPath: CommandLine.arguments[2])
try? FileManager.default.removeItem(at: outputURL)

let asset = AVURLAsset(url: inputURL)
let composition = AVMutableComposition()

guard let sourceVideoTrack = asset.tracks(withMediaType: .video).first,
      let videoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
    fputs("Missing video track\n", stderr)
    exit(1)
}

let duration = asset.duration
try videoTrack.insertTimeRange(CMTimeRange(start: .zero, duration: duration), of: sourceVideoTrack, at: .zero)
videoTrack.preferredTransform = sourceVideoTrack.preferredTransform

if let sourceAudioTrack = asset.tracks(withMediaType: .audio).first,
   let audioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) {
    try? audioTrack.insertTimeRange(CMTimeRange(start: .zero, duration: duration), of: sourceAudioTrack, at: .zero)
}

let transformedSize = sourceVideoTrack.naturalSize.applying(sourceVideoTrack.preferredTransform)
let renderSize = CGSize(width: abs(transformedSize.width), height: abs(transformedSize.height))

let instruction = AVMutableVideoCompositionInstruction()
instruction.timeRange = CMTimeRange(start: .zero, duration: duration)
instruction.layerInstructions = [AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)]

let videoComposition = AVMutableVideoComposition()
videoComposition.instructions = [instruction]
videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
videoComposition.renderSize = renderSize

let videoLayer = CALayer()
videoLayer.frame = CGRect(origin: .zero, size: renderSize)
let parentLayer = makeParentLayer(size: renderSize, videoLayer: videoLayer)
videoComposition.animationTool = AVVideoCompositionCoreAnimationTool(postProcessingAsVideoLayer: videoLayer, in: parentLayer)

guard let exporter = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
    fputs("Could not create exporter\n", stderr)
    exit(1)
}

exporter.outputURL = outputURL
exporter.outputFileType = .mp4
exporter.videoComposition = videoComposition
exporter.shouldOptimizeForNetworkUse = true

let semaphore = DispatchSemaphore(value: 0)
exporter.exportAsynchronously { semaphore.signal() }
semaphore.wait()

if exporter.status == .completed {
    print(outputURL.path)
} else {
    fputs("Export failed: \(exporter.error?.localizedDescription ?? "unknown error")\n", stderr)
    exit(1)
}

func makeParentLayer(size: CGSize, videoLayer: CALayer) -> CALayer {
    let parent = CALayer()
    parent.frame = CGRect(origin: .zero, size: size)
    parent.addSublayer(videoLayer)

    let captions = [
        Caption(start: 0, end: 3, title: "Create passport photos at home", subtitle: "Choose from official-size templates"),
        Caption(start: 3, end: 6, title: "Import or take a photo", subtitle: "Use clear front-facing guidance"),
        Caption(start: 6, end: 9, title: "Smart framing checks", subtitle: "Eye line, head size, and face position"),
        Caption(start: 9, end: 12, title: "Review what needs fixing", subtitle: "Clear checklist before export"),
        Caption(start: 12, end: 15, title: "Fine-tune the photo", subtitle: "Crop, zoom, rotate, and adjust tone"),
        Caption(start: 15, end: 18, title: "Export digital files", subtitle: "JPG, HEIF, PNG, or PDF"),
        Caption(start: 18, end: 21, title: "4x6 print layout ready", subtitle: "Made for common photo labs"),
        Caption(start: 21, end: 24, title: "Private by design", subtitle: "No cloud upload. No ad SDKs."),
        Caption(start: 24, end: 27, title: "IDPhoto Pro", subtitle: "Private passport photos, made simple")
    ]

    for caption in captions {
        let layer = captionLayer(caption, size: size)
        layer.opacity = 0
        layer.add(fadeAnimation(start: caption.start, end: caption.end), forKey: "fade")
        parent.addSublayer(layer)
    }
    return parent
}

func captionLayer(_ caption: Caption, size: CGSize) -> CALayer {
    let boxWidth = size.width - 76
    let box = CALayer()
    box.frame = CGRect(x: 38, y: 88, width: boxWidth, height: 138)
    box.backgroundColor = NSColor.black.withAlphaComponent(0.64).cgColor
    box.cornerRadius = 20
    box.borderWidth = 1
    box.borderColor = NSColor.white.withAlphaComponent(0.18).cgColor

    let title = CATextLayer()
    title.string = caption.title
    title.foregroundColor = NSColor.white.cgColor
    title.font = NSFont.systemFont(ofSize: 28, weight: .bold)
    title.fontSize = 28
    title.alignmentMode = .center
    title.contentsScale = 2
    title.isWrapped = true
    title.frame = CGRect(x: 18, y: 68, width: boxWidth - 36, height: 44)

    let subtitle = CATextLayer()
    subtitle.string = caption.subtitle
    subtitle.foregroundColor = NSColor.white.withAlphaComponent(0.88).cgColor
    subtitle.font = NSFont.systemFont(ofSize: 20, weight: .medium)
    subtitle.fontSize = 20
    subtitle.alignmentMode = .center
    subtitle.contentsScale = 2
    subtitle.isWrapped = true
    subtitle.frame = CGRect(x: 18, y: 28, width: boxWidth - 36, height: 34)

    box.addSublayer(title)
    box.addSublayer(subtitle)
    return box
}

func fadeAnimation(start: Double, end: Double) -> CAKeyframeAnimation {
    let animation = CAKeyframeAnimation(keyPath: "opacity")
    animation.values = [0, 1, 1, 0]
    animation.keyTimes = [0, 0.08, 0.92, 1]
    animation.beginTime = AVCoreAnimationBeginTimeAtZero + start
    animation.duration = max(end - start, 0.1)
    animation.fillMode = .both
    animation.isRemovedOnCompletion = false
    return animation
}
