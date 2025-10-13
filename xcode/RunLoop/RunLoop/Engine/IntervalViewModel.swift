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
    private var currentPreset: Preset?

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
            .sink { [weak self] value in self?.state = value }
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

        // Count-in if enabled
        if countInEnabled {
            await performCountIn()
        }

        // Start engine
        engine.start(preset: preset)

        // Schedule notifications for all boundaries
        if case .running(_, let timeline) = engine.state {
            await scheduleNotifications(for: timeline)
        }
    }

    /// Pause the current session
    func pause() async {
        engine.pause()
        await notificationService.cancelAll()
    }

    /// Resume the paused session
    func resume() async {
        engine.resume()

        // Reschedule notifications
        if case .running(_, let timeline) = engine.state {
            await scheduleNotifications(for: timeline)
        }
    }

    /// Stop the current session
    func stop() async {
        engine.stop()
        await notificationService.cancelAll()
        audioService.deactivateSession()
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
        audioService.deactivateSession()
    }

    private func scheduleNotifications(for timeline: IntervalEngine.Timeline) async {
        await notificationService.cancelAll()

        // Schedule notifications for upcoming boundaries (limit to 50 to respect iOS limit)
        let boundariesToSchedule = Array(timeline.boundaries.prefix(50))

        for boundary in boundariesToSchedule {
            let nextBoundary = timeline.boundaries[safe: boundary.intervalIndex + 1]
            let nextTitle = nextBoundary?.interval.title ?? "Finished"

            await notificationService.scheduleIntervalNotification(
                at: boundary.date,
                title: boundary.interval.title,
                subtitle: "Next: \(nextTitle)",
                identifier: boundary.date.ISO8601Format()
            )
        }
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
}

// MARK: - Array Extension

extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
