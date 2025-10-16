//
//  IntervalActivityAttributes.swift
//  RunLoop
//
//  Defines the Live Activity data structure for Dynamic Island and Lock Screen.
//

import Foundation
#if canImport(ActivityKit)
import ActivityKit

/// Attributes for the interval timer Live Activity
struct IntervalActivityAttributes: ActivityAttributes {

    // Dynamic state that changes during the workout
    public struct ContentState: Codable, Hashable {
        var intervalTitle: String
        var intervalEndDate: Date
        var intervalColor: String
        var isPaused: Bool
        var currentIntervalIndex: Int
        var totalIntervals: Int
        var currentCycle: Int
        var totalCycles: Int
        var updateTimestamp: Date  // Force updates to be unique
    }

    // Fixed data for the activity (set once, never changes)
    var presetName: String
}
#endif
