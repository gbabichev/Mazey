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

    /// Every friend, in the order they unlock: animals mixed with vehicles and other cool
    /// characters. The gaps grow slowly, so the first one arrives within a couple of mazes
    /// and the last takes around a hundred and thirty.
    static let all: [Friend] = [
        Friend(id: "racecar", emoji: "🏎️", name: "Race car", starsNeeded: 10),
        Friend(id: "kitten", emoji: "🐱", name: "Kitten", starsNeeded: 25),
        Friend(id: "rocket", emoji: "🚀", name: "Rocket", starsNeeded: 40),
        Friend(id: "panda", emoji: "🐼", name: "Panda", starsNeeded: 55),
        Friend(id: "firetruck", emoji: "🚒", name: "Fire truck", starsNeeded: 75),
        Friend(id: "lion", emoji: "🦁", name: "Lion", starsNeeded: 95),
        Friend(id: "robot", emoji: "🤖", name: "Robot", starsNeeded: 120),
        Friend(id: "frog", emoji: "🐸", name: "Frog", starsNeeded: 145),
        Friend(id: "helicopter", emoji: "🚁", name: "Helicopter", starsNeeded: 175),
        Friend(id: "dragon", emoji: "🐉", name: "Dragon", starsNeeded: 205),
        Friend(id: "tractor", emoji: "🚜", name: "Tractor", starsNeeded: 240),
        Friend(id: "monkey", emoji: "🐵", name: "Monkey", starsNeeded: 275),
        Friend(id: "saucer", emoji: "🛸", name: "UFO", starsNeeded: 315),
        Friend(id: "owl", emoji: "🦉", name: "Owl", starsNeeded: 355),
        Friend(id: "train", emoji: "🚂", name: "Train", starsNeeded: 400),
        Friend(id: "elephant", emoji: "🐘", name: "Elephant", starsNeeded: 445),
        Friend(id: "trex", emoji: "🦖", name: "T-rex", starsNeeded: 495),
        Friend(id: "flamingo", emoji: "🦩", name: "Flamingo", starsNeeded: 545),
        Friend(id: "superhero", emoji: "🦸", name: "Superhero", starsNeeded: 600),
        Friend(id: "sloth", emoji: "🦥", name: "Sloth", starsNeeded: 670),
        // The last one is a long way off. There is no fighter-jet emoji, so it is the airplane.
        Friend(id: "jet", emoji: "✈️", name: "Fighter jet", starsNeeded: 750),
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
