//
//  HomeView.swift
//  RunLoop
//
//  Main timer interface with large countdown, progress ring, and controls.
//

import SwiftUI

struct HomeView: View {

    // MARK: - Environment

    @Environment(PresetStore.self) private var presetStore
    @State private var viewModel = IntervalViewModel()

    // MARK: - State

    @State private var showingPresetEditor = false
    @State private var showingSettings = false
    @State private var editingPreset: Preset?

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
                    }

                    Spacer()

                    // Main timer display
                    timerDisplay

                    Spacer()

                    // Controls
                    if viewModel.state.isActive {
                        activeControls
                    } else {
                        startButton
                    }

                    Spacer()
                }
                .padding()
            }
            .navigationTitle("RunLoop")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gear")
                    }
                }

                if !viewModel.state.isActive {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button {
                            editingPreset = nil
                            showingPresetEditor = true
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
                    .environment(presetStore)
            }
            .sheet(isPresented: $showingPresetEditor) {
                PresetEditorView(preset: editingPreset)
                    .environment(presetStore)
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
            Text("Select Workout")
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(presetStore.presets) { preset in
                        PresetCard(
                            preset: preset,
                            isSelected: presetStore.selectedPresetId == preset.id
                        )
                        .onTapGesture {
                            presetStore.selectPreset(preset)
                        }
                        .contextMenu {
                            Button {
                                editingPreset = preset
                                showingPresetEditor = true
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }

                            Button(role: .destructive) {
                                presetStore.deletePreset(preset)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
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
}

// MARK: - Preset Card

struct PresetCard: View {
    let preset: Preset
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(preset.name)
                .font(.headline)
                .foregroundStyle(.white)

            Text("\(preset.intervalCount) intervals")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))

            Text(preset.cycleDescription)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.6))
        }
        .padding()
        .frame(width: 160)
        .background(isSelected ? Color.blue : Color.white.opacity(0.2))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.white : Color.clear, lineWidth: 2)
        )
    }
}

// MARK: - Previews

#Preview {
    HomeView()
        .environment(PresetStore.preview)
}
