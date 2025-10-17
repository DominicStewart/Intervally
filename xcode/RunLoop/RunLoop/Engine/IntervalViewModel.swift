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
    private let presetStore: PresetStore

    // MARK: - Published State (via @Observable)

    var state: IntervalEngine.State = .idle
    var currentInterval: Interval?
    var nextInterval: Interval?
    var remainingTime: TimeInterval = 0
    var elapsedTime: TimeInterval = 0
    var progress: Double = 0
    var currentCycle: Int = 0
    var totalCycles: Int?
    var countdownNumber: Int? = nil  // For visual countdown (3, 2, 1)
    var isCountingIn: Bool = false  // True during countdown phase

    // MARK: - Settings (persisted via AppStorage)

    var soundsEnabled: Bool = true
    var voiceEnabled: Bool = true
    var hapticsEnabled: Bool = true
    var speechRate: Double = 0.5 // AVSpeechUtterance rate
    var countInEnabled: Bool = true  // Enable countdown by default
    var keepScreenAwake: Bool = false

    // MARK: - Private Properties

    private var cancellables = Set<AnyCancellable>()
    private var watchUpdateTimer: Timer?
    private var currentPreset: Preset?
    private var currentIntervalIndex: Int = 0

    // MARK: - Initialization

    init(presetStore: PresetStore) {
        self.presetStore = presetStore
        setupEngineCallbacks()
        setupAudioSession()
        requestNotificationPermission()
        observeEngine()
        setupWatchSyncObserver()
    }

    // MARK: - Engine Observation

    private func setupWatchSyncObserver() {
        // Listen for Watch sync requests
        NotificationCenter.default.publisher(for: .watchRequestedSync)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                print("📱 Responding to Watch sync request")
                self?.sendFullWorkoutSync()  // Send full workout structure for late-join
            }
            .store(in: &cancellables)
    }

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
            cycleCount: preset.cycleCount,
            watchHapticsEnabled: presetStore.watchHapticsEnabled,
            currentIntervalIndex: 0,  // Start at beginning
            currentCycle: 1,  // Start at cycle 1
            remainingTime: preset.intervals.first?.duration ?? 0  // First interval duration
        )

        // Start periodic watch sync (every 10 seconds for late-join scenarios)
        startWatchUpdateTimer()
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
    }

    /// Stop the current session
    func stop() async {
        engine.stop()
        await notificationService.cancelAll()
        audioService.stopSilentAudioLoop()
        audioService.deactivateSession()
        stopWatchUpdateTimer()  // Stop periodic watch updates
        watchService.sendWorkoutStopped()
        currentPreset = nil

        // Reset countdown state if stopped during countdown
        isCountingIn = false
        countdownNumber = nil
    }

    /// Skip to next interval
    func skipForward() {
        engine.skipForward()

        // Send immediate update to Watch with new interval
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(100)) // Wait for engine to update
            sendWatchUpdate()
            print("📱 Sent skip forward update to Watch")
        }
    }

    /// Skip to previous interval
    func skipBackward() {
        engine.skipBackward()

        // Send immediate update to Watch with new interval
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(100)) // Wait for engine to update
            sendWatchUpdate()
            print("📱 Sent skip backward update to Watch")
        }
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

        // Send interval transition to Watch (for sync if Watch app opened mid-workout)
        watchService.sendIntervalTransition(
            intervalTitle: interval.title,
            remainingTime: remainingTime,
            color: interval.colorHex
        )
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
    }

    private func performCountIn() async {
        // Enter countdown mode (triggers UI transition to workout view)
        isCountingIn = true

        // Give audio session a moment to initialize
        try? await Task.sleep(for: .milliseconds(200))

        // Simple count-in: 3, 2, 1
        for count in (1...3).reversed() {
            // Show countdown number visually
            countdownNumber = count

            if voiceEnabled {
                speechService.speak("\(count)", rate: Float(speechRate))
            }
            if hapticsEnabled {
                hapticsService.trigger(pattern: .countIn)
            }
            try? await Task.sleep(for: .seconds(1))
        }

        // Clear countdown number and exit countdown mode
        countdownNumber = nil
        isCountingIn = false
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, secs)
    }

    /// Send current state to Apple Watch (called periodically by timer)
    func sendWatchUpdate() {
        watchService.sendTimerUpdate(
            intervalTitle: currentInterval?.title,
            remainingTime: remainingTime,
            isActive: state.isActive,
            isPaused: state.isPaused,
            color: currentInterval?.colorHex
        )
    }

    /// Send full workout sync to Watch (for late-join scenarios)
    func sendFullWorkoutSync() {
        guard let preset = currentPreset, state.isActive || isCountingIn else {
            // No active workout, just send timer update
            sendWatchUpdate()
            return
        }

        // Send full workout structure so Watch can run autonomously
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
            cycleCount: preset.cycleCount,
            watchHapticsEnabled: presetStore.watchHapticsEnabled,
            currentIntervalIndex: currentIntervalIndex,
            currentCycle: currentCycle,
            remainingTime: remainingTime
        )

        print("📱 Sent full workout sync to Watch (late-join)")
    }

    /// Start timer for periodic watch updates (for late-join sync)
    private func startWatchUpdateTimer() {
        stopWatchUpdateTimer()

        // Update every 10 seconds for late-join scenarios (when Watch app opens mid-workout)
        watchUpdateTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                // Only send updates if there's an active workout
                guard self.state.isActive || self.isCountingIn else { return }
                self.sendWatchUpdate()
            }
        }
        print("⏰ Watch update timer started (10s interval)")
    }

    /// Stop the watch update timer
    private func stopWatchUpdateTimer() {
        watchUpdateTimer?.invalidate()
        watchUpdateTimer = nil
    }
}

// MARK: - Array Extension

extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
