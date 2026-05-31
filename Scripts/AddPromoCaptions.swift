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
    fputs("Usage: swift AddPromoCaptions.swift input.mp4 output.mp4\n", stderr)
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
        Caption(start: 0.0, end: 3.0, title: "Create passport photos at home", subtitle: "Private passport, visa, and ID photos"),
        Caption(start: 3.0, end: 6.5, title: "Choose an official-size template", subtitle: "Passport, visa, green card, and ID formats"),
        Caption(start: 6.5, end: 10.0, title: "Import or take a photo", subtitle: "Use guided framing for better alignment"),
        Caption(start: 10.0, end: 13.8, title: "Adjust with simple gestures", subtitle: "Move, zoom, and rotate directly on the photo"),
        Caption(start: 13.8, end: 18.0, title: "Check photo requirements", subtitle: "Based on published photo requirements"),
        Caption(start: 18.0, end: 21.5, title: "Change allowed background colors", subtitle: "Prepare a clean document-style photo"),
        Caption(start: 21.5, end: 25.5, title: "Export JPG, PDF, or 4x6 print layout", subtitle: "Digital files and photo lab print sheets"),
        Caption(start: 25.5, end: 29.2, title: "100% on-device. No cloud upload.", subtitle: "No ads. No subscription.")
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
    let boxWidth = size.width - 72
    let box = CALayer()
    box.frame = CGRect(x: 36, y: 92, width: boxWidth, height: 142)
    box.backgroundColor = NSColor.black.withAlphaComponent(0.62).cgColor
    box.cornerRadius = 20
    box.borderWidth = 1
    box.borderColor = NSColor.white.withAlphaComponent(0.18).cgColor

    let title = CATextLayer()
    title.string = caption.title
    title.foregroundColor = NSColor.white.cgColor
    title.font = NSFont.systemFont(ofSize: 29, weight: .bold)
    title.fontSize = 29
    title.alignmentMode = .center
    title.contentsScale = 2
    title.isWrapped = true
    title.frame = CGRect(x: 18, y: 70, width: boxWidth - 36, height: 46)

    let subtitle = CATextLayer()
    subtitle.string = caption.subtitle
    subtitle.foregroundColor = NSColor.white.withAlphaComponent(0.88).cgColor
    subtitle.font = NSFont.systemFont(ofSize: 20, weight: .medium)
    subtitle.fontSize = 20
    subtitle.alignmentMode = .center
    subtitle.contentsScale = 2
    subtitle.isWrapped = true
    subtitle.frame = CGRect(x: 18, y: 30, width: boxWidth - 36, height: 34)

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
