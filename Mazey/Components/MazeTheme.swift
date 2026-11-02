//
//  MazeTheme.swift
//  Mazey
//

import SwiftUI

/// A look for one maze: colors plus emoji for the player, start, finish and scenery.
/// Emoji keep the themes free of asset files and identical on every platform.
nonisolated struct MazeTheme: Identifiable, Sendable {
    let id: String
    let name: String

    // Emoji
    let playerEmoji: String
    let startEmoji: String
    let finishEmoji: String
    /// Scenery scattered at random over the maze cells and the background.
    let decorations: [String]

    // Colors
    let backgroundTop: Color
    let backgroundBottom: Color
    let paper: Color
    let wall: Color
    let path: Color
    let hint: Color
    let startTint: Color
    let finishTint: Color
    /// Color for the main action buttons.
    let accent: Color
    /// Readable text color on a light card.
    let ink: Color
    /// True when the background is dark, so toolbars switch to light-on-dark.
    let isDark: Bool
}

nonisolated extension MazeTheme {
    static let space = MazeTheme(
        id: "space", name: "Space",
        playerEmoji: "🚀", startEmoji: "🌍", finishEmoji: "🪐",
        decorations: ["⭐️", "✨", "☄️", "🛸", "🌙"],
        backgroundTop: Color(red: 0.10, green: 0.08, blue: 0.30),
        backgroundBottom: Color(red: 0.32, green: 0.12, blue: 0.48),
        paper: Color(red: 0.14, green: 0.13, blue: 0.36),
        wall: Color(red: 0.72, green: 0.67, blue: 1.00),
        path: Color(red: 0.30, green: 0.85, blue: 0.95),
        hint: Color(red: 1.00, green: 0.85, blue: 0.30),
        startTint: Color(red: 0.35, green: 0.85, blue: 0.55),
        finishTint: Color(red: 1.00, green: 0.55, blue: 0.70),
        accent: Color(red: 1.00, green: 0.55, blue: 0.20),
        ink: Color(red: 0.20, green: 0.15, blue: 0.50),
        isDark: true
    )

    static let dinosaur = MazeTheme(
        id: "dinosaur", name: "Dinosaur",
        playerEmoji: "🦕", startEmoji: "🌴", finishEmoji: "🥚",
        decorations: ["🌿", "🌴", "🦴", "🌋", "🍃", "🪨"],
        backgroundTop: Color(red: 0.80, green: 0.93, blue: 0.70),
        backgroundBottom: Color(red: 0.98, green: 0.88, blue: 0.62),
        paper: Color(red: 1.00, green: 0.97, blue: 0.86),
        wall: Color(red: 0.36, green: 0.45, blue: 0.22),
        path: Color(red: 0.40, green: 0.72, blue: 0.33),
        hint: Color(red: 0.95, green: 0.55, blue: 0.15),
        startTint: Color(red: 0.45, green: 0.75, blue: 0.35),
        finishTint: Color(red: 0.95, green: 0.65, blue: 0.35),
        accent: Color(red: 0.85, green: 0.45, blue: 0.15),
        ink: Color(red: 0.30, green: 0.38, blue: 0.18),
        isDark: false
    )

    static let ocean = MazeTheme(
        id: "ocean", name: "Ocean",
        playerEmoji: "🐠", startEmoji: "🌊", finishEmoji: "🐚",
        decorations: ["🫧", "🪸", "🐙", "🐡", "⭐️", "🦀"],
        backgroundTop: Color(red: 0.65, green: 0.90, blue: 1.00),
        backgroundBottom: Color(red: 0.30, green: 0.62, blue: 0.90),
        paper: Color(red: 0.90, green: 0.98, blue: 1.00),
        wall: Color(red: 0.10, green: 0.35, blue: 0.60),
        path: Color(red: 0.20, green: 0.75, blue: 0.80),
        hint: Color(red: 1.00, green: 0.75, blue: 0.20),
        startTint: Color(red: 0.35, green: 0.80, blue: 0.75),
        finishTint: Color(red: 1.00, green: 0.65, blue: 0.55),
        accent: Color(red: 1.00, green: 0.50, blue: 0.35),
        ink: Color(red: 0.08, green: 0.30, blue: 0.55),
        isDark: false
    )

    static let farm = MazeTheme(
        id: "farm", name: "Farm",
        playerEmoji: "🐰", startEmoji: "🏡", finishEmoji: "🥕",
        decorations: ["🌻", "🌷", "🦋", "🐝", "🌼", "🍄"],
        backgroundTop: Color(red: 0.78, green: 0.93, blue: 0.98),
        backgroundBottom: Color(red: 0.80, green: 0.93, blue: 0.55),
        paper: Color(red: 1.00, green: 0.98, blue: 0.88),
        wall: Color(red: 0.55, green: 0.35, blue: 0.20),
        path: Color(red: 0.96, green: 0.60, blue: 0.25),
        hint: Color(red: 0.35, green: 0.65, blue: 0.95),
        startTint: Color(red: 0.55, green: 0.80, blue: 0.40),
        finishTint: Color(red: 1.00, green: 0.70, blue: 0.40),
        accent: Color(red: 0.40, green: 0.70, blue: 0.30),
        ink: Color(red: 0.45, green: 0.28, blue: 0.15),
        isDark: false
    )

    static let all: [MazeTheme] = [.space, .dinosaur, .ocean, .farm]

    /// The theme for a maze seed. The same seed always gets the same theme, but it is
    /// never the same as `previous`, so New Maze always looks different.
    static func theme(for seed: UInt64, avoiding previous: MazeTheme? = nil) -> MazeTheme {
        let index = Int(seed % UInt64(all.count))
        let theme = all[index]
        guard theme.id == previous?.id else { return theme }
        return all[(index + 1) % all.count]
    }
}
