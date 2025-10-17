//
//  SettingsView.swift
//  RunLoop
//
//  Settings interface for configuring audio, voice, haptics, and app behaviour.
//

import SwiftUI

struct SettingsView: View {

    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss
    @Environment(PresetStore.self) private var presetStore

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                // Audio & Alerts
                Section("Audio & Alerts") {
                    Toggle("Sounds", isOn: Binding(
                        get: { presetStore.soundsEnabled },
                        set: { presetStore.soundsEnabled = $0 }
                    ))
                    .tint(.blue)

                    Toggle("Voice Announcements", isOn: Binding(
                        get: { presetStore.voiceEnabled },
                        set: { presetStore.voiceEnabled = $0 }
                    ))
                    .tint(.blue)

                    Toggle("iPhone Haptics", isOn: Binding(
                        get: { presetStore.hapticsEnabled },
                        set: { presetStore.hapticsEnabled = $0 }
                    ))
                    .tint(.blue)

                    Toggle("Watch Haptics", isOn: Binding(
                        get: { presetStore.watchHapticsEnabled },
                        set: { presetStore.watchHapticsEnabled = $0 }
                    ))
                    .tint(.blue)
                }

                // Voice Settings
                Section("Voice Settings") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Speech Rate")
                            .font(.subheadline)

                        HStack {
                            Text("Slow")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Slider(
                                value: Binding(
                                    get: { presetStore.speechRate },
                                    set: { presetStore.speechRate = $0 }
                                ),
                                in: 0.3...0.7
                            )
                            .tint(.blue)

                            Text("Fast")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // Behaviour
                Section("Behaviour") {
                    Toggle("Count-In (3-2-1)", isOn: Binding(
                        get: { presetStore.countInEnabled },
                        set: { presetStore.countInEnabled = $0 }
                    ))
                    .tint(.blue)

                    Toggle("Keep Screen Awake", isOn: Binding(
                        get: { presetStore.keepScreenAwake },
                        set: { presetStore.keepScreenAwake = $0 }
                    ))
                    .tint(.blue)
                }

                // About
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Bundle ID")
                        Spacer()
                        Text("com.example.runloop")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // Reset
                Section {
                    Button(role: .destructive) {
                        resetToDefaults()
                    } label: {
                        HStack {
                            Spacer()
                            Text("Reset to Defaults")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func resetToDefaults() {
        presetStore.resetToDefaults()
    }
}

// MARK: - Previews

#Preview {
    SettingsView()
        .environment(PresetStore.preview)
}
