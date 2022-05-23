//
//  PlayerController.swift
//  OverPlay
//
//  Created by Luke Van In on 2022/05/23.
//

import Foundation
import AVFoundation
import Combine


///
/// Base state for all controller states. This class should not be instantiated used directly.
///
private class ControllerState {
    unowned var context: VideoController!
    func enter() { }
    func volumeGesture(volume: Float) { }
    func endVolumeGesture() { }
    func seekGesture(time: TimeInterval) { }
    func endSeekGesture() { }
    func beginShakeGesture() { }
    func endShakeGesture() { }
}

//extension ControllerState {
//
//    ///
//    /// Convenience method used to seek the video by a given time from the current playback position.
//    ///
//    func seek(delta: TimeInterval) {
//        let time = context.currentTime + delta
//        seek(time: time)
//    }
//
//    ///
//    /// Convenience method used to adjust the current volume by a given amount.
//    ///
//    func adjustVolume(delta: Float) {
//        let volume = context.volume + delta
//        setVolume(volume: volume)
//    }
//}


private final class PlaybackControllerState: ControllerState {
    
    override func enter() {
        if context.isPlaying == true {
            // Resume playing
            context.player.rate = 1
        }
        else {
            // Pause playback.
            context.player.rate = 0
        }
    }
    
    override func seekGesture(time: TimeInterval) {
        context.setState(SeekControllerState(targetTime: time))
    }
    
    override func volumeGesture(volume: Float) {
        context.player.volume = volume
    }
    
    override func beginShakeGesture() {
        context.setState(ShakeControllerState())
    }
}


private final class SeekControllerState: ControllerState {
    
    private var seeking = false
    private var lastTime: TimeInterval
    private var targetTime: TimeInterval
    
    init(targetTime: TimeInterval) {
        self.targetTime = targetTime
        self.lastTime = .greatestFiniteMagnitude
    }

    override func enter() {
        // Stop playing the video so that we can seek smoothly.
        context.player.rate = 0
    }
    
    override func endSeekGesture() {
        dispatchPrecondition(condition: .onQueue(.main))
        context.setState(PlaybackControllerState())
    }
    
    override func seekGesture(time: TimeInterval) {
        dispatchPrecondition(condition: .onQueue(.main))
        targetTime = time
        performSeek()
    }
    
    private func performSeek() {
        guard seeking == false else {
            // We are already seeking. We will try seek again when the current seek completes.
            return
        }
        if lastTime == targetTime {
            // We have already seeked to the target position.
            return
        }
        // Start seeking.
        seeking = true
        lastTime = targetTime
        context.player.seek(
            to: CMTime(seconds: lastTime, preferredTimescale: 1000),
            toleranceBefore: CMTime(seconds: 0.033, preferredTimescale: 1000), // TODO: Configure tolerance
            toleranceAfter: CMTime(seconds: 0.033, preferredTimescale: 1000), // TODO: Configure tolerance
            completionHandler: { [weak self] _ in
                dispatchPrecondition(condition: .onQueue(.main))
                guard let self = self else {
                    return
                }
                self.seeking = false
                self.performSeek()
            }
        )
    }
}


private final class ShakeControllerState: ControllerState {
    override func endShakeGesture() {
        if context.isPlaying == true {
            context.pause()
        }
        else {
            context.resume()
        }
        context.setState(PlaybackControllerState())
    }
}


final class VideoController {
    
    var volume: Float {
        player.volume
    }
    
    var currentTime: TimeInterval {
        guard let t = player.currentItem?.currentTime().seconds, t.isNormal else {
            return 0
        }
        return t
    }
    
    var duration: TimeInterval {
        guard let t = player.currentItem?.duration.seconds, t.isNormal else {
            return 0
        }
        return t
    }
    
    private(set) var isPlaying: Bool = true

    fileprivate var attitudeMeasurement: MotionProviderEvent.AttitudeMeasurement?
    fileprivate let player: AVPlayer

    private var motionEventCancellable: AnyCancellable?
    private var videoPlayerStatusObserver: NSKeyValueObservation?
    private var currentState: ControllerState?
    private var displayLink: CADisplayLink?

    private let motionController: MotionController

    init(player: AVPlayer, motionController: MotionController) {
        self.player = player
        self.motionController = motionController
//        videoPlayerStatusObserver = videoPlayer.observe(\.status) { player, change in
//            switch change.newValue {
//            case .none:
//                print("status > none")
//            case .some(.unknown):
//                print("status > unknown")
//            case .some(.failed):
//                print("status > failed > \(player.error?.localizedDescription ?? "- unknown error -")")
//            case .some(.readyToPlay):
//                print("ready to play")
//            }
//        }
        setState(PlaybackControllerState())
        startMotionController()
        startDisplayLink()
    }
    
    deinit {
//        videoPlayerStatusObserver?.invalidate()
//        videoPlayerStatusObserver = nil
        stopDisplayLink()
    }
    
    func restart() {
        player.seek(to: .zero)
    }
    
    func pause() {
        isPlaying = false
    }
    
    func resume() {
        isPlaying = true
    }
    
    func setVolume(_ volume: Float) {
    }
    
    func seek(time: TimeInterval) {
    }
    
    // MARK: Motion
    
    private func startMotionController() {
        motionController.start()
        motionEventCancellable = motionController.eventPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] event in
                guard let self = self else {
                    return
                }
                self.handleMotionEvent(event)
            }
    }
    
    private func stopMotionController() {
        motionController.stop()
    }
    
    private func handleMotionEvent(_ event: MotionProviderEvent) {
        dispatchPrecondition(condition: .onQueue(.main))
        switch event {
            
        case .error(let error):
            // TODO: Log or display error
            break
            
        case .measurement(let attitudeMeasurement):
            self.attitudeMeasurement = attitudeMeasurement
            
        case .shake(let isShaking):
            print("ViewController shaking: \(isShaking ? "yes" : "no")")
            if isShaking == true {
                currentState?.beginShakeGesture()
            }
            else {
                currentState?.endShakeGesture()
            }
        }
    }

    // MARK: Display Link
    
    private func startDisplayLink() {
        displayLink = CADisplayLink(target: self, selector: #selector(onDisplayLink))
        displayLink?.add(to: .main, forMode: .common)
    }
    
    private func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
    }
    
    @objc func onDisplayLink() {
        guard let attitudeMeasurement = attitudeMeasurement else {
            return
        }
        // Convert roll from [-1/4 ... +1/4] to [-1 ... +1]
        let seekInput = attitudeMeasurement.roll.converted(to: .revolutions).value * 4
        let volumeInput = attitudeMeasurement.pitch.converted(to: .revolutions).value - 0.25
        if abs(seekInput) > 0.5 {
            // print("input: " + input.formatted(.number.precision(.fractionLength(3))))
            
            let timeDelta = seekInput * 0.7
            let targetSeekTime = min(max(0, currentTime + timeDelta), duration)
            currentState?.seekGesture(time: targetSeekTime)
        }
        else if abs(volumeInput) > 0.1 {
            let delta = Float(volumeInput * 0.1)
            currentState?.volumeGesture(volume: volume + delta)
        }
        else {
            currentState?.endSeekGesture()
            currentState?.endVolumeGesture()
        }
    }
    
    // MARK: Control
    
    fileprivate func setState(_ state: ControllerState?) {
        dispatchPrecondition(condition: .onQueue(.main))
        currentState = state
        currentState?.context = self
        currentState?.enter()
    }
}
