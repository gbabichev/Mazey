//
//  ThemedAppearance.swift
//  Mazey
//

import SwiftUI

extension View {
    /// Makes a Mac window's title and toolbar controls read against the theme's background.
    /// A dark theme needs white text, a light one dark text, whatever the Mac's own appearance is.
    /// iPhone and iPad do this per navigation bar instead, so nothing changes there.
    @ViewBuilder
    func themedWindowAppearance(_ theme: MazeTheme) -> some View {
        #if os(macOS)
        preferredColorScheme(theme.isDark ? .dark : .light)
        #else
        self
        #endif
    }
}

extension Color {
    /// The contrast ratio between two colors, from 1 (identical) to 21 (black on white).
    nonisolated static func contrastRatio(_ first: Color, _ second: Color) -> Double {
        let (a, b) = (first.relativeLuminance, second.relativeLuminance)
        return (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }

    /// How bright the color looks, from 0 (black) to 1 (white), as WCAG defines it.
    nonisolated var relativeLuminance: Double {
        let color = resolve(in: EnvironmentValues())
        return 0.2126 * Double(color.linearRed) + 0.7152 * Double(color.linearGreen) + 0.0722 * Double(color.linearBlue)
    }

    /// Black or white, whichever reads better on top of this color. Always at least 4.5 to 1.
    nonisolated var readableText: Color {
        Color.contrastRatio(self, .white) >= Color.contrastRatio(self, .black) ? .white : .black
    }
}

extension MazeTheme {
    /// What the card behind big text looks like: the system material, pinned to the theme's light or dark look.
    nonisolated var cardBackground: Color { isDark ? Color(white: 0.2) : Color(white: 0.95) }

    /// Big headline text for a card: white on a dark theme; on a light one the theme's deep ink,
    /// or black if that ink is too pale to read well.
    nonisolated var headlineColor: Color {
        if isDark { return .white }
        return Color.contrastRatio(cardBackground, ink) >= 4.5 ? ink : .black
    }
}
