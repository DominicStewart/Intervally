//
//  RunLoopActivityAttributes.swift
//  RunLoop
//
//  Live Activity attributes for Dynamic Island and Lock Screen.
//  Displays current interval, remaining time, and provides Skip/Pause actions.
//

import Foundation
import ActivityKit
import WidgetKit
import SwiftUI

/// Attributes for RunLoop Live Activity
struct RunLoopActivityAttributes: ActivityAttributes {

    /// Static attributes (set at activity start, never change)
    public struct ContentState: Codable, Hashable {
        /// Current interval title
        var currentIntervalTitle: String

        /// Remaining time in seconds
        var remainingTime: TimeInterval

        /// Current interval colour hex
        var intervalColorHex: String

        /// Is the session paused?
        var isPaused: Bool

        /// Current cycle number
        var currentCycle: Int

        /// Total cycles (nil if infinite)
        var totalCycles: Int?

        /// Next interval title (if available)
        var nextIntervalTitle: String?
    }

    /// Preset name (constant for activity lifetime)
    var presetName: String
}

// MARK: - Live Activity Widget

#if canImport(ActivityKit)

@available(iOS 16.1, *)
struct RunLoopLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RunLoopActivityAttributes.self) { context in
            // Lock Screen / Banner UI
            lockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI (when tapped)
                DynamicIslandExpandedRegion(.leading) {
                    HStack {
                        Circle()
                            .fill(Color(hex: context.state.intervalColorHex))
                            .frame(width: 20, height: 20)

                        Text(context.state.currentIntervalTitle)
                            .font(.headline)
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    Text(formatTime(context.state.remainingTime))
                        .font(.title2)
                        .fontWeight(.bold)
                        .monospacedDigit()
                }

                DynamicIslandExpandedRegion(.center) {
                    if let next = context.state.nextIntervalTitle {
                        Text("Next: \(next)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 16) {
                        Button {
                            // Skip backward action
                        } label: {
                            Image(systemName: "backward.fill")
                                .font(.title3)
                        }
                        .buttonStyle(.bordered)

                        Button {
                            // Pause/Resume action
                        } label: {
                            Image(systemName: context.state.isPaused ? "play.fill" : "pause.fill")
                                .font(.title3)
                        }
                        .buttonStyle(.borderedProminent)

                        Button {
                            // Skip forward action
                        } label: {
                            Image(systemName: "forward.fill")
                                .font(.title3)
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.top, 8)
                }
            } compactLeading: {
                // Compact leading (icon)
                Circle()
                    .fill(Color(hex: context.state.intervalColorHex))
                    .frame(width: 20, height: 20)
            } compactTrailing: {
                // Compact trailing (time)
                Text(formatTime(context.state.remainingTime))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .monospacedDigit()
            } minimal: {
                // Minimal view (just icon)
                Circle()
                    .fill(Color(hex: context.state.intervalColorHex))
            }
        }
    }

    private func lockScreenView(context: ActivityViewContext<RunLoopActivityAttributes>) -> some View {
        VStack(spacing: 12) {
            HStack {
                Circle()
                    .fill(Color(hex: context.state.intervalColorHex))
                    .frame(width: 30, height: 30)

                VStack(alignment: .leading, spacing: 4) {
                    Text(context.state.currentIntervalTitle)
                        .font(.headline)

                    if let next = context.state.nextIntervalTitle {
                        Text("Next: \(next)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(formatTime(context.state.remainingTime))
                        .font(.title2)
                        .fontWeight(.bold)
                        .monospacedDigit()

                    if let total = context.state.totalCycles {
                        Text("Cycle \(context.state.currentCycle)/\(total)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            ProgressView(value: 1.0 - (context.state.remainingTime / 240.0)) // Approximate
                .tint(Color(hex: context.state.intervalColorHex))
        }
        .padding()
        .background(Color.black.opacity(0.8))
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}

#endif

// MARK: - Live Activity Manager

@MainActor
final class LiveActivityManager {

    #if canImport(ActivityKit)
    @available(iOS 16.1, *)
    private var currentActivity: Activity<RunLoopActivityAttributes>?
    #endif

    /// Start a Live Activity
    func start(presetName: String, initialState: RunLoopActivityAttributes.ContentState) async {
        #if canImport(ActivityKit)
        guard #available(iOS 16.1, *) else { return }

        let attributes = RunLoopActivityAttributes(presetName: presetName)

        do {
            let activity = try Activity<RunLoopActivityAttributes>.request(
                attributes: attributes,
                contentState: initialState,
                pushType: nil
            )

            currentActivity = activity
            print("✅ Live Activity started: \(activity.id)")
        } catch {
            print("❌ Failed to start Live Activity: \(error.localizedDescription)")
        }
        #endif
    }

    /// Update the Live Activity state
    func update(state: RunLoopActivityAttributes.ContentState) async {
        #if canImport(ActivityKit)
        guard #available(iOS 16.1, *) else { return }

        guard let activity = currentActivity else { return }

        await activity.update(using: state)
        print("🔄 Live Activity updated")
        #endif
    }

    /// End the Live Activity
    func end() async {
        #if canImport(ActivityKit)
        guard #available(iOS 16.1, *) else { return }

        guard let activity = currentActivity else { return }

        await activity.end(dismissalPolicy: .immediate)
        currentActivity = nil
        print("🛑 Live Activity ended")
        #endif
    }
}
