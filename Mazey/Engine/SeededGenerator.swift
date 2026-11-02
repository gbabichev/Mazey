//
//  SeededGenerator.swift
//  Mazey
//

import Foundation

/// A small, fast random number generator (SplitMix64). The same seed always
/// produces the same sequence on every platform, which makes mazes reproducible.
nonisolated struct SeededGenerator: RandomNumberGenerator, Sendable {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// A value in `0..<count`. `count` must be positive.
    mutating func next(below count: Int) -> Int {
        Int(next() % UInt64(count))
    }
}
