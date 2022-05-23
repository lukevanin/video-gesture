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
        // Use this method to optionally configure and attach the UIWindow `window` to the provided UIWindowScene `scene`.
        // If using a storyboard, the `window` property will automatically be initialized and attached to the scene.
        // This delegate does not imply the connecting scene or session are new (see `application:configurationForConnectingSceneSession` instead).
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
        // Called as the scene is being released by the system.
        // This occurs shortly after the scene enters the background, or when its session is discarded.
        // Release any resources associated with this scene that can be re-created the next time the scene connects.
        // The scene may re-connect later, as its session was not necessarily discarded (see `application:didDiscardSceneSessions` instead).
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Called when the scene has moved from an inactive state to an active state.
        // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
        // This may occur due to temporary interruptions (ex. an incoming phone call).
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the scene transitions from the background to the foreground.
        // Use this method to undo the changes made on entering the background.
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
        // Use this method to save data, release shared resources, and store enough scene-specific state information
        // to restore the scene back to its current state.
    }


}

