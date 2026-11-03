//
//  SoundEngine.swift
//  Mazey
//

import AVFoundation

/// Plays the synthesized sound effects through AVAudioEngine, with a haptic for each, and a
/// recording of applause at the finish.
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
    private var applause: AVAudioPCMBuffer?
    private var melodyStart = 0
    private var lastStepTime: ContinuousClock.Instant?
    private let haptics = Haptics()

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
        // Start activating the audio session now, so it is ready before the first sound.
        activateSession()
    }

    func startMelody(at position: Int) {
        melodyStart = position
    }

    func play(_ requested: SoundEffect) {
        let effect = inMelody(requested)
        if !shouldPlay(effect) { return }
        haptics.perform(HapticKind.kind(for: effect))
        guard startEngineIfNeeded() else { return }
        let player = players[nextPlayer]
        nextPlayer = (nextPlayer + 1) % players.count
        player.scheduleBuffer(buffer(for: effect), at: nil, options: .interrupts, completionHandler: nil)
        player.play()
        if effect == .finish { playApplause() }
    }

    // MARK: - Private

    /// The bundled applause (see Sounds/CREDITS.md), on the next player along.
    private func playApplause() {
        if applause == nil { applause = Self.loadApplause(matching: format) }
        guard let applause else { return }
        let player = players[nextPlayer]
        nextPlayer = (nextPlayer + 1) % players.count
        player.scheduleBuffer(applause, at: nil, options: .interrupts, completionHandler: nil)
        player.play()
    }

    /// Reads the applause file into memory. It is encoded in the engine's own format
    /// (mono, 44.1 kHz), so it needs no conversion; if it is missing the fanfare plays alone.
    private static func loadApplause(matching format: AVAudioFormat) -> AVAudioPCMBuffer? {
        guard let url = Bundle.main.url(forResource: "Applause", withExtension: "m4a"),
              let file = try? AVAudioFile(forReading: url),
              file.processingFormat.sampleRate == format.sampleRate,
              file.processingFormat.channelCount == format.channelCount,
              let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length))
        else { return nil }
        try? file.read(into: buffer)
        return buffer
    }

    /// A step's length becomes a place in the song: the first step is the first note.
    private func inMelody(_ effect: SoundEffect) -> SoundEffect {
        switch effect {
        case .step(let length): .step(melodyStart + max(0, length - 1))
        case .retrace(let length): .retrace(melodyStart + max(0, length - 1))
        default: effect
        }
    }

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

    /// Sets up the ambient session and activates it, all off the main thread: changing the
    /// category or activating can block while the system brings up audio (and changing the
    /// category can block longer once the session is active). Activation uses the asynchronous
    /// API where it exists (iOS 27); before that it is the same call on the background queue.
    private func activateSession() {
        #if os(iOS)
        DispatchQueue.global(qos: .userInitiated).async {
            let session = AVAudioSession.sharedInstance()
            try? session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            if #available(iOS 27.0, *) {
                session.activate(options: []) { @Sendable _, _ in }
            } else {
                try? session.setActive(true)
            }
        }
        #endif
    }

    /// Starts the engine, and restarts it after an interruption (a phone call, Siri, a route change).
    private func startEngineIfNeeded() -> Bool {
        if engine.isRunning { return true }
        do {
            try engine.start()
            return true
        } catch {
            // Usually the session was deactivated by an interruption. Reactivate it for the next sound.
            activateSession()
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
    /// The melody wraps round at its end, so positions past it share buffers.
    nonisolated var normalized: SoundEffect {
        let count = Melody.count
        switch self {
        case .step(let length): return .step(abs(length) % count)
        case .retrace(let length): return .retrace(abs(length) % count)
        default: return self
        }
    }
}
