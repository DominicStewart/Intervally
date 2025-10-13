//
//  ProgressRing.swift
//  RunLoop
//
//  Circular progress ring component for visualizing interval progress.
//

import SwiftUI

/// Circular progress ring with customizable colour and line width
struct ProgressRing: View {

    // MARK: - Properties

    let progress: Double // 0.0 to 1.0
    let color: Color
    let lineWidth: CGFloat

    // MARK: - Initializer

    init(
        progress: Double,
        color: Color = .blue,
        lineWidth: CGFloat = 20
    ) {
        self.progress = progress
        self.color = color
        self.lineWidth = lineWidth
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(color.opacity(0.2), lineWidth: lineWidth)

            // Progress ring
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    color,
                    style: StrokeStyle(
                        lineWidth: lineWidth,
                        lineCap: .round
                    )
                )
                .rotationEffect(.degrees(-90)) // Start from top
                .animation(.linear(duration: 0.1), value: progress)
        }
    }
}

// MARK: - Previews

#Preview("Progress Ring") {
    VStack(spacing: 40) {
        ProgressRing(progress: 0.25, color: .red, lineWidth: 20)
            .frame(width: 200, height: 200)

        ProgressRing(progress: 0.5, color: .green, lineWidth: 15)
            .frame(width: 150, height: 150)

        ProgressRing(progress: 0.75, color: .blue, lineWidth: 10)
            .frame(width: 100, height: 100)

        ProgressRing(progress: 1.0, color: .orange, lineWidth: 25)
            .frame(width: 250, height: 250)
    }
    .padding()
}
