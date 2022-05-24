//
//  Extensions.swift
//  OverPlay
//
//  Created by Luke Van In on 2022/05/23.
//

import Foundation
import CoreLocation
import AVFoundation


extension AVPlayer.Status: CustomStringConvertible {
    public var description: String {
        switch self {
        case .readyToPlay:
            return "ready to play"
        case .unknown:
            return "unknown"
        case .failed:
            return "failed"
        @unknown default:
            return "unknown"
        }
    }
}


extension AVPlayer.TimeControlStatus: CustomStringConvertible {
    public var description: String {
        switch self {
        case .paused:
            return "paused"
        case .playing:
            return "playing"
        case .waitingToPlayAtSpecifiedRate:
            return "waiting to play at specified rate"
        @unknown default:
            return "unknown"
        }
    }
}


extension CLAuthorizationStatus: CustomStringConvertible {
    public var description: String {
        switch self {
        case .notDetermined:
            return "not determined"
        case .restricted:
            return "restricted"
        case .denied:
            return "denied"
        case .authorizedWhenInUse:
            return "authorized when in use"
        case .authorizedAlways:
            return "authorized always"
        @unknown default:
            return "unknown"
        }
    }
}
