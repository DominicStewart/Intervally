//
//  HomeView.swift
//  RunLoop
//
//  Main timer interface with large countdown, progress ring, and controls.
//

import SwiftUI

struct HomeView: View {

    // MARK: - Constants

    private let appVersion = "1.1.0" // Increment this with each change

    // MARK: - Environment

    @Environment(PresetStore.self) private var presetStore
    @State private var viewModel = IntervalViewModel()

    // MARK: - State

    @State private var showingPresetEditor = false
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
            .navigationTitle("RunLoop")
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
                    } else {
                        Button {
                            showingSettings = true
                        } label: {
                            Image(systemName: "gear")
                        }
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
                        } else {
                            HStack(spacing: 16) {
                                Button {
                                    editingPreset = nil
                                    showingPresetEditor = true
                                } label: {
                                    Image(systemName: "plus")
                                }

                                Button {
                                    isDeleteMode = true
                                } label: {
                                    Image(systemName: "trash")
                                }
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
            .sheet(isPresented: $showingPresetEditor) {
                PresetEditorView(preset: editingPreset)
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
                    Text("Tap to edit")
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
                                presetStore.selectPreset(preset)
                                editingPreset = preset
                                showingPresetEditor = true
                            }
                        }
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

                VStack(spacing: 8) {
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

            // Cycle info
            if viewModel.state.isActive {
                Text(viewModel.cycleText)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
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
            } else if viewModel.state.isActive {
                Text("Last interval")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
            }

            // Elapsed time
            if viewModel.state.isActive {
                Text("Elapsed: \(viewModel.formattedElapsedTime)")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
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
            HStack {
                Text(preset.name)
                    .font(.headline)
                    .foregroundStyle(.white)

                Spacer()

                if isDeleteMode {
                    // Checkmark for deletion
                    Image(systemName: isMarkedForDeletion ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(isMarkedForDeletion ? .red : .white.opacity(0.5))
                } else {
                    // Edit icon indicator
                    Image(systemName: "pencil.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                }
            }

            Text("\(preset.intervalCount) intervals")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))

            Text(preset.cycleDescription)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.6))
        }
        .padding()
        .frame(width: 160)
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
