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
        .sheet(isPresented: $confirmsReset) {
            ParentGateView {
                onReset()
                dismiss()
            }
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
            LabeledContent("Stars collected", value: "\(collection.totalStars)")
            LabeledContent("Mazes with every star", value: "\(statistics.perfectMazes)")
            LabeledContent("Stickers in the book", value: "\(collection.ownedStickerCount) of \(CollectionStore.totalStickerCount)")
            LabeledContent("Friends unlocked", value: "\(collection.unlockedFriends.count) of \(Friend.all.count)")
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

/// "Ask a grown-up": the reset only goes ahead when a simple sum is answered correctly.
private struct ParentGateView: View {
    let onPassed: () -> Void
    @State private var gate = ParentGate.make()
    @State private var missed = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 18) {
            Text("Ask a grown-up")
                .font(.title2.weight(.semibold))
            Text("This erases all stickers, stars, statistics and settings, as if the app was just installed. It cannot be undone.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Text("What is \(gate.question)?")
                .font(.title.weight(.bold))
                .padding(.top, 4)
            HStack(spacing: 12) {
                ForEach(gate.choices, id: \.self) { choice in
                    Button("\(choice)") { choose(choice) }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        .font(.title3.weight(.semibold))
                }
            }
            if missed {
                Text("Not quite. Here is another one.")
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
            Button("Cancel", role: .cancel) { dismiss() }
                .keyboardShortcut(.cancelAction)
        }
        .padding(24)
        #if os(iOS)
        .presentationDetents([.medium])
        #else
        .frame(width: 420)
        #endif
    }

    private func choose(_ choice: Int) {
        if gate.isCorrect(choice) {
            dismiss()
            onPassed()
        } else {
            missed = true
            gate = ParentGate.make()
        }
    }
}
