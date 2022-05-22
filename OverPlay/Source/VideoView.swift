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
    
    var videoGravity: AVLayerVideoGravity {
        get {
            playerLayer.videoGravity
        }
        set {
            playerLayer.videoGravity = newValue
        }
    }
    
//    var orientation: CGFloat = 0

//    private var videoAspect: CGFloat = 1280 / 720 // TODO: Get pixel buffer size at runtime
//    private var displayLink: CADisplayLink?
    
    private var playerLayer: AVPlayerLayer {
        layer as! AVPlayerLayer
    }
    
//    override init(frame: CGRect) {
//        super.init(frame: frame)
//        displayLink = CADisplayLink(target: self, selector: #selector(onDisplayLink))
//        displayLink?.add(to: .main, forMode: .common)
//    }
    
//    deinit {
//        displayLink?.invalidate()
//    }

//    required init?(coder: NSCoder) {
//        fatalError("init(coder:) has not been implemented")
//    }
    
//    @objc func onDisplayLink() {
//        let bounds = bounds.size
//        let videoAspect = videoSize.width / videoSize.height
//        let videoHeight = sqrt(bounds.width * bounds.width + bounds.height * bounds.height) * 2
//        let videoWidth = videoHeight * videoAspect
//    }

    override class var layerClass: AnyClass {
        return AVPlayerLayer.self
    }
}
