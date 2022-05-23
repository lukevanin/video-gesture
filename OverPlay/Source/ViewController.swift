//
//  ViewController.swift
//  OverPlay
//
//  Created by Luke Van In on 2022/05/20.
//

import Combine
import UIKit
import AVFoundation


//private class ControllerState {
//    unowned var context: ViewController!
//    func enter() { }
//}


//private class SeekState: ControllerState {
//    override func enter() {
//        <#code#>
//    }
//}


final class ViewController: UIViewController {
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        [.portrait]
    }
    
    private let rateSlider: UISlider
    private let seekSlider: UISlider
    private let volumeSlider: UISlider
    private let resetButton: UIButton
    
    private var videoPlayer: AVPlayer?
    private var videoPlayerStatusObserver: NSKeyValueObservation?
    
    private var motionEventCancellable: AnyCancellable?
    private var attitudeMeasurement: MotionProviderEvent.AttitudeMeasurement?
    
    private var startSeekTime: TimeInterval?
    private var targetSeekTime: TimeInterval?
    private var lastSeekTime: TimeInterval?
    
    private var seeking: Bool = false
    private var paused: Bool = false
    
    private var displayLink: CADisplayLink?
    
    private let videoFileURL: URL
    private let videoView: VideoView
    private let motionController: MotionController
    
    init(videoFileURL: URL, motionController: MotionController) {
        self.rateSlider = UISlider()
        self.volumeSlider = UISlider()
        self.seekSlider = UISlider()
        self.resetButton = UIButton()
        self.videoView = VideoView()
        self.motionController = motionController
        self.videoFileURL = videoFileURL
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .cyan
        view.addSubview(videoView)
        
        videoView.translatesAutoresizingMaskIntoConstraints = false
        videoView.videoGravity = .resizeAspectFill
        
        rateSlider.translatesAutoresizingMaskIntoConstraints = false
        rateSlider.minimumValue = -1
        rateSlider.maximumValue = +1
        rateSlider.value = 0
        rateSlider.isContinuous = true
        rateSlider.addTarget(self, action: #selector(onRateSliderChanged), for: .valueChanged)
        
        seekSlider.translatesAutoresizingMaskIntoConstraints = false
        seekSlider.isUserInteractionEnabled = false
        seekSlider.minimumValue = 0
        seekSlider.maximumValue = 1
        seekSlider.value = 0
        seekSlider.isContinuous = true

        volumeSlider.translatesAutoresizingMaskIntoConstraints = false
        volumeSlider.minimumValue = 0
        volumeSlider.maximumValue = 1
        volumeSlider.value = 0.5
        volumeSlider.isContinuous = true
        volumeSlider.addTarget(self, action: #selector(onVolumeSliderChanged), for: .valueChanged)
        
        resetButton.translatesAutoresizingMaskIntoConstraints = false
        resetButton.setTitle("Reset", for: .normal)
        resetButton.addTarget(self, action: #selector(onResetButtonTapped), for: .touchUpInside)
        
        let controlsStack = UIStackView()
        controlsStack.translatesAutoresizingMaskIntoConstraints = false
        controlsStack.axis = .vertical
        controlsStack.spacing = 44
        controlsStack.addArrangedSubview(seekSlider)
        controlsStack.addArrangedSubview(volumeSlider)
        controlsStack.addArrangedSubview(rateSlider)
        controlsStack.addArrangedSubview(resetButton)
        view.addSubview(controlsStack)

        NSLayoutConstraint.activate([
            videoView.leftAnchor.constraint(equalTo: view.leftAnchor),
            videoView.rightAnchor.constraint(equalTo: view.rightAnchor),
            videoView.topAnchor.constraint(equalTo: view.topAnchor),
            videoView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            controlsStack.leftAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leftAnchor, constant: +32),
            controlsStack.rightAnchor.constraint(equalTo: view.safeAreaLayoutGuide.rightAnchor, constant: -32),
            controlsStack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -32)
        ])
    }

    @objc func onRateSliderChanged(sender: UISlider) {
        invalidatePlayerRate()
    }

    @objc func onVolumeSliderChanged(sender: UISlider) {
        invalidatePlayerVolume()
    }
    
    @objc func onResetButtonTapped(sender: UIButton) {
        resetVideo()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        setupVideoPlayer()
        invalidatePlayerRate()
        invalidatePlayerVolume()
        startMotion()
        startDisplayLink()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopDisplayLink()
        stopMotion()
        destroyVideoPlayer()
    }
    
    // MARK: Video Player
    
    private func setupVideoPlayer() {
        guard videoPlayer == nil else {
            // Video player already exists.
            return
        }
        let asset = AVAsset(url: videoFileURL)
        let playerItem = AVPlayerItem(
            asset: asset,
            automaticallyLoadedAssetKeys: [
                "duration"
            ]
        )
        let videoPlayer = AVPlayer(playerItem: playerItem)
        videoPlayerStatusObserver = videoPlayer.observe(\.status) { player, change in
            switch change.newValue {
            case .none:
                print("status > none")
            case .some(.unknown):
                print("status > unknown")
            case .some(.failed):
                print("status > failed > \(player.error?.localizedDescription ?? "- unknown error -")")
            case .some(.readyToPlay):
                print("ready to play")
            }
        }
        self.videoPlayer = videoPlayer
        self.videoView.player = videoPlayer
    }
    
    private func destroyVideoPlayer() {
        videoPlayerStatusObserver?.invalidate()
        videoPlayerStatusObserver = nil
        videoPlayer = nil
        videoView.player = nil
    }
    
    private func resetVideo() {
        guard let videoPlayer = videoPlayer else {
            return
        }
        videoPlayer.seek(to: .zero)
    }

    private func invalidatePlayerRate() {
        guard let videoPlayer = videoPlayer else {
            return
        }
        let rate: Float
        if seeking == true || paused == true {
            rate = 0
        }
        else {
            let rawValue = round(rateSlider.value * 10) / 10
            let absoluteRate = 1 + abs(rawValue * 5)
            let direction = rawValue >= 0 ? Float(+1) : Float(-1)
            rate = absoluteRate * direction
        }
        guard rate != videoPlayer.rate else {
            return
        }
        print("rate: " + rate.formatted(.number.precision(.fractionLength(3))))
        videoPlayer.rate = rate
    }
    
    private func invalidatePlayerVolume() {
        guard let videoPlayer = videoPlayer else {
            return
        }
        guard videoPlayer.volume != volumeSlider.value else {
            return
        }
        print("volume: \(volumeSlider.value)")
        videoPlayer.volume = volumeSlider.value
    }
    
    
    // MARK: Motion
    
    private func startMotion() {
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
    
    private func stopMotion() {
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
            if isShaking == false {
                paused.toggle()
                invalidatePlayerRate()
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
        updateMeasurements()
        updateSeekIndicator()
    }
    
    private func updateMeasurements() {
        guard let attitudeMeasurement = attitudeMeasurement else {
            return
        }
        guard let videoPlayer = videoPlayer else {
            return
        }
        guard let playerItem = videoPlayer.currentItem else {
            return
        }
        let duration = playerItem.duration.seconds
        guard duration.isNormal else {
            return
        }
        // Convert roll from [-1/4 ... +1/4] to [-1 ... +1]
        let input = attitudeMeasurement.roll.converted(to: .revolutions).value * 4
        if abs(input) > 0.5 {
            // print("input: " + input.formatted(.number.precision(.fractionLength(3))))
            
            let currentTime = videoPlayer.currentTime().seconds
            startSeekTime = currentTime
            let timeDelta = input * 0.7
            targetSeekTime = min(max(0, startSeekTime! + timeDelta), duration)
            seekVideo()
        }
        else {
            targetSeekTime = nil
            lastSeekTime = nil
            startSeekTime = nil
            
            let t = attitudeMeasurement.pitch.converted(to: .revolutions).value - 0.25
            // print("pitch: " + t.formatted(.number.precision(.fractionLength(3))))
            guard abs(t) > 0.1 else {
                return
            }
            volumeSlider.value += Float(t * 0.1)
            invalidatePlayerVolume()
        }
    }

    private func updateSeekIndicator() {
        guard let videoPlayer = videoPlayer else {
            return
        }
        guard let currentItem = videoPlayer.currentItem else {
            return
        }
        let currentTime = videoPlayer.currentTime().seconds
        let duration = currentItem.duration.seconds
        let t = currentTime / duration
        seekSlider.value = Float(t)
    }
    
    // MARK: Control
    
    private func seekVideo() {
        guard let videoPlayer = videoPlayer else {
            return
        }
        guard seeking == false else {
            return
        }
        guard let targetSeekTime = targetSeekTime else {
            return
        }
        if let seekTime = lastSeekTime {
            if seekTime == targetSeekTime {
                return
            }
        }
        seeking = true
        lastSeekTime = targetSeekTime
        invalidatePlayerRate()
        videoPlayer.seek(
            to: CMTime(seconds: lastSeekTime!, preferredTimescale: 1000),
            toleranceBefore: CMTime(seconds: 0.033, preferredTimescale: 1000),
            toleranceAfter: CMTime(seconds: 0.033, preferredTimescale: 1000),
            completionHandler: { [weak self] _ in
                dispatchPrecondition(condition: .onQueue(.main))
                guard let self = self else {
                    return
                }
                self.seeking = false
                self.invalidatePlayerRate()
                self.seekVideo()
            }
        )
    }
    
}

