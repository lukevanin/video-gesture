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


// MARK: Interface


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
    case shake(Bool)
}


protocol MotionProvider: AnyObject {
    var statePublisher: AnyPublisher<MotionProviderState, Never> { get }
    var eventPublisher: AnyPublisher<MotionProviderEvent, Never> { get }
    func start()
    func stop()
}


// MARK: Implementation


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
    
    var accelerationSamples = [Double]()
    var isShakingPossible = false
    var isShaking = false
    
    override func enter() {
        logger.debug("Motion controller started")
        context.stateSubject.send(.running)
        context.motionManager.deviceMotionUpdateInterval = context.configuration.motionUpdateInterval
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
                self.updateMotion(motion: motion)
            }
        )
    }
    
    private func updateMotion(motion: CMDeviceMotion) {
        let a = motion.userAcceleration
        let accelerationMagnitude = sqrt(a.x * a.x + a.y * a.y + a.z * a.z)
        self.accelerationSamples.append(accelerationMagnitude)
        if self.accelerationSamples.count > context.configuration.shakeAccelerationSampleCount {
            self.accelerationSamples.removeFirst()
        }
        let accelerationMean = self.accelerationSamples.reduce(0.0, +) / Double(context.configuration.shakeAccelerationSampleCount)
        
        // Shake event is possible if the instantaneous magnitude exceeds the threshold.
        isShakingPossible = accelerationMagnitude >= context.configuration.shakeAccelerationStartThreshold

        // Trigger shake event when average acceleration over time exceeds a given threshold.
        var shaking = self.isShaking
        if shaking == false {
            if accelerationMean >= context.configuration.shakeAccelerationStartThreshold {
                shaking = true
            }
        }
        else {
            if accelerationMean <= context.configuration.shakeAccelerationStopThreshold {
                shaking = false
            }
        }
        if shaking != self.isShaking {
            logger.debug("Shaking \(shaking ? "yes" : "no")")
            self.isShaking = shaking
            self.context.eventSubject.send(.shake(self.isShaking))
        }
        
        // Publish attitude event. Attitude events are ignored while the device is shaking.
        if isShaking || isShakingPossible {
            return
        }
        let q = motion.attitude.quaternion
        // Compute roll and pitch from the motion attitude quaternion.
        // See: https://en.wikipedia.org/wiki/Conversion_between_quaternions_and_Euler_angles#Source_code_2
        let roll = atan2(2 * (q.y * q.w - q.x * q.z), 1 - 2 * q.y * q.y - 2 * q.z * q.z)
        let pitch = atan2(2 * (q.x * q.w + q.y * q.z), 1 - 2 * q.x * q.x - 2 * q.z * q.z)
        let measurements = MotionProviderEvent.AttitudeMeasurement(
            roll: Measurement(value: roll, unit: UnitAngle.radians),
            pitch: Measurement(value: pitch, unit: UnitAngle.radians)
        )
        self.context.eventSubject.send(.measurement(measurements))
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
    
    struct Configuration {
        let motionUpdateInterval = 1.0 / 120.0
        var shakeAccelerationSampleCount: Int = 60
        var shakeAccelerationStartThreshold: Double = 1.2
        var shakeAccelerationStopThreshold: Double = 0.9
    }

    lazy var statePublisher: AnyPublisher<MotionProviderState, Never> = stateSubject.eraseToAnyPublisher()
    lazy var eventPublisher: AnyPublisher<MotionProviderEvent, Never> = eventSubject.eraseToAnyPublisher()
    
    fileprivate let configuration: Configuration
    fileprivate let motionManager = CMMotionManager()
    fileprivate let stateSubject = CurrentValueSubject<MotionProviderState, Never>(.stopped)
    fileprivate let eventSubject = PassthroughSubject<MotionProviderEvent, Never>()

    private var currentState: MotionState?
    
    init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
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
