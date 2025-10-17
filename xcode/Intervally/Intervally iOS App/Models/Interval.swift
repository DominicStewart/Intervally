//
//  Interval.swift
//  RunLoop
//
//  Represents a single interval in a workout session.
//  Each interval has a title, duration, colour, and optional voice cue.
//

import Foundation
import SwiftUI

/// A single interval in a workout preset
struct Interval: Identifiable, Codable, Equatable, Hashable {
    /// Unique identifier
    var id: UUID

    /// Display name (e.g., "Run", "Walk", "Sprint")
    var title: String

    /// Duration in seconds
    var duration: TimeInterval

    /// Hex colour string for visual identification (e.g., "#FF5733")
    var colorHex: String

    /// Optional voice cue text to announce when interval starts
    /// If nil, uses the title
    var voiceCue: String?

    // MARK: - Initializers

    init(
        id: UUID = UUID(),
        title: String,
        duration: TimeInterval,
        colorHex: String = "#007AFF",
        voiceCue: String? = nil
    ) {
        self.id = id
        self.title = title
        self.duration = duration
        self.colorHex = colorHex
        self.voiceCue = voiceCue
    }

    // MARK: - Computed Properties

    /// SwiftUI Color from hex string
    var color: Color {
        Color(hex: colorHex)
    }

    /// Voice announcement text (uses voiceCue if set, otherwise title)
    var announcement: String {
        voiceCue ?? title
    }

    /// Formatted duration string (mm:ss)
    var formattedDuration: String {
        formatTime(duration)
    }

    // MARK: - Helpers

    private func formatTime(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}

// MARK: - Color Extension for Hex Support

extension Color {
    /// Initialize Color from hex string (e.g., "#FF5733" or "FF5733")
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

    /// Convert Color to hex string
    func toHex() -> String? {
        guard let components = UIColor(self).cgColor.components,
              components.count >= 3 else {
            return nil
        }

        let r = Int(components[0] * 255.0)
        let g = Int(components[1] * 255.0)
        let b = Int(components[2] * 255.0)

        return String(format: "#%02X%02X%02X", r, g, b)
    }
}

// MARK: - Sample Data

extension Interval {
    /// Sample intervals for previews and testing
    static let samples: [Interval] = [
        Interval(
            title: "Run",
            duration: 240, // 4:00
            colorHex: "#FF3B30", // Red
            voiceCue: "Run"
        ),
        Interval(
            title: "Walk",
            duration: 60, // 1:00
            colorHex: "#34C759", // Green
            voiceCue: "Walk"
        ),
        Interval(
            title: "Sprint",
            duration: 30, // 0:30
            colorHex: "#FF9500", // Orange
            voiceCue: "Sprint"
        ),
        Interval(
            title: "Rest",
            duration: 90, // 1:30
            colorHex: "#007AFF", // Blue
            voiceCue: "Rest"
        )
    ]
}
