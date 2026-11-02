//
//  MazeTheme.swift
//  Mazey
//

import SwiftUI

/// A collectible picture. Earning one means finishing a maze in its theme.
nonisolated struct Sticker: Hashable, Sendable {
    let emoji: String
    /// Said by VoiceOver, since an emoji alone is not a good description.
    let name: String

    init(_ emoji: String, _ name: String) {
        self.emoji = emoji
        self.name = name
    }
}

/// A look for one maze: colors plus emoji for the player, start, finish and scenery.
/// Emoji keep the themes free of asset files and identical on every platform.
nonisolated struct MazeTheme: Identifiable, Sendable {
    let id: String
    let name: String

    // Emoji
    let playerEmoji: String
    let startEmoji: String
    let finishEmoji: String
    /// Scenery scattered around the maze in the background (never inside it, where it would
    /// compete with the collectible stars).
    let decorations: [String]
    /// The stickers that can be earned in this theme, in the order they are handed out.
    let stickers: [Sticker]

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
    static let all: [MazeTheme] = [
        .space, .dinosaur, .ocean, .farm,
        .unicorn, .vehicles, .robots,
        .spring, .summer, .autumn, .winter,
    ]

    /// The theme for a maze seed. The same seed always gets the same theme, but it is
    /// never the same as `previous`, so New Maze always looks different.
    static func theme(for seed: UInt64, avoiding previous: MazeTheme? = nil) -> MazeTheme {
        let index = Int(seed % UInt64(all.count))
        let theme = all[index]
        guard theme.id == previous?.id else { return theme }
        return all[(index + 1) % all.count]
    }
}
