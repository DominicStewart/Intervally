//
//  PresetEditorView.swift
//  RunLoop
//
//  Editor for creating and modifying interval presets.
//

import SwiftUI

struct PresetEditorView: View {

    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss
    @Environment(PresetStore.self) private var presetStore

    // MARK: - State

    @State private var name: String
    @State private var intervals: [Interval]
    @State private var cycleCount: Int?
    @State private var isInfinite: Bool
    @State private var enableHealthKitWorkout: Bool

    @State private var editingInterval: Interval?

    private let isEditing: Bool
    private let originalPresetId: UUID?

    // MARK: - Initialization

    init(preset: Preset? = nil) {
        if let preset = preset {
            // Editing existing preset
            isEditing = true
            originalPresetId = preset.id
            _name = State(initialValue: preset.name)
            _intervals = State(initialValue: preset.intervals)
            _cycleCount = State(initialValue: preset.cycleCount)
            _isInfinite = State(initialValue: preset.cycleCount == nil)
            _enableHealthKitWorkout = State(initialValue: preset.enableHealthKitWorkout)
        } else {
            // Creating new preset
            isEditing = false
            originalPresetId = nil
            _name = State(initialValue: "New Workout")
            _intervals = State(initialValue: [
                Interval(title: "Run", duration: 240, colorHex: "#FF3B30"),
                Interval(title: "Walk", duration: 60, colorHex: "#34C759")
            ])
            _cycleCount = State(initialValue: 6)
            _isInfinite = State(initialValue: false)
            _enableHealthKitWorkout = State(initialValue: true)
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                // Preset Name
                Section("Preset Name") {
                    TextField("Name", text: $name)
                        .autocorrectionDisabled()
                        .onChange(of: name) { _, newValue in
                            if newValue.count > 20 {
                                name = String(newValue.prefix(20))
                            }
                        }
                    Text("\(name.count)/20")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Intervals
                Section("Intervals") {
                    ForEach(intervals) { interval in
                        Button {
                            editingInterval = interval
                        } label: {
                            IntervalRow(interval: interval)
                        }
                        .buttonStyle(.plain)
                        .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                        .contentShape(Rectangle()) // Makes entire row tappable
                    }
                    .onDelete(perform: deleteIntervals)
                    .onMove(perform: moveIntervals)

                    Button {
                        addInterval()
                    } label: {
                        Label("Add Interval", systemImage: "plus.circle.fill")
                    }
                }

                // Cycle Configuration
                Section("Cycles") {
                    Toggle("Repeat Until Stopped", isOn: $isInfinite)
                        .tint(.blue)
                        .onChange(of: isInfinite) { _, newValue in
                            if newValue {
                                cycleCount = nil
                            } else {
                                cycleCount = 6
                            }
                        }

                    if !isInfinite {
                        Stepper(value: Binding(
                            get: { cycleCount ?? 1 },
                            set: { cycleCount = $0 }
                        ), in: 1...100) {
                            HStack {
                                Text("Cycle Count")
                                Spacer()
                                Text("\(cycleCount ?? 1)")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                // Apple Watch Settings
                Section {
                    Toggle("Track as HealthKit Workout", isOn: $enableHealthKitWorkout)
                        .tint(.blue)
                } header: {
                    Text("Apple Watch")
                } footer: {
                    Text("Enable to track this as a workout in the Health app on your Apple Watch. Disable for non-fitness activities like Pomodoro timers or cooking.")
                }

                // Summary
                Section("Summary") {
                    HStack {
                        Text("Total Intervals")
                        Spacer()
                        Text("\(intervals.count)")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Cycle Duration")
                        Spacer()
                        Text(formatCycleDuration())
                            .foregroundStyle(.secondary)
                    }

                    if !isInfinite, let count = cycleCount {
                        HStack {
                            Text("Total Duration")
                            Spacer()
                            Text(formatTotalDuration(cycles: count))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(isEditing ? "Edit Preset" : "New Preset")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        savePreset()
                    }
                    .disabled(!isValid)
                }

                ToolbarItem(placement: .bottomBar) {
                    EditButton()
                }
            }
            .sheet(item: $editingInterval) { interval in
                IntervalEditorView(interval: interval) { updatedInterval in
                    updateInterval(updatedInterval)
                    editingInterval = nil
                }
            }
        }
    }

    // MARK: - Computed Properties

    private var isValid: Bool {
        !name.isEmpty && intervals.count >= 2
    }

    // MARK: - Actions

    private func addInterval() {
        let newInterval = Interval(
            title: "Interval \(intervals.count + 1)",
            duration: 60,
            colorHex: "#007AFF"
        )
        intervals.append(newInterval)
    }

    private func deleteIntervals(at offsets: IndexSet) {
        intervals.remove(atOffsets: offsets)
    }

    private func moveIntervals(from source: IndexSet, to destination: Int) {
        intervals.move(fromOffsets: source, toOffset: destination)
    }

    private func updateInterval(_ updated: Interval) {
        if let index = intervals.firstIndex(where: { $0.id == updated.id }) {
            intervals[index] = updated
        }
    }

    private func savePreset() {
        let preset = Preset(
            id: originalPresetId ?? UUID(),
            name: name,
            intervals: intervals,
            cycleCount: isInfinite ? nil : cycleCount,
            enableHealthKitWorkout: enableHealthKitWorkout
        )

        if isEditing {
            presetStore.updatePreset(preset)
        } else {
            presetStore.addPreset(preset)
            presetStore.selectPreset(preset)
        }

        dismiss()
    }

    private func formatCycleDuration() -> String {
        let total = intervals.reduce(0) { $0 + $1.duration }
        return formatTime(total)
    }

    private func formatTotalDuration(cycles: Int) -> String {
        let cycleTime = intervals.reduce(0) { $0 + $1.duration }
        let total = cycleTime * Double(cycles)
        return formatTime(total)
    }

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

// MARK: - Interval Row

struct IntervalRow: View {
    let interval: Interval

    var body: some View {
        HStack(spacing: 12) {
            // Colour indicator
            Circle()
                .fill(interval.color)
                .frame(width: 30, height: 30)

            // Title and duration
            VStack(alignment: .leading, spacing: 4) {
                Text(interval.title)
                    .font(.headline)

                Text(interval.formattedDuration)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Interval Editor View

struct IntervalEditorView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var minutes: Int
    @State private var seconds: Int
    @State private var selectedColorHex: String
    @State private var voiceCue: String

    private let interval: Interval
    private let onSave: (Interval) -> Void

    // Predefined colours
    private let availableColors: [(name: String, hex: String)] = [
        ("Red", "#FF3B30"),
        ("Orange", "#FF9500"),
        ("Yellow", "#FFCC00"),
        ("Green", "#34C759"),
        ("Teal", "#5AC8FA"),
        ("Blue", "#007AFF"),
        ("Purple", "#5856D6"),
        ("Pink", "#FF2D55"),
        ("Gray", "#8E8E93")
    ]

    init(interval: Interval, onSave: @escaping (Interval) -> Void) {
        self.interval = interval
        self.onSave = onSave

        let totalSeconds = Int(interval.duration)
        _title = State(initialValue: interval.title)
        _minutes = State(initialValue: totalSeconds / 60)
        _seconds = State(initialValue: totalSeconds % 60)
        _selectedColorHex = State(initialValue: interval.colorHex)

        // Only populate voiceCue if it's different from title (i.e., user has customized it)
        let isCustomVoiceCue = interval.voiceCue != nil && interval.voiceCue != interval.title
        _voiceCue = State(initialValue: isCustomVoiceCue ? (interval.voiceCue ?? "") : "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Title") {
                    TextField("Title", text: $title)
                        .autocorrectionDisabled()
                        .onChange(of: title) { _, newValue in
                            if newValue.count > 20 {
                                title = String(newValue.prefix(20))
                            }
                        }
                    Text("\(title.count)/20")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Duration") {
                    Picker("Minutes", selection: $minutes) {
                        ForEach(0..<60, id: \.self) { min in
                            Text("\(min) min").tag(min)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 120)

                    Picker("Seconds", selection: $seconds) {
                        ForEach(0..<60, id: \.self) { sec in
                            Text("\(sec) sec").tag(sec)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 120)
                }

                Section("Colour") {
                    VStack(spacing: 20) {
                        // First row (0-2)
                        HStack(spacing: 20) {
                            Spacer()
                            colorCircle(for: availableColors[0])
                            colorCircle(for: availableColors[1])
                            colorCircle(for: availableColors[2])
                            Spacer()
                        }

                        // Second row (3-5)
                        HStack(spacing: 20) {
                            Spacer()
                            colorCircle(for: availableColors[3])
                            colorCircle(for: availableColors[4])
                            colorCircle(for: availableColors[5])
                            Spacer()
                        }

                        // Third row (6-8)
                        HStack(spacing: 20) {
                            Spacer()
                            colorCircle(for: availableColors[6])
                            colorCircle(for: availableColors[7])
                            colorCircle(for: availableColors[8])
                            Spacer()
                        }
                    }
                    .padding(.vertical, 12)
                }
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                .id("color-picker") // Prevent unnecessary re-renders

                Section("Voice Cue") {
                    TextField("Same as title", text: $voiceCue)
                        .autocorrectionDisabled()
                    Text("Leave empty to use the interval title")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Edit Interval")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .disabled(!isValid)
                }
            }
        }
        .id(interval.id) // Force refresh when interval changes
        .presentationDetents([.large]) // Prevent sheet size conflicts
    }

    private var isValid: Bool {
        !title.isEmpty && (minutes > 0 || seconds > 0)
    }

    @ViewBuilder
    private func colorCircle(for colorInfo: (name: String, hex: String)) -> some View {
        ColorCircleButton(
            colorInfo: colorInfo,
            selectedColorHex: $selectedColorHex
        )
    }

    private func save() {
        let duration = Double(minutes * 60 + seconds)
        let updated = Interval(
            id: interval.id,
            title: title,
            duration: duration,
            colorHex: selectedColorHex,
            voiceCue: voiceCue.isEmpty ? nil : voiceCue
        )

        onSave(updated)
        dismiss()
    }
}

// MARK: - Color Circle Button

struct ColorCircleButton: View {
    let colorInfo: (name: String, hex: String)
    @Binding var selectedColorHex: String

    var body: some View {
        let isSelected = selectedColorHex == colorInfo.hex

        ZStack {
            Circle()
                .fill(Color(hex: colorInfo.hex))
                .frame(width: isSelected ? 65 : 50, height: isSelected ? 65 : 50)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: isSelected ? 3 : 0)
                )
        }
        .frame(width: 70, height: 70)
        .background(Color.clear)
        .onTapGesture {
            selectedColorHex = colorInfo.hex
        }
    }
}

// MARK: - Previews

#Preview("Preset Editor - New") {
    PresetEditorView()
        .environment(PresetStore.preview)
}

#Preview("Preset Editor - Edit") {
    PresetEditorView(preset: Preset.sample)
        .environment(PresetStore.preview)
}

#Preview("Interval Editor") {
    IntervalEditorView(interval: Interval.samples[0]) { _ in }
}
