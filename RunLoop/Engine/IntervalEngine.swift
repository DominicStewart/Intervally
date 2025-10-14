//
//  IntervalEngine.swift
//  RunLoop
//
//  Core state machine for managing interval timer sessions.
//  Uses absolute timeline scheduling for drift-free accuracy.
//

import Foundation
import Combine

/// Core interval timer engine with state machine and absolute timeline
@MainActor
final class IntervalEngine: ObservableObject {

    // MARK: - State

    enum State: Equatable {
        case idle
        case running(startDate: Date, timeline: Timeline)
        case paused(elapsed: TimeInterval, timeline: Timeline)
        case finished

        var isRunning: Bool {
            if case .running = self { return true }
            return false
        }

        var isPaused: Bool {
            if case .paused = self { return true }
            return false
        }

        var isActive: Bool {
            isRunning || isPaused
        }
    }

    /// Timeline: absolute boundary dates for each interval
    struct Timeline: Equatable {
        struct Boundary: Equatable {
            let date: Date
            let intervalIndex: Int
            let cycleIndex: Int
            let interval: Interval
        }

        let boundaries: [Boundary]
        let preset: Preset
        let startDate: Date

        /// Find current boundary index for a given date
        func currentBoundaryIndex(at date: Date) -> Int {
            // Find the first boundary that is in the future
            for (index, boundary) in boundaries.enumerated() {
                if date < boundary.date {
                    return index
                }
            }
            // Past all boundaries
            return boundaries.count
        }

        /// Get current interval info at a given date
        func currentInterval(at date: Date) -> (interval: Interval, boundaryIndex: Int, isFinished: Bool)? {
            let boundaryIndex = currentBoundaryIndex(at: date)

            if boundaryIndex == 0 {
                // Before first boundary - we're in the first interval
                return (preset.intervals[0], 0, false)
            } else if boundaryIndex >= boundaries.count {
                // Past all boundaries - finished
                return nil
            } else {
                // Between boundaries - we're in the interval that ends at boundaryIndex
                let boundary = boundaries[boundaryIndex]
                return (boundary.interval, boundaryIndex, false)
            }
        }

        /// Calculate remaining time in current interval
        func remainingTime(at date: Date) -> TimeInterval {
            let boundaryIndex = currentBoundaryIndex(at: date)

            if boundaryIndex >= boundaries.count {
                return 0
            }

            let boundary = boundaries[boundaryIndex]
            return boundary.date.timeIntervalSince(date)
        }

        /// Total elapsed time from start
        func elapsedTime(at date: Date) -> TimeInterval {
            date.timeIntervalSince(startDate)
        }

        /// Progress within current interval (0.0 to 1.0)
        func progress(at date: Date) -> Double {
            guard let info = currentInterval(at: date) else { return 1.0 }

            let boundaryIndex = info.boundaryIndex
            let interval = info.interval

            // Calculate start time of current interval
            let intervalStart: Date
            if boundaryIndex == 0 {
                intervalStart = startDate
            } else {
                intervalStart = boundaries[boundaryIndex - 1].date
            }

            let intervalEnd = boundaries[boundaryIndex].date
            let elapsed = date.timeIntervalSince(intervalStart)
            let duration = intervalEnd.timeIntervalSince(intervalStart)

            return min(max(elapsed / duration, 0.0), 1.0)
        }
    }

    // MARK: - Published State

    @Published private(set) var state: State = .idle
    @Published private(set) var currentInterval: Interval?
    @Published private(set) var nextInterval: Interval?
    @Published private(set) var remainingTime: TimeInterval = 0
    @Published private(set) var elapsedTime: TimeInterval = 0
    @Published private(set) var progress: Double = 0
    @Published private(set) var currentCycle: Int = 0
    @Published private(set) var totalCycles: Int? = nil

    // MARK: - Private Properties

    private var timer: Timer?
    private var lastBoundaryIndex: Int = -1

    /// Callback when transitioning to a new interval
    var onIntervalTransition: ((Interval, Int, Int) -> Void)?

    /// Callback when session finishes
    var onSessionFinish: (() -> Void)?

    // MARK: - Public Methods

    /// Start a new session with the given preset
    func start(preset: Preset) {
        guard preset.isValid else {
            print("⚠️ Cannot start: preset has fewer than 2 intervals")
            return
        }

        let now = Date.now
        let timeline = buildTimeline(preset: preset, startDate: now)

        state = .running(startDate: now, timeline: timeline)
        totalCycles = preset.cycleCount
        lastBoundaryIndex = -1

        startTimer()
        tick() // Immediate update
    }

    /// Pause the current session
    func pause() {
        guard case .running(let startDate, let timeline) = state else { return }

        let now = Date.now
        let elapsed = now.timeIntervalSince(startDate)

        stopTimer()
        state = .paused(elapsed: elapsed, timeline: timeline)
    }

    /// Resume a paused session
    func resume() {
        guard case .paused(let elapsed, let timeline) = state else { return }

        // Rebuild timeline with adjusted start date
        let now = Date.now
        let adjustedStartDate = now.addingTimeInterval(-elapsed)

        let newTimeline = Timeline(
            boundaries: timeline.boundaries.map { boundary in
                Timeline.Boundary(
                    date: boundary.date.addingTimeInterval(now.timeIntervalSince(timeline.startDate) - elapsed),
                    intervalIndex: boundary.intervalIndex,
                    cycleIndex: boundary.cycleIndex,
                    interval: boundary.interval
                )
            },
            preset: timeline.preset,
            startDate: adjustedStartDate
        )

        state = .running(startDate: adjustedStartDate, timeline: newTimeline)
        startTimer()
        tick()
    }

    /// Stop the session
    func stop() {
        stopTimer()
        state = .idle
        currentInterval = nil
        nextInterval = nil
        remainingTime = 0
        elapsedTime = 0
        progress = 0
        currentCycle = 0
        totalCycles = nil
        lastBoundaryIndex = -1
    }

    /// Skip to the next interval
    func skipForward() {
        guard case .running(let startDate, let timeline) = state else { return }

        let now = Date.now
        let boundaryIndex = timeline.currentBoundaryIndex(at: now)

        guard boundaryIndex < timeline.boundaries.count else {
            // Already at the last interval
            finish()
            return
        }

        // Jump to the next boundary
        let nextBoundary = timeline.boundaries[boundaryIndex]
        let timeToSkip = nextBoundary.date.timeIntervalSince(now)

        // Adjust timeline by moving all boundaries backward
        let newTimeline = Timeline(
            boundaries: timeline.boundaries.map { boundary in
                Timeline.Boundary(
                    date: boundary.date.addingTimeInterval(-timeToSkip),
                    intervalIndex: boundary.intervalIndex,
                    cycleIndex: boundary.cycleIndex,
                    interval: boundary.interval
                )
            },
            preset: timeline.preset,
            startDate: startDate.addingTimeInterval(-timeToSkip)
        )

        state = .running(startDate: startDate.addingTimeInterval(-timeToSkip), timeline: newTimeline)
        tick()

        // Trigger transition callback
        if let info = newTimeline.currentInterval(at: now) {
            let boundary = newTimeline.boundaries[info.boundaryIndex]
            onIntervalTransition?(info.interval, boundary.intervalIndex, boundary.cycleIndex)
        }
    }

    /// Skip to the previous interval
    func skipBackward() {
        guard case .running(let startDate, let timeline) = state else { return }

        let now = Date.now
        let boundaryIndex = timeline.currentBoundaryIndex(at: now)

        // If we're in the first interval, restart it
        if boundaryIndex <= 1 {
            // Restart the session
            let newStartDate = now
            let newTimeline = buildTimeline(preset: timeline.preset, startDate: newStartDate)
            state = .running(startDate: newStartDate, timeline: newTimeline)
            lastBoundaryIndex = -1
            tick()
            return
        }

        // Jump back to the previous interval's start
        let previousBoundary = timeline.boundaries[boundaryIndex - 2]
        let timeToRewind = now.timeIntervalSince(previousBoundary.date)

        // Adjust timeline by moving all boundaries forward
        let newTimeline = Timeline(
            boundaries: timeline.boundaries.map { boundary in
                Timeline.Boundary(
                    date: boundary.date.addingTimeInterval(timeToRewind),
                    intervalIndex: boundary.intervalIndex,
                    cycleIndex: boundary.cycleIndex,
                    interval: boundary.interval
                )
            },
            preset: timeline.preset,
            startDate: startDate.addingTimeInterval(timeToRewind)
        )

        state = .running(startDate: startDate.addingTimeInterval(timeToRewind), timeline: newTimeline)
        lastBoundaryIndex = boundaryIndex - 2
        tick()

        // Trigger transition callback
        if let info = newTimeline.currentInterval(at: now) {
            let boundary = newTimeline.boundaries[info.boundaryIndex]
            onIntervalTransition?(info.interval, boundary.intervalIndex, boundary.cycleIndex)
        }
    }

    // MARK: - Private Methods

    private func startTimer() {
        // Use a high-frequency timer for smooth UI updates
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
        timer?.tolerance = 0.01
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        guard case .running(_, let timeline) = state else { return }

        let now = Date.now

        // Update current interval and remaining time
        if let info = timeline.currentInterval(at: now) {
            currentInterval = info.interval
            remainingTime = timeline.remainingTime(at: now)
            elapsedTime = timeline.elapsedTime(at: now)
            progress = timeline.progress(at: now)

            let boundaryIndex = info.boundaryIndex
            let boundary = timeline.boundaries[boundaryIndex]

            currentCycle = boundary.cycleIndex + 1

            // Determine next interval
            if boundaryIndex + 1 < timeline.boundaries.count {
                nextInterval = timeline.boundaries[boundaryIndex + 1].interval
            } else {
                nextInterval = nil
            }

            // Check for boundary crossing
            if boundaryIndex != lastBoundaryIndex {
                lastBoundaryIndex = boundaryIndex

                // Trigger transition callback
                onIntervalTransition?(info.interval, boundary.intervalIndex, boundary.cycleIndex)
            }
        } else {
            // Session finished
            finish()
        }
    }

    private func finish() {
        stopTimer()
        state = .finished
        currentInterval = nil
        nextInterval = nil
        remainingTime = 0
        progress = 1.0

        onSessionFinish?()
    }

    /// Build absolute timeline from preset
    private func buildTimeline(preset: Preset, startDate: Date) -> Timeline {
        var boundaries: [Timeline.Boundary] = []
        var currentDate = startDate

        let cycles = preset.cycleCount ?? 1000 // Arbitrary large number for infinite
        let actualCycles = min(cycles, 1000) // Cap to prevent memory issues

        for cycle in 0..<actualCycles {
            for (index, interval) in preset.intervals.enumerated() {
                currentDate = currentDate.addingTimeInterval(interval.duration)

                boundaries.append(
                    Timeline.Boundary(
                        date: currentDate,
                        intervalIndex: index,
                        cycleIndex: cycle,
                        interval: interval
                    )
                )
            }
        }

        return Timeline(boundaries: boundaries, preset: preset, startDate: startDate)
    }
}
