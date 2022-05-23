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
    
    private let seekIndicator: UIProgressView = {
        let view = UIProgressView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let volumeIndicator: UIProgressView = {
        let view = UIProgressView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let seekIconImageView: UIImageView = {
        let view = UIImageView(image: UIImage(systemName: "timer"))
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let volumeIconImageView: UIImageView = {
        let view = UIImageView(image: UIImage(systemName: "speaker"))
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let resetButton: UIButton = {
        let view = UIButton()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.setTitle("Reset", for: .normal)
        return view
    }()
    
    private let videoView: VideoView = {
        let view = VideoView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.videoGravity = .resizeAspectFill
        return view
    }()

    private let videoPlayer: AVPlayer
    private let videoController: VideoController

    init(videoPlayer: AVPlayer, videoController: VideoController) {
        self.videoPlayer = videoPlayer
        self.videoController = videoController
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .black
        view.tintColor = .white
        view.addSubview(videoView)
        
        videoView.player = videoPlayer
        resetButton.addTarget(self, action: #selector(onResetButtonTapped), for: .touchUpInside)
        
        let seekControlsStack: UIStackView = {
            let view = UIStackView()
            view.translatesAutoresizingMaskIntoConstraints = false
            view.axis = .horizontal
            view.alignment = .center
            view.spacing = 16
            view.addArrangedSubview(seekIconImageView)
            view.addArrangedSubview(seekIndicator)
            return view
        }()
        
        let volumeControlsStack: UIStackView = {
            let view = UIStackView()
            view.translatesAutoresizingMaskIntoConstraints = false
            view.axis = .horizontal
            view.alignment = .center
            view.spacing = 16
            view.addArrangedSubview(volumeIconImageView)
            view.addArrangedSubview(volumeIndicator)
            return view
        }()

        let controlsStack: UIStackView = {
            let view = UIStackView()
            view.translatesAutoresizingMaskIntoConstraints = false
            view.axis = .vertical
            view.spacing = 44
            view.addArrangedSubview(seekControlsStack)
            view.addArrangedSubview(volumeControlsStack)
            view.addArrangedSubview(resetButton)
            return view
        }()
        view.addSubview(controlsStack)

        NSLayoutConstraint.activate([
            videoView.leftAnchor.constraint(equalTo: view.leftAnchor),
            videoView.rightAnchor.constraint(equalTo: view.rightAnchor),
            videoView.topAnchor.constraint(equalTo: view.topAnchor),
            videoView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            volumeIconImageView.widthAnchor.constraint(equalToConstant: 32),
            volumeIconImageView.heightAnchor.constraint(equalToConstant: 32),
            
            seekIconImageView.widthAnchor.constraint(equalToConstant: 32),
            seekIconImageView.heightAnchor.constraint(equalToConstant: 32),

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
        seekIndicator.progress = Float(t)
    }

    private func updateVolumeIndicator() {
        dispatchPrecondition(condition: .onQueue(.main))
        volumeIndicator.progress = videoController.volume
    }
}

