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
    @Published var isStartingWorkout = false

    // MARK: - Private Properties

    private let healthStore = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    private var isCleanupComplete = false
    private var isCollectionActive = false  // Track if beginCollection succeeded

    // MARK: - Initialization

    override init() {
        super.init()

        // Clean up any existing workout sessions from previous app runs
        Task {
            await cleanupExistingSessions()
        }
    }

    /// Clean up any existing workout sessions that may be lingering from previous app runs
    private func cleanupExistingSessions() async {
        // Request authorization first
        await requestAuthorization()

        // Try to recover any active workout session from a previous app run
        let recoveredSession: HKWorkoutSession? = await withCheckedContinuation { continuation in
            healthStore.recoverActiveWorkoutSession { session, error in
                if let error = error {
                    print("⌚️ Error recovering workout session: \(error.localizedDescription)")
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: session)
            }
        }

        if let session = recoveredSession {
            print("⌚️ Found existing workout session from previous run")
            print("⌚️ Session state: \(session.state.rawValue)")

            // PROPER APPROACH: End it cleanly and save the workout
            // This is what other apps do - they don't discard, they finish properly

            session.delegate = self
            let builder = session.associatedWorkoutBuilder()
            builder.delegate = self

            // End the session if it's still active
            if session.state == .running || session.state == .paused {
                print("⌚️ Ending previous workout session cleanly")
                session.end()
                try? await Task.sleep(for: .seconds(1))
            }

            // Finish and save the workout (don't discard - this corrupts HealthKit)
            do {
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    builder.endCollection(withEnd: Date()) { success, error in
                        if let error = error {
                            print("⌚️ Note: Collection already ended - \(error.localizedDescription)")
                        }

                        // Finish the workout
                        builder.finishWorkout { workout, error in
                            if let error = error {
                                print("⌚️ Could not save previous workout: \(error.localizedDescription)")
                                continuation.resume(throwing: error)
                            } else {
                                print("✅ Previous workout saved to Health app")
                                continuation.resume()
                            }
                        }
                    }
                }
            } catch {
                print("⌚️ Previous workout cleanup had errors (this is OK)")
            }

            try? await Task.sleep(for: .seconds(1))
            print("⌚️ Previous session cleaned up properly")
        } else {
            print("⌚️ No previous workout sessions found - clean start")
        }

        // Extra wait to let HealthKit fully stabilize
        print("⌚️ Waiting for HealthKit to fully initialize...")
        try? await Task.sleep(for: .seconds(3))

        await MainActor.run {
            self.isCleanupComplete = true
        }

        print("⌚️ HealthKit initialization complete - ready for workouts")
    }

    // MARK: - Authorization

    private func requestAuthorization() async {
        // Request permission to read/write workout data
        let typesToShare: Set = [
            HKObjectType.workoutType()
        ]

        let typesToRead: Set = [
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!
        ]

        do {
            try await healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead)
            print("✅ HealthKit authorization granted")
        } catch {
            print("❌ HealthKit authorization failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Workout Control

    /// Start a workout session for interval training
    func startWorkout(presetName: String) {
        // Ensure authorization is requested first
        Task { @MainActor in
            // Prevent duplicate starts (on main actor for synchronization)
            guard !self.isStartingWorkout && self.session == nil else {
                print("⌚️ Workout already starting or active - skipping duplicate start")
                return
            }

            self.isStartingWorkout = true

            // Wait for cleanup to complete if it's still running
            if !self.isCleanupComplete {
                print("⌚️ Waiting for cleanup to complete before starting workout...")
                // Wait up to 3 seconds for cleanup
                for _ in 0..<30 {
                    if self.isCleanupComplete {
                        break
                    }
                    try? await Task.sleep(for: .milliseconds(100))
                }
            }

            print("⌚️ Starting workout session for: \(presetName)")

            await self.requestAuthorization()
            await self.startWorkoutSession(presetName: presetName)

            self.isStartingWorkout = false
        }
    }

    private func startWorkoutSession(presetName: String) async {
        // Clean up any existing session first (in case it's in error state)
        if let existingSession = session {
            print("⌚️ Cleaning up existing session before starting new one")
            existingSession.end()
            await MainActor.run {
                self.session = nil
                self.builder = nil
                self.isCollectionActive = false
            }
            // Give it a moment to clean up
            try? await Task.sleep(for: .milliseconds(200))
        }

        // Note: We don't do a "final check" here because:
        // 1. We already cleaned up orphaned sessions at app launch
        // 2. Checking here creates a race condition (we find our OWN session being created)
        // 3. The guard at the top ensures we don't have a local session already
        print("⌚️ Creating new HealthKit workout session...")

        // Create workout configuration for interval training
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .functionalStrengthTraining  // More standard type for intervals
        configuration.locationType = .indoor

        do {
            // Create and start the workout session
            let workoutSession = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            let workoutBuilder = workoutSession.associatedWorkoutBuilder()

            // Set delegates
            workoutSession.delegate = self
            workoutBuilder.delegate = self

            // Set data source for the builder
            workoutBuilder.dataSource = HKLiveWorkoutDataSource(
                healthStore: healthStore,
                workoutConfiguration: configuration
            )

            // Store session and builder
            self.session = workoutSession
            self.builder = workoutBuilder

            // Start the session and wait for it to begin
            workoutSession.startActivity(with: Date())

            // Wait a moment for the session to start
            try? await Task.sleep(for: .milliseconds(100))

            // Check if builder is already collecting (safety check for HealthKit state)
            if workoutBuilder.elapsedTime(at: Date()) > 0 {
                print("⚠️ Builder already collecting - skipping beginCollection")
                await MainActor.run {
                    self.isWorkoutActive = true
                    self.workoutName = presetName
                    self.isCollectionActive = false  // Don't try to end collection later
                }
                print("✅ Workout session already active: \(presetName)")
                return
            }

            // Begin collection using continuation to make it async
            do {
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    workoutBuilder.beginCollection(withStart: Date()) { success, error in
                        if let error = error {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume()
                        }
                    }
                }

                // Collection started successfully
                print("✅ Workout collection started")
                await MainActor.run {
                    self.isCollectionActive = true
                }

            } catch {
                // If beginCollection fails with "already started", treat it as success
                let errorMessage = error.localizedDescription.lowercased()
                if errorMessage.contains("already started") || errorMessage.contains("already begun") {
                    print("⚠️ Workout collection already started - continuing anyway")
                    await MainActor.run {
                        self.isWorkoutActive = true
                        self.workoutName = presetName
                        self.isCollectionActive = false  // Don't try to end collection later
                    }
                    print("✅ Workout session active despite error: \(presetName)")
                    return
                } else {
                    // Re-throw other errors
                    throw error
                }
            }

            // Update state
            await MainActor.run {
                self.isWorkoutActive = true
                self.workoutName = presetName
            }

            print("✅ Workout session started: \(presetName)")

        } catch {
            print("❌ Failed to start workout session: \(error.localizedDescription)")

            // Clean up on error
            await MainActor.run {
                self.session = nil
                self.builder = nil
                self.isWorkoutActive = false
                self.isStartingWorkout = false
                self.isCollectionActive = false
            }

            print("⌚️ Cleaned up after error - ready for retry")
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
    /// - Parameter saveToHealthApp: If true, saves workout to Health app; if false, discards it
    func endWorkout(saveToHealthApp: Bool = true) {
        guard session != nil else {
            print("⌚️ No active workout to end")
            return
        }

        print("⌚️ Ending HealthKit workout session...")
        session?.end()

        // Only end collection if it was actually started
        if isCollectionActive {
            print("⌚️ Ending data collection...")
            builder?.endCollection(withEnd: Date()) { success, error in
                if let error = error {
                    print("❌ Failed to end workout collection: \(error.localizedDescription)")
                    // Continue anyway - try to finish the workout
                }

                print("✅ Workout collection ended")

                // Save or discard based on setting
                if saveToHealthApp {
                    // Save the workout to Health app
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
                            self.isStartingWorkout = false
                            self.isCollectionActive = false
                            print("⌚️ HealthKit session fully cleaned up")
                        }
                    }
                } else {
                    // Discard the workout (don't save to Health app)
                    print("⚠️ Discarding workout - not saving to Health app (non-fitness preset)")
                    self.builder?.discardWorkout()

                    // Clean up
                    DispatchQueue.main.async {
                        self.session = nil
                        self.builder = nil
                        self.isWorkoutActive = false
                        self.workoutName = ""
                        self.isStartingWorkout = false
                        self.isCollectionActive = false
                        print("⌚️ HealthKit session discarded and cleaned up")
                    }
                }
            }
        } else {
            print("⚠️ Collection was never started - discarding workout session without saving")
            // Collection never started, so we can't save the workout
            // Just discard and clean up (the session.end() call above will handle ending)

            // Wait a moment for session to end, then clean up
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.session = nil
                self.builder = nil
                self.isWorkoutActive = false
                self.workoutName = ""
                self.isStartingWorkout = false
                self.isCollectionActive = false
                print("⌚️ HealthKit session discarded and cleaned up")
            }
        }

        print("✅ Workout session ending (async \(saveToHealthApp ? "save" : "discard") in progress)")
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
                self.isStartingWorkout = false
            case .paused:
                print("⌚️ Workout state: Paused")
            case .ended:
                print("⌚️ Workout state: Ended")
                self.isWorkoutActive = false
                self.isStartingWorkout = false
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
            self.isStartingWorkout = false
            self.isCollectionActive = false
            self.session = nil
            self.builder = nil
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
