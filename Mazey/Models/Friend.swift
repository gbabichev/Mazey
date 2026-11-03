//
//  Friend.swift
//  Mazey
//

import Foundation

/// A character the player can swap in for the world's own, unlocked by collecting stars.
/// Stars only ever add up: nothing is spent and nothing is lost.
nonisolated struct Friend: Identifiable, Hashable, Sendable {
    let id: String
    let emoji: String
    let name: String
    /// Total stars collected, across all mazes, needed to unlock this friend.
    let starsNeeded: Int

    /// Every friend, in the order they unlock. The gaps grow slowly, so the first few arrive
    /// within a play session or two and the last takes around forty mazes.
    static let all: [Friend] = [
        Friend(id: "kitten", emoji: "🐱", name: "Kitten", starsNeeded: 5),
        Friend(id: "panda", emoji: "🐼", name: "Panda", starsNeeded: 10),
        Friend(id: "frog", emoji: "🐸", name: "Frog", starsNeeded: 18),
        Friend(id: "lion", emoji: "🦁", name: "Lion", starsNeeded: 27),
        Friend(id: "monkey", emoji: "🐵", name: "Monkey", starsNeeded: 37),
        Friend(id: "owl", emoji: "🦉", name: "Owl", starsNeeded: 48),
        Friend(id: "koala", emoji: "🐨", name: "Koala", starsNeeded: 60),
        Friend(id: "tiger", emoji: "🐯", name: "Tiger", starsNeeded: 73),
        Friend(id: "turtle", emoji: "🐢", name: "Turtle", starsNeeded: 88),
        Friend(id: "giraffe", emoji: "🦒", name: "Giraffe", starsNeeded: 104),
        Friend(id: "parrot", emoji: "🦜", name: "Parrot", starsNeeded: 121),
        Friend(id: "elephant", emoji: "🐘", name: "Elephant", starsNeeded: 140),
        Friend(id: "bear", emoji: "🐻", name: "Bear", starsNeeded: 160),
        Friend(id: "zebra", emoji: "🦓", name: "Zebra", starsNeeded: 182),
        Friend(id: "flamingo", emoji: "🦩", name: "Flamingo", starsNeeded: 205),
        Friend(id: "sloth", emoji: "🦥", name: "Sloth", starsNeeded: 230),
    ]

    static func friend(id: String?) -> Friend? {
        guard let id else { return nil }
        return all.first { $0.id == id }
    }

    /// The friends unlocked once `stars` have been collected.
    static func unlocked(by stars: Int) -> [Friend] {
        all.filter { $0.starsNeeded <= stars }
    }

    /// The next friend still to unlock, if there is one.
    static func next(after stars: Int) -> Friend? {
        all.first { $0.starsNeeded > stars }
    }

    func isUnlocked(by stars: Int) -> Bool { starsNeeded <= stars }
}
