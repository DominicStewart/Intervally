//
//  Intervally_WatchApp.swift
//  Intervally Watch Watch App
//
//  Created by Dominic Stewart on 10/15/25.
//

import SwiftUI

@main
struct Intervally_Watch_Watch_AppApp: App {
    @StateObject private var connectivity = WatchConnectivityManager()

    init() {
        print("⌚️ Watch app launching...")
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(connectivity)
                .onAppear {
                    print("⌚️ ContentView appeared")
                }
        }
    }
}
