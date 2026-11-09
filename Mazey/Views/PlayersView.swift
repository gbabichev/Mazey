//
//  PlayersView.swift
//  Mazey
//

import SwiftUI

/// Who is playing. Each player has their own stickers, characters and statistics, which is
/// what lets several children share one iPad. Tapping a player switches to them.
struct PlayersView: View {
    let session: MazeGameSession
    @State private var editing: Player?
    @State private var addsPlayer = false
    @Environment(\.dismiss) private var dismiss

    private var roster: PlayerRoster { session.roster }

    var body: some View {
        #if os(iOS)
        NavigationStack {
            list
                .navigationTitle("Players")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
        }
        .presentationDetents([.medium, .large])
        .sheets(for: self)
        #else
        VStack(alignment: .leading, spacing: 16) {
            Text("Players")
                .font(.title2.weight(.semibold))
            list
            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 440, height: 560)
        .sheets(for: self)
        #endif
    }

    private var list: some View {
        List {
            Section {
                ForEach(roster.players) { player in
                    row(for: player)
                }
            }
            Section {
                Button {
                    addsPlayer = true
                } label: {
                    Label("Add player", systemImage: "plus.circle.fill")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                }
                .disabled(!roster.canAddPlayer)
            } footer: {
                Text(roster.canAddPlayer
                     ? "Everyone has their own stickers, characters and statistics."
                     : "That is as many players as fit. Remove one to add another.")
            }
        }
    }

    private func row(for player: Player) -> some View {
        let isCurrent = player.id == roster.currentID
        let summary = session.summary(of: player)
        return HStack(spacing: 14) {
            Button {
                session.selectPlayer(player.id)
                dismiss()
            } label: {
                HStack(spacing: 14) {
                    Text(player.avatar).font(.system(size: 40))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(player.name)
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                        Text("\(summary.stickers) stickers · \(summary.stars) stars")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if isCurrent {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.green)
                            .accessibilityLabel("Playing now")
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                editing = player
            } label: {
                Image(systemName: "pencil.circle")
                    .font(.title2)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Edit \(player.name)")
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .contain)
    }

    fileprivate func editorSheets<Content: View>(_ content: Content) -> some View {
        content
            .sheet(item: $editing) { player in
                PlayerEditorView(session: session, mode: .edit(player)) {}
            }
            .sheet(isPresented: $addsPlayer) {
                PlayerEditorView(session: session, mode: .add) { dismiss() }
            }
    }
}

private extension View {
    func sheets(for view: PlayersView) -> some View { view.editorSheets(self) }
}

/// Adds a player, or changes a player's name and picture, or removes them.
struct PlayerEditorView: View {
    enum Mode {
        case add
        case edit(Player)
    }

    let session: MazeGameSession
    let mode: Mode
    /// Called once a new player has been added, so the list behind can close too.
    let onAdded: () -> Void

    @State private var name: String
    @State private var avatar: String
    @State private var confirmsRemoval = false
    @Environment(\.dismiss) private var dismiss

    init(session: MazeGameSession, mode: Mode, onAdded: @escaping () -> Void) {
        self.session = session
        self.mode = mode
        self.onAdded = onAdded
        switch mode {
        case .add:
            _name = State(initialValue: "")
            _avatar = State(initialValue: session.roster.suggestedAvatar)
        case .edit(let player):
            _name = State(initialValue: player.name)
            _avatar = State(initialValue: player.avatar)
        }
    }

    private var editedPlayer: Player? {
        if case .edit(let player) = mode { return player }
        return nil
    }

    private var title: String { editedPlayer == nil ? "New player" : "Edit player" }

    var body: some View {
        #if os(iOS)
        NavigationStack {
            form
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { Button("Save") { save() } }
                }
        }
        .presentationDetents([.large])
        #else
        VStack(alignment: .leading, spacing: 16) {
            Text(title).font(.title2.weight(.semibold))
            form
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Save") { save() }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 440, height: 600)
        #endif
    }

    private var form: some View {
        Form {
            Section("Name") {
                TextField("Player name", text: $name)
                    .autocorrectionDisabled()
                    #if os(iOS)
                    .textInputAutocapitalization(.words)
                    #endif
                    .onChange(of: name) { _, newValue in
                        if newValue.count > 14 { name = String(newValue.prefix(14)) }
                    }
            }
            Section("Picture") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 52), spacing: 8)], spacing: 8) {
                    ForEach(PlayerAvatar.all, id: \.self) { emoji in
                        Button {
                            avatar = emoji
                        } label: {
                            Text(emoji)
                                .font(.system(size: 34))
                                .frame(width: 52, height: 52)
                                .background(avatar == emoji ? Color.accentColor.opacity(0.25) : Color.clear, in: RoundedRectangle(cornerRadius: 12))
                                .overlay {
                                    if avatar == emoji {
                                        RoundedRectangle(cornerRadius: 12).strokeBorder(Color.accentColor, lineWidth: 3)
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(avatar == emoji ? .isSelected : [])
                    }
                }
                .padding(.vertical, 4)
            }
            if let player = editedPlayer, session.roster.players.count > 1 {
                Section {
                    Button("Remove \(player.name)…", role: .destructive) { confirmsRemoval = true }
                } footer: {
                    Text("Removes this player and everything they earned. A grown-up has to confirm.")
                }
            }
        }
        .formStyle(.grouped)
        .sheet(isPresented: $confirmsRemoval) {
            if let player = editedPlayer {
                ParentGateView(
                    message: "This removes \(player.name) and all their stickers, stars, characters and statistics. It cannot be undone."
                ) {
                    session.removePlayer(player.id)
                    dismiss()
                }
            }
        }
    }

    private func save() {
        if let player = editedPlayer {
            session.roster.update(player.id, name: name, avatar: avatar)
            dismiss()
        } else {
            session.addPlayer(name: name, avatar: avatar)
            dismiss()
            onAdded()
        }
    }
}
