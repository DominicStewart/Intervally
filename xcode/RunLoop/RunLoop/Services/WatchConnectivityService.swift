//
//  WatchConnectivityService.swift
//  RunLoop
//
//  Manages communication between iPhone and Apple Watch.
//

import Foundation
import Combine
import WatchConnectivity

/// Service for communicating with Apple Watch
@MainActor
final class WatchConnectivityService: NSObject, ObservableObject {

    static let shared = WatchConnectivityService()

    private override init() {
        super.init()

        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
            print("✅ Watch Connectivity activated")
        }
    }

    // MARK: - Send Data to Watch

    /// Send interval transition to watch (requires watch app to be open for haptic)
    func sendIntervalTransition(intervalTitle: String, remainingTime: TimeInterval, color: String) {
        guard WCSession.default.activationState == .activated else { return }

        let message: [String: Any] = [
            "type": "intervalTransition",
            "intervalTitle": intervalTitle,
            "remainingTime": remainingTime,
            "color": color
        ]

        // Try to send message for immediate haptic (only works if watch app is reachable)
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(message, replyHandler: nil) { error in
                print("⚠️ Failed to send immediate interval message: \(error.localizedDescription)")
            }
            print("📲 Interval transition (immediate): \(intervalTitle)")
        } else {
            print("⚠️ Watch not reachable, using context update for interval transition")
        }

        // ALWAYS update context as well for reliability (in case immediate message fails)
        let context: [String: Any] = [
            "intervalTitle": intervalTitle,
            "remainingTime": remainingTime,
            "isActive": true,
            "isPaused": false,
            "color": color,
            "timestamp": Date().timeIntervalSince1970
        ]

        do {
            try WCSession.default.updateApplicationContext(context)
            print("📲 Interval transition (context): \(intervalTitle)")
        } catch {
            print("❌ Failed to update context for interval: \(error.localizedDescription)")
        }
    }

    /// Send timer state update to watch
    func sendTimerUpdate(
        intervalTitle: String?,
        remainingTime: TimeInterval,
        isActive: Bool,
        isPaused: Bool,
        color: String?
    ) {
        guard WCSession.default.activationState == .activated else { return }

        let context: [String: Any] = [
            "intervalTitle": intervalTitle ?? "",
            "remainingTime": remainingTime,
            "isActive": isActive,
            "isPaused": isPaused,
            "color": color ?? "#007AFF",
            "timestamp": Date().timeIntervalSince1970
        ]

        do {
            try WCSession.default.updateApplicationContext(context)
            print("📲 Updated watch context")
        } catch {
            print("❌ Failed to update watch context: \(error.localizedDescription)")
        }
    }

    /// Send workout started event with full workout structure
    func sendWorkoutStarted(presetName: String, intervals: [[String: Any]], cycleCount: Int?) {
        guard WCSession.default.activationState == .activated else {
            print("❌ WCSession not activated, state: \(WCSession.default.activationState.rawValue)")
            return
        }

        print("📱 iPhone WCSession state:")
        print("   - isPaired: \(WCSession.default.isPaired)")
        print("   - isWatchAppInstalled: \(WCSession.default.isWatchAppInstalled)")
        print("   - isReachable: \(WCSession.default.isReachable)")
        print("   - activationState: \(WCSession.default.activationState.rawValue)")

        var message: [String: Any] = [
            "type": "workoutStarted",
            "presetName": presetName,
            "intervals": intervals,
            "startTime": Date().timeIntervalSince1970
        ]

        if let cycleCount = cycleCount {
            message["cycleCount"] = cycleCount
        }

        // Try immediate message first
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(message, replyHandler: nil) { error in
                print("⚠️ Failed to send workout started message: \(error.localizedDescription)")
            }
            print("📲 Workout started (immediate): \(presetName)")
        }

        // Also send via context for reliability
        do {
            try WCSession.default.updateApplicationContext(message)
            print("📲 Workout started (context): \(presetName)")
        } catch {
            print("❌ Failed to send workout context: \(error.localizedDescription)")
        }
    }

    /// Send workout stopped event
    func sendWorkoutStopped() {
        guard WCSession.default.activationState == .activated else { return }

        // Send immediate message to stop workout session
        let message: [String: Any] = [
            "type": "workoutStopped"
        ]

        WCSession.default.sendMessage(message, replyHandler: nil) { _ in
            // Silently ignore if watch app not open
        }

        // Also update context for consistency
        let context: [String: Any] = [
            "intervalTitle": "",
            "remainingTime": 0.0,
            "isActive": false,
            "isPaused": false,
            "color": "#007AFF"
        ]

        do {
            try WCSession.default.updateApplicationContext(context)
            print("📲 Sent workout stopped to watch")
        } catch {
            print("❌ Failed to send workout stopped: \(error.localizedDescription)")
        }
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityService: WCSessionDelegate {

    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        if let error = error {
            print("❌ Watch session activation failed: \(error.localizedDescription)")
        } else {
            print("✅ Watch session activated: \(activationState.rawValue)")
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {
        print("⚠️ Watch session became inactive")
    }

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        print("⚠️ Watch session deactivated")
        session.activate()
    }
}
