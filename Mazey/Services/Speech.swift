//
//  Speech.swift
//  Mazey
//

import AVFoundation

/// Speaks short phrases with the built-in speech synthesizer, in a bright, friendly voice.
/// It uses the app's audio session, so on iOS it follows the silent switch like the sound effects.
@MainActor
final class Speech {
    private let synthesizer = AVSpeechSynthesizer()
    private var pending: Task<Void, Never>?

    /// Says `phrase` after its delay. Anything still being said, or waiting to be said, is dropped.
    func speak(_ phrase: SpokenPhrase) {
        stop()
        pending = Task {
            try? await Task.sleep(for: .seconds(phrase.delay))
            guard !Task.isCancelled else { return }
            synthesizer.speak(utterance(for: phrase))
        }
    }

    func stop() {
        pending?.cancel()
        pending = nil
        synthesizer.stopSpeaking(at: .immediate)
    }

    private func utterance(for phrase: SpokenPhrase) -> AVSpeechUtterance {
        let utterance = AVSpeechUtterance(string: phrase.text)
        utterance.voice = Self.voice
        // Pitch is left near natural: raising it far is what makes a synthetic voice sound robotic.
        utterance.pitchMultiplier = 1.08
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.92
        utterance.preUtteranceDelay = 0.05
        return utterance
    }

    /// The most natural English voice installed: Premium and Enhanced voices beat the compact
    /// default, and novelty, Personal and old robotic "Eloquence" voices are never used.
    private static let voice: AVSpeechSynthesisVoice? = {
        let candidates = AVSpeechSynthesisVoice.speechVoices().filter { voice in
            voice.language.hasPrefix("en")
                && !voice.voiceTraits.contains(.isNoveltyVoice)
                && !voice.voiceTraits.contains(.isPersonalVoice)
                && !voice.identifier.contains("eloquence")
                && !voice.identifier.contains("speech.synthesis.voice")
        }
        func rank(_ voice: AVSpeechSynthesisVoice) -> Int {
            (voice.quality.rawValue * 10) + (voice.language == "en-US" ? 5 : 0)
        }
        return candidates.max { rank($0) < rank($1) } ?? AVSpeechSynthesisVoice(language: "en-US")
    }()
}
