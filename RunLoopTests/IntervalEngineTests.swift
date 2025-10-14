//
//  IntervalEngineTests.swift
//  RunLoopTests
//
//  Unit tests for IntervalEngine core logic.
//  Tests timeline calculation, pause/resume, skip, and drift handling.
//

import XCTest
@testable import RunLoop

@MainActor
final class IntervalEngineTests: XCTestCase {

    var engine: IntervalEngine!

    override func setUp() async throws {
        engine = IntervalEngine()
    }

    override func tearDown() async throws {
        engine = nil
    }

    // MARK: - Basic Timeline Tests

    func testTimelineCreation_WithFiniteCycles() async throws {
        // Given: A preset with 2 intervals and 3 cycles
        let preset = Preset(
            name: "Test",
            intervals: [
                Interval(title: "Run", duration: 60),
                Interval(title: "Walk", duration: 30)
            ],
            cycleCount: 3
        )

        // When: Starting the engine
        engine.start(preset: preset)

        // Then: Timeline should have 6 boundaries (2 intervals × 3 cycles)
        if case .running(_, let timeline) = engine.state {
            XCTAssertEqual(timeline.boundaries.count, 6)

            // Verify first boundary
            let firstBoundary = timeline.boundaries[0]
            XCTAssertEqual(firstBoundary.intervalIndex, 0)
            XCTAssertEqual(firstBoundary.cycleIndex, 0)
            XCTAssertEqual(firstBoundary.interval.title, "Run")

            // Verify last boundary
            let lastBoundary = timeline.boundaries[5]
            XCTAssertEqual(lastBoundary.intervalIndex, 1)
            XCTAssertEqual(lastBoundary.cycleIndex, 2)
            XCTAssertEqual(lastBoundary.interval.title, "Walk")

            // Verify timing: first boundary should be 60s after start
            let expectedFirstBoundary = timeline.startDate.addingTimeInterval(60)
            XCTAssertEqual(firstBoundary.date.timeIntervalSince1970, expectedFirstBoundary.timeIntervalSince1970, accuracy: 0.1)

            // Verify total duration: (60 + 30) × 3 = 270s
            let lastBoundaryOffset = lastBoundary.date.timeIntervalSince(timeline.startDate)
            XCTAssertEqual(lastBoundaryOffset, 270, accuracy: 0.1)
        } else {
            XCTFail("Engine should be in running state")
        }
    }

    func testTimelineCreation_WithInfiniteCycles() async throws {
        // Given: A preset with infinite cycles
        let preset = Preset(
            name: "Infinite",
            intervals: [
                Interval(title: "Work", duration: 45),
                Interval(title: "Rest", duration: 15)
            ],
            cycleCount: nil
        )

        // When: Starting the engine
        engine.start(preset: preset)

        // Then: Timeline should have many boundaries (capped at 2000 = 1000 cycles × 2 intervals)
        if case .running(_, let timeline) = engine.state {
            XCTAssertEqual(timeline.boundaries.count, 2000)
        } else {
            XCTFail("Engine should be in running state")
        }
    }

    // MARK: - Current Interval Tests

    func testCurrentInterval_AtStart() async throws {
        // Given: A started preset
        let preset = createSimplePreset()
        engine.start(preset: preset)

        // Then: Current interval should be the first one
        XCTAssertEqual(engine.currentInterval?.title, "Run")
        XCTAssertEqual(engine.currentCycle, 1)
    }

    func testCurrentInterval_MidInterval() async throws {
        // Given: A started preset
        let preset = createSimplePreset()
        engine.start(preset: preset)

        // When: Time passes
        try await Task.sleep(for: .milliseconds(100))

        // Then: Still in first interval
        XCTAssertEqual(engine.currentInterval?.title, "Run")
        XCTAssertLessThan(engine.remainingTime, 240) // Less than original 240s
        XCTAssertGreaterThan(engine.remainingTime, 239) // But not much less
    }

    // MARK: - Pause/Resume Tests

    func testPauseAndResume() async throws {
        // Given: A running preset
        let preset = createSimplePreset()
        engine.start(preset: preset)

        // Wait a bit
        try await Task.sleep(for: .milliseconds(100))
        let remainingBeforePause = engine.remainingTime

        // When: Pausing
        engine.pause()

        // Then: State should be paused
        XCTAssertTrue(engine.state.isPaused)

        // When: Waiting while paused
        try await Task.sleep(for: .milliseconds(200))

        // Then: Remaining time should not change
        XCTAssertEqual(engine.remainingTime, remainingBeforePause, accuracy: 0.1)

        // When: Resuming
        engine.resume()

        // Then: State should be running again
        XCTAssertTrue(engine.state.isRunning)

        // Wait a bit more
        try await Task.sleep(for: .milliseconds(100))

        // Remaining time should continue from where it left off
        XCTAssertLessThan(engine.remainingTime, remainingBeforePause)
    }

    // MARK: - Skip Tests

    func testSkipForward() async throws {
        // Given: A running preset
        let preset = createSimplePreset()
        engine.start(preset: preset)

        let initialInterval = engine.currentInterval?.title

        // When: Skipping forward
        engine.skipForward()

        // Give the engine a moment to update
        try await Task.sleep(for: .milliseconds(50))

        // Then: Should be in next interval
        XCTAssertNotEqual(engine.currentInterval?.title, initialInterval)
        XCTAssertEqual(engine.currentInterval?.title, "Walk")
    }

    func testSkipBackward_FromSecondInterval() async throws {
        // Given: A running preset in second interval
        let preset = createSimplePreset()
        engine.start(preset: preset)

        // Skip to second interval
        engine.skipForward()
        try await Task.sleep(for: .milliseconds(50))

        XCTAssertEqual(engine.currentInterval?.title, "Walk")

        // When: Skipping backward
        engine.skipBackward()
        try await Task.sleep(for: .milliseconds(50))

        // Then: Should be back in first interval
        XCTAssertEqual(engine.currentInterval?.title, "Run")
    }

    func testSkipBackward_FromFirstInterval() async throws {
        // Given: A running preset in first interval
        let preset = createSimplePreset()
        engine.start(preset: preset)

        // When: Skipping backward from first interval
        engine.skipBackward()
        try await Task.sleep(for: .milliseconds(50))

        // Then: Should restart first interval
        XCTAssertEqual(engine.currentInterval?.title, "Run")
        XCTAssertEqual(engine.remainingTime, 240, accuracy: 1.0) // Near full duration
    }

    // MARK: - Stop Tests

    func testStop() async throws {
        // Given: A running preset
        let preset = createSimplePreset()
        engine.start(preset: preset)

        XCTAssertTrue(engine.state.isActive)

        // When: Stopping
        engine.stop()

        // Then: State should be idle
        if case .idle = engine.state {
            XCTAssertTrue(true)
        } else {
            XCTFail("Engine should be in idle state")
        }

        XCTAssertNil(engine.currentInterval)
        XCTAssertEqual(engine.remainingTime, 0)
        XCTAssertEqual(engine.elapsedTime, 0)
    }

    // MARK: - Transition Callback Tests

    func testIntervalTransitionCallback() async throws {
        // Given: A preset with short intervals
        let preset = Preset(
            name: "Fast",
            intervals: [
                Interval(title: "First", duration: 0.1),
                Interval(title: "Second", duration: 0.1)
            ],
            cycleCount: 1
        )

        var transitionCalled = false
        var transitionInterval: String?

        engine.onIntervalTransition = { interval, _, _ in
            transitionCalled = true
            transitionInterval = interval.title
        }

        // When: Starting and waiting for transition
        engine.start(preset: preset)

        // Then: Initial transition should be called
        try await Task.sleep(for: .milliseconds(50))
        XCTAssertTrue(transitionCalled)
        XCTAssertEqual(transitionInterval, "First")

        // Reset
        transitionCalled = false

        // Wait for second transition
        try await Task.sleep(for: .milliseconds(120))

        // Should transition to second interval
        XCTAssertTrue(transitionCalled)
        XCTAssertEqual(transitionInterval, "Second")
    }

    func testSessionFinishCallback() async throws {
        // Given: A preset with very short duration
        let preset = Preset(
            name: "Quick",
            intervals: [
                Interval(title: "Only", duration: 0.1)
            ],
            cycleCount: 1
        )

        var finishCalled = false
        engine.onSessionFinish = {
            finishCalled = true
        }

        // When: Starting and waiting for finish
        engine.start(preset: preset)
        try await Task.sleep(for: .milliseconds(200))

        // Then: Finish callback should be called
        XCTAssertTrue(finishCalled)

        if case .finished = engine.state {
            XCTAssertTrue(true)
        } else {
            XCTFail("Engine should be in finished state")
        }
    }

    // MARK: - Progress Tests

    func testProgress_IncreasesOverTime() async throws {
        // Given: A running preset
        let preset = createSimplePreset()
        engine.start(preset: preset)

        let initialProgress = engine.progress

        // When: Time passes
        try await Task.sleep(for: .milliseconds(100))

        // Then: Progress should increase
        XCTAssertGreaterThan(engine.progress, initialProgress)
        XCTAssertLessThanOrEqual(engine.progress, 1.0)
    }

    // MARK: - Cycle Counting Tests

    func testCycleCounting() async throws {
        // Given: A preset with 2 cycles
        let preset = Preset(
            name: "Multi",
            intervals: [
                Interval(title: "A", duration: 0.1),
                Interval(title: "B", duration: 0.1)
            ],
            cycleCount: 2
        )

        engine.start(preset: preset)

        // Initially in cycle 1
        XCTAssertEqual(engine.currentCycle, 1)

        // Wait for first cycle to complete
        try await Task.sleep(for: .milliseconds(250))

        // Should be in cycle 2
        XCTAssertEqual(engine.currentCycle, 2)
    }

    // MARK: - Edge Cases

    func testInvalidPreset_LessThan2Intervals() async throws {
        // Given: An invalid preset
        let preset = Preset(
            name: "Invalid",
            intervals: [
                Interval(title: "Only", duration: 60)
            ],
            cycleCount: 1
        )

        // When: Attempting to start
        engine.start(preset: preset)

        // Then: Engine should remain idle
        if case .idle = engine.state {
            XCTAssertTrue(true)
        } else {
            XCTFail("Engine should remain in idle state for invalid preset")
        }
    }

    func testZeroDurationInterval() async throws {
        // Given: A preset with zero-duration interval (edge case)
        let preset = Preset(
            name: "Zero",
            intervals: [
                Interval(title: "Instant", duration: 0),
                Interval(title: "Normal", duration: 60)
            ],
            cycleCount: 1
        )

        // When: Starting
        engine.start(preset: preset)

        // Then: Should handle gracefully (will transition immediately)
        try await Task.sleep(for: .milliseconds(50))

        XCTAssertTrue(engine.state.isRunning)
    }

    // MARK: - Helpers

    private func createSimplePreset() -> Preset {
        Preset(
            name: "Simple",
            intervals: [
                Interval(title: "Run", duration: 240),
                Interval(title: "Walk", duration: 60)
            ],
            cycleCount: 2
        )
    }
}
