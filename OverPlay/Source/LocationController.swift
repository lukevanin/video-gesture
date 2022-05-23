//
//  LocationController.swift
//  OverPlay
//
//  Created by Luke Van In on 2022/05/23.
//

import Foundation
import OSLog
import Combine
import CoreLocation


private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "location")


// MARK: Interface


enum LocationProviderState {
    case initializing
    case unavailable
    case authorizing
    case active
    case inactive
}


enum LocationProviderEvent {
    case locationChanged
}


protocol LocationProvider: AnyObject {
    var statePublisher: AnyPublisher<LocationProviderState, Never> { get }
    var eventPublisher: AnyPublisher<LocationProviderEvent, Never> { get }
    func start()
    func stop()
}


// MARK: Implementation


private class ControllerState {
    unowned var context: LocationController!
    func enter() { }
    func start() { }
    func stop() { }
    func invalidateAuthorization() { }
    func updateLocation(location: CLLocation) { }
}


private final class InitialControllerState: ControllerState {
    
    override func enter() {
        logger.debug("Initialized")
    }
    
    override func start() {
        switch context.locationManager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            context.setState(ActiveControllerState())
        case .denied, .restricted:
            context.setState(UnavailableControllerState())
        case .notDetermined:
            context.setState(AuthorizationControllerState())
        @unknown default:
            fatalError("Unsupported location state")
        }
    }
}


private final class UnavailableControllerState: ControllerState {
    override func enter() {
        logger.debug("Unavailable")
        context.stateSubject.send(.unavailable)
    }
    
    override func invalidateAuthorization() {
        switch context.locationManager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            context.setState(ActiveControllerState())
        case .denied, .restricted, .notDetermined:
            break
        @unknown default:
            fatalError("Unsupported location state")
        }
    }
}


private final class AuthorizationControllerState: ControllerState {
    override func enter() {
        logger.debug("Authorizing")
        context.stateSubject.send(.authorizing)
        context.locationManager.requestWhenInUseAuthorization()
    }
    
    override func invalidateAuthorization() {
        switch context.locationManager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            context.setState(ActiveControllerState())
        case .denied, .restricted:
            context.setState(UnavailableControllerState())
        case .notDetermined:
            break
        @unknown default:
            fatalError("Unsupported location state")
        }
    }
}


private final class ActiveControllerState: ControllerState {
    
    private var enabled = false
    private var initialLocation: CLLocation?
    
    deinit {
        stop()
    }
    
    override func enter() {
        logger.debug("Active")
        start()
    }
    
    override func start() {
        guard enabled == false else {
            return
        }
        logger.debug("Location monitoring started")
        enabled = true
        context.locationManager.startUpdatingLocation()
    }
    
    override func stop() {
        guard enabled == true else {
            return
        }
        logger.debug("Location monitoring stopped")
        enabled = false
        context.locationManager.stopUpdatingLocation()
    }
    
    override func invalidateAuthorization() {
        switch context.locationManager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            break
        case .denied, .restricted:
            context.setState(UnavailableControllerState())
        case .notDetermined:
            context.setState(AuthorizationControllerState())
        @unknown default:
            fatalError("Unsupported location state")
        }
    }
    
    override func updateLocation(location: CLLocation) {
        guard let initialLocation = initialLocation else {
            // We have not received a location update yet. Store the location.
            self.initialLocation = location
            return
        }
        let distanceInMeters = location.distance(from: initialLocation)
        let distance = Measurement(value: distanceInMeters, unit: UnitLength.meters)
        logger.debug("Distance moved \(distance.formatted(.measurement(width: .wide)))")
        guard distance >= context.configuration.distanceThreshold else {
            // We have not moved far enough
            return
        }
        // We have moved further than the threshold. Store the new location and emit an event.
        logger.debug("Location changed")
        self.initialLocation = location
        context.eventSubject.send(.locationChanged)
    }
}


final class LocationController: NSObject, LocationProvider {
    
    struct Configuration {
        var distanceThreshold: Measurement<UnitLength>
    }
    
    lazy var statePublisher: AnyPublisher<LocationProviderState, Never> = stateSubject.eraseToAnyPublisher()
    lazy var eventPublisher: AnyPublisher<LocationProviderEvent, Never> = eventSubject.eraseToAnyPublisher()

    fileprivate let locationManager: CLLocationManager = CLLocationManager()
    fileprivate let stateSubject = CurrentValueSubject<LocationProviderState, Never>(.initializing)
    fileprivate let eventSubject = PassthroughSubject<LocationProviderEvent, Never>()
    fileprivate let configuration: Configuration
    
    private var currentState: ControllerState?

    init(configuration: Configuration) {
        self.configuration = configuration
        super.init()
        if CLLocationManager.locationServicesEnabled() == true {
            setState(InitialControllerState())
        }
        else {
            setState(UnavailableControllerState())
        }
        logger.debug("Monitoring distance: \(configuration.distanceThreshold.formatted(.measurement(width: .wide)))")
        locationManager.distanceFilter = configuration.distanceThreshold.converted(to: .meters).value
        locationManager.delegate = self
    }
    
    func start() {
        currentState?.start()
    }
    
    func stop() {
        currentState?.stop()
    }
    
    fileprivate func setState(_ state: ControllerState!) {
        currentState = state
        currentState?.context = self
        currentState?.enter()
    }
}

extension LocationController: CLLocationManagerDelegate {
 
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else {
                return
            }
            logger.debug("Authorization state changed: \(manager.authorizationStatus.description)")
            self.currentState?.invalidateAuthorization()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else {
                return
            }
            locations.forEach { location in
                logger.debug("Location update: \(location)")
                self.currentState?.updateLocation(location: location)
            }
        }
    }
}
