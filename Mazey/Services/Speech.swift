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
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.pitchMultiplier = 1.25
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.95
        return utterance
    }
}
