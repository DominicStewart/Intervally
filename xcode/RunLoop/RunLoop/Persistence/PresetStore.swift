//
//  PresetStore.swift
//  RunLoop
//
//  Manages persistent storage of presets and user settings.
//  Uses JSON file storage in Documents directory.
//

import Foundation
import SwiftUI

/// Observable store for managing presets and settings
@MainActor
@Observable
final class PresetStore {

    // MARK: - Published State

    var presets: [Preset] = []
    var selectedPresetId: UUID?

    // MARK: - Settings (persisted via UserDefaults)

    var soundsEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "soundsEnabled") || !UserDefaults.standard.dictionaryRepresentation().keys.contains("soundsEnabled") }
        set { UserDefaults.standard.set(newValue, forKey: "soundsEnabled") }
    }

    var voiceEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "voiceEnabled") || !UserDefaults.standard.dictionaryRepresentation().keys.contains("voiceEnabled") }
        set { UserDefaults.standard.set(newValue, forKey: "voiceEnabled") }
    }

    var hapticsEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "hapticsEnabled") || !UserDefaults.standard.dictionaryRepresentation().keys.contains("hapticsEnabled") }
        set { UserDefaults.standard.set(newValue, forKey: "hapticsEnabled") }
    }

    var watchHapticsEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "watchHapticsEnabled") || !UserDefaults.standard.dictionaryRepresentation().keys.contains("watchHapticsEnabled") }
        set { UserDefaults.standard.set(newValue, forKey: "watchHapticsEnabled") }
    }

    var speechRate: Double {
        get {
            if UserDefaults.standard.dictionaryRepresentation().keys.contains("speechRate") {
                return UserDefaults.standard.double(forKey: "speechRate")
            }
            return 0.5
        }
        set { UserDefaults.standard.set(newValue, forKey: "speechRate") }
    }

    var countInEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "countInEnabled") }
        set { UserDefaults.standard.set(newValue, forKey: "countInEnabled") }
    }

    var keepScreenAwake: Bool {
        get { UserDefaults.standard.bool(forKey: "keepScreenAwake") }
        set { UserDefaults.standard.set(newValue, forKey: "keepScreenAwake") }
    }

    // MARK: - Private Properties

    private let presetsFileName = "presets.json"

    // MARK: - Initialization

    init() {
        loadPresets()
    }

    // MARK: - Computed Properties

    var selectedPreset: Preset? {
        guard let id = selectedPresetId else { return nil }
        return presets.first { $0.id == id }
    }

    // MARK: - Public Methods

    // MARK: Preset Management

    /// Add a new preset
    func addPreset(_ preset: Preset) {
        presets.append(preset)
        savePresets()
    }

    /// Update an existing preset
    func updatePreset(_ preset: Preset) {
        if let index = presets.firstIndex(where: { $0.id == preset.id }) {
            presets[index] = preset
            savePresets()
        }
    }

    /// Delete a preset
    func deletePreset(_ preset: Preset) {
        presets.removeAll { $0.id == preset.id }
        if selectedPresetId == preset.id {
            selectedPresetId = nil
        }
        savePresets()
    }

    /// Delete presets at indices
    func deletePresets(at offsets: IndexSet) {
        let presetsToDelete = offsets.map { presets[$0] }
        for preset in presetsToDelete {
            deletePreset(preset)
        }
    }

    /// Reorder presets
    func movePresets(from source: IndexSet, to destination: Int) {
        presets.move(fromOffsets: source, toOffset: destination)
        savePresets()
    }

    /// Select a preset
    func selectPreset(_ preset: Preset) {
        selectedPresetId = preset.id
    }

    /// Load default presets (useful for first launch or reset)
    func loadDefaults() {
        presets = Preset.defaults
        selectedPresetId = presets.first?.id
        savePresets()
    }

    /// Reset to defaults
    func resetToDefaults() {
        loadDefaults()
    }

    // MARK: - Persistence

    private var presetsFileURL: URL {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsDirectory.appendingPathComponent(presetsFileName)
    }

    /// Load presets from disk
    private func loadPresets() {
        let fileURL = presetsFileURL

        // Check if file exists
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            print("ℹ️ No saved presets found, loading defaults")
            loadDefaults()
            return
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let decoded = try JSONDecoder().decode([Preset].self, from: data)
            presets = decoded
            print("✅ Loaded \(presets.count) presets from disk")

            // Select first preset if none selected
            if selectedPresetId == nil, let first = presets.first {
                selectedPresetId = first.id
            }
        } catch {
            print("❌ Failed to load presets: \(error.localizedDescription)")
            loadDefaults()
        }
    }

    /// Save presets to disk
    private func savePresets() {
        let fileURL = presetsFileURL

        do {
            let data = try JSONEncoder().encode(presets)
            try data.write(to: fileURL, options: [.atomic])
            print("✅ Saved \(presets.count) presets to disk")
        } catch {
            print("❌ Failed to save presets: \(error.localizedDescription)")
        }
    }
}

// MARK: - Preview Helper

extension PresetStore {
    /// Create a store with sample data for previews
    static var preview: PresetStore {
        let store = PresetStore()
        store.presets = Preset.defaults
        store.selectedPresetId = store.presets.first?.id
        return store
    }
}
