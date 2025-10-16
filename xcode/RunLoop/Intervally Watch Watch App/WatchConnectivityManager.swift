//
//  WatchConnectivityManager.swift
//  Intervally Watch
//
//  Manages communication with iPhone and triggers haptics on interval changes.
//

import Foundation
import Combine
import WatchConnectivity
import WatchKit

class WatchConnectivityManager: NSObject, ObservableObject {

    @Published var isActive = false
    @Published var isPaused = false
    @Published var currentInterval = "Ready"
    @Published var remainingTime: TimeInterval = 0
    @Published var intervalColor = "#007AFF"

    var formattedTime: String {
        let minutes = Int(remainingTime) / 60
        let seconds = Int(remainingTime) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    // Workout manager for always-on display
    let workoutManager = WorkoutManager()

    // Workout structure
    private var intervals: [(title: String, duration: TimeInterval, color: String)] = []
    private var currentIntervalIndex = 0
    private var currentCycle = 0
    private var totalCycles: Int?
    private var workoutStartTime: Date?
    private var intervalStartTime: Date?
    private var isRunningAutonomously = false

    // Local timer for autonomous countdown
    private var countdownTimer: Timer?

    override init() {
        super.init()

        print("⌚️ WatchConnectivityManager initializing...")
        print("⌚️ Current thread: \(Thread.isMainThread ? "MAIN" : "BACKGROUND")")

        guard WCSession.isSupported() else {
            print("❌ WCSession NOT supported on this device")
            return
        }

        print("⌚️ WCSession is supported")
        let session = WCSession.default
        print("⌚️ Setting delegate...")
        session.delegate = self
        print("⌚️ Calling activate...")
        session.activate()
        print("⌚️ WCSession.activate() called")

        // Check state after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            print("⌚️ 3 seconds later - activationState: \(session.activationState.rawValue)")
            if session.activationState == .activated {
                print("⌚️ 3 seconds later - isReachable: \(session.isReachable)")
                print("⌚️ 3 seconds later - isCompanionAppInstalled: \(session.isCompanionAppInstalled)")
            } else {
                print("❌ Session FAILED to activate")
                print("   This suggests a pairing or entitlements issue")
            }
        }
    }

    private func triggerHaptic() {
        // Strong haptic for interval transitions
        WKInterfaceDevice.current().play(.success)
        print("⌚️ Haptic triggered on watch")
    }

    // MARK: - Autonomous Timer

    private func startCountdown() {
        stopCountdown()

        countdownTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.updateCountdown()
        }
        print("⌚️ Started autonomous countdown timer")
    }

    private func stopCountdown() {
        countdownTimer?.invalidate()
        countdownTimer = nil
    }

    private func updateCountdown() {
        guard let intervalStart = intervalStartTime else { return }
        guard !intervals.isEmpty else { return }

        let currentIntervalDuration = intervals[currentIntervalIndex].duration
        let elapsed = Date().timeIntervalSince(intervalStart)
        let remaining = currentIntervalDuration - elapsed

        if remaining <= 0 {
            // Time to transition to next interval
            transitionToNextInterval()
        } else {
            // Update remaining time
            DispatchQueue.main.async {
                self.remainingTime = remaining
            }
        }
    }

    private func transitionToNextInterval() {
        guard !intervals.isEmpty else { return }

        let transitionStartTime = Date().timeIntervalSince1970
        print("⌚️ ⏰ Transition starting at \(transitionStartTime)")

        // Move to next interval
        currentIntervalIndex += 1

        // Check if we've completed a cycle
        if currentIntervalIndex >= intervals.count {
            currentIntervalIndex = 0
            currentCycle += 1

            // Check if workout is complete
            if let total = totalCycles, currentCycle >= total {
                print("⌚️ Workout complete!")
                stopWorkout()
                return
            }
        }

        // Update to new interval - MUST happen synchronously on main thread
        let newInterval = intervals[currentIntervalIndex]

        if Thread.isMainThread {
            // Already on main thread - update synchronously
            self.currentInterval = newInterval.title
            self.intervalColor = newInterval.color
            self.remainingTime = newInterval.duration
            self.intervalStartTime = Date()
            self.triggerHaptic()

            let transitionEndTime = Date().timeIntervalSince1970
            print("⌚️ ✅ Transitioned to: \(newInterval.title) in \(Int((transitionEndTime - transitionStartTime) * 1000))ms")
        } else {
            // Not on main thread - dispatch synchronously
            DispatchQueue.main.sync {
                self.currentInterval = newInterval.title
                self.intervalColor = newInterval.color
                self.remainingTime = newInterval.duration
                self.intervalStartTime = Date()
                self.triggerHaptic()

                let transitionEndTime = Date().timeIntervalSince1970
                print("⌚️ ✅ Transitioned to: \(newInterval.title) in \(Int((transitionEndTime - transitionStartTime) * 1000))ms")
            }
        }
    }

    private func stopWorkout() {
        stopCountdown()
        isRunningAutonomously = false
        DispatchQueue.main.async {
            self.isActive = false
            self.isPaused = false
            self.currentInterval = "Ready"
            self.remainingTime = 0
        }
        workoutManager.endWorkout()
        print("⌚️ Stopped autonomous mode")
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityManager: WCSessionDelegate {

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        print("⌚️ *** ACTIVATION CALLBACK FIRED ***")
        if let error = error {
            print("❌ Watch session activation failed: \(error.localizedDescription)")
        } else {
            print("✅ Watch session activated: \(activationState.rawValue)")
            print("   isReachable: \(session.isReachable)")
            print("   isCompanionAppInstalled: \(session.isCompanionAppInstalled)")
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        print("⌚️ Reachability changed: \(session.isReachable)")
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
        print("⌚️ 📥 Received user info: \(userInfo)")
    }

    // Receive messages from iPhone (for interval transitions with immediate haptic)
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        print("⌚️ 📥 Received immediate message: \(message)")
        DispatchQueue.main.async {
            if let type = message["type"] as? String {
                print("⌚️ 📥 Message type: \(type)")
                switch type {
                case "intervalTransition":
                    // IGNORE - Watch runs autonomously now
                    // This message is only here for backwards compatibility
                    print("⌚️ Ignoring interval transition message (running autonomously)")

                case "workoutStarted":
                    print("⌚️ 🏃 Processing workoutStarted message")
                    self.handleWorkoutStarted(message)

                case "workoutStopped":
                    print("⌚️ 🛑 Processing workoutStopped message")
                    self.stopWorkout()

                default:
                    print("⌚️ ⚠️ Unknown message type: \(type)")
                    break
                }
            } else {
                print("⌚️ ⚠️ Message has no type field")
            }
        }
    }

    // Receive application context updates (for workout structure or sync)
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        print("⌚️ 📥 Received application context: \(applicationContext.keys)")
        DispatchQueue.main.async {
            // Check if this is a workout started context (contains intervals)
            if let type = applicationContext["type"] as? String {
                print("⌚️ 📥 Context type: \(type)")
                if type == "workoutStarted" {
                    print("⌚️ 🏃 Processing workoutStarted context")
                    self.handleWorkoutStarted(applicationContext)
                    return
                }
            }

            // Otherwise handle as sync update
            if let active = applicationContext["isActive"] as? Bool,
               let paused = applicationContext["isPaused"] as? Bool {

                let wasPaused = self.isPaused

                // If running autonomously, ONLY handle pause/resume/stop - ignore all time/interval updates
                if self.isRunningAutonomously {
                    print("⌚️ 🚫 Running autonomously - ignoring iPhone update (active: \(active), paused: \(paused))")

                    // Only handle state changes
                    if !active {
                        // Workout stopped on iPhone
                        print("⌚️ iPhone stopped workout - stopping Watch")
                        self.stopWorkout()
                        return
                    }

                    if active && paused && !wasPaused {
                        print("⌚️ iPhone paused - pausing Watch")
                        self.isPaused = true
                        self.stopCountdown()
                        self.workoutManager.pauseWorkout()
                    } else if active && !paused && wasPaused {
                        print("⌚️ iPhone resumed - resuming Watch")
                        self.isPaused = false
                        self.intervalStartTime = Date().addingTimeInterval(-self.intervals[self.currentIntervalIndex].duration + self.remainingTime)
                        self.startCountdown()
                        self.workoutManager.resumeWorkout()
                    }
                    return
                }

                // Not running autonomously - use iPhone updates
                if let title = applicationContext["intervalTitle"] as? String,
                   let time = applicationContext["remainingTime"] as? TimeInterval,
                   let color = applicationContext["color"] as? String {

                    self.currentInterval = title.isEmpty ? "Ready" : title
                    self.remainingTime = time
                    self.intervalColor = color
                    self.isActive = active
                    self.isPaused = paused
                    print("⌚️ Using iPhone updates: \(title), \(time)s")
                }
            }
        }
    }

    // MARK: - Workout Handling

    private func handleWorkoutStarted(_ data: [String: Any]) {
        guard let presetName = data["presetName"] as? String,
              let intervalsData = data["intervals"] as? [[String: Any]] else {
            print("❌ Invalid workout data")
            return
        }

        // Parse intervals
        self.intervals = intervalsData.compactMap { intervalDict in
            guard let title = intervalDict["title"] as? String,
                  let duration = intervalDict["duration"] as? TimeInterval,
                  let color = intervalDict["color"] as? String else {
                return nil
            }
            return (title: title, duration: duration, color: color)
        }

        guard !self.intervals.isEmpty else {
            print("❌ No valid intervals received")
            return
        }

        // Parse cycle count
        self.totalCycles = data["cycleCount"] as? Int

        // Reset state
        self.currentIntervalIndex = 0
        self.currentCycle = 1
        self.workoutStartTime = Date()
        self.intervalStartTime = Date()

        // Set initial interval
        let firstInterval = self.intervals[0]
        self.currentInterval = firstInterval.title
        self.intervalColor = firstInterval.color
        self.remainingTime = firstInterval.duration
        self.isActive = true
        self.isPaused = false

        print("⌚️ Workout started: \(presetName)")
        print("⌚️ Loaded \(self.intervals.count) intervals, \(totalCycles ?? 0) cycles")
        print("⌚️ Running in AUTONOMOUS mode - ignoring iPhone updates")

        // Mark as running autonomously
        self.isRunningAutonomously = true

        // Start HealthKit workout session
        self.workoutManager.startWorkout(presetName: presetName)

        // Start autonomous countdown
        self.startCountdown()
    }
}
