//
//  DownloadController.swift
//  OverPlay
//
//  Created by Luke Van In on 2022/05/24.
//

import Foundation
import OSLog
import Combine


private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "download")


enum DownloadState: Equatable {
    case pending
    case downloading
    case failed(Error)
    case completed(URL)
    
    static func ==(lhs: DownloadState, rhs: DownloadState) -> Bool {
        switch (lhs, rhs) {
        case (.pending, .pending):
            return true
        case (.downloading, .downloading):
            return true
        case (.failed(let lhs), .failed(let rhs)):
            return lhs.localizedDescription == rhs.localizedDescription
        case (.completed(let lhs), .completed(let rhs)):
            return lhs == rhs
        default:
            return false
        }
    }
}


final class DownloadController: NSObject {
    
    lazy var statePublisher = stateSubject.eraseToAnyPublisher()

    private var task: URLSessionDownloadTask?

    private let sourceURL: URL
    private let cacheFileURL: URL
    private let session: URLSession
    private let stateSubject = CurrentValueSubject<DownloadState, Never>(.pending)
    
    init(sourceURL: URL, cacheFileURL: URL, session: URLSession) {
        self.sourceURL = sourceURL
        self.cacheFileURL = cacheFileURL
        self.session = session
    }
    
    func start() {
        guard stateSubject.value == .pending else {
            // Download already started
            return
        }
        let reachable = try? cacheFileURL.checkResourceIsReachable()
        if reachable == true {
            // Cache file exists. Use the cache file.
            logger.debug("Using cached resource: \(self.cacheFileURL)")
            stateSubject.send(.completed(cacheFileURL))
        }
        else {
            // Cache file does not exist yet. Download the remote resource and move it to the cache file location.
            logger.debug("Downloading resource: \(self.sourceURL)")
            self.stateSubject.send(.downloading)
            task = session.downloadTask(with: sourceURL) { [weak self] temporaryFileURL, response, error in
                DispatchQueue.main.async {
                    guard let self = self else {
                        return
                    }
                    guard let temporaryFileURL = temporaryFileURL else {
                        if let error = error {
                            logger.error("Download failed. \(error.localizedDescription)")
                            self.stateSubject.send(.failed(error))
                        }
                        else if let response = response as? HTTPURLResponse {
                            let error = URLError(URLError.Code(rawValue: response.statusCode))
                            logger.error("Download failed. \(error.localizedDescription)")
                            self.stateSubject.send(.failed(error))
                        }
                        else {
                            let error = URLError(.unknown)
                            logger.error("Download failed. \(error.localizedDescription)")
                            self.stateSubject.send(.failed(error))
                        }
                        return
                    }
                    do {
                        try FileManager.default.copyItem(at: temporaryFileURL, to: self.cacheFileURL)
                        logger.info("Download completed.")
                        logger.debug("Moving download from \(temporaryFileURL) to \(self.cacheFileURL)")
                        self.stateSubject.send(.completed(self.cacheFileURL))
                    }
                    catch {
                        logger.error("Cannot save downloaded file. \(error.localizedDescription)")
                        self.stateSubject.send(.failed(error))
                    }
                }
            }
            task?.resume()
        }
    }
    
    func cancel() {
        task?.cancel()
        task = nil
    }
}
