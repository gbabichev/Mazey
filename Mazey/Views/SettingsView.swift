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
    @State private var showsIntro = false

    var body: some View {
        content
            .sheet(isPresented: $showsIntro) {
                IntroView(theme: session.theme) { showsIntro = false }
                    #if os(macOS)
                    .frame(width: 520, height: 620)
                    #endif
            }
    }

    @ViewBuilder
    private var content: some View {
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
                Label("Sound", systemImage: "speaker.wave.2.fill")
            }
            .toggleStyle(.switch)
            Toggle(isOn: $session.isDragMusicOn) {
                Label("Music while dragging", systemImage: "music.note")
            }
            .toggleStyle(.switch)
            .disabled(!session.isSoundOn)
            Toggle(isOn: $session.isApplauseOn) {
                Label("Applause at the end", systemImage: "hands.clap.fill")
            }
            .toggleStyle(.switch)
            .disabled(!session.isSoundOn)
        } footer: {
            Text(session.isSoundOn ? "Sounds and vibration while you play." : "Turn on sound to choose what plays.")
        }

        Section {
            Button {
                showsIntro = true
            } label: {
                Label("How to play", systemImage: "questionmark.circle.fill")
            }
        } footer: {
            Text("A quick tour of stars, stickers and characters.")
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
