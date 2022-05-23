//
//  Extensions.swift
//  OverPlay
//
//  Created by Luke Van In on 2022/05/23.
//

import Foundation
import CoreLocation


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
