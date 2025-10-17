//
//  HomeView.swift
//  RunLoop
//
//  Main timer interface with large countdown, progress ring, and controls.
//

import SwiftUI

struct HomeView: View {

    // MARK: - Constants

    private let appVersion = "1.5.0" // Increment this with each change

    // MARK: - Environment

    @Environment(PresetStore.self) private var presetStore
    @State private var viewModel = IntervalViewModel()

    // MARK: - State

    @State private var showingSettings = false
    @State private var editingPreset: Preset?
    @State private var isDeleteMode = false
    @State private var presetsToDelete: Set<UUID> = []

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient based on current interval colour
                backgroundGradient
                    .ignoresSafeArea()

                VStack(spacing: 20) {
                    // Preset selector
                    if !viewModel.state.isActive {
                        presetSelector
                            .padding(.top)
                            .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    }

                    Spacer()

                    // Main timer display
                    timerDisplay

                    Spacer()

                    // Controls
                    if viewModel.state.isActive {
                        activeControls
                            .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    } else {
                        startButton
                            .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    }

                    Spacer()

                    // Version number at bottom
                    if !viewModel.state.isActive {
                        Text("v\(appVersion)")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.4))
                            .padding(.bottom, 8)
                    }
                }
                .animation(.snappy(duration: 0.25), value: viewModel.state)
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

                if !viewModel.state.isActive {
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
            .sheet(isPresented: $showingSettings) {
                SettingsView()
                    .environment(presetStore)
                    .presentationDragIndicator(.visible)
            }
            .sheet(item: $editingPreset) { preset in
                PresetEditorView(preset: preset.id == Preset.empty.id ? nil : preset)
                    .environment(presetStore)
                    .presentationDragIndicator(.visible)
            }
        }
        .onAppear {
            syncSettings()
        }
    }

    // MARK: - Components

    private var backgroundGradient: some View {
        let color = viewModel.currentInterval?.color ?? Color.blue.opacity(0.3)
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

    private var timerDisplay: some View {
        VStack(spacing: 16) {
            // Progress ring with time
            ZStack {
                ProgressRing(
                    progress: viewModel.progress,
                    color: viewModel.currentInterval?.color ?? .blue,
                    lineWidth: 20
                )
                .frame(width: 280, height: 280)
                .accessibilityHidden(true)

                VStack(spacing: 8) {
                    // Show countdown overlay if active
                    if let countdownNum = viewModel.countdownNumber {
                        Text("\(countdownNum)")
                            .font(.system(size: 120, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .transition(.scale.combined(with: .opacity))
                    } else {
                        // Current interval name
                        if let interval = viewModel.currentInterval {
                            Text(interval.title)
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                        }

                        // Remaining time
                        Text(viewModel.formattedRemainingTime)
                            .font(.system(size: 72, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .monospacedDigit()
                    }
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(viewModel.currentInterval != nil ?
                "\(viewModel.currentInterval!.title). Time remaining: \(viewModel.formattedRemainingTime)" :
                "Timer: \(viewModel.formattedRemainingTime)"
            )

            // Cycle info
            if viewModel.state.isActive {
                Text(viewModel.cycleText)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
                    .accessibilityLabel(viewModel.cycleText)
            }

            // Next interval preview
            if let next = viewModel.nextInterval {
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
            } else if viewModel.state.isActive {
                Text("Last interval")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
                    .accessibilityLabel("Last interval")
            }

            // Elapsed time
            if viewModel.state.isActive {
                Text("Elapsed: \(viewModel.formattedElapsedTime)")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
                    .accessibilityLabel("Elapsed time: \(viewModel.formattedElapsedTime)")
            }
        }
    }

    private var startButton: some View {
        Button {
            startWorkout()
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

    private var activeControls: some View {
        VStack(spacing: 16) {
            // Skip buttons
            HStack(spacing: 20) {
                Button {
                    viewModel.skipBackward()
                } label: {
                    Image(systemName: "backward.fill")
                        .font(.title)
                        .foregroundStyle(.white)
                        .frame(width: 60, height: 60)
                        .background(Color.white.opacity(0.2))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Skip to previous interval")
                .accessibilityHint("Go back to the start of the previous interval")

                Spacer()

                // Pause/Resume button
                Button {
                    togglePause()
                } label: {
                    Image(systemName: viewModel.state.isPaused ? "play.fill" : "pause.fill")
                        .font(.title)
                        .foregroundStyle(.white)
                        .frame(width: 80, height: 80)
                        .background(Color.orange)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(viewModel.state.isPaused ? "Resume workout" : "Pause workout")
                .accessibilityHint(viewModel.state.isPaused ? "Continue the workout" : "Pause the timer")

                Spacer()

                Button {
                    viewModel.skipForward()
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.title)
                        .foregroundStyle(.white)
                        .frame(width: 60, height: 60)
                        .background(Color.white.opacity(0.2))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Skip to next interval")
                .accessibilityHint("Jump to the start of the next interval")
            }
            .padding(.horizontal)

            // Stop button
            Button {
                stopWorkout()
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

    private func startWorkout() {
        guard let preset = presetStore.selectedPreset else { return }

        Task {
            await viewModel.start(preset: preset)
        }
    }

    private func togglePause() {
        Task {
            if viewModel.state.isPaused {
                await viewModel.resume()
            } else {
                await viewModel.pause()
            }
        }
    }

    private func stopWorkout() {
        Task {
            await viewModel.stop()
        }
    }

    private func syncSettings() {
        viewModel.soundsEnabled = presetStore.soundsEnabled
        viewModel.voiceEnabled = presetStore.voiceEnabled
        viewModel.hapticsEnabled = presetStore.hapticsEnabled
        viewModel.speechRate = presetStore.speechRate
        viewModel.countInEnabled = presetStore.countInEnabled
        viewModel.keepScreenAwake = presetStore.keepScreenAwake
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
