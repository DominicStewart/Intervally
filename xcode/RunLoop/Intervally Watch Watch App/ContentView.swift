//
//  ContentView.swift
//  Intervally Watch
//
//  Main watch app interface showing current interval and timer.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var connectivity: WatchConnectivityManager
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    var body: some View {
        VStack(spacing: 8) {
            if connectivity.isActive {
                // Active workout display
                VStack(spacing: 12) {
                    // Workout active indicator
                    if connectivity.workoutManager.isWorkoutActive {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(.green)
                                .frame(width: 8, height: 8)
                            Text("LIVE")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Interval name
                    Text(connectivity.currentInterval)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(Color(hex: connectivity.intervalColor))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    // Timer
                    Text(connectivity.formattedTime)
                        .font(.system(size: 52, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Color(hex: connectivity.intervalColor))

                    // Status indicators
                    if connectivity.isPaused {
                        Text("PAUSED")
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(Color.orange.opacity(0.2))
                            .clipShape(Capsule())
                    }
                }
            } else {
                // Idle state
                VStack(spacing: 12) {
                    Image(systemName: "figure.run")
                        .font(.system(size: 50))
                        .foregroundStyle(.blue)
                        .symbolEffect(.pulse)

                    Text("Intervally")
                        .font(.title3)
                        .fontWeight(.semibold)

                    Text("Start a workout on your iPhone")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: isLuminanceReduced) { oldValue, newValue in
            print("⌚️ isLuminanceReduced changed: \(oldValue) -> \(newValue)")
            print("⌚️ HealthKit active: \(connectivity.workoutManager.isWorkoutActive)")
            print("⌚️ Workout active: \(connectivity.isActive)")
            connectivity.setAlwaysOnMode(newValue)
        }
        .onAppear {
            print("⌚️ ContentView appeared")

            // TEMPORARILY DISABLED: Always-On session causes HealthKit state corruption
            // We'll re-enable this after fixing the underlying HealthKit issue
            // For now, the app will close when wrist is lowered, but workouts will work correctly

            // if !connectivity.workoutManager.isWorkoutActive && !connectivity.workoutManager.isStartingWorkout {
            //     connectivity.workoutManager.startWorkout(presetName: "Interval Training")
            //     print("⌚️ Started Always-On session for idle screen")
            // } else if connectivity.workoutManager.isStartingWorkout {
            //     print("⌚️ Workout already starting - skipping duplicate onAppear")
            // }

            // Request sync from iPhone in case we're joining mid-workout
            connectivity.requestSyncFromiPhone()

            // Set initial Always-On state
            print("⌚️ Initial isLuminanceReduced value: \(isLuminanceReduced)")
            connectivity.setAlwaysOnMode(isLuminanceReduced)
        }
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
