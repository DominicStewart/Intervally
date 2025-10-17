//
//  Preset.swift
//  RunLoop
//
//  Represents a saved workout preset containing multiple intervals and cycle configuration.
//

import Foundation

/// A workout preset with a collection of intervals and cycle settings
struct Preset: Identifiable, Codable, Equatable, Hashable {
    /// Unique identifier
    var id: UUID

    /// Preset name (e.g., "Run/Walk 4-1", "HIIT Sprint")
    var name: String

    /// Array of intervals in the preset
    var intervals: [Interval]

    /// Number of cycles to repeat (nil = infinite repeat)
    var cycleCount: Int?

    /// Whether to enable HealthKit workout tracking on Apple Watch
    var enableHealthKitWorkout: Bool

    // MARK: - Initializers

    init(
        id: UUID = UUID(),
        name: String,
        intervals: [Interval],
        cycleCount: Int? = nil,
        enableHealthKitWorkout: Bool = true
    ) {
        self.id = id
        self.name = name
        self.intervals = intervals
        self.cycleCount = cycleCount
        self.enableHealthKitWorkout = enableHealthKitWorkout
    }

    // MARK: - Computed Properties

    /// Total duration of one cycle (sum of all interval durations)
    var cycleDuration: TimeInterval {
        intervals.reduce(0) { $0 + $1.duration }
    }

    /// Total workout duration (cycle duration × cycle count)
    /// Returns nil if infinite repeat
    var totalDuration: TimeInterval? {
        guard let count = cycleCount else { return nil }
        return cycleDuration * Double(count)
    }

    /// Formatted total duration string
    var formattedTotalDuration: String {
        guard let duration = totalDuration else {
            return "Infinite"
        }
        return formatTime(duration)
    }

    /// Human-readable cycle description
    var cycleDescription: String {
        if let count = cycleCount {
            return "\(count) cycle\(count == 1 ? "" : "s")"
        } else {
            return "Repeat until stopped"
        }
    }

    /// Number of intervals in the preset
    var intervalCount: Int {
        intervals.count
    }

    /// Validation: preset must have at least 2 intervals
    var isValid: Bool {
        intervals.count >= 2
    }

    // MARK: - Helpers

    private func formatTime(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60

        if minutes >= 60 {
            let hours = minutes / 60
            let mins = minutes % 60
            return String(format: "%d:%02d:%02d", hours, mins, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
    }
}

// MARK: - Sample Data

extension Preset {
    /// Default presets for new users
    static let defaults: [Preset] = [
        Preset(
            name: "Run/Walk 4–1",
            intervals: [
                Interval(
                    title: "Run",
                    duration: 240, // 4:00
                    colorHex: "#FF3B30",
                    voiceCue: "Run"
                ),
                Interval(
                    title: "Walk",
                    duration: 60, // 1:00
                    colorHex: "#34C759",
                    voiceCue: "Walk"
                )
            ],
            cycleCount: 6
        ),
        Preset(
            name: "Run/Walk 2–1",
            intervals: [
                Interval(
                    title: "Run",
                    duration: 120, // 2:00
                    colorHex: "#FF3B30",
                    voiceCue: "Run"
                ),
                Interval(
                    title: "Walk",
                    duration: 60, // 1:00
                    colorHex: "#34C759",
                    voiceCue: "Walk"
                )
            ],
            cycleCount: 10
        ),
        Preset(
            name: "HIIT Sprint",
            intervals: [
                Interval(
                    title: "Sprint",
                    duration: 30, // 0:30
                    colorHex: "#FF9500",
                    voiceCue: "Sprint"
                ),
                Interval(
                    title: "Rest",
                    duration: 90, // 1:30
                    colorHex: "#007AFF",
                    voiceCue: "Rest"
                )
            ],
            cycleCount: 8
        ),
        Preset(
            name: "Interval Training",
            intervals: [
                Interval(
                    title: "Work",
                    duration: 45, // 0:45
                    colorHex: "#FF3B30",
                    voiceCue: "Work"
                ),
                Interval(
                    title: "Recovery",
                    duration: 15, // 0:15
                    colorHex: "#5856D6",
                    voiceCue: "Recover"
                )
            ],
            cycleCount: 12
        ),
        Preset(
            name: "Long Run",
            intervals: [
                Interval(
                    title: "Run",
                    duration: 600, // 10:00
                    colorHex: "#FF3B30",
                    voiceCue: "Run"
                ),
                Interval(
                    title: "Walk",
                    duration: 120, // 2:00
                    colorHex: "#34C759",
                    voiceCue: "Walk"
                )
            ],
            cycleCount: nil // Infinite
        )
    ]

    /// Sample preset for previews
    static let sample = defaults[0]

    /// Empty preset used as sentinel for creating new presets
    static let empty = Preset(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!,
        name: "",
        intervals: [],
        cycleCount: nil
    )
}
