//
//  PlayerController.swift
//  OverPlay
//
//  Created by Luke Van In on 2022/05/23.
//

import Foundation
import OSLog
import AVFoundation
import Combine


private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "video-controller")


///
/// Base state for all controller states. This class should not be instantiated used directly.
///
private class ControllerState {
    unowned var context: VideoController!
    func enter() { }
    func update() { }
    func volumeGesture(volume: Float) { }
    func endVolumeGesture() { }
    func seekGesture(time: TimeInterval) { }
    func endSeekGesture() { }
    func beginShakeGesture() { }
    func endShakeGesture() { }
}


private final class PlaybackControllerState: ControllerState {
    
    override func enter() {
        logger.debug("Playing")
        update()
    }
    
    override func update() {
        let rate: Float
        if context.isActive == true && context.isPlaying == true {
            // Resume playing
            rate = 1
        }
        else {
            // Pause playback.
            rate = 0
        }
        if context.player.rate != rate {
            logger.debug("Setting playback rate \(rate)")
            context.player.rate = rate
        }
    }
    
    override func seekGesture(time: TimeInterval) {
        context.setState(SeekControllerState(targetTime: time))
    }
    
    override func volumeGesture(volume: Float) {
        let clampedVolume = max(0, min(1, volume))
        context.player.volume = clampedVolume
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
        logger.debug("Seeking")
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
    
    override func enter() {
        logger.debug("Shaking")
    }
    
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
    
    private(set) var isActive: Bool = false

    fileprivate var attitudeMeasurement: MotionProviderEvent.AttitudeMeasurement?
    fileprivate let player: AVPlayer

    private var motionEventCancellable: AnyCancellable?
    private var locationEventCancellable: AnyCancellable?
    private var videoPlayerStatusObserver: NSKeyValueObservation?
    private var currentState: ControllerState?
    private var displayLink: CADisplayLink?

    private let motionController: MotionProvider
    private let locationController: LocationProvider

    init(player: AVPlayer, motionController: MotionProvider, locationController: LocationProvider) {
        self.player = player
        self.motionController = motionController
        self.locationController = locationController
        setState(PlaybackControllerState())
        startMotionController()
        startDisplayLink()
    }
    
    deinit {
        stopDisplayLink()
        locationController.stop()
    }
    
    func setActive(_ active: Bool) {
        guard active != isActive else {
            return
        }
        logger.debug("Active \(active ? "yes" : "no")")
        isActive = active
        invalidateLocationController()
    }
    
    func restart() {
        logger.debug("Restart")
        player.seek(to: .zero)
    }
    
    func pause() {
        logger.debug("Pause")
        isPlaying = false
    }
    
    func resume() {
        logger.debug("Resume")
        isPlaying = true
    }
    
    func setVolume(_ volume: Float) {
        // TODO: Set volume manually.
    }
    
    func seek(time: TimeInterval) {
        // TODO: Seek manually.
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
            
        case .error(_):
            // TODO: Log or display error
            break
            
        case .measurement(let attitudeMeasurement):
            self.attitudeMeasurement = attitudeMeasurement
            
        case .shake(let isShaking):
            if isShaking == true {
                currentState?.beginShakeGesture()
            }
            else {
                currentState?.endShakeGesture()
            }
        }
    }
    
    // MARK: Location
    
    private func invalidateLocationController() {
        if isActive == true {
            locationController.start()
            if locationEventCancellable == nil {
                locationEventCancellable = locationController.eventPublisher
                    .receive(on: RunLoop.main)
                    .sink { [weak self] event in
                        guard let self = self else {
                            return
                        }
                        self.handleLocationEvent(event: event)
                    }
            }
        }
        else {
            locationEventCancellable?.cancel()
            locationController.stop()
        }
    }
    
    private func handleLocationEvent(event: LocationProviderEvent) {
        switch event {
        case .locationChanged:
            restart()
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
            let timeDelta = seekInput * 0.7
            let targetSeekTime = min(max(0, currentTime + timeDelta), duration)
            currentState?.seekGesture(time: targetSeekTime)
        }
        else if abs(volumeInput) > 0.13 {
            let delta = Float(volumeInput * 0.1)
            currentState?.volumeGesture(volume: volume + delta)
        }
        else {
            currentState?.endSeekGesture()
            currentState?.endVolumeGesture()
        }
        currentState?.update()
    }
    
    // MARK: State
    
    fileprivate func setState(_ state: ControllerState?) {
        dispatchPrecondition(condition: .onQueue(.main))
        currentState = state
        currentState?.context = self
        currentState?.enter()
    }
}
