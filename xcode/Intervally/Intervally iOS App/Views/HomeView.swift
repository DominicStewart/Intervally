//
//  HomeView.swift
//  RunLoop
//
//  Main timer interface with large countdown, progress ring, and controls.
//

import SwiftUI

struct HomeView: View {

    // MARK: - Constants

    private let appVersion = "2.0.0" // Increment this with each change

    // MARK: - Environment

    @Environment(PresetStore.self) private var presetStore
    @State private var viewModel: IntervalViewModel?

    // MARK: - State

    @State private var showingSettings = false
    @State private var editingPreset: Preset?
    @State private var isDeleteMode = false
    @State private var presetsToDelete: Set<UUID> = []

    // MARK: - Body

    var body: some View {
        Group {
            if let vm = viewModel {
                content(vm: vm)
            } else {
                Color.clear
                    .onAppear {
                        viewModel = IntervalViewModel(presetStore: presetStore)
                    }
            }
        }
    }

    @ViewBuilder
    private func content(vm: IntervalViewModel) -> some View {
        NavigationStack {
            ZStack {
                // Background gradient based on current interval colour
                backgroundGradient(vm: vm)
                    .ignoresSafeArea()

                VStack(spacing: 20) {
                    // Preset selector (hidden during countdown and workout)
                    if !vm.state.isActive && !vm.isCountingIn {
                        presetSelector
                            .padding(.top)
                            .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    }

                    Spacer()

                    // Main timer display
                    timerDisplay(vm: vm)

                    Spacer()

                    // Controls
                    if vm.state.isActive || vm.isCountingIn {
                        activeControls(vm: vm)
                            .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    } else {
                        startButton(vm: vm)
                            .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    }

                    Spacer()

                    // Version number at bottom (hidden during countdown and workout)
                    if !vm.state.isActive && !vm.isCountingIn {
                        Text("v\(appVersion)")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.4))
                            .padding(.bottom, 8)
                    }
                }
                .animation(.snappy(duration: 0.25), value: vm.state)
                .animation(.snappy(duration: 0.25), value: vm.isCountingIn)
                .padding()
            }
            .navigationTitle("Intervally")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isDeleteMode {
                        Button {
                            confirmDelete()
                        } label: {
                            Image(systemName: "checkmark")
                        }
                        .disabled(presetsToDelete.isEmpty)
                        .accessibilityLabel("Confirm deletion")
                        .accessibilityHint(presetsToDelete.isEmpty ? "Select workouts to delete first" : "Delete selected workouts")
                    } else {
                        Button {
                            showingSettings = true
                        } label: {
                            Image(systemName: "gear")
                        }
                        .accessibilityLabel("Settings")
                        .accessibilityHint("Open app settings")
                    }
                }

                if !vm.state.isActive {
                    ToolbarItem(placement: .navigationBarLeading) {
                        if isDeleteMode {
                            Button {
                                cancelDelete()
                            } label: {
                                Text("Cancel")
                            }
                            .accessibilityLabel("Cancel deletion")
                            .accessibilityHint("Exit delete mode without deleting")
                        } else {
                            HStack(spacing: 16) {
                                Button {
                                    // Create new preset by setting editingPreset to nil
                                    editingPreset = nil
                                    // Delay to ensure state updates
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                                        editingPreset = Preset.empty
                                    }
                                } label: {
                                    Image(systemName: "plus")
                                }
                                .accessibilityLabel("Create new workout")
                                .accessibilityHint("Add a new workout preset")

                                Button {
                                    isDeleteMode = true
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .accessibilityLabel("Delete workouts")
                                .accessibilityHint("Enter delete mode to remove workouts")
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showingSettings, onDismiss: {
                syncSettings(vm: vm)
            }) {
                SettingsView()
                    .environment(presetStore)
                    .presentationDragIndicator(.visible)
            }
            .sheet(item: $editingPreset) { preset in
                PresetEditorView(preset: preset.id == Preset.empty.id ? nil : preset)
                    .environment(presetStore)
                    .presentationDragIndicator(.visible)
            }
            .onAppear {
                syncSettings(vm: vm)
            }
        }
    }

    // MARK: - Components

    private func backgroundGradient(vm: IntervalViewModel) -> some View {
        // Use grey during countdown, then interval color
        let color: Color = {
            if vm.isCountingIn {
                return Color.gray.opacity(0.3)
            } else {
                return vm.currentInterval?.color ?? Color.blue.opacity(0.3)
            }
        }()

        return LinearGradient(
            colors: [color.opacity(0.3), Color.black.opacity(0.8)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var presetSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(isDeleteMode ? "Select to Delete" : "Select Workout")
                    .font(.headline)
                    .foregroundStyle(.white)

                Spacer()

                if !isDeleteMode {
                    Text("Tap again to edit")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(presetStore.presets) { preset in
                        PresetCard(
                            preset: preset,
                            isSelected: presetStore.selectedPresetId == preset.id,
                            isDeleteMode: isDeleteMode,
                            isMarkedForDeletion: presetsToDelete.contains(preset.id)
                        )
                        .onTapGesture {
                            if isDeleteMode {
                                togglePresetForDeletion(preset)
                            } else {
                                // First tap: select, second tap: edit
                                if presetStore.selectedPresetId == preset.id {
                                    editingPreset = preset
                                } else {
                                    presetStore.selectPreset(preset)
                                }
                            }
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(preset.name). \(preset.intervalCount) intervals. \(preset.cycleDescription)")
                        .accessibilityHint(isDeleteMode ?
                            (presetsToDelete.contains(preset.id) ? "Tap to unmark for deletion" : "Tap to mark for deletion") :
                            (presetStore.selectedPresetId == preset.id ? "Tap again to edit" : "Tap to select")
                        )
                        .accessibilityAddTraits(presetStore.selectedPresetId == preset.id ? [.isSelected] : [])
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
            .frame(height: 120)
        }
    }

    private func timerDisplay(vm: IntervalViewModel) -> some View {
        VStack(spacing: 16) {
            // Progress ring with time
            ZStack {
                ProgressRing(
                    progress: vm.progress,
                    color: vm.currentInterval?.color ?? .blue,
                    lineWidth: 20
                )
                .frame(width: 280, height: 280)
                .accessibilityHidden(true)

                VStack(spacing: 8) {
                    // Show countdown overlay if active
                    if let countdownNum = vm.countdownNumber {
                        Text("\(countdownNum)")
                            .font(.system(size: 120, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .transition(.scale.combined(with: .opacity))
                    } else {
                        // Current interval name
                        if let interval = vm.currentInterval {
                            Text(interval.title)
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                        }

                        // Remaining time
                        Text(vm.formattedRemainingTime)
                            .font(.system(size: 72, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .monospacedDigit()
                    }
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(vm.currentInterval != nil ?
                "\(vm.currentInterval!.title). Time remaining: \(vm.formattedRemainingTime)" :
                "Timer: \(vm.formattedRemainingTime)"
            )

            // Cycle info
            if vm.state.isActive {
                Text(vm.cycleText)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
                    .accessibilityLabel(vm.cycleText)
            }

            // Next interval preview
            if let next = vm.nextInterval {
                HStack(spacing: 8) {
                    Text("Next:")
                        .foregroundStyle(.white.opacity(0.6))
                    Text(next.title)
                        .fontWeight(.semibold)
                        .foregroundStyle(next.color)
                }
                .font(.subheadline)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Next: \(next.title)")
            } else if vm.state.isActive {
                Text("Last interval")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
                    .accessibilityLabel("Last interval")
            }

            // Elapsed time
            if vm.state.isActive {
                Text("Elapsed: \(vm.formattedElapsedTime)")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
                    .accessibilityLabel("Elapsed time: \(vm.formattedElapsedTime)")
            }
        }
    }

    private func startButton(vm: IntervalViewModel) -> some View {
        Button {
            startWorkout(vm: vm)
        } label: {
            Text("Start")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 60)
                .background(Color.green)
                .cornerRadius(16)
        }
        .disabled(presetStore.selectedPreset == nil)
        .buttonStyle(.plain)
        .padding(.horizontal)
        .accessibilityLabel("Start workout")
        .accessibilityHint(presetStore.selectedPreset != nil ? "Begin \(presetStore.selectedPreset!.name) workout" : "Select a workout first")
    }

    private func activeControls(vm: IntervalViewModel) -> some View {
        VStack(spacing: 16) {
            // Skip buttons (disabled during countdown)
            HStack(spacing: 20) {
                Button {
                    vm.skipBackward()
                } label: {
                    Image(systemName: "backward.fill")
                        .font(.title)
                        .foregroundStyle(.white)
                        .frame(width: 60, height: 60)
                        .background(Color.white.opacity(0.2))
                        .clipShape(Circle())
                }
                .disabled(vm.isCountingIn)
                .opacity(vm.isCountingIn ? 0.5 : 1.0)
                .buttonStyle(.plain)
                .accessibilityLabel("Skip to previous interval")
                .accessibilityHint("Go back to the start of the previous interval")

                Spacer()

                // Pause/Resume button (disabled during countdown)
                Button {
                    togglePause(vm: vm)
                } label: {
                    Image(systemName: vm.state.isPaused ? "play.fill" : "pause.fill")
                        .font(.title)
                        .foregroundStyle(.white)
                        .frame(width: 80, height: 80)
                        .background(Color.orange)
                        .clipShape(Circle())
                }
                .disabled(vm.isCountingIn)
                .opacity(vm.isCountingIn ? 0.5 : 1.0)
                .buttonStyle(.plain)
                .accessibilityLabel(vm.state.isPaused ? "Resume workout" : "Pause workout")
                .accessibilityHint(vm.state.isPaused ? "Continue the workout" : "Pause the timer")

                Spacer()

                Button {
                    vm.skipForward()
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.title)
                        .foregroundStyle(.white)
                        .frame(width: 60, height: 60)
                        .background(Color.white.opacity(0.2))
                        .clipShape(Circle())
                }
                .disabled(vm.isCountingIn)
                .opacity(vm.isCountingIn ? 0.5 : 1.0)
                .buttonStyle(.plain)
                .accessibilityLabel("Skip to next interval")
                .accessibilityHint("Jump to the start of the next interval")
            }
            .padding(.horizontal)

            // Stop button
            Button {
                stopWorkout(vm: vm)
            } label: {
                Text("Stop")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.red.opacity(0.8))
                    .cornerRadius(12)
            }
            .buttonStyle(.plain)
            .padding(.horizontal)
            .accessibilityLabel("Stop workout")
            .accessibilityHint("End the current workout session")
        }
    }

    // MARK: - Actions

    private func startWorkout(vm: IntervalViewModel) {
        guard let preset = presetStore.selectedPreset else { return }

        Task {
            await vm.start(preset: preset)
        }
    }

    private func togglePause(vm: IntervalViewModel) {
        Task {
            if vm.state.isPaused {
                await vm.resume()
            } else {
                await vm.pause()
            }
        }
    }

    private func stopWorkout(vm: IntervalViewModel) {
        Task {
            await vm.stop()
        }
    }

    private func syncSettings(vm: IntervalViewModel) {
        vm.soundsEnabled = presetStore.soundsEnabled
        vm.voiceEnabled = presetStore.voiceEnabled
        vm.hapticsEnabled = presetStore.hapticsEnabled
        vm.speechRate = presetStore.speechRate
        vm.countInEnabled = presetStore.countInEnabled
        vm.keepScreenAwake = presetStore.keepScreenAwake
    }

    private func togglePresetForDeletion(_ preset: Preset) {
        if presetsToDelete.contains(preset.id) {
            presetsToDelete.remove(preset.id)
        } else {
            presetsToDelete.insert(preset.id)
        }
    }

    private func confirmDelete() {
        for presetId in presetsToDelete {
            if let preset = presetStore.presets.first(where: { $0.id == presetId }) {
                presetStore.deletePreset(preset)
            }
        }
        cancelDelete()
    }

    private func cancelDelete() {
        isDeleteMode = false
        presetsToDelete.removeAll()
    }
}

// MARK: - Preset Card

struct PresetCard: View {
    let preset: Preset
    let isSelected: Bool
    let isDeleteMode: Bool
    let isMarkedForDeletion: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Text(preset.name)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)

                Spacer(minLength: 8)

                if isDeleteMode {
                    // Checkmark for deletion
                    Image(systemName: isMarkedForDeletion ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(isMarkedForDeletion ? .red : .white.opacity(0.5))
                        .padding(.top, 2)
                } else {
                    // Edit icon indicator
                    Image(systemName: "pencil.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                        .padding(.top, 4)
                }
            }

            Text("\(preset.intervalCount) intervals")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)

            Text(preset.cycleDescription)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.6))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .frame(minWidth: 160, maxWidth: 200)
        .frame(minHeight: 100)
        .background(
            isDeleteMode && isMarkedForDeletion
                ? Color.red.opacity(0.3)
                : (isSelected ? Color.blue : Color.white.opacity(0.2))
        )
        .cornerRadius(12)
    }
}

// MARK: - Previews

#Preview {
    HomeView()
        .environment(PresetStore.preview)
}
