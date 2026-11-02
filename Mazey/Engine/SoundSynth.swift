//
//  SoundSynth.swift
//  Mazey
//

import Foundation

/// Builds every sound effect from scratch as raw audio samples, so the app needs no audio files.
/// Pure maths with no audio framework, which keeps it easy to test.
nonisolated enum SoundSynth {
    static let sampleRate = 44_100.0

    /// How a note sounds.
    enum Timbre: Sendable {
        case bell    // bright, ringing
        case pluck   // short and woody
        case soft    // smooth triangle wave, good for glides
        case buzz    // rough, for low rumbles
        case noise   // breathy whoosh
        case piano   // struck string: a bright attack that dies away, higher partials faster
    }

    struct Note: Sendable {
        var frequency: Double
        var start: Double
        var duration: Double
        var gain: Float = 0.5
        var timbre: Timbre = .bell
        /// If set, the pitch glides from `frequency` to this over the note.
        var endFrequency: Double?
    }

    /// The pitches of the step sounds: a pentatonic scale, so any run of steps sounds pleasant.
    static let stepScale = [0, 2, 4, 7, 9, 12, 14, 16, 19, 21]

    static func samples(for effect: SoundEffect) -> [Float] {
        render(notes(for: effect))
    }

    /// The pitch of a note of the melody (see `Melody`).
    static func melodyFrequency(at position: Int) -> Double {
        frequency(semitonesAboveC5: Double(Melody.midi(at: position) - 72))
    }

    // MARK: - Effects

    static func notes(for effect: SoundEffect) -> [Note] {
        switch effect {
        case .step(let position):
            return [Note(frequency: melodyFrequency(at: position), start: 0, duration: 0.7, gain: 0.3, timbre: .piano)]
        case .retrace(let position):
            // The same note again, softer and shorter, like the song rewinding.
            return [Note(frequency: melodyFrequency(at: position), start: 0, duration: 0.4, gain: 0.17, timbre: .piano)]
        case .collect(let number):
            let step = stepScale[max(0, number - 1) % stepScale.count]
            return [
                Note(frequency: frequency(semitonesAboveC5: step + 12), start: 0, duration: 0.28, gain: 0.4, timbre: .bell),
                Note(frequency: frequency(semitonesAboveC5: step + 19), start: 0.05, duration: 0.25, gain: 0.25, timbre: .bell),
            ]
        case .finish:
            return finishFanfare
        case .hint(let level):
            let pitches: [Double]
            switch level {
            case .small: pitches = [16, 23]
            case .medium: pitches = [12, 16, 19]
            case .full: pitches = [12, 16, 19, 23, 26]
            }
            return pitches.enumerated().map { index, semitones in
                Note(frequency: frequency(semitonesAboveC5: semitones), start: Double(index) * 0.07, duration: 0.32, gain: 0.35, timbre: .bell)
            }
        case .newMaze(let themeID):
            return newMazeFlourish(themeID: themeID)
        case .restart:
            return [
                Note(frequency: 600, start: 0, duration: 0.25, gain: 0.25, timbre: .soft, endFrequency: 200),
                Note(frequency: 0, start: 0, duration: 0.25, gain: 0.12, timbre: .noise),
            ]
        case .soundOn:
            return [
                Note(frequency: frequency(semitonesAboveC5: 12), start: 0, duration: 0.12, gain: 0.4, timbre: .bell),
                Note(frequency: frequency(semitonesAboveC5: 16), start: 0.08, duration: 0.16, gain: 0.4, timbre: .bell),
            ]
        }
    }

    /// A rising arpeggio, a held chord and a few sparkles on top.
    private static var finishFanfare: [Note] {
        var notes: [Note] = []
        for (index, semitones) in [0.0, 4, 7, 12, 16].enumerated() {
            notes.append(Note(frequency: frequency(semitonesAboveC5: semitones), start: Double(index) * 0.09, duration: 0.35, gain: 0.45, timbre: .bell))
        }
        for semitones in [0.0, 4, 7, 12] {
            notes.append(Note(frequency: frequency(semitonesAboveC5: semitones), start: 0.5, duration: 0.9, gain: 0.22, timbre: .soft))
        }
        for (index, semitones) in [19.0, 24, 28].enumerated() {
            notes.append(Note(frequency: frequency(semitonesAboveC5: semitones), start: 0.6 + Double(index) * 0.1, duration: 0.5, gain: 0.18, timbre: .bell))
        }
        return notes
    }

    /// A short sound for the start of a maze that matches the theme.
    private static func newMazeFlourish(themeID: String) -> [Note] {
        switch themeID {
        case "space":
            // A launch: a rising sweep with a breath of noise, then a twinkle.
            return [
                Note(frequency: 220, start: 0, duration: 0.45, gain: 0.3, timbre: .soft, endFrequency: 900),
                Note(frequency: 0, start: 0, duration: 0.5, gain: 0.12, timbre: .noise),
                Note(frequency: frequency(semitonesAboveC5: 16), start: 0.4, duration: 0.4, gain: 0.3, timbre: .bell),
                Note(frequency: frequency(semitonesAboveC5: 23), start: 0.5, duration: 0.4, gain: 0.25, timbre: .bell),
            ]
        case "dinosaur":
            // Two heavy stomps and a low rumble.
            return [
                Note(frequency: 95, start: 0, duration: 0.2, gain: 0.5, timbre: .buzz, endFrequency: 70),
                Note(frequency: 80, start: 0.24, duration: 0.26, gain: 0.5, timbre: .buzz, endFrequency: 55),
                Note(frequency: 0, start: 0.24, duration: 0.3, gain: 0.1, timbre: .noise),
            ]
        case "ocean":
            // Four bubbles popping up.
            return [
                Note(frequency: 600, start: 0, duration: 0.1, gain: 0.35, timbre: .soft, endFrequency: 1200),
                Note(frequency: 800, start: 0.12, duration: 0.1, gain: 0.35, timbre: .soft, endFrequency: 1500),
                Note(frequency: 500, start: 0.24, duration: 0.12, gain: 0.35, timbre: .soft, endFrequency: 1000),
                Note(frequency: 900, start: 0.35, duration: 0.1, gain: 0.35, timbre: .soft, endFrequency: 1700),
            ]
        case "farm":
            // A boing and a cheerful two-note call.
            return [
                Note(frequency: 260, start: 0, duration: 0.14, gain: 0.35, timbre: .soft, endFrequency: 620),
                Note(frequency: 620, start: 0.14, duration: 0.14, gain: 0.35, timbre: .soft, endFrequency: 360),
                Note(frequency: frequency(semitonesAboveC5: 7), start: 0.32, duration: 0.25, gain: 0.35, timbre: .bell),
                Note(frequency: frequency(semitonesAboveC5: 12), start: 0.42, duration: 0.3, gain: 0.35, timbre: .bell),
            ]
        case "unicorn":
            // A magic harp glissando up, ending on a twinkle.
            var notes = (0..<7).map { index in
                Note(frequency: frequency(semitonesAboveC5: Double(stepScale[index % stepScale.count] - 5)), start: Double(index) * 0.06, duration: 0.4, gain: 0.3, timbre: .bell)
            }
            notes.append(Note(frequency: frequency(semitonesAboveC5: 28), start: 0.45, duration: 0.5, gain: 0.25, timbre: .bell))
            return notes
        case "vehicles":
            // Two honks and an engine revving up.
            return [
                Note(frequency: 330, start: 0, duration: 0.14, gain: 0.35, timbre: .buzz),
                Note(frequency: 330, start: 0.2, duration: 0.14, gain: 0.35, timbre: .buzz),
                Note(frequency: 70, start: 0.4, duration: 0.4, gain: 0.35, timbre: .buzz, endFrequency: 160),
            ]
        case "robots":
            // Cheerful beeps and boops.
            return [
                Note(frequency: 880, start: 0, duration: 0.07, gain: 0.3, timbre: .soft),
                Note(frequency: 1320, start: 0.09, duration: 0.07, gain: 0.3, timbre: .soft),
                Note(frequency: 660, start: 0.18, duration: 0.07, gain: 0.3, timbre: .soft),
                Note(frequency: 990, start: 0.27, duration: 0.18, gain: 0.3, timbre: .soft, endFrequency: 1500),
            ]
        case "spring":
            // Two quick bird tweets.
            return [
                Note(frequency: 1800, start: 0, duration: 0.09, gain: 0.3, timbre: .soft, endFrequency: 2600),
                Note(frequency: 2400, start: 0.1, duration: 0.08, gain: 0.3, timbre: .soft, endFrequency: 1900),
                Note(frequency: 2000, start: 0.3, duration: 0.09, gain: 0.3, timbre: .soft, endFrequency: 2800),
                Note(frequency: frequency(semitonesAboveC5: 16), start: 0.45, duration: 0.35, gain: 0.25, timbre: .bell),
            ]
        case "summer":
            // A wave rolling in, then a bright strum.
            return [
                Note(frequency: 0, start: 0, duration: 0.5, gain: 0.18, timbre: .noise),
                Note(frequency: frequency(semitonesAboveC5: 0), start: 0.4, duration: 0.35, gain: 0.3, timbre: .pluck),
                Note(frequency: frequency(semitonesAboveC5: 4), start: 0.46, duration: 0.35, gain: 0.3, timbre: .pluck),
                Note(frequency: frequency(semitonesAboveC5: 7), start: 0.52, duration: 0.4, gain: 0.3, timbre: .pluck),
            ]
        case "autumn":
            // Rustling leaves and a gentle low note.
            return [
                Note(frequency: 0, start: 0, duration: 0.35, gain: 0.16, timbre: .noise),
                Note(frequency: 0, start: 0.25, duration: 0.3, gain: 0.12, timbre: .noise),
                Note(frequency: frequency(semitonesAboveC5: -12), start: 0.35, duration: 0.5, gain: 0.35, timbre: .pluck),
                Note(frequency: frequency(semitonesAboveC5: -5), start: 0.5, duration: 0.5, gain: 0.3, timbre: .pluck),
            ]
        case "winter":
            // Sleigh bells.
            return (0..<6).map { index in
                Note(frequency: 2400 + Double(index % 3) * 300, start: Double(index) * 0.07, duration: 0.3, gain: 0.22, timbre: .bell)
            }
        default:
            return [
                Note(frequency: frequency(semitonesAboveC5: 12), start: 0, duration: 0.3, gain: 0.35, timbre: .bell),
                Note(frequency: frequency(semitonesAboveC5: 19), start: 0.1, duration: 0.3, gain: 0.35, timbre: .bell),
            ]
        }
    }

    // MARK: - Rendering

    /// C5, the base of the scale, is 523.25 Hz.
    static func frequency(semitonesAboveC5 semitones: Double) -> Double {
        523.25 * pow(2, semitones / 12)
    }

    private static func frequency(semitonesAboveC5 semitones: Int) -> Double {
        frequency(semitonesAboveC5: Double(semitones))
    }

    /// Mixes the notes into one buffer. Every note fades in and out in a few milliseconds so
    /// nothing clicks, and the result is scaled down if it would clip.
    static func render(_ notes: [Note]) -> [Float] {
        let end = notes.map { $0.start + $0.duration }.max() ?? 0
        var output = [Float](repeating: 0, count: Int((end + 0.02) * sampleRate))
        var noiseSource = SeededGenerator(seed: 7)

        for note in notes {
            let first = Int(note.start * sampleRate)
            let count = Int(note.duration * sampleRate)
            var phase = 0.0
            var filtered = 0.0
            for i in 0..<count where first + i < output.count {
                let t = Double(i) / sampleRate
                let progress = Double(i) / Double(max(1, count))
                let pitch = note.endFrequency.map { note.frequency + ($0 - note.frequency) * progress } ?? note.frequency
                phase += 2 * Double.pi * pitch / sampleRate

                var envelope = min(1, t / 0.004)
                let wave: Double
                switch note.timbre {
                case .bell:
                    wave = sin(phase) + 0.4 * sin(2.76 * phase) + 0.2 * sin(5.4 * phase)
                    envelope *= exp(-t * 5)
                case .pluck:
                    wave = sin(phase) + 0.3 * sin(2 * phase) + 0.1 * sin(3 * phase)
                    envelope *= exp(-t * 12)
                case .soft:
                    wave = 2 / Double.pi * asin(sin(phase))
                    envelope *= exp(-t * 3)
                case .buzz:
                    wave = (1...6).reduce(0.0) { $0 + sin(Double($1) * phase) / Double($1) } * 0.6
                    envelope *= exp(-t * 6)
                case .piano:
                    // Partials a little sharp of whole multiples, as in a real string, each
                    // dying away faster the higher it is.
                    var sum = 0.0
                    for (index, level) in [1.0, 0.55, 0.32, 0.2, 0.12, 0.07].enumerated() {
                        let n = Double(index + 1)
                        let stretch = (1 + 0.0004 * n * n).squareRoot()
                        sum += level * exp(-t * 1.6 * n) * sin(n * stretch * phase)
                    }
                    wave = sum
                    envelope *= exp(-t * 2.2)
                case .noise:
                    let sample = Double(noiseSource.next() % 20_001) / 10_000 - 1
                    // A low-pass filter that opens and closes over the note gives a breath.
                    let alpha = 0.02 + 0.25 * sin(Double.pi * progress)
                    filtered += alpha * (sample - filtered)
                    wave = filtered * 4
                    envelope = pow(sin(Double.pi * progress), 2)
                }
                let release = min(1, Double(count - i) / (0.01 * sampleRate))
                output[first + i] += Float(wave * envelope * release) * note.gain
            }
        }

        let peak = output.reduce(0) { max($0, abs($1)) }
        if peak > 0.9 {
            let scale = 0.9 / peak
            for i in output.indices { output[i] *= scale }
        }
        return output
    }
}
