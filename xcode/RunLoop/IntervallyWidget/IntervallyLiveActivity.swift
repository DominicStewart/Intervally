//
//  IntervallyLiveActivity.swift
//  IntervallyWidget
//
//  Live Activity widget for interval timer on Lock Screen and Dynamic Island.
//

import WidgetKit
import SwiftUI
import ActivityKit

struct IntervallyLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: IntervalActivityAttributes.self) { context in
            // Lock screen/banner UI
            LockScreenLiveActivityView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(context.state.intervalTitle)
                            .font(.headline)
                            .foregroundStyle(Color(hex: context.state.intervalColor))
                        Text("\(context.state.currentIntervalIndex + 1)/\(context.state.totalIntervals)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 4) {
                        if context.state.isPaused {
                            Text(timerInterval: context.state.intervalEndDate...context.state.intervalEndDate, pauseTime: Date())
                                .font(.title2)
                                .fontWeight(.bold)
                                .monospacedDigit()
                        } else {
                            Text(timerInterval: Date.now...context.state.intervalEndDate, countsDown: true)
                                .font(.title2)
                                .fontWeight(.bold)
                                .monospacedDigit()
                        }
                        if context.state.isPaused {
                            Text("PAUSED")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                        }
                    }
                }

                DynamicIslandExpandedRegion(.center) {
                    // Progress bar (placeholder)
                    ProgressView(value: 0.5)
                        .tint(Color(hex: context.state.intervalColor))
                }

                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Text(context.attributes.presetName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        if context.state.totalCycles > 1 {
                            Text("Cycle \(context.state.currentCycle)/\(context.state.totalCycles)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } compactLeading: {
                // Compact leading (left side of notch)
                Image(systemName: "figure.run")
                    .foregroundStyle(Color(hex: context.state.intervalColor))
            } compactTrailing: {
                // Compact trailing (right side of notch)
                if context.state.isPaused {
                    Text(timerInterval: context.state.intervalEndDate...context.state.intervalEndDate, pauseTime: Date())
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .monospacedDigit()
                } else {
                    Text(timerInterval: Date.now...context.state.intervalEndDate, countsDown: true)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .monospacedDigit()
                }
            } minimal: {
                // Minimal (when multiple activities)
                Image(systemName: "figure.run")
                    .foregroundStyle(Color(hex: context.state.intervalColor))
            }
        }
    }
}

// MARK: - Lock Screen View

struct LockScreenLiveActivityView: View {
    let context: ActivityViewContext<IntervalActivityAttributes>

    var body: some View {
        HStack(spacing: 16) {
            // Left side - interval info
            VStack(alignment: .leading, spacing: 4) {
                Text(context.attributes.presetName)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(context.state.intervalTitle)
                    .font(.headline)
                    .foregroundStyle(Color(hex: context.state.intervalColor))

                HStack(spacing: 4) {
                    Text("Interval \(context.state.currentIntervalIndex + 1)/\(context.state.totalIntervals)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    if context.state.totalCycles > 1 {
                        Text("• Cycle \(context.state.currentCycle)/\(context.state.totalCycles)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            // Right side - timer
            VStack(alignment: .trailing, spacing: 4) {
                if context.state.isPaused {
                    Text(timerInterval: context.state.intervalEndDate...context.state.intervalEndDate, pauseTime: Date())
                        .font(.title)
                        .fontWeight(.bold)
                        .monospacedDigit()
                } else {
                    Text(timerInterval: Date.now...context.state.intervalEndDate, countsDown: true)
                        .font(.title)
                        .fontWeight(.bold)
                        .monospacedDigit()
                }

                if context.state.isPaused {
                    Text("PAUSED")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
        .padding()
        .activityBackgroundTint(Color(hex: context.state.intervalColor).opacity(0.1))
        .activitySystemActionForegroundColor(Color(hex: context.state.intervalColor))
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let scanner = Scanner(string: hex)
        var rgbValue: UInt64 = 0

        scanner.scanHexInt64(&rgbValue)

        let r = Double((rgbValue & 0xFF0000) >> 16) / 255.0
        let g = Double((rgbValue & 0x00FF00) >> 8) / 255.0
        let b = Double(rgbValue & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b)
    }
}
