//
//  ViewController.swift
//  OverPlay
//
//  Created by Luke Van In on 2022/05/20.
//

import Combine
import OSLog
import UIKit
import AVFoundation


private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "ui")


final class ViewController: UIViewController {
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        [.portrait]
    }
    
    private var displayLink: CADisplayLink?
    private var motionCancellable: AnyCancellable?
    private var playerStatusObserver: NSKeyValueObservation?
    private var playerTimeControlStatusObserver: NSKeyValueObservation?

    private let loadingActivityIndicator: UIActivityIndicatorView = {
        let view = UIActivityIndicatorView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.style = .large
        view.tintColor = .white
        view.hidesWhenStopped = true
        view.stopAnimating()
        return view
    }()

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
    
    private let errorIconImageView: UIImageView = {
        let view = UIImageView(image: UIImage(systemName: "exclamationmark.triangle.fill"))
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
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
        let view = VideoView(frame: .zero)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let videoPlayer: AVPlayer
    private let videoController: VideoController
    private let motionController: MotionController

    init(videoPlayer: AVPlayer, videoController: VideoController, motionController: MotionController) {
        self.videoPlayer = videoPlayer
        self.videoController = videoController
        self.motionController = motionController
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
                
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
        
        view.backgroundColor = .black
        view.tintColor = .white
        view.addSubview(videoView)
        view.addSubview(errorIconImageView)
        view.addSubview(loadingActivityIndicator)
        view.addSubview(controlsStack)

        NSLayoutConstraint.activate([
            videoView.leftAnchor.constraint(equalTo: view.leftAnchor),
            videoView.rightAnchor.constraint(equalTo: view.rightAnchor),
            videoView.topAnchor.constraint(equalTo: view.topAnchor),
            videoView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            errorIconImageView.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor),
            errorIconImageView.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor),
            errorIconImageView.widthAnchor.constraint(equalToConstant: 64),
            errorIconImageView.heightAnchor.constraint(equalToConstant: 64),
            
            loadingActivityIndicator.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor),
            loadingActivityIndicator.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor),

            volumeIconImageView.widthAnchor.constraint(equalToConstant: 32),
            volumeIconImageView.heightAnchor.constraint(equalToConstant: 32),
            
            seekIconImageView.widthAnchor.constraint(equalToConstant: 32),
            seekIconImageView.heightAnchor.constraint(equalToConstant: 32),

            controlsStack.leftAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leftAnchor, constant: +32),
            controlsStack.rightAnchor.constraint(equalTo: view.safeAreaLayoutGuide.rightAnchor, constant: -32),
            controlsStack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -32)
        ])
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
        playerStatusObserver = videoPlayer.observe(\.status) { [weak self] player, change in
            dispatchPrecondition(condition: .onQueue(.main))
            guard let self = self else {
                return
            }
            self.invalidateActivityIndicator()
        }
        playerTimeControlStatusObserver = videoPlayer.observe(\.timeControlStatus) { [weak self] player, change in
            dispatchPrecondition(condition: .onQueue(.main))
            guard let self = self else {
                return
            }
            self.invalidateActivityIndicator()
        }
        videoController.setActive(true)
        motionCancellable = motionController.eventPublisher
            .receive(on: RunLoop.main)
            // .throttle(for: 0.016, scheduler: RunLoop.main, latest: true)
            .sink { [weak self] event in
                guard let self = self else {
                    return
                }
                switch event {
                case .measurement(let attitude):
                    self.videoView.orientation = -attitude.roll.converted(to: .radians).value
                default:
                    break
                }
            }
    }
    
    private func destroyVideoPlayer() {
        videoController.setActive(false)
        motionCancellable?.cancel()
        motionCancellable = nil
        displayLink?.invalidate()
        displayLink = nil
        playerStatusObserver?.invalidate()
        playerStatusObserver = nil
    }
    
    private func invalidateActivityIndicator() {
        logger.debug("Player state: status=\(self.videoPlayer.status.description), time control status=\(self.videoPlayer.timeControlStatus.description)")
        switch videoPlayer.status {
        case .unknown:
            setErrorVisible(false)
            setActivityIndicator(true)
        case .failed:
            setErrorVisible(true)
            setActivityIndicator(false)
        case .readyToPlay:
            switch videoPlayer.timeControlStatus {
            case .waitingToPlayAtSpecifiedRate:
                setErrorVisible(false)
                setActivityIndicator(true)
            case .playing, .paused:
                setErrorVisible(false)
                setActivityIndicator(false)
            @unknown default:
                fatalError("Unknown player time control status")
            }
        @unknown default:
            fatalError("Unknown player status")
        }
    }
    
    private func setErrorVisible(_ visible: Bool) {
        if errorIconImageView.isHidden == visible {
            errorIconImageView.isHidden = !visible
        }
    }
    
    private func setActivityIndicator(_ visible: Bool) {
        switch (loadingActivityIndicator.isAnimating, visible) {
        case (false, true):
            loadingActivityIndicator.startAnimating()
        case (true, false):
            loadingActivityIndicator.stopAnimating()
        default:
            break
        }
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

