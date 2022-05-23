//
//  ViewControllerBuilder.swift
//  OverPlay
//
//  Created by Luke Van In on 2022/05/23.
//

import UIKit
import AVFoundation


struct VideoViewControllerBuilder {
    
    enum BuilderError: Error {
        case missingFileURL
    }
    
    private var fileURL: URL?
    
    func with(fileURL: URL) -> VideoViewControllerBuilder {
        VideoViewControllerBuilder(fileURL: fileURL)
    }
    
    func build() throws -> UIViewController {
        guard let fileURL = fileURL else {
            throw BuilderError.missingFileURL
        }

        let asset = AVAsset(url: fileURL)
        let playerItem = AVPlayerItem(
            asset: asset,
            automaticallyLoadedAssetKeys: [
                "duration"
            ]
        )
        let videoPlayer = AVPlayer(playerItem: playerItem)
        let motionController = MotionController()
        let locationController = LocationController(
            configuration: LocationController.Configuration(
                distanceThreshold: Measurement(value: 10, unit: .meters)
            )
        )
        let videoController = VideoController(
            player: videoPlayer,
            motionController: motionController,
            locationController: locationController
        )
        let viewController = ViewController(
            videoPlayer: videoPlayer,
            videoController: videoController
        )
        return viewController
    }
}
