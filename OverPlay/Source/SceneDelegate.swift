//
//  SceneDelegate.swift
//  OverPlay
//
//  Created by Luke Van In on 2022/05/20.
//

import UIKit
import OSLog


private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "scene")


class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    let videoFilename = "WeAreGoingOnBullrun-optimized" // TODO: Load video file name from Info.plist
    var window: UIWindow?


    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let scene = (scene as? UIWindowScene) else {
            logger.critical("Cannot initialize app. Scene unavailable.")
            return
        }
        guard let videoFileURL = Bundle.main.url(forResource: videoFilename, withExtension: "mp4") else {
            logger.critical("Cannot initialize app. Video file unavailable: \(self.videoFilename)")
            return
        }
        let viewController: UIViewController
        do {
            viewController = try VideoViewControllerBuilder().with(fileURL: videoFileURL).build()
        }
        catch {
            logger.critical("Cannot initialize view controller. \(error.localizedDescription)")
            return
        }
        window = UIWindow(windowScene: scene)
        window?.rootViewController = viewController
        window?.makeKeyAndVisible()
        logger.debug("App initialized")
    }

    func sceneDidDisconnect(_ scene: UIScene) {
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
    }

    func sceneWillResignActive(_ scene: UIScene) {
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
    }


}

