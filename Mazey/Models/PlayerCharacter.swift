//
//  PlayerCharacter.swift
//  Mazey
//

import Foundation

/// A character the player can swap in for the world's own, unlocked by collecting stars.
/// Stars only ever add up: nothing is spent and nothing is lost.
nonisolated struct PlayerCharacter: Identifiable, Hashable, Sendable {
    let id: String
    let emoji: String
    let name: String
    /// Total stars collected, across all mazes, needed to unlock this character.
    let starsNeeded: Int

    /// Every character, in the order they unlock: animals mixed with vehicles and other cool
    /// characters. The gaps grow slowly, so the first one arrives within a couple of mazes
    /// and the last takes around a hundred and thirty.
    static let all: [PlayerCharacter] = [
        PlayerCharacter(id: "racecar", emoji: "🏎️", name: "Race car", starsNeeded: 10),
        PlayerCharacter(id: "kitten", emoji: "🐱", name: "Kitten", starsNeeded: 25),
        PlayerCharacter(id: "rocket", emoji: "🚀", name: "Rocket", starsNeeded: 40),
        PlayerCharacter(id: "panda", emoji: "🐼", name: "Panda", starsNeeded: 55),
        PlayerCharacter(id: "firetruck", emoji: "🚒", name: "Fire truck", starsNeeded: 75),
        PlayerCharacter(id: "lion", emoji: "🦁", name: "Lion", starsNeeded: 95),
        PlayerCharacter(id: "robot", emoji: "🤖", name: "Robot", starsNeeded: 120),
        PlayerCharacter(id: "frog", emoji: "🐸", name: "Frog", starsNeeded: 145),
        PlayerCharacter(id: "helicopter", emoji: "🚁", name: "Helicopter", starsNeeded: 175),
        PlayerCharacter(id: "dragon", emoji: "🐉", name: "Dragon", starsNeeded: 205),
        PlayerCharacter(id: "tractor", emoji: "🚜", name: "Tractor", starsNeeded: 240),
        PlayerCharacter(id: "monkey", emoji: "🐵", name: "Monkey", starsNeeded: 275),
        PlayerCharacter(id: "saucer", emoji: "🛸", name: "UFO", starsNeeded: 315),
        PlayerCharacter(id: "owl", emoji: "🦉", name: "Owl", starsNeeded: 355),
        PlayerCharacter(id: "train", emoji: "🚂", name: "Train", starsNeeded: 400),
        PlayerCharacter(id: "elephant", emoji: "🐘", name: "Elephant", starsNeeded: 445),
        PlayerCharacter(id: "trex", emoji: "🦖", name: "T-rex", starsNeeded: 495),
        PlayerCharacter(id: "flamingo", emoji: "🦩", name: "Flamingo", starsNeeded: 545),
        PlayerCharacter(id: "superhero", emoji: "🦸", name: "Superhero", starsNeeded: 600),
        PlayerCharacter(id: "sloth", emoji: "🦥", name: "Sloth", starsNeeded: 670),
        // The last one is a long way off. There is no fighter-jet emoji, so it is the airplane.
        PlayerCharacter(id: "jet", emoji: "✈️", name: "Fighter jet", starsNeeded: 750),
    ]

    static func character(id: String?) -> PlayerCharacter? {
        guard let id else { return nil }
        return all.first { $0.id == id }
    }

    /// The characters unlocked once `stars` have been collected.
    static func unlocked(by stars: Int) -> [PlayerCharacter] {
        all.filter { $0.starsNeeded <= stars }
    }

    /// The next character still to unlock, if there is one.
    static func next(after stars: Int) -> PlayerCharacter? {
        all.first { $0.starsNeeded > stars }
    }

    func isUnlocked(by stars: Int) -> Bool { starsNeeded <= stars }
}
