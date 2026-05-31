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

let arguments = CommandLine.arguments
guard arguments.count >= 4 else {
    fputs("Usage: swift GeneratePromoVideo.swift input.mp4 narration.aiff output.mp4\n", stderr)
    exit(2)
}

let inputURL = URL(fileURLWithPath: arguments[1])
let narrationURL = URL(fileURLWithPath: arguments[2])
let outputURL = URL(fileURLWithPath: arguments[3])
try? FileManager.default.removeItem(at: outputURL)

let sourceAsset = AVURLAsset(url: inputURL)
let narrationAsset = AVURLAsset(url: narrationURL)
let composition = AVMutableComposition()

guard let sourceVideoTrack = sourceAsset.tracks(withMediaType: .video).first,
      let videoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
    fputs("Missing video track\n", stderr)
    exit(1)
}

let duration = sourceAsset.duration
try videoTrack.insertTimeRange(CMTimeRange(start: .zero, duration: duration), of: sourceVideoTrack, at: .zero)
videoTrack.preferredTransform = sourceVideoTrack.preferredTransform

if let sourceAudioTrack = sourceAsset.tracks(withMediaType: .audio).first,
   let audioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) {
    try? audioTrack.insertTimeRange(CMTimeRange(start: .zero, duration: duration), of: sourceAudioTrack, at: .zero)
}

if let narrationSourceTrack = narrationAsset.tracks(withMediaType: .audio).first,
   let narrationTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) {
    try? narrationTrack.insertTimeRange(
        CMTimeRange(start: .zero, duration: min(narrationAsset.duration, duration)),
        of: narrationSourceTrack,
        at: .zero
    )
}

let transformedSize = sourceVideoTrack.naturalSize.applying(sourceVideoTrack.preferredTransform)
let renderSize = CGSize(width: abs(transformedSize.width), height: abs(transformedSize.height))

let instruction = AVMutableVideoCompositionInstruction()
instruction.timeRange = CMTimeRange(start: .zero, duration: duration)

let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
instruction.layerInstructions = [layerInstruction]

let videoComposition = AVMutableVideoComposition()
videoComposition.instructions = [instruction]
videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
videoComposition.renderSize = renderSize
let videoLayer = makeVideoLayer(size: renderSize)
videoComposition.animationTool = AVVideoCompositionCoreAnimationTool(
    postProcessingAsVideoLayer: videoLayer,
    in: makeParentLayer(size: renderSize, duration: duration.seconds, videoLayer: videoLayer)
)

guard let exporter = AVAssetExportSession(asset: composition, presetName: AVAssetExportPreset1280x720) else {
    fputs("Could not create exporter\n", stderr)
    exit(1)
}

exporter.outputURL = outputURL
exporter.outputFileType = .mp4
exporter.videoComposition = videoComposition
exporter.shouldOptimizeForNetworkUse = true

let semaphore = DispatchSemaphore(value: 0)
exporter.exportAsynchronously {
    semaphore.signal()
}
semaphore.wait()

if exporter.status == .completed {
    print(outputURL.path)
} else {
    fputs("Export failed: \(exporter.error?.localizedDescription ?? "unknown error")\n", stderr)
    exit(1)
}

func makeVideoLayer(size: CGSize) -> CALayer {
    let layer = CALayer()
    layer.frame = CGRect(origin: .zero, size: size)
    return layer
}

func makeParentLayer(size: CGSize, duration: Double, videoLayer: CALayer) -> CALayer {
    let parent = CALayer()
    parent.frame = CGRect(origin: .zero, size: size)

    parent.addSublayer(videoLayer)

    for caption in captions(totalDuration: duration) {
        let group = captionLayer(caption, size: size)
        group.opacity = 0
        group.add(fadeAnimation(start: caption.start, end: caption.end), forKey: "captionFade")
        parent.addSublayer(group)
    }

    return parent
}

func captions(totalDuration: Double) -> [Caption] {
    [
        Caption(start: 0.0, end: 3.4, title: "Create passport photos at home", subtitle: "Private passport, visa, and ID photos"),
        Caption(start: 3.4, end: 7.4, title: "Choose an official-size template", subtitle: "Passport, visa, green card, and ID formats"),
        Caption(start: 7.4, end: 11.6, title: "Import or take a photo", subtitle: "Use guided framing for better alignment"),
        Caption(start: 11.6, end: 16.2, title: "Adjust with simple gestures", subtitle: "Move, zoom, and rotate directly on the photo"),
        Caption(start: 16.2, end: 22.8, title: "Check photo requirements", subtitle: "Face position, head size, eye line, and quality"),
        Caption(start: 22.8, end: 28.7, title: "Change allowed background colors", subtitle: "Prepare a clean document-style photo"),
        Caption(start: 28.7, end: 35.6, title: "Export digital files or print layouts", subtitle: "JPG, PDF, and 4×6 inch photo lab sheets"),
        Caption(start: 35.6, end: min(43.8, totalDuration), title: "100% on-device processing", subtitle: "No cloud upload. No ads. No subscription."),
        Caption(start: min(43.8, totalDuration - 0.2), end: totalDuration, title: "IDPhoto Pro", subtitle: "A private passport and visa photo maker")
    ]
}

func captionLayer(_ caption: Caption, size: CGSize) -> CALayer {
    let boxWidth = size.width - 72
    let boxHeight: CGFloat = 160
    let box = CALayer()
    box.frame = CGRect(x: 36, y: 92, width: boxWidth, height: boxHeight)
    box.backgroundColor = NSColor.black.withAlphaComponent(0.62).cgColor
    box.cornerRadius = 22
    box.borderWidth = 1
    box.borderColor = NSColor.white.withAlphaComponent(0.18).cgColor
    box.masksToBounds = true

    let title = CATextLayer()
    title.string = caption.title
    title.foregroundColor = NSColor.white.cgColor
    title.font = NSFont.systemFont(ofSize: 37, weight: .bold)
    title.fontSize = 37
    title.alignmentMode = .center
    title.contentsScale = 2
    title.isWrapped = true
    title.frame = CGRect(x: 22, y: 76, width: boxWidth - 44, height: 56)

    let subtitle = CATextLayer()
    subtitle.string = caption.subtitle
    subtitle.foregroundColor = NSColor.white.withAlphaComponent(0.88).cgColor
    subtitle.font = NSFont.systemFont(ofSize: 24, weight: .medium)
    subtitle.fontSize = 24
    subtitle.alignmentMode = .center
    subtitle.contentsScale = 2
    subtitle.isWrapped = true
    subtitle.frame = CGRect(x: 22, y: 28, width: boxWidth - 44, height: 42)

    box.addSublayer(title)
    box.addSublayer(subtitle)
    return box
}

func fadeAnimation(start: Double, end: Double) -> CAKeyframeAnimation {
    let fade = CAKeyframeAnimation(keyPath: "opacity")
    fade.values = [0, 1, 1, 0]
    fade.keyTimes = [0, 0.06, 0.92, 1]
    fade.beginTime = AVCoreAnimationBeginTimeAtZero + start
    fade.duration = max(end - start, 0.1)
    fade.fillMode = .both
    fade.isRemovedOnCompletion = false
    return fade
}
