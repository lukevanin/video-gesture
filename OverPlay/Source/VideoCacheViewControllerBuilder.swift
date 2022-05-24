//
//  VideoCacheViewControllerBuilder.swift
//  OverPlay
//
//  Created by Luke Van In on 2022/05/24.
//

import UIKit

struct VideoCacheViewControllerBuilder {
    enum BuilderError: Error {
        case missingVideoURL
        case missingCacheFileURL
    }

    private var videoURL: URL?
    private var cacheFileURL: URL?

    ///
    /// Sets the URL of the remote video file to play.
    ///
    func with(videoURL: URL) -> VideoCacheViewControllerBuilder {
        VideoCacheViewControllerBuilder(videoURL: videoURL, cacheFileURL: cacheFileURL)
    }

    ///
    /// Sets the URL of the local video file to play.
    ///
    func with(cacheFileURL: URL) -> VideoCacheViewControllerBuilder {
        VideoCacheViewControllerBuilder(videoURL: videoURL, cacheFileURL: cacheFileURL)
    }

    func build() throws -> UIViewController {
        guard let videoURL = videoURL else {
            throw BuilderError.missingVideoURL
        }
        guard let cacheFileURL = cacheFileURL else {
            throw BuilderError.missingCacheFileURL
        }
        let controller = DownloadController(sourceURL: videoURL, cacheFileURL: cacheFileURL, session: .shared)
        let viewController = VideoDownloadViewController(downloadController: controller)
        return viewController
    }
}
