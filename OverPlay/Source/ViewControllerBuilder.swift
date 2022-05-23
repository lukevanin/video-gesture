//
//  ViewControllerBuilder.swift
//  OverPlay
//
//  Created by Luke Van In on 2022/05/23.
//

import UIKit
import AVFoundation


///
/// Constructs a video player view controller given a URL to a video file.  Remote video playback is not supported.
///
struct VideoViewControllerBuilder {
    
    enum BuilderError: Error {
        case missingFileURL
    }
    
    struct Configuration {
        var locationChangeThreshold = Measurement(value: 10, unit: UnitLength.meters)
    }
    
    private var fileURL: URL?
    private var configuration = Configuration()
    
    ///
    /// Sets the URL of the local video file to play.
    ///
    func with(fileURL: URL) -> VideoViewControllerBuilder {
        VideoViewControllerBuilder(
            fileURL: fileURL,
            configuration: configuration
        )
    }
    
    ///
    /// Sets a custom configuration for the video view controller.
    ///
    func with(configuration: Configuration) -> VideoViewControllerBuilder {
        VideoViewControllerBuilder(
            fileURL: fileURL,
            configuration: configuration
        )
    }
    
    ///
    /// Returns the constructed view controller using the provided parameters. Throws an error if the view controller cannot be instantiated.
    ///
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
                distanceThreshold: configuration.locationChangeThreshold
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
