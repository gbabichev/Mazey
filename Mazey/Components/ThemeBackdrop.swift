//
//  ThemeBackdrop.swift
//  Mazey
//

import SwiftUI

/// The themed gradient with a light sprinkle of scenery emoji. The maze card is drawn
/// over it, so the scenery only shows around the edges. Positions come from `seed`,
/// so they stay put between redraws.
struct ThemeBackdrop: View {
    let theme: MazeTheme
    let seed: UInt64

    private static let itemCount = 22
    /// Kept free of scenery so the status bar and toolbar stay easy to read.
    private static let clearTop: Double = 110

    var body: some View {
        let theme = theme
        let seed = seed
        ZStack {
            LinearGradient(
                colors: [theme.backgroundTop, theme.backgroundBottom],
                startPoint: .top,
                endPoint: .bottom
            )
            Canvas { context, size in
                guard !theme.decorations.isEmpty else { return }
                var rng = SeededGenerator(seed: seed ^ 0xA5A5_A5A5)
                for _ in 0..<Self.itemCount {
                    let emoji = theme.decorations[rng.next(below: theme.decorations.count)]
                    let x = Double(rng.next(below: 1000)) / 1000 * size.width
                    let y = Self.clearTop + Double(rng.next(below: 1000)) / 1000 * max(0, size.height - Self.clearTop)
                    let fontSize = 26 + Double(rng.next(below: 24))
                    let angle = Double(rng.next(below: 60) - 30) * .pi / 180
                    var layer = context
                    layer.opacity = 0.4
                    layer.translateBy(x: x, y: y)
                    layer.rotate(by: .radians(angle))
                    layer.draw(layer.resolve(Text(verbatim: emoji).font(.system(size: fontSize))), at: .zero, anchor: .center)
                }
            }
        }
        .accessibilityHidden(true)
    }
}
