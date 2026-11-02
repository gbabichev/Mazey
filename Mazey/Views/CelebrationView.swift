//
//  CelebrationView.swift
//  Mazey
//

import SwiftUI

/// The friendly "you did it" card shown when the finish is reached.
struct CelebrationView: View {
    let theme: MazeTheme
    let onNext: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { _ in
                    Image(systemName: "star.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(theme.hint)
                        .symbolEffect(.bounce, options: .repeating)
                }
            }
            Text("You did it!")
                .font(.system(size: 36, weight: .heavy, design: .rounded))
                .foregroundStyle(theme.ink)
            Button(action: onNext) {
                Label("Next Maze", systemImage: "arrow.right.circle.fill")
                    .font(.title2.weight(.bold))
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(theme.accent)
        }
        .padding(28)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28))
        .shadow(radius: 12)
    }
}
