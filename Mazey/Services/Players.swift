//
//  Players.swift
//  Mazey
//

import Foundation
import Observation

/// One child who plays. Each player has their own stickers, stars, characters, statistics and
/// difficulty; the sound and maze shape settings are shared by everyone on the device.
nonisolated struct Player: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var name: String
    /// An emoji picture, so children can find themselves without reading.
    var avatar: String
}

nonisolated enum PlayerAvatar {
    /// The pictures to choose from. They avoid the unlockable characters, so a player's picture is
    /// never mistaken for a character.
    static let all = [
        "🐶", "🐰", "🐻", "🦊", "🐯", "🐮", "🐷", "🐭", "🐹", "🐥", "🦆", "🐴",
        "🐞", "🐙", "🐠", "🐬", "🦋", "🐢", "🐧", "🦄", "🐳", "🦔", "🐝", "🦀",
    ]
}

/// The names of the settings kept for each player, each saved under a key made from the
/// player's id (see `PlayerRoster.key(_:for:)`).
nonisolated enum PlayerData {
    static let progress = "progress.v1"
    static let difficulty = "difficulty"
    static let demoSeen = "demoSeen"
    static let completed = "completedMazes"

    static let all = [progress, difficulty, demoSeen, completed]
}

/// Who plays on this device, and who is playing now. Saved on the device.
@MainActor
@Observable
final class PlayerRoster {
    static let key = "players.v1"
    /// Enough for a family or a small class, and few enough to fit on one screen.
    static let maximumPlayers = 8

    private(set) var players: [Player]
    private(set) var currentID: UUID
    @ObservationIgnored private let defaults: UserDefaults

    private struct Saved: Codable {
        var players: [Player]
        var currentID: UUID
    }

    /// Loads the saved players. On the first launch with players there are none saved, so the
    /// first player is made and takes over anything saved by the older single-player app.
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.key),
           let saved = try? JSONDecoder().decode(Saved.self, from: data), !saved.players.isEmpty {
            players = saved.players
            currentID = saved.players.contains { $0.id == saved.currentID } ? saved.currentID : saved.players[0].id
        } else {
            let first = Player(id: UUID(), name: Self.defaultName(number: 1), avatar: PlayerAvatar.all[0])
            players = [first]
            currentID = first.id
            adoptSavedDataOfTheSinglePlayerApp(for: first.id)
            save()
        }
    }

    var current: Player { players.first { $0.id == currentID } ?? players[0] }
    var canAddPlayer: Bool { players.count < Self.maximumPlayers }

    /// The key a setting is saved under for one player.
    static func key(_ base: String, for id: UUID) -> String { "\(base).\(id.uuidString)" }

    static func defaultName(number: Int) -> String { "Player \(number)" }

    // MARK: Changing who plays

    /// Adds a player. A name left empty becomes "Player 3" and so on; a long name is cut short.
    @discardableResult
    func add(name: String, avatar: String? = nil) -> Player {
        let player = Player(
            id: UUID(),
            name: Self.cleaned(name, fallback: Self.defaultName(number: players.count + 1)),
            avatar: avatar ?? nextUnusedAvatar()
        )
        players.append(player)
        save()
        return player
    }

    func update(_ id: UUID, name: String, avatar: String) {
        guard let index = players.firstIndex(where: { $0.id == id }) else { return }
        players[index].name = Self.cleaned(name, fallback: players[index].name)
        players[index].avatar = avatar
        save()
    }

    func select(_ id: UUID) {
        guard players.contains(where: { $0.id == id }), id != currentID else { return }
        currentID = id
        save()
    }

    /// Removes a player and everything they earned. The last player cannot be removed. If the
    /// player who was playing is removed, the first one left takes over.
    func remove(_ id: UUID) {
        guard players.count > 1, players.contains(where: { $0.id == id }) else { return }
        for base in PlayerData.all { defaults.removeObject(forKey: Self.key(base, for: id)) }
        players.removeAll { $0.id == id }
        if currentID == id { currentID = players[0].id }
        save()
    }

    /// Removes every player and everything they earned, then starts again with one new player,
    /// as on a first launch.
    func resetAll() {
        for player in players {
            for base in PlayerData.all { defaults.removeObject(forKey: Self.key(base, for: player.id)) }
        }
        let first = Player(id: UUID(), name: Self.defaultName(number: 1), avatar: PlayerAvatar.all[0])
        players = [first]
        currentID = first.id
        save()
    }

    // MARK: Private

    private static func cleaned(_ name: String, fallback: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : String(trimmed.prefix(14))
    }

    /// A picture nobody is using yet, to suggest for a new player.
    var suggestedAvatar: String { nextUnusedAvatar() }

    private func nextUnusedAvatar() -> String {
        let used = Set(players.map(\.avatar))
        return PlayerAvatar.all.first { !used.contains($0) } ?? PlayerAvatar.all[players.count % PlayerAvatar.all.count]
    }

    /// Before there were players, progress was saved under plain keys. Move it to the first
    /// player so nobody loses anything.
    private func adoptSavedDataOfTheSinglePlayerApp(for id: UUID) {
        for base in PlayerData.all {
            guard let value = defaults.object(forKey: base) else { continue }
            defaults.set(value, forKey: Self.key(base, for: id))
            defaults.removeObject(forKey: base)
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(Saved(players: players, currentID: currentID)) {
            defaults.set(data, forKey: Self.key)
        }
    }
}
