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
    
    private var displayLink: CADisplayLink?
    
    private let seekSlider: UISlider
    private let volumeSlider: UISlider
    private let resetButton: UIButton
    private let videoView: VideoView

    private let videoPlayer: AVPlayer
    private let videoController: VideoController

    init(videoPlayer: AVPlayer, videoController: VideoController) {
        self.volumeSlider = UISlider()
        self.seekSlider = UISlider()
        self.resetButton = UIButton()
        self.videoView = VideoView()
        self.videoPlayer = videoPlayer
        self.videoController = videoController
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
        videoView.player = videoPlayer
        
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
        videoController.setVolume(sender.value)
    }
    
    @objc func onResetButtonTapped(sender: UIButton) {
        videoController.restart()
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
        displayLink = CADisplayLink(target: self, selector: #selector(onDisplayLink))
        displayLink?.add(to: .main, forMode: .common)
        videoController.setActive(true)
    }
    
    private func destroyVideoPlayer() {
        displayLink?.invalidate()
        displayLink = nil
        videoController.setActive(false)
        videoView.player = nil
    }
    
    @objc func onDisplayLink() {
        updateSeekIndicator()
        updateVolumeIndicator()
    }
    
    private func updateSeekIndicator() {
        dispatchPrecondition(condition: .onQueue(.main))
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
        dispatchPrecondition(condition: .onQueue(.main))
        volumeSlider.value = videoController.volume
    }
}

