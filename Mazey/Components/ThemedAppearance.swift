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
