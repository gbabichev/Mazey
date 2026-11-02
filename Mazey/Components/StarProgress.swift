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
                Image(systemName: index < collected ? "star.fill" : "star")
                    .foregroundStyle(index < collected ? Color(red: 1.0, green: 0.8, blue: 0.1) : .secondary)
                    .scaleEffect(index < collected ? 1 : 0.85)
                    .animation(.spring(duration: 0.35, bounce: 0.6), value: collected)
            }
        }
        .font(.callout)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(collected) of \(total) stars collected")
    }
}
