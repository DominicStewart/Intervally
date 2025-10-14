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

    var state: IntervalEngine.State { engine.state }
    var currentInterval: Interval? { engine.currentInterval }
    var nextInterval: Interval? { engine.nextInterval }
    var remainingTime: TimeInterval { engine.remainingTime }
    var elapsedTime: TimeInterval { engine.elapsedTime }
    var progress: Double { engine.progress }
    var currentCycle: Int { engine.currentCycle }
    var totalCycles: Int? { engine.totalCycles }

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
