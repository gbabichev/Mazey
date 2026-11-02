//
//  ActivityTimer.swift
//  Mazey
//

import Foundation

/// Measures how long a maze took by counting only the time the player was busy with it.
///
/// The clock starts at the first move. Each later move adds the time since the one before, but
/// at most `idleCap`, so a child who wanders off for a snack, or an app left in the background,
/// does not turn a one-minute maze into twenty.
nonisolated struct ActivityTimer: Equatable, Sendable {
    static let idleCap: TimeInterval = 20

    private(set) var total: TimeInterval = 0
    private var lastActivity: Date?

    var hasStarted: Bool { lastActivity != nil }

    /// Notes that the player did something at `now`.
    mutating func record(at now: Date) {
        if let lastActivity {
            total += min(max(0, now.timeIntervalSince(lastActivity)), Self.idleCap)
        }
        lastActivity = now
    }

    mutating func reset() {
        total = 0
        lastActivity = nil
    }
}
