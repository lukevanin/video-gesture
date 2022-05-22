//
//  MotionController.swift
//  OverPlay
//
//  Created by Luke Van In on 2022/05/21.
//

import Foundation
import OSLog
import CoreMotion
import Combine


private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "motion")


enum MotionProviderState {
    case unavailable
    case running
    case stopped
}

enum MotionProviderEvent {
    
    struct AttitudeMeasurement {
        let roll: Measurement<UnitAngle>
        let pitch: Measurement<UnitAngle>
    }

    case error(Error)
    case measurement(AttitudeMeasurement)
}


protocol MotionProvider {
    var statePublisher: AnyPublisher<MotionProviderState, Never> { get }
    var eventPublisher: AnyPublisher<MotionProviderEvent, Never> { get }
    func start()
    func stop()
}


private class MotionState {
    unowned var context: MotionController!
    
    func enter() { }
    
    func start() { }
    
    func stop() { }
}


final private class InitialMotionState: MotionState {
    
    override func enter() {
        logger.debug("Motion controller initialized")
    }
 
    override func start() {
        guard context.motionManager.isDeviceMotionAvailable else {
            // Device motion is not available.
            context.setState(ErrorMotionState())
            return
        }
        context.setState(RunningMotionState())
    }
}


final private class ErrorMotionState: MotionState {
    override func enter() {
        logger.error("Device motion not available")
        context.stateSubject.send(.unavailable)
    }
}


final private class RunningMotionState: MotionState {
    private let queue: OperationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        queue.underlyingQueue = .global(qos: .userInteractive)
        return queue
    }()
    
    var referenceAttitude: CMAttitude!
    
    override func enter() {
        logger.debug("Motion controller started")
        context.stateSubject.send(.running)
        context.motionManager.deviceMotionUpdateInterval = 1.0 / 30.0
        context.motionManager.startDeviceMotionUpdates(
            using: .xArbitraryCorrectedZVertical,
            to: queue,
            withHandler: { [weak self] motion, error in
                guard let self = self else {
                    return
                }
                guard let motion = motion else {
                    logger.error("Device motion error \(error!.localizedDescription)")
                    self.context.eventSubject.send(.error(error!))
                    return
                }
                
                let q = motion.attitude.quaternion
                // See: https://en.wikipedia.org/wiki/Conversion_between_quaternions_and_Euler_angles#Source_code_2
                let roll = atan2(2 * (q.y * q.w - q.x * q.z), 1 - 2 * q.y * q.y - 2 * q.z * q.z)
                let pitch = atan2(2 * (q.x * q.w + q.y * q.z), 1 - 2 * q.x * q.x - 2 * q.z * q.z)
                let measurements = MotionProviderEvent.AttitudeMeasurement(
                    roll: Measurement(value: roll, unit: UnitAngle.radians),
                    pitch: Measurement(value: pitch, unit: UnitAngle.radians)
                )
                // let formattedRoll = measurements.roll.value.formatted(.number.precision(.fractionLength(3)))
                // let formattedPitch = measurements.pitch.value.formatted(.number.precision(.fractionLength(3)))
                // logger.info("r: \(formattedRoll), p: \(formattedPitch)")
                self.context.eventSubject.send(.measurement(measurements))
            }
        )
    }
    
    override func stop() {
        context.setState(StoppedMotionState())
    }
}


final private class StoppedMotionState: MotionState {
    
    override func enter() {
        logger.debug("Motion controller stopped")
        context.stateSubject.send(.stopped)
        context.motionManager.stopDeviceMotionUpdates()
    }
    
    override func start() {
        context.setState(RunningMotionState())
    }
}


final class MotionController: MotionProvider {

    let statePublisher: AnyPublisher<MotionProviderState, Never>
    let eventPublisher: AnyPublisher<MotionProviderEvent, Never>
    
    fileprivate let motionManager = CMMotionManager()
    fileprivate let stateSubject = CurrentValueSubject<MotionProviderState, Never>(.stopped)
    fileprivate let eventSubject = PassthroughSubject<MotionProviderEvent, Never>()

    private var currentState: MotionState?
    
    init() {
        self.statePublisher = stateSubject.eraseToAnyPublisher()
        self.eventPublisher = eventSubject.eraseToAnyPublisher()
        setState(InitialMotionState())
    }
    
    func start() {
        currentState?.start()
    }
    
    func stop() {
        currentState?.stop()
    }
    
    fileprivate func setState(_ state: MotionState?) {
        currentState = state
        currentState?.context = self
        currentState?.enter()
    }
}
