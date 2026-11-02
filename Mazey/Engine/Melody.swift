//
//  Melody.swift
//  Mazey
//

import Foundation

/// Public-domain tunes that play one note per step along the path, so a long walk through a
/// maze is a song instead of the same few notes over and over. Every maze starts at the
/// beginning of one of the tunes, and the next tune follows when one ends.
nonisolated enum Melody {
    struct Tune: Sendable {
        let name: String
        let notes: [Int]

        /// Notes written as "C5 F#4 Bb4": a letter, an optional sharp or flat, an octave.
        init(_ name: String, _ written: String) {
            self.name = name
            notes = written.split(separator: " ").map { Melody.midiNumber(String($0)) }
        }
    }

    static let tunes: [Tune] = [
        Tune("Ode to Joy", """
            E5 E5 F5 G5 G5 F5 E5 D5 C5 C5 D5 E5 E5 D5 D5 \
            E5 E5 F5 G5 G5 F5 E5 D5 C5 C5 D5 E5 D5 C5 C5 \
            D5 D5 E5 C5 D5 E5 F5 E5 C5 D5 E5 F5 E5 D5 C5 D5 G4 \
            E5 E5 F5 G5 G5 F5 E5 D5 C5 C5 D5 E5 D5 C5 C5
            """),
        Tune("Twinkle, Twinkle", """
            C5 C5 G5 G5 A5 A5 G5 F5 F5 E5 E5 D5 D5 C5 \
            G5 G5 F5 F5 E5 E5 D5 G5 G5 F5 F5 E5 E5 D5 \
            C5 C5 G5 G5 A5 A5 G5 F5 F5 E5 E5 D5 D5 C5
            """),
        Tune("Minuet in G", """
            D5 G4 A4 B4 C5 D5 G4 G4 E5 C5 D5 E5 F#5 G5 G4 G4 \
            C5 D5 C5 B4 A4 B4 C5 B4 A4 G4 F#4 G4 A4 B4 G4 B4 A4
            """),
        Tune("Für Elise", """
            E5 D#5 E5 D#5 E5 B4 D5 C5 A4 C4 E4 A4 B4 E4 G#4 B4 C5 \
            E4 E5 D#5 E5 D#5 E5 B4 D5 C5 A4 C4 E4 A4 B4 E4 C5 B4 A4
            """),
        Tune("Canon in D", """
            F#5 E5 D5 C#5 B4 A4 B4 C#5 D5 C#5 B4 A4 G4 F#4 G4 E4 \
            F#5 E5 D5 C#5 B4 A4 B4 C#5 D5 C#5 B4 A4 G4 F#4 G4 E4
            """),
        Tune("Frère Jacques", """
            C5 D5 E5 C5 C5 D5 E5 C5 E5 F5 G5 E5 F5 G5 \
            G5 A5 G5 F5 E5 C5 G5 A5 G5 F5 E5 C5 C5 G4 C5 C5 G4 C5
            """),
    ]

    /// Every tune one after another.
    static let notes: [Int] = tunes.flatMap(\.notes)
    static var count: Int { notes.count }

    /// The MIDI note (60 is middle C) at a position in the song, which wraps round at the end.
    static func midi(at position: Int) -> Int {
        notes[((position % count) + count) % count]
    }

    /// Where in the song a maze begins: the start of one of the tunes, picked from the seed.
    static func startPosition(for seed: UInt64) -> Int {
        var rng = SeededGenerator(seed: seed ^ 0x5011_AB1E)
        let tune = rng.next(below: tunes.count)
        return tunes[..<tune].reduce(0) { $0 + $1.notes.count }
    }

    static func midiNumber(_ written: String) -> Int {
        let semitones: [Character: Int] = ["C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11]
        var characters = Array(written)
        let letter = characters.removeFirst()
        var value = semitones[letter] ?? 0
        if let accidental = characters.first, accidental == "#" || accidental == "b" {
            value += accidental == "#" ? 1 : -1
            characters.removeFirst()
        }
        let octave = Int(String(characters)) ?? 4
        return 12 * (octave + 1) + value
    }
}
