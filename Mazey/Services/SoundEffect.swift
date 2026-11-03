//
//  SoundEffect.swift
//  Mazey
//

import Foundation

/// Everything the game can make a sound for.
nonisolated enum SoundEffect: Hashable, Sendable {
    /// The path grew. The number is how many steps long it now is, which picks the next note
    /// of the melody (see `Melody`).
    case step(Int)
    /// The path shrank. The number is its new length; the note it had on the way out plays again.
    case retrace(Int)
    case finish
    /// The recorded clapping after the finish fanfare. Its own effect so it can be switched off alone.
    case applause
    /// A star was picked up. The number is how many have been collected in this maze,
    /// which sets the pitch so a full set climbs the scale.
    case collect(Int)
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
    /// Plays a sound effect, with the haptic that goes with it.
    func play(_ effect: SoundEffect)
    /// Sets where in the song a maze's first step begins.
    func startMelody(at position: Int)
}

extension SoundPlaying {
    func startMelody(at position: Int) {}
}

/// Plays nothing. The default for tests and previews.
@MainActor
final class SilentSounds: SoundPlaying {
    func play(_ effect: SoundEffect) {}
}
