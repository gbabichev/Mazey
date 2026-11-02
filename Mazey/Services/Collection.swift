//
//  Collection.swift
//  Mazey
//

import Foundation
import Observation

// MARK: - Saved data

/// One sticker in the book: how many times it has been earned, and whether any was a gold one.
nonisolated struct StickerEntry: Codable, Equatable, Sendable {
    var count: Int
    var gold: Bool
    var firstEarned: Date
}

/// What happened in one finished maze.
nonisolated struct FinishRecord: Codable, Equatable, Identifiable, Sendable {
    var id = UUID()
    var date: Date
    var difficulty: MazeDifficulty
    var themeID: String
    var rows: Int
    var columns: Int
    var seconds: Double
    var starsCollected: Int
    var starsTotal: Int
    var stickerIndex: Int

    /// Every star in the maze was collected.
    var isPerfect: Bool { starsTotal > 0 && starsCollected >= starsTotal }
}

/// Everything remembered between launches.
nonisolated struct Progress: Codable, Equatable, Sendable {
    /// Keyed by "themeID/index".
    var stickers: [String: StickerEntry] = [:]
    var finishes: [FinishRecord] = []

    static func key(themeID: String, index: Int) -> String { "\(themeID)/\(index)" }
}

// MARK: - Choosing a sticker

nonisolated enum StickerAwarder {
    /// Which of a theme's stickers a finished maze earns: one the player does not have yet if
    /// there is any, so the book keeps filling; after that, a gold run upgrades a sticker that is
    /// not gold yet; otherwise any of them again. `seed` makes the pick repeatable.
    static func choose(themeID: String, stickerCount: Int, in progress: Progress, wantsGold: Bool, seed: UInt64) -> Int {
        guard stickerCount > 0 else { return 0 }
        let all = Array(0..<stickerCount)
        let entries = all.map { progress.stickers[Progress.key(themeID: themeID, index: $0)] }
        let unowned = all.filter { entries[$0] == nil }
        let pool: [Int]
        if !unowned.isEmpty {
            pool = unowned
        } else if wantsGold, case let notGold = all.filter({ entries[$0]?.gold == false }), !notGold.isEmpty {
            pool = notGold
        } else {
            pool = all
        }
        return pool[Int(seed % UInt64(pool.count))]
    }
}

/// What a finished maze earned.
nonisolated struct FinishReward: Equatable, Sendable {
    var themeID: String
    var stickerIndex: Int
    var sticker: Sticker
    /// The sticker was not in the book before.
    var isNew: Bool
    /// This sticker is gold: every star was collected.
    var isGold: Bool
    var starsCollected: Int
    var starsTotal: Int
    /// The fastest maze so far at this difficulty (only announced after a few tries).
    var isPersonalBest: Bool
}

// MARK: - Statistics

nonisolated struct DifficultyStatistics: Equatable, Sendable {
    var count: Int
    var average: Double
    var fastest: Double
}

/// Numbers worked out from the list of finished mazes.
nonisolated struct Statistics: Sendable {
    let finishes: [FinishRecord]
    let calendar: Calendar

    init(finishes: [FinishRecord], calendar: Calendar = .current) {
        self.finishes = finishes
        self.calendar = calendar
    }

    var totalFinished: Int { finishes.count }
    var totalStars: Int { finishes.reduce(0) { $0 + $1.starsCollected } }
    var perfectMazes: Int { finishes.filter(\.isPerfect).count }

    var daysPlayed: Int {
        Set(finishes.map { calendar.startOfDay(for: $0.date) }).count
    }

    /// Days in a row, up to and including today (or yesterday, so the streak is not lost before
    /// the child has played today), on which at least one maze was finished.
    func currentStreak(today: Date = Date()) -> Int {
        let days = Set(finishes.map { calendar.startOfDay(for: $0.date) })
        var day = calendar.startOfDay(for: today)
        if !days.contains(day) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: day), days.contains(yesterday) else { return 0 }
            day = yesterday
        }
        var streak = 0
        while days.contains(day) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return streak
    }

    func difficulty(_ difficulty: MazeDifficulty) -> DifficultyStatistics? {
        let times = finishes.filter { $0.difficulty == difficulty }.map(\.seconds)
        guard let fastest = times.min() else { return nil }
        return DifficultyStatistics(count: times.count, average: times.reduce(0, +) / Double(times.count), fastest: fastest)
    }

    /// The most recent finishes, newest first.
    func recent(_ limit: Int) -> [FinishRecord] {
        Array(finishes.sorted { $0.date > $1.date }.prefix(limit))
    }

    /// "1:05" for 65 seconds; "0:07" for 7.
    static func format(_ seconds: Double) -> String {
        let whole = max(0, Int(seconds.rounded()))
        return "\(whole / 60):" + String(format: "%02d", whole % 60)
    }
}

// MARK: - The store

/// The sticker book and the history of finished mazes, saved on the device.
@MainActor
@Observable
final class CollectionStore {
    static let key = "progress.v1"
    /// Older finishes are dropped past this, so the saved data stays small.
    static let maximumRecords = 1000
    /// A personal best is only announced after this many earlier mazes at that difficulty.
    static let bestNeedsHistory = 3

    private(set) var progress: Progress
    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.key), let saved = try? JSONDecoder().decode(Progress.self, from: data) {
            progress = saved
        } else {
            progress = Progress()
        }
    }

    // MARK: Recording

    /// Records a finished maze, awards its sticker and returns what was earned.
    @discardableResult
    func recordFinish(
        theme: MazeTheme,
        difficulty: MazeDifficulty,
        rows: Int,
        columns: Int,
        seconds: Double,
        starsCollected: Int,
        starsTotal: Int,
        seed: UInt64,
        now: Date = Date()
    ) -> FinishReward {
        let wantsGold = starsTotal > 0 && starsCollected >= starsTotal
        let index = StickerAwarder.choose(
            themeID: theme.id, stickerCount: theme.stickers.count, in: progress, wantsGold: wantsGold, seed: seed
        )
        let key = Progress.key(themeID: theme.id, index: index)
        let isNew = progress.stickers[key] == nil
        var entry = progress.stickers[key] ?? StickerEntry(count: 0, gold: false, firstEarned: now)
        entry.count += 1
        entry.gold = entry.gold || wantsGold
        progress.stickers[key] = entry

        let earlier = progress.finishes.filter { $0.difficulty == difficulty }
        let isBest = earlier.count >= Self.bestNeedsHistory && earlier.allSatisfy { seconds < $0.seconds }

        progress.finishes.append(FinishRecord(
            date: now, difficulty: difficulty, themeID: theme.id, rows: rows, columns: columns,
            seconds: seconds, starsCollected: starsCollected, starsTotal: starsTotal, stickerIndex: index
        ))
        if progress.finishes.count > Self.maximumRecords {
            progress.finishes.removeFirst(progress.finishes.count - Self.maximumRecords)
        }
        save()

        return FinishReward(
            themeID: theme.id, stickerIndex: index, sticker: theme.stickers[index], isNew: isNew,
            isGold: wantsGold, starsCollected: starsCollected, starsTotal: starsTotal, isPersonalBest: isBest
        )
    }

    private func save() {
        if let data = try? JSONEncoder().encode(progress) {
            defaults.set(data, forKey: Self.key)
        }
    }

    // MARK: Reading

    var statistics: Statistics { Statistics(finishes: progress.finishes) }

    func entry(themeID: String, index: Int) -> StickerEntry? {
        progress.stickers[Progress.key(themeID: themeID, index: index)]
    }

    /// Different stickers in the book (earning the same one twice counts once).
    var ownedStickerCount: Int { progress.stickers.count }

    static var totalStickerCount: Int { MazeTheme.all.reduce(0) { $0 + $1.stickers.count } }

    func ownedCount(in theme: MazeTheme) -> Int {
        theme.stickers.indices.filter { entry(themeID: theme.id, index: $0) != nil }.count
    }

    /// The most recently earned stickers, newest first, each shown once.
    func newestStickers(_ limit: Int) -> [(theme: MazeTheme, sticker: Sticker, entry: StickerEntry)] {
        progress.stickers
            .compactMap { key, entry -> (MazeTheme, Sticker, StickerEntry)? in
                let parts = key.split(separator: "/")
                guard parts.count == 2, let index = Int(parts[1]),
                      let theme = MazeTheme.all.first(where: { $0.id == parts[0] }),
                      theme.stickers.indices.contains(index) else { return nil }
                return (theme, theme.stickers[index], entry)
            }
            .sorted { $0.2.firstEarned > $1.2.firstEarned }
            .prefix(limit)
            .map { (theme: $0.0, sticker: $0.1, entry: $0.2) }
    }
}
