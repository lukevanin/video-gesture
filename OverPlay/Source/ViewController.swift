//
//  ViewController.swift
//  OverPlay
//
//  Created by Luke Van In on 2022/05/20.
//

import UIKit
import AVFoundation


final class VideoView: UIView {
    
    var player: AVPlayer? {
        get {
            return playerLayer.player
        }
        set {
            playerLayer.player = newValue
        }
    }
    
    var videoGravity: AVLayerVideoGravity {
        get {
            playerLayer.videoGravity
        }
        set {
            playerLayer.videoGravity = newValue
        }
    }
    
    private var playerLayer: AVPlayerLayer {
        layer as! AVPlayerLayer
    }
    
    override class var layerClass: AnyClass {
        return AVPlayerLayer.self
    }
}


final class ViewController: UIViewController {
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    private let rateSlider: UISlider
    private let volumeSlider: UISlider
    private let resetButton: UIButton
    
    private var videoPlayer: AVPlayer?
    private var videoPlayerStatusObserver: NSKeyValueObservation?
    
    private let videoFileURL: URL
    private let videoView: VideoView
    
    init(videoFileURL: URL) {
        self.rateSlider = UISlider()
        self.volumeSlider = UISlider()
        self.resetButton = UIButton()
        self.videoView = VideoView()
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
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        destroyVideoPlayer()
    }
    
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
        let rawValue = rateSlider.value
        let absoluteRate = abs(rawValue) + 1
        let direction = rawValue >= 0 ? Float(+1) : Float(-1)
        let relativeRate = absoluteRate * direction
        print("rate: \(relativeRate)")
        videoPlayer.rate = relativeRate
    }
    
    private func invalidatePlayerVolume() {
        guard let videoPlayer = videoPlayer else {
            return
        }
        print("volume: \(volumeSlider.value)")
        videoPlayer.volume = volumeSlider.value
    }
}

