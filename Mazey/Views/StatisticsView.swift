//
//  StatisticsView.swift
//  Mazey
//

import Charts
import SwiftUI

/// The numbers for grown-ups: how many mazes, how long they take, and how it is trending.
/// Children never see times, so there is nothing to race against.
struct StatisticsView: View {
    /// Whose numbers these are; each player has their own.
    let player: Player
    let collection: CollectionStore
    /// Wipes this player's progress and starts them over.
    let onReset: () -> Void
    @State private var confirmsReset = false
    @Environment(\.dismiss) private var dismiss

    private var statistics: Statistics { collection.statistics }

    var body: some View {
        #if os(iOS)
        NavigationStack {
            content
                .navigationTitle("Statistics")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
        }
        #else
        VStack(alignment: .leading, spacing: 16) {
            Text("Statistics")
                .font(.title2.weight(.semibold))
            content
            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 520, height: 640)
        #endif
    }

    private var content: some View {
        Form {
            Section {
                LabeledContent("Player") {
                    Text("\(player.avatar) \(player.name)")
                }
            }
            if statistics.totalFinished == 0 {
                Section {
                    Text("No mazes finished yet. Numbers will show up here after the first one.")
                        .foregroundStyle(.secondary)
                }
            } else {
                overall
                byLevel
                recent
            }
            resetSection
        }
        .formStyle(.grouped)
        .sheet(isPresented: $confirmsReset) {
            ParentGateView(
                message: "This erases \(player.name)'s stickers, stars, characters and statistics, as if they had just started. Other players are not changed. It cannot be undone."
            ) {
                onReset()
                dismiss()
            }
        }
    }

    private var resetSection: some View {
        Section {
            Button("Reset \(player.name)'s progress…", role: .destructive) { confirmsReset = true }
        } footer: {
            Text("Clears this player's stickers, stars, characters and statistics and starts them over. Other players are not changed.")
        }
    }

    // MARK: - Sections

    private var overall: some View {
        Section("Overall") {
            LabeledContent("Mazes finished", value: "\(statistics.totalFinished)")
            LabeledContent("Stars collected", value: "\(collection.totalStars)")
            LabeledContent("Mazes with every star", value: "\(statistics.perfectMazes)")
            LabeledContent("Stickers in the book", value: "\(collection.ownedStickerCount) of \(CollectionStore.totalStickerCount)")
            LabeledContent("Characters unlocked", value: "\(collection.unlockedCharacters.count) of \(PlayerCharacter.all.count)")
            LabeledContent("Days played", value: "\(statistics.daysPlayed)")
            LabeledContent("Days in a row", value: "\(statistics.currentStreak())")
        }
    }

    private var byLevel: some View {
        Section {
            ForEach(MazeDifficulty.allCases) { difficulty in
                if let numbers = statistics.difficulty(difficulty) {
                    HStack {
                        Text(String(repeating: "⭐️", count: difficulty.starCount))
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(numbers.count) \(numbers.count == 1 ? "maze" : "mazes")")
                            Text("average \(Statistics.format(numbers.average)) · fastest \(Statistics.format(numbers.fastest))")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    HStack {
                        Text(String(repeating: "⭐️", count: difficulty.starCount))
                        Spacer()
                        Text("none yet").foregroundStyle(.secondary)
                    }
                }
            }
        } header: {
            Text("By level")
        } footer: {
            Text("Time counts only while the maze is being played; long pauses are cut short.")
        }
    }

    private var recent: some View {
        let latest = statistics.recent(20)
        return Section("Recent mazes") {
            Chart(Array(latest.reversed().enumerated()), id: \.element.id) { index, record in
                BarMark(
                    x: .value("Maze", index),
                    y: .value("Seconds", record.seconds)
                )
                .foregroundStyle(by: .value("Level", String(repeating: "⭐️", count: record.difficulty.starCount)))
            }
            .chartXAxis(.hidden)
            .chartYAxisLabel("seconds")
            .frame(height: 160)
            .padding(.vertical, 4)

            ForEach(latest.prefix(8)) { record in
                HStack {
                    Text(record.date, style: .date)
                    Text(String(repeating: "⭐️", count: record.difficulty.starCount))
                    Spacer()
                    Text("\(record.starsCollected)/\(record.starsTotal) ★")
                        .foregroundStyle(.secondary)
                    Text(Statistics.format(record.seconds))
                        .monospacedDigit()
                        .frame(minWidth: 44, alignment: .trailing)
                }
                .font(.callout)
            }
        }
    }
}
