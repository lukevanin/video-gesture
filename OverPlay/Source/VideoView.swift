//
//  VideoView.swift
//  OverPlay
//
//  Created by Luke Van In on 2022/05/21.
//

import UIKit
import AVFoundation
import CoreVideo


final class VideoView: UIView {
    
    var player: AVPlayer? {
        get {
            return playerLayer.player
        }
        set {
            playerLayer.player = newValue
        }
    }
    
//    var videoGravity: AVLayerVideoGravity {
//        get {
//            playerLayer.videoGravity
//        }
//        set {
//            playerLayer.videoGravity = newValue
//        }
//    }
    
    var orientation: CGFloat = 0 {
        didSet {
            invalidateOrientation()
        }
    }

    private var videoAspect: CGFloat = 1280 / 720 // TODO: Get pixel buffer size at runtime
    private var videoFrame: CGRect = .zero
    
    private let transformLayer: CATransformLayer = CATransformLayer()
    private let playerLayer: AVPlayerLayer = AVPlayerLayer()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.backgroundColor = UIColor.cyan.cgColor
        playerLayer.backgroundColor = UIColor.magenta.cgColor
        playerLayer.videoGravity = .resize
        transformLayer.addSublayer(playerLayer)
        layer.addSublayer(transformLayer)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        let bounds = self.frame.size
        let videoHeight = sqrt(bounds.width * bounds.width + bounds.height * bounds.height)
        let videoWidth = videoHeight * videoAspect
        let videoSize = CGSize(width: videoWidth, height: videoHeight)
        videoFrame = CGRect(origin: .zero, size: videoSize).integral
        if playerLayer.frame != videoFrame {
            print(bounds.width, bounds.height, videoWidth, videoHeight)
            playerLayer.frame = videoFrame
        }
        invalidateOrientation()
    }
    
    private func invalidateOrientation() {
        let transform = CGAffineTransform
            .identity
            .translatedBy(x: bounds.width * 0.5, y: bounds.height * 0.5)
            .rotated(by: orientation)
            .translatedBy(x: -videoFrame.width * 0.5, y: -videoFrame.height * 0.5)
        transformLayer.setAffineTransform(transform)
    }
}
