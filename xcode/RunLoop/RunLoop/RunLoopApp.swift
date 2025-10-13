//
//  RunLoopApp.swift
//  RunLoop
//
//  Main app entry point.
//  Bundle ID: com.example.runloop
//  Requires: iOS 17+
//

import SwiftUI

@main
struct RunLoopApp: App {

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
