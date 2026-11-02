//
//  SpokenPhrase.swift
//  Mazey
//

import Foundation

/// A short line the app says out loud, for players who cannot read yet.
nonisolated enum SpokenPhrase: Hashable, Sendable {
    /// A cheer for finishing. The number picks which one (it wraps).
    case cheer(Int)
    /// What to do, said when the demo shows. It names the theme's character and goal.
    case goal(themeID: String)

    static let cheers = ["You did it!", "Great job!", "Hooray!", "Awesome!", "Wow, you found it!"]

    var text: String {
        switch self {
        case .cheer(let variant):
            Self.cheers[abs(variant) % Self.cheers.count]
        case .goal(let themeID):
            switch themeID {
            case "space": "Help the rocket reach the planet!"
            case "dinosaur": "Help the dinosaur find its egg!"
            case "ocean": "Help the fish find the shell!"
            case "farm": "Help the bunny find the carrot!"
            case "unicorn": "Help the unicorn find the castle!"
            case "vehicles": "Help the car reach the finish!"
            case "robots": "Help the robot find its battery!"
            case "spring": "Help the bee find the tulip!"
            case "summer": "Help the surfer find the ice cream!"
            case "autumn": "Help the fox find the pumpkin!"
            case "winter": "Help the penguin find the snowman!"
            default: "Drag to the finish!"
            }
        }
    }

    /// Seconds to wait before speaking, so a cheer does not talk over the fanfare.
    var delay: Double {
        switch self {
        case .cheer: 0.7
        case .goal: 0.4
        }
    }
}
