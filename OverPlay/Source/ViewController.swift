//
//  ViewController.swift
//  OverPlay
//
//  Created by Luke Van In on 2022/05/20.
//

import Combine
import UIKit
import AVFoundation


final class ViewController: UIViewController {
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        [.portrait]
    }
    
    private var videoPlayer: AVPlayer?
    private var videoPeriodicObserver: Any?
    private var videoController: VideoController?
    
    private let seekSlider: UISlider
    private let volumeSlider: UISlider
    private let resetButton: UIButton
    
    private let videoFileURL: URL
    private let videoView: VideoView
    
    init(videoFileURL: URL, motionController: MotionController) {
        self.volumeSlider = UISlider()
        self.seekSlider = UISlider()
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
        
        seekSlider.translatesAutoresizingMaskIntoConstraints = false
        seekSlider.isUserInteractionEnabled = false
        seekSlider.isEnabled = false
        seekSlider.minimumValue = 0
        seekSlider.maximumValue = 1
        seekSlider.value = 0
        seekSlider.isContinuous = true

        volumeSlider.translatesAutoresizingMaskIntoConstraints = false
        volumeSlider.isUserInteractionEnabled = false
        volumeSlider.isEnabled = false
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

    @objc func onVolumeSliderChanged(sender: UISlider) {
        videoController?.setVolume(sender.value)
    }
    
    @objc func onResetButtonTapped(sender: UIButton) {
        videoController?.restart()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        setupVideoPlayer()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        destroyVideoPlayer()
    }
    
    // MARK: Video Player

    private func setupVideoPlayer() {
        let asset = AVAsset(url: videoFileURL)
        let playerItem = AVPlayerItem(
            asset: asset,
            automaticallyLoadedAssetKeys: [
                "duration"
            ]
        )
        let videoPlayer = AVPlayer(playerItem: playerItem)
        let videoPeriodicObserver = videoPlayer.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.01, preferredTimescale: 1000),
            queue: .main,
            using: { [weak self] time in
                guard let self = self else {
                    return
                }
                self.updateSeekIndicator()
                self.updateVolumeIndicator()
            }
        )
        
        let motionController = MotionController()
        let videoController = VideoController(player: videoPlayer, motionController: motionController)

        self.videoPeriodicObserver = videoPeriodicObserver
        self.videoController = videoController
        self.videoPlayer = videoPlayer
        self.videoView.player = videoPlayer
    }
    
    private func destroyVideoPlayer() {
        videoController = nil
        videoPlayer = nil
        videoView.player = nil
    }
    
    private func updateSeekIndicator() {
        guard let videoController = videoController else {
            return
        }
        let t: TimeInterval
        if videoController.duration > 0 {
            t = videoController.currentTime / videoController.duration
        }
        else {
            t = 0
        }
        seekSlider.value = Float(t)
    }

    private func updateVolumeIndicator() {
        guard let videoController = videoController else {
            return
        }
        volumeSlider.value = videoController.volume
    }
}

