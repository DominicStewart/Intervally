//
//  IntervallyApp.swift
//  Intervally iOS App
//
//  Main app entry point.
//  Bundle ID: com.dominic.intervally
//  Requires: iOS 17+
//

import SwiftUI

@main
struct IntervallyApp: App {

    // MARK: - State

    @State private var presetStore = PresetStore()

    // MARK: - Body

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environment(presetStore)
                .preferredColorScheme(.dark) // Force dark mode for better visibility
        }
    }
}
