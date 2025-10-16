//
//  IntervalViewModel.swift
//  RunLoop
//
//  Observable view model bridging IntervalEngine to SwiftUI.
//  Coordinates engine, services, and app lifecycle.
//

import Foundation
import SwiftUI
import Combine
#if canImport(ActivityKit)
import ActivityKit
#endif

/// Main view model for interval timer sessions
@MainActor
@Observable
final class IntervalViewModel {

    // MARK: - Engine & Services

    private let engine = IntervalEngine()
    private let audioService = AudioService()
    private let speechService = SpeechService()
    private let hapticsService = HapticsService()
    private let notificationService = NotificationService()
    private let watchService = WatchConnectivityService.shared

    // MARK: - Published State (via @Observable)

    var state: IntervalEngine.State = .idle
    var currentInterval: Interval?
    var nextInterval: Interval?
    var remainingTime: TimeInterval = 0
    var elapsedTime: TimeInterval = 0
    var progress: Double = 0
    var currentCycle: Int = 0
    var totalCycles: Int?

    // MARK: - Settings (persisted via AppStorage)

    var soundsEnabled: Bool = true
    var voiceEnabled: Bool = true
    var hapticsEnabled: Bool = true
    var speechRate: Double = 0.5 // AVSpeechUtterance rate
    var countInEnabled: Bool = false
    var keepScreenAwake: Bool = false

    // MARK: - Private Properties

    private var cancellables = Set<AnyCancellable>()
    private var liveActivityUpdateTimer: Timer?
    private var watchUpdateTimer: Timer?
    private var currentPreset: Preset?
    #if canImport(ActivityKit)
    private var currentActivity: Activity<IntervalActivityAttributes>?
    #endif
    private var currentIntervalIndex: Int = 0

    // MARK: - Initialization

    init() {
        setupEngineCallbacks()
        setupAudioSession()
        requestNotificationPermission()
        observeEngine()
    }

    // MARK: - Engine Observation

    private func observeEngine() {
        // Subscribe to all engine state changes
        engine.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] value in
                self?.state = value
                // Don't send watch updates here - they'll be sent periodically via timer
            }
            .store(in: &cancellables)

        engine.$currentInterval
            .receive(on: DispatchQueue.main)
            .sink { [weak self] value in self?.currentInterval = value }
            .store(in: &cancellables)

        engine.$nextInterval
            .receive(on: DispatchQueue.main)
            .sink { [weak self] value in self?.nextInterval = value }
            .store(in: &cancellables)

        engine.$remainingTime
            .receive(on: DispatchQueue.main)
            .sink { [weak self] value in self?.remainingTime = value }
            .store(in: &cancellables)

        engine.$elapsedTime
            .receive(on: DispatchQueue.main)
            .sink { [weak self] value in self?.elapsedTime = value }
            .store(in: &cancellables)

        engine.$progress
            .receive(on: DispatchQueue.main)
            .sink { [weak self] value in self?.progress = value }
            .store(in: &cancellables)

        engine.$currentCycle
            .receive(on: DispatchQueue.main)
            .sink { [weak self] value in self?.currentCycle = value }
            .store(in: &cancellables)

        engine.$totalCycles
            .receive(on: DispatchQueue.main)
            .sink { [weak self] value in self?.totalCycles = value }
            .store(in: &cancellables)
    }

    // MARK: - Public Methods

    /// Start a session with the given preset
    func start(preset: Preset) async {
        currentPreset = preset

        // Cancel any pending notifications
        await notificationService.cancelAll()

        // Setup audio session
        audioService.configureSession()

        // Start silent audio loop to keep session alive in background
        audioService.startSilentAudioLoop()

        // Count-in if enabled
        if countInEnabled {
            await performCountIn()
        }

        // Start engine
        engine.start(preset: preset)

        // Send full workout structure to Apple Watch
        let intervalsData = preset.intervals.map { interval in
            [
                "title": interval.title,
                "duration": interval.duration,
                "color": interval.colorHex
            ] as [String: Any]
        }
        watchService.sendWorkoutStarted(
            presetName: preset.name,
            intervals: intervalsData,
            cycleCount: preset.cycleCount
        )

        // Watch runs autonomously - no need for periodic updates
        // Only send pause/resume/stop commands as needed

        // Live Activity will be started on first interval transition when we have valid data

        // No notifications scheduled - app must be running (foreground or background)
    }

    /// Pause the current session
    func pause() async {
        engine.pause()
        await notificationService.cancelAll()
        watchService.sendTimerUpdate(
            intervalTitle: currentInterval?.title,
            remainingTime: remainingTime,
            isActive: true,
            isPaused: true,
            color: currentInterval?.colorHex
        )
        #if canImport(ActivityKit)
        updateLiveActivity()
        #endif
    }

    /// Resume the paused session
    func resume() async {
        engine.resume()
        watchService.sendTimerUpdate(
            intervalTitle: currentInterval?.title,
            remainingTime: remainingTime,
            isActive: true,
            isPaused: false,
            color: currentInterval?.colorHex
        )
        #if canImport(ActivityKit)
        updateLiveActivity()
        #endif
    }

    /// Stop the current session
    func stop() async {
        engine.stop()
        await notificationService.cancelAll()
        audioService.stopSilentAudioLoop()
        audioService.deactivateSession()
        watchService.sendWorkoutStopped()
        #if canImport(ActivityKit)
        endLiveActivity()
        #endif
        currentPreset = nil
    }

    /// Skip to next interval
    func skipForward() {
        engine.skipForward()
    }

    /// Skip to previous interval
    func skipBackward() {
        engine.skipBackward()
    }

    // MARK: - Formatted Helpers

    var formattedRemainingTime: String {
        formatTime(remainingTime)
    }

    var formattedElapsedTime: String {
        formatTime(elapsedTime)
    }

    var cycleText: String {
        if let total = totalCycles {
            return "Cycle \(currentCycle) of \(total)"
        } else {
            return "Cycle \(currentCycle)"
        }
    }

    // MARK: - Private Methods

    private func setupEngineCallbacks() {
        // Observe engine state changes
        engine.onIntervalTransition = { [weak self] interval, intervalIndex, cycleIndex in
            Task { @MainActor in
                await self?.handleIntervalTransition(interval, intervalIndex: intervalIndex, cycleIndex: cycleIndex)
            }
        }

        engine.onSessionFinish = { [weak self] in
            Task { @MainActor in
                await self?.handleSessionFinish()
            }
        }
    }

    private func setupAudioSession() {
        audioService.configureSession()
    }

    private func requestNotificationPermission() {
        Task {
            await notificationService.requestPermission()
        }
    }

    private func handleIntervalTransition(_ interval: Interval, intervalIndex: Int, cycleIndex: Int) async {
        print("🔄 Transition: \(interval.title) (Interval \(intervalIndex), Cycle \(cycleIndex + 1))")

        // Track current interval index
        currentIntervalIndex = intervalIndex

        // Start or update Live Activity
        #if canImport(ActivityKit)
        if currentActivity == nil, let preset = currentPreset {
            startLiveActivity(preset: preset)
        } else {
            // Add delay to avoid iOS rate limiting
            try? await Task.sleep(for: .milliseconds(500))
            updateLiveActivity()
        }
        #endif

        // Play alerts
        if soundsEnabled {
            audioService.playChime()
        }

        if voiceEnabled {
            speechService.speak(interval.announcement, rate: Float(speechRate))
        }

        if hapticsEnabled {
            hapticsService.trigger(pattern: .intervalTransition)
        }

        // Watch runs autonomously - no need to send transition updates
    }

    private func handleSessionFinish() async {
        print("✅ Session finished")

        // Play completion alert
        if soundsEnabled {
            audioService.playChime()
        }

        if voiceEnabled {
            speechService.speak("Workout complete", rate: Float(speechRate))
        }

        if hapticsEnabled {
            hapticsService.trigger(pattern: .sessionComplete)
        }

        await notificationService.cancelAll()
        audioService.stopSilentAudioLoop()
        audioService.deactivateSession()
        #if canImport(ActivityKit)
        endLiveActivity()
        #endif
    }

    private func performCountIn() async {
        // Give audio session a moment to initialize
        try? await Task.sleep(for: .milliseconds(200))

        // Simple count-in: 3, 2, 1
        for count in (1...3).reversed() {
            if voiceEnabled {
                speechService.speak("\(count)", rate: Float(speechRate))
            }
            if hapticsEnabled {
                hapticsService.trigger(pattern: .countIn)
            }
            try? await Task.sleep(for: .seconds(1))
        }
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, secs)
    }

    /// Send current state to Apple Watch (called periodically by timer)
    private func sendWatchUpdate() {
        watchService.sendTimerUpdate(
            intervalTitle: currentInterval?.title,
            remainingTime: remainingTime,
            isActive: state.isActive,
            isPaused: state.isPaused,
            color: currentInterval?.colorHex
        )
    }

    /// Start timer for periodic watch updates (avoids iOS throttling)
    private func startWatchUpdateTimer() {
        stopWatchUpdateTimer()

        // Update every 2 seconds to avoid updateApplicationContext throttling
        watchUpdateTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.sendWatchUpdate()
            }
        }
        print("⏰ Watch update timer started (2s interval)")
    }

    /// Stop the watch update timer
    private func stopWatchUpdateTimer() {
        watchUpdateTimer?.invalidate()
        watchUpdateTimer = nil
    }

    // MARK: - Live Activity

    #if canImport(ActivityKit)
    /// Start a Live Activity for the current workout
    private func startLiveActivity(preset: Preset) {
        print("🚀 Attempting to start Live Activity for: \(preset.name)")

        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("⚠️ Live Activities not enabled in settings")
            return
        }

        print("✅ Live Activities are enabled")

        let attributes = IntervalActivityAttributes(presetName: preset.name)

        let initialState = IntervalActivityAttributes.ContentState(
            intervalTitle: currentInterval?.title ?? "Ready",
            intervalEndDate: Date().addingTimeInterval(remainingTime),
            intervalColor: currentInterval?.colorHex ?? "#007AFF",
            isPaused: false,
            currentIntervalIndex: 0,
            totalIntervals: preset.intervalCount,
            currentCycle: 1,
            totalCycles: preset.cycleCount ?? 1,
            updateTimestamp: Date()
        )

        print("📊 Initial state - Title: \(initialState.intervalTitle), Elapsed: \(elapsedTime)s")

        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: initialState, staleDate: nil)
            )
            currentActivity = activity
            print("✅ Live Activity started successfully")
            print("   Activity ID: \(activity.id)")
            print("   Activity state: \(activity.activityState)")

            // Don't start periodic timer - only update on actual interval changes
        } catch {
            print("❌ Failed to start Live Activity")
            print("   Error: \(error)")
            print("   Error details: \((error as NSError).userInfo)")
        }
    }

    /// Update the Live Activity with current state
    private func updateLiveActivity() {
        guard let activity = currentActivity else {
            print("❌ No activity to update")
            return
        }

        guard activity.activityState == .active else {
            print("❌ Activity not active, state: \(activity.activityState)")
            return
        }

        guard let preset = currentPreset else {
            print("❌ Missing preset")
            return
        }

        let updatedState = IntervalActivityAttributes.ContentState(
            intervalTitle: currentInterval?.title ?? "Ready",
            intervalEndDate: Date().addingTimeInterval(remainingTime),
            intervalColor: currentInterval?.colorHex ?? "#007AFF",
            isPaused: state.isPaused,
            currentIntervalIndex: currentIntervalIndex,
            totalIntervals: preset.intervalCount,
            currentCycle: currentCycle,
            totalCycles: totalCycles ?? 1,
            updateTimestamp: Date()
        )

        print("📲 Attempting update - Activity state: \(activity.activityState), Title: \(updatedState.intervalTitle)")
        print("   Remaining time: \(remainingTime)s, End date: \(updatedState.intervalEndDate)")
        print("   Update timestamp: \(updatedState.updateTimestamp)")

        Task {
            let content = ActivityContent<IntervalActivityAttributes.ContentState>(
                state: updatedState,
                staleDate: nil
            )

            await activity.update(content)

            print("✅ Live Activity updated successfully: \(updatedState.intervalTitle)")
            print("   Activity ID: \(activity.id)")
            print("   Activity state after update: \(activity.activityState)")

            // Force a small delay and check state again
            try? await Task.sleep(for: .milliseconds(100))
            print("   Activity state 100ms later: \(activity.activityState)")
        }
    }

    /// End the Live Activity
    private func endLiveActivity() {
        guard let activity = currentActivity else { return }

        Task {
            await activity.end(nil, dismissalPolicy: .immediate)
            currentActivity = nil
            print("✅ Live Activity ended")
        }
    }

    /// Start timer to periodically update Live Activity (prevents content expiration)
    private func startLiveActivityUpdateTimer() {
        stopLiveActivityUpdateTimer()

        liveActivityUpdateTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                await MainActor.run {
                    self.updateLiveActivity()
                }
            }
        }
        print("⏰ Live Activity update timer started (30s interval)")
    }

    /// Stop the Live Activity update timer
    private func stopLiveActivityUpdateTimer() {
        liveActivityUpdateTimer?.invalidate()
        liveActivityUpdateTimer = nil
        print("⏰ Live Activity update timer stopped")
    }
    #endif
}

// MARK: - Array Extension

extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
