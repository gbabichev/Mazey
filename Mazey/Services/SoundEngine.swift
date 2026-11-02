//
//  SoundEngine.swift
//  Mazey
//

import AVFoundation

/// Plays the synthesized sound effects through AVAudioEngine.
///
/// On iOS the audio session is "ambient": sounds follow the silent switch and mix with
/// music or podcasts a parent may have playing, instead of cutting them off.
@MainActor
final class SoundEngine: SoundPlaying {
    static let shared = SoundEngine()

    private let engine = AVAudioEngine()
    private let format = AVAudioFormat(standardFormatWithSampleRate: SoundSynth.sampleRate, channels: 1)!
    private var players: [AVAudioPlayerNode] = []
    private var nextPlayer = 0
    private var buffers: [SoundEffect: AVAudioPCMBuffer] = [:]
    private var lastStepTime: ContinuousClock.Instant?
    private var sessionConfigured = false

    /// Step sounds closer together than this are skipped, so a fast drag stays musical.
    private let minimumStepGap: Duration = .milliseconds(45)
    /// Several players let sounds overlap, such as a step during the finish fanfare.
    private let playerCount = 6

    private init() {
        for _ in 0..<playerCount {
            let player = AVAudioPlayerNode()
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: format)
            players.append(player)
        }
    }

    func play(_ effect: SoundEffect) {
        if !shouldPlay(effect) { return }
        configureSessionIfNeeded()
        guard startEngineIfNeeded() else { return }
        let player = players[nextPlayer]
        nextPlayer = (nextPlayer + 1) % players.count
        player.scheduleBuffer(buffer(for: effect), at: nil, options: .interrupts, completionHandler: nil)
        player.play()
    }

    // MARK: - Private

    /// Drops step sounds that would arrive too quickly after the last one.
    private func shouldPlay(_ effect: SoundEffect) -> Bool {
        switch effect {
        case .step, .retrace:
            let now = ContinuousClock.now
            if let last = lastStepTime, now - last < minimumStepGap { return false }
            lastStepTime = now
            return true
        default:
            return true
        }
    }

    private func configureSessionIfNeeded() {
        guard !sessionConfigured else { return }
        sessionConfigured = true
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)
        #endif
    }

    /// Starts the engine, and restarts it after an interruption (a phone call, Siri, a route change).
    private func startEngineIfNeeded() -> Bool {
        if engine.isRunning { return true }
        do {
            try engine.start()
            return true
        } catch {
            return false
        }
    }

    /// Renders an effect the first time it is needed and keeps it. Step pitches repeat, so
    /// there are only a handful of different buffers.
    private func buffer(for effect: SoundEffect) -> AVAudioPCMBuffer {
        let key = effect.normalized
        if let cached = buffers[key] { return cached }
        let samples = SoundSynth.samples(for: key)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count))!
        buffer.frameLength = AVAudioFrameCount(samples.count)
        samples.withUnsafeBufferPointer { source in
            buffer.floatChannelData![0].update(from: source.baseAddress!, count: samples.count)
        }
        buffers[key] = buffer
        return buffer
    }
}

private extension SoundEffect {
    /// Steps repeat their pitch every few cells, so they share buffers.
    nonisolated var normalized: SoundEffect {
        let count = SoundSynth.stepScale.count
        switch self {
        case .step(let length): return .step(abs(length) % count)
        case .retrace(let length): return .retrace(abs(length) % count)
        default: return self
        }
    }
}
