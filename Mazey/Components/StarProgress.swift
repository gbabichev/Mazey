//
//  StarProgress.swift
//  Mazey
//

import SwiftUI

/// A row of stars that fill in as they are collected, so a child can see how many are left
/// without reading anything.
struct StarProgress: View {
    let collected: Int
    let total: Int

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<total, id: \.self) { index in
                // Gold either way, so the empty ones read as stars still to find, not as disabled.
                Image(systemName: index < collected ? "star.fill" : "star")
                    .foregroundStyle(Color(red: 0.95, green: 0.72, blue: 0.0))
                    .scaleEffect(index < collected ? 1 : 0.85)
                    .animation(.spring(duration: 0.35, bounce: 0.6), value: collected)
            }
        }
        .font(.title3)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(collected) of \(total) stars collected")
    }
}
