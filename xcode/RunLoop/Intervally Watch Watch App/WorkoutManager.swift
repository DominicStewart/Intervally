//
//  WorkoutManager.swift
//  Intervally Watch
//
//  Manages HealthKit workout session for always-on display and background execution.
//

import Foundation
import Combine
import HealthKit
import WatchKit

class WorkoutManager: NSObject, ObservableObject {

    // MARK: - Published State

    @Published var isWorkoutActive = false
    @Published var workoutName = ""

    // MARK: - Private Properties

    private let healthStore = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?

    // MARK: - Initialization

    override init() {
        super.init()
        requestAuthorization()
    }

    // MARK: - Authorization

    private func requestAuthorization() {
        // Request permission to read/write workout data
        let typesToShare: Set = [
            HKObjectType.workoutType()
        ]

        let typesToRead: Set = [
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!
        ]

        healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead) { success, error in
            if let error = error {
                print("❌ HealthKit authorization failed: \(error.localizedDescription)")
            } else if success {
                print("✅ HealthKit authorization granted")
            }
        }
    }

    // MARK: - Workout Control

    /// Start a workout session for interval training
    func startWorkout(presetName: String) {
        // Create workout configuration for interval training
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .other  // Use .other for custom interval workouts
        configuration.locationType = .unknown

        do {
            // Create and start the workout session
            session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            builder = session?.associatedWorkoutBuilder()

            // Set delegates
            session?.delegate = self
            builder?.delegate = self

            // Set data source for the builder
            builder?.dataSource = HKLiveWorkoutDataSource(
                healthStore: healthStore,
                workoutConfiguration: configuration
            )

            // Start the session
            session?.startActivity(with: Date())
            builder?.beginCollection(withStart: Date()) { success, error in
                if let error = error {
                    print("❌ Failed to begin workout collection: \(error.localizedDescription)")
                } else {
                    print("✅ Workout collection started")
                }
            }

            // Update state
            DispatchQueue.main.async {
                self.isWorkoutActive = true
                self.workoutName = presetName
            }

            print("✅ Workout session started: \(presetName)")

            // Keep screen on and enable water lock
            WKInterfaceDevice.current().enableWaterLock()

        } catch {
            print("❌ Failed to start workout session: \(error.localizedDescription)")
        }
    }

    /// Pause the workout
    func pauseWorkout() {
        session?.pause()
        print("⏸️ Workout paused")
    }

    /// Resume the workout
    func resumeWorkout() {
        session?.resume()
        print("▶️ Workout resumed")
    }

    /// End the workout session
    func endWorkout() {
        session?.end()

        // Stop collecting data
        builder?.endCollection(withEnd: Date()) { success, error in
            if let error = error {
                print("❌ Failed to end workout collection: \(error.localizedDescription)")
                return
            }

            // Save the workout
            self.builder?.finishWorkout { workout, error in
                if let error = error {
                    print("❌ Failed to save workout: \(error.localizedDescription)")
                } else {
                    print("✅ Workout saved to Health app")
                }

                // Clean up
                DispatchQueue.main.async {
                    self.session = nil
                    self.builder = nil
                    self.isWorkoutActive = false
                    self.workoutName = ""
                }
            }
        }

        print("✅ Workout session ended")
    }
}

// MARK: - HKWorkoutSessionDelegate

extension WorkoutManager: HKWorkoutSessionDelegate {

    func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState,
        date: Date
    ) {
        DispatchQueue.main.async {
            switch toState {
            case .running:
                print("⌚️ Workout state: Running")
            case .paused:
                print("⌚️ Workout state: Paused")
            case .ended:
                print("⌚️ Workout state: Ended")
                self.isWorkoutActive = false
            default:
                break
            }
        }
    }

    func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didFailWithError error: Error
    ) {
        print("❌ Workout session failed: \(error.localizedDescription)")
        DispatchQueue.main.async {
            self.isWorkoutActive = false
        }
    }
}

// MARK: - HKLiveWorkoutBuilderDelegate

extension WorkoutManager: HKLiveWorkoutBuilderDelegate {

    func workoutBuilder(
        _ workoutBuilder: HKLiveWorkoutBuilder,
        didCollectDataOf collectedTypes: Set<HKSampleType>
    ) {
        // Handle collected data (heart rate, calories, etc.)
        // This is called periodically as data is collected
    }

    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
        // Handle workout events
    }
}
