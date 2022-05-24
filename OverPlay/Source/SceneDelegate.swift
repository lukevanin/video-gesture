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

    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let scene = (scene as? UIWindowScene) else {
            logger.critical("Cannot initialize app. Scene unavailable.")
            return
        }
        let viewController: UIViewController
        let videoURL = URL(string: "http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/WeAreGoingOnBullrun.mp4")!
        do {
            viewController = try VideoViewControllerBuilder().with(url: videoURL).build()
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

