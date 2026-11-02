//
//  SoundEffect.swift
//  Mazey
//

import Foundation

/// Everything the game can make a sound for.
nonisolated enum SoundEffect: Hashable, Sendable {
    /// The path grew. The number is how many steps long it now is, which sets the pitch.
    case step(Int)
    /// The path shrank. The number is its new length.
    case retrace(Int)
    case finish
    case hint(MazeHintLevel)
    /// A new maze appeared, with a flourish that matches its theme.
    case newMaze(themeID: String)
    case restart
    /// Played when sound is switched back on.
    case soundOn
}

/// Something that can play sound effects. The game talks to this, so tests can listen in
/// without making any noise.
@MainActor
protocol SoundPlaying: AnyObject {
    func play(_ effect: SoundEffect)
}

/// Plays nothing. The default for tests and previews.
@MainActor
final class SilentSounds: SoundPlaying {
    func play(_ effect: SoundEffect) {}
}
