//
//  Haptics.swift
//  Mazey
//

import Foundation
#if os(iOS)
import CoreHaptics
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// A touch feedback the game can give.
nonisolated enum HapticKind: Equatable, Sendable {
    /// A single tap. `intensity` runs from 0 (barely there) to 1.
    case tick(intensity: Double)
    /// Rising taps ending in a soft rumble, for finishing a maze.
    case celebrate
    /// No feedback at all.
    case none

    /// The feedback that pairs with a sound effect.
    static func kind(for effect: SoundEffect) -> HapticKind {
        switch effect {
        case .step(let length):
            // Climbs with the pitch of the step sound.
            let position = Double(abs(length) % SoundSynth.stepScale.count) / Double(SoundSynth.stepScale.count - 1)
            return .tick(intensity: 0.35 + 0.35 * position)
        case .retrace: return .tick(intensity: 0.25)
        case .finish: return .celebrate
        case .applause: return .none
        case .collect: return .tick(intensity: 0.55)
        case .hint: return .tick(intensity: 0.5)
        case .newMaze: return .tick(intensity: 0.6)
        case .restart: return .tick(intensity: 0.4)
        case .soundOn: return .tick(intensity: 0.5)
        }
    }
}

/// Plays haptics. On iPhone that is the Taptic Engine; on a Mac it is the trackpad, when the
/// pointer is on one. Other devices (such as iPad) have no haptic hardware and do nothing.
@MainActor
final class Haptics {
    #if os(iOS)
    private let impact = UIImpactFeedbackGenerator(style: .soft)
    private var engine: CHHapticEngine?
    #endif

    init() {
        #if os(iOS)
        impact.prepare()
        #endif
    }

    func perform(_ kind: HapticKind) {
        #if os(iOS)
        switch kind {
        case .tick(let intensity):
            impact.impactOccurred(intensity: intensity)
            impact.prepare()
        case .celebrate:
            celebrate()
        case .none:
            break
        }
        #elseif os(macOS)
        switch kind {
        case .tick: NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        case .celebrate: NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
        case .none: break
        }
        #endif
    }

    #if os(iOS)
    /// Five taps that grow stronger, then a gentle rumble. Falls back to the system "success"
    /// buzz when the device cannot play custom patterns.
    private func celebrate() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            return
        }
        do {
            let engine = try engine ?? makeEngine()
            self.engine = engine
            try engine.start()
            let player = try engine.makePlayer(with: Self.celebrationPattern())
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            engine = nil
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }

    private func makeEngine() throws -> CHHapticEngine {
        let engine = try CHHapticEngine()
        // Let the system stop the engine when idle; it is started again for each celebration.
        engine.isAutoShutdownEnabled = true
        return engine
    }

    private static func celebrationPattern() throws -> CHHapticPattern {
        var events: [CHHapticEvent] = (0..<5).map { index in
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: Float(0.4 + 0.12 * Double(index))),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5),
                ],
                relativeTime: 0.09 * Double(index)
            )
        }
        events.append(CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.25),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.2),
            ],
            relativeTime: 0.5,
            duration: 0.8
        ))
        return try CHHapticPattern(events: events, parameters: [])
    }
    #endif
}
