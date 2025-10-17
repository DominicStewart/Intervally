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
    private var watchHapticsEnabled = true  // Haptics enabled by default
    private var enableHealthKitWorkout = true  // HealthKit workout enabled by default

    // Local timer for autonomous countdown
    private var countdownTimer: Timer?
    private var isAlwaysOnMode = false
    private var lastSyncRequestTime: Date?

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
        guard watchHapticsEnabled else {
            print("⌚️ Haptics disabled - skipping")
            return
        }

        // Strong haptic for interval transitions
        WKInterfaceDevice.current().play(.success)
        print("⌚️ Haptic triggered on watch")
    }

    // MARK: - Autonomous Timer

    /// Set Always-On display mode (adjusts timer update frequency)
    func setAlwaysOnMode(_ isAlwaysOn: Bool) {
        guard isAlwaysOnMode != isAlwaysOn else { return }
        isAlwaysOnMode = isAlwaysOn

        print("⌚️ Always-On mode: \(isAlwaysOn ? "ON" : "OFF")")

        // Restart timer with new interval if running
        if countdownTimer != nil {
            startCountdown()
        }
    }

    private func startCountdown() {
        stopCountdown()

        // Use 0.5s when active (feels responsive), 2s in Always-On mode (saves battery)
        let interval: TimeInterval = isAlwaysOnMode ? 2.0 : 0.5

        countdownTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.updateCountdown()
        }
        print("⌚️ Started autonomous countdown timer (interval: \(interval)s)")
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
        // Pass save flag to WorkoutManager
        workoutManager.endWorkout(saveToHealthApp: enableHealthKitWorkout)
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

        // If iPhone becomes reachable and we're not running a workout, request sync
        if session.isReachable && !isRunningAutonomously && !isActive {
            print("⌚️ iPhone reachable - requesting sync")
            requestSyncFromiPhone()
        }
    }

    /// Request current workout state from iPhone (for late-join scenarios)
    func requestSyncFromiPhone() {
        // Don't request if we're already running a workout autonomously
        if isRunningAutonomously {
            print("⌚️ Already running autonomously - no sync needed")
            return
        }

        // Throttle sync requests to once every 3 seconds
        if let lastRequest = lastSyncRequestTime, Date().timeIntervalSince(lastRequest) < 3.0 {
            print("⌚️ ⚠️ Sync request throttled - too soon after last request")
            return
        }

        guard WCSession.default.activationState == .activated else {
            print("⌚️ ⚠️ Cannot request sync - session not activated")
            return
        }

        guard WCSession.default.isReachable else {
            print("⌚️ ⚠️ Cannot request sync - iPhone not reachable")
            return
        }

        let message = ["type": "requestSync"]
        WCSession.default.sendMessage(message, replyHandler: nil) { error in
            print("⌚️ ⚠️ Failed to request sync: \(error.localizedDescription)")
        }
        lastSyncRequestTime = Date()
        print("⌚️ 📤 Sent sync request to iPhone")
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
                    // If running autonomously, ignore iPhone transitions - we have our own timer
                    if self.isRunningAutonomously {
                        print("⌚️ Ignoring interval transition - running autonomously with own timer")
                    } else {
                        print("⌚️ Received interval transition - not autonomous yet")
                    }

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
            // Check message type
            if let type = applicationContext["type"] as? String {
                print("⌚️ 📥 Context type: \(type)")

                switch type {
                case "workoutStarted":
                    print("⌚️ 🏃 Processing workoutStarted context")
                    self.handleWorkoutStarted(applicationContext)
                    return

                case "timerUpdate":
                    print("⌚️ 📥 Processing timerUpdate")
                    // Fall through to handle timer update
                    break

                default:
                    print("⌚️ ⚠️ Unknown context type: \(type)")
                    break
                }
            }

            // Handle timer update or legacy context without type
            if let active = applicationContext["isActive"] as? Bool,
               let paused = applicationContext["isPaused"] as? Bool {

                // If iPhone has no active workout, return
                if !active {
                    print("⌚️ iPhone has no active workout")
                    self.isActive = false
                    return
                }

                let wasPaused = self.isPaused

                // If running autonomously, ONLY handle pause/resume/stop
                if self.isRunningAutonomously {
                    print("⌚️ 🚫 Running autonomously - checking state changes only")

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

                // Not running autonomously - use iPhone updates (late-join scenario)
                if let title = applicationContext["intervalTitle"] as? String,
                   let time = applicationContext["remainingTime"] as? TimeInterval,
                   let color = applicationContext["color"] as? String {

                    self.currentInterval = title.isEmpty ? "Ready" : title
                    self.remainingTime = time
                    self.intervalColor = color
                    self.isActive = active
                    self.isPaused = paused
                    print("⌚️ Syncing from iPhone (late-join): \(title), \(time)s")
                    print("⌚️ ⚠️ WARNING: Receiving simple updates without full workout structure")
                    print("⌚️ ⚠️ This means Watch is NOT in autonomous mode - updates will be slow")

                    // Start HealthKit session to keep app alive during late-join
                    // (we don't have full workout structure, so just use keep-alive mode)
                    if active && !self.workoutManager.isWorkoutActive && !self.workoutManager.isStartingWorkout {
                        self.workoutManager.startWorkout(presetName: "Interval Training")
                        print("⌚️ Late-join: Starting HealthKit session for keep-alive")
                    }

                    // Request full workout structure to switch to autonomous mode
                    print("⌚️ Requesting full workout structure from iPhone...")
                    self.requestSyncFromiPhone()
                }
            }
        }
    }

    // MARK: - Sync Handling

    /// Handle interval transition sync (when Watch was opened mid-workout)
    private func handleIntervalTransitionSync(_ data: [String: Any]) {
        guard let title = data["intervalTitle"] as? String,
              let time = data["remainingTime"] as? TimeInterval,
              let color = data["color"] as? String else {
            print("⌚️ ⚠️ Invalid interval transition data")
            return
        }

        // Check if interval changed (title is different)
        if title != self.currentInterval {
            print("⌚️ 🔄 Interval changed on iPhone - syncing to: \(title)")

            // Update to new interval
            self.currentInterval = title
            self.intervalColor = color
            self.remainingTime = time
            self.intervalStartTime = Date()

            // Trigger haptic for the transition
            self.triggerHaptic()
        } else {
            // Same interval - just check if we're significantly out of sync
            let timeDiff = abs(self.remainingTime - time)
            if timeDiff > 2.0 {
                print("⌚️ 🔄 Time diff \(timeDiff)s - resyncing")
                self.remainingTime = time
                self.intervalStartTime = Date()
            }
        }
    }

    // MARK: - Workout Handling

    private func handleWorkoutStarted(_ data: [String: Any]) {
        // Prevent duplicate workout starts (iPhone sends both message AND context)
        if isRunningAutonomously {
            print("⌚️ Workout already started - ignoring duplicate start message")
            return
        }

        guard let presetName = data["presetName"] as? String,
              let intervalsData = data["intervals"] as? [[String: Any]] else {
            print("❌ Invalid workout data")
            return
        }

        // Extract haptics setting
        if let hapticsEnabled = data["watchHapticsEnabled"] as? Bool {
            self.watchHapticsEnabled = hapticsEnabled
            print("⌚️ Watch haptics: \(hapticsEnabled ? "enabled" : "disabled")")
        }

        // Extract HealthKit workout setting
        if let healthKitEnabled = data["enableHealthKitWorkout"] as? Bool {
            self.enableHealthKitWorkout = healthKitEnabled
            print("⌚️ HealthKit workout: \(healthKitEnabled ? "enabled" : "disabled")")
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

        // Extract current position (for late-join scenarios)
        let startIntervalIndex = data["currentIntervalIndex"] as? Int ?? 0
        let startCycle = data["currentCycle"] as? Int ?? 1
        let startRemainingTime = data["remainingTime"] as? TimeInterval ?? self.intervals[0].duration

        // Set state to current position
        self.currentIntervalIndex = startIntervalIndex
        self.currentCycle = startCycle
        self.workoutStartTime = Date()

        // Calculate interval start time based on remaining time
        let currentIntervalDuration = self.intervals[startIntervalIndex].duration
        let elapsed = currentIntervalDuration - startRemainingTime
        self.intervalStartTime = Date().addingTimeInterval(-elapsed)

        // Set current interval
        let currentIntervalData = self.intervals[startIntervalIndex]
        self.currentInterval = currentIntervalData.title
        self.intervalColor = currentIntervalData.color
        self.remainingTime = startRemainingTime
        self.isActive = true
        self.isPaused = false

        print("⌚️ Workout started: \(presetName)")
        print("⌚️ Loaded \(self.intervals.count) intervals, \(totalCycles ?? 0) cycles")
        print("⌚️ Running in AUTONOMOUS mode - ignoring iPhone updates")

        // Mark as running autonomously
        self.isRunningAutonomously = true

        // Always start HealthKit workout session to keep app alive in background
        // We'll decide whether to save or discard the data when stopping
        if !self.workoutManager.isWorkoutActive && !self.workoutManager.isStartingWorkout {
            self.workoutManager.startWorkout(presetName: presetName)
            if self.enableHealthKitWorkout {
                print("⌚️ Starting HealthKit workout session (will save to Health app): \(presetName)")
            } else {
                print("⌚️ Starting HealthKit workout session for keep-alive only (will not save): \(presetName)")
            }
        } else {
            print("⌚️ HealthKit workout session already active")
        }

        // Start autonomous countdown
        self.startCountdown()
    }
}
