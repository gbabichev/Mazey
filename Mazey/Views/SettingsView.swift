//
//  SettingsView.swift
//  Mazey
//

import SwiftUI

/// Switches for what the app plays. The speaker button in the toolbar is a shortcut
/// for the first one.
struct SettingsView: View {
    @Bindable var session: MazeGameSession
    @Environment(\.dismiss) private var dismiss
    @State private var showsStatistics = false

    var body: some View {
        #if os(iOS)
        NavigationStack {
            Form { switches }
                .navigationTitle("Settings")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
        }
        .presentationDetents([.medium, .large])
        .sheet(isPresented: $showsStatistics) { StatisticsView(collection: session.collection, onReset: session.resetEverything) }
        #else
        // A Mac sheet has no navigation bar: a heading, the switches, and a Done button.
        VStack(alignment: .leading, spacing: 16) {
            Text("Settings")
                .font(.title2.weight(.semibold))
            Form { switches }
                .formStyle(.grouped)
                .scrollDisabled(true)
            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 400)
        .sheet(isPresented: $showsStatistics) { StatisticsView(collection: session.collection, onReset: session.resetEverything) }
        #endif
    }

    @ViewBuilder
    private var switches: some View {
        Section {
            Toggle(isOn: $session.isSoundOn) {
                Label("Sound effects", systemImage: "speaker.wave.2.fill")
            }
            .toggleStyle(.switch)
        } footer: {
            Text("Sounds and vibration while you play.")
        }

        Section {
            Button {
                showsStatistics = true
            } label: {
                Label("Statistics", systemImage: "chart.bar.fill")
            }
        } footer: {
            Text("How many mazes, and how long they take. For grown-ups.")
        }
    }
}
