//
//  ParentGate.swift
//  Mazey
//

/// A sum a young child cannot do yet, asked before anything that erases their progress.
nonisolated struct ParentGate: Equatable, Sendable {
    let left: Int
    let right: Int
    /// Possible answers, in the order they are shown; exactly one is right.
    let choices: [Int]

    var question: String { "\(left) + \(right)" }
    var answer: Int { left + right }

    func isCorrect(_ choice: Int) -> Bool { choice == answer }

    /// A new sum. Both numbers are 6 to 9, so the answer is always 12 to 18.
    static func make<G: RandomNumberGenerator>(using generator: inout G) -> ParentGate {
        let left = Int.random(in: 6...9, using: &generator)
        let right = Int.random(in: 6...9, using: &generator)
        let answer = left + right
        // Wrong answers that look plausible: close to the real one, never equal or repeated.
        var options: Set<Int> = [answer]
        while options.count < 4 {
            let offset = Int.random(in: -3...3, using: &generator)
            if offset != 0, answer + offset > 0 { options.insert(answer + offset) }
        }
        return ParentGate(left: left, right: right, choices: options.sorted())
    }

    static func make() -> ParentGate {
        var generator = SystemRandomNumberGenerator()
        return make(using: &generator)
    }
}
