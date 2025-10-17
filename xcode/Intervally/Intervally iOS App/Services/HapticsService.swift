//
//  HapticsService.swift
//  RunLoop
//
//  Manages haptic feedback for interval transitions and events.
//

import Foundation
import UIKit
import CoreHaptics

/// Service for triggering haptic feedback
final class HapticsService {

    // MARK: - Haptic Patterns

    enum Pattern {
        case intervalTransition
        case sessionComplete
        case countIn
        case skip
    }

    // MARK: - Properties

    private var hapticEngine: CHHapticEngine?
    private let impactGenerator = UIImpactFeedbackGenerator(style: .heavy)
    private let notificationGenerator = UINotificationFeedbackGenerator()

    // MARK: - Initialization

    init() {
        setupHapticEngine()
        impactGenerator.prepare()
        notificationGenerator.prepare()
    }

    // MARK: - Public Methods

    /// Trigger haptic feedback for the given pattern
    func trigger(pattern: Pattern) {
        switch pattern {
        case .intervalTransition:
            triggerIntervalTransition()
        case .sessionComplete:
            triggerSessionComplete()
        case .countIn:
            triggerCountIn()
        case .skip:
            triggerSkip()
        }
    }

    // MARK: - Private Methods

    private func setupHapticEngine() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else {
            print("⚠️ Device does not support haptics")
            return
        }

        do {
            hapticEngine = try CHHapticEngine()
            try hapticEngine?.start()
            print("✅ Haptic engine initialized")
        } catch {
            print("❌ Failed to initialize haptic engine: \(error.localizedDescription)")
        }
    }

    // MARK: - Haptic Patterns

    private func triggerIntervalTransition() {
        // Double tap pattern for interval transitions
        let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0)
        let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0)

        let event1 = CHHapticEvent(eventType: .hapticTransient, parameters: [intensity, sharpness], relativeTime: 0)
        let event2 = CHHapticEvent(eventType: .hapticTransient, parameters: [intensity, sharpness], relativeTime: 0.1)

        playHapticPattern(events: [event1, event2])
    }

    private func triggerSessionComplete() {
        // Success pattern: three increasing taps
        notificationGenerator.notificationOccurred(.success)
    }

    private func triggerCountIn() {
        // Single medium tap
        impactGenerator.impactOccurred(intensity: 0.7)
    }

    private func triggerSkip() {
        // Light single tap
        impactGenerator.impactOccurred(intensity: 0.5)
    }

    private func playHapticPattern(events: [CHHapticEvent]) {
        guard let engine = hapticEngine else {
            // Fallback to impact generator
            impactGenerator.impactOccurred()
            return
        }

        do {
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            print("❌ Failed to play haptic pattern: \(error.localizedDescription)")
            impactGenerator.impactOccurred()
        }
    }
}
