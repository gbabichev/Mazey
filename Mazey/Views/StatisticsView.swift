//
//  StatisticsView.swift
//  Mazey
//

import Charts
import SwiftUI

/// The numbers for grown-ups: how many mazes, how long they take, and how it is trending.
/// Children never see times, so there is nothing to race against.
struct StatisticsView: View {
    let collection: CollectionStore
    /// Wipes everything and starts the app over.
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
        .confirmationDialog("Start over?", isPresented: $confirmsReset, titleVisibility: .visible) {
            Button("Erase everything", role: .destructive) {
                onReset()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes all stickers, stars, statistics and settings, as if the app was just installed. It cannot be undone.")
        }
    }

    private var resetSection: some View {
        Section {
            Button("Reset everything…", role: .destructive) { confirmsReset = true }
        } footer: {
            Text("Clears stickers, statistics and settings and starts over.")
        }
    }

    // MARK: - Sections

    private var overall: some View {
        Section("Overall") {
            LabeledContent("Mazes finished", value: "\(statistics.totalFinished)")
            LabeledContent("Stars collected", value: "\(statistics.totalStars)")
            LabeledContent("Perfect mazes (all stars)", value: "\(statistics.perfectMazes)")
            LabeledContent("Stickers in the book", value: "\(collection.ownedStickerCount) of \(CollectionStore.totalStickerCount)")
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
