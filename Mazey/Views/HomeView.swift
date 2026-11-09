//
//  HomeView.swift
//  Mazey
//

import SwiftUI

/// The first screen: a big Play button, then the sticker book and characters. Wide screens put the title beside the buttons.
struct HomeView: View {
    let session: MazeGameSession
    let onPlay: () -> Void
    let onStickers: () -> Void
    let onCharacters: () -> Void

    @State private var showsSettings = false
    /// Where the title and buttons are, so no scenery is drawn behind them.
    @State private var clearAreas: [String: CGRect] = [:]

    private var theme: MazeTheme { session.theme }
    private var titleColor: Color { theme.isDark ? .white : theme.ink }

    var body: some View {
        GeometryReader { geometry in
            let isWide = geometry.size.width > geometry.size.height * 1.15
            let layout = isWide ? AnyLayout(HStackLayout(spacing: 48)) : AnyLayout(VStackLayout(spacing: 30))
            layout {
                hero
                menu
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
        }
        .background {
            ThemeBackdrop(theme: theme, seed: session.maze.seed, keepClear: Array(clearAreas.values))
                .ignoresSafeArea()
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showsSettings = true } label: { Image(systemName: "gearshape.fill") }
                    .accessibilityLabel("Settings")
            }
        }
        .sheet(isPresented: $showsSettings) { SettingsView(session: session) }
        .themedWindowAppearance(theme)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(theme.isDark ? .dark : .light, for: .navigationBar)
        #endif
    }

    // MARK: - Pieces

    /// The title, with the theme's character on its way to the goal.
    private var hero: some View {
        heroContent.keepsSceneryClear("hero", in: $clearAreas)
    }

    private var heroContent: some View {
        VStack(spacing: 14) {
            HStack(spacing: 18) {
                Text(session.playerEmoji)
                Image(systemName: "arrow.right")
                    .font(.system(size: 34, weight: .heavy))
                    .foregroundStyle(titleColor.opacity(0.7))
                Text(theme.finishEmoji)
            }
            .font(.system(size: 76))
            .accessibilityHidden(true)

            Text("Maze Adventures")
                .font(.system(size: 42, weight: .heavy, design: .rounded))
                .foregroundStyle(titleColor)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.6)
        }
    }

    /// Play, then the sticker book and characters. When there is not enough
    /// height (a phone on its side) the sticker book and characters sit side by side.
    private var menu: some View {
        ViewThatFits(in: .vertical) {
            menuStack(sideBySide: false)
            menuStack(sideBySide: true)
        }
    }

    private func menuStack(sideBySide: Bool) -> some View {
        VStack(spacing: 18) {
            Button(action: onPlay) {
                Label("Play", systemImage: "play.fill")
                    .font(.system(size: 40, weight: .heavy, design: .rounded))
                    .padding(.horizontal, 40)
                    .padding(.vertical, 10)
                    .frame(maxWidth: 360)
            }
            .buttonStyle(.borderedProminent)
            .tint(theme.accent)
            .controlSize(.extraLarge)
            .keepsSceneryClear("play", in: $clearAreas)

            let layout = sideBySide ? AnyLayout(HStackLayout(spacing: 12)) : AnyLayout(VStackLayout(spacing: 18))
            layout {
                Button(action: onStickers) { stickerButtonLabel }
                    .buttonStyle(.bordered)
                    .controlSize(.extraLarge)
                    .tint(titleColor)
                    .keepsSceneryClear("stickers", in: $clearAreas)

                Button(action: onCharacters) { charactersButtonLabel }
                    .buttonStyle(.bordered)
                    .controlSize(.extraLarge)
                    .tint(titleColor)
                    .keepsSceneryClear("characters", in: $clearAreas)
            }
            .frame(maxWidth: sideBySide ? 360 : nil)
        }
    }

    /// The sticker book: its name, and how full it is.
    private var stickerButtonLabel: some View {
        let collection = session.collection
        return menuButtonLabel(
            title: "Stickers",
            detail: ("square.grid.2x2.fill", "\(collection.ownedStickerCount) / \(CollectionStore.totalStickerCount)"),
            accessibility: "Sticker book, \(collection.ownedStickerCount) of \(CollectionStore.totalStickerCount) stickers"
        ) {
            Image(systemName: "book.pages.fill").font(.system(size: 30))
        }
    }

    /// The characters picker: who is playing now, its name, and how far the next character is.
    private var charactersButtonLabel: some View {
        let collection = session.collection
        let detail: (symbol: String, text: String)
        if let next = PlayerCharacter.next(after: collection.totalStars) {
            detail = ("star.fill", "\(collection.totalStars) / \(next.starsNeeded)")
        } else {
            detail = ("star.fill", "All found!")
        }
        return menuButtonLabel(
            title: "Characters",
            detail: detail,
            accessibility: "Characters, \(collection.unlockedCharacters.count) of \(PlayerCharacter.all.count) unlocked"
        ) {
            Text(session.playerEmoji).font(.system(size: 34))
        }
    }

    /// An icon, a name and a small count, so each button says what it opens.
    private func menuButtonLabel<Icon: View>(
        title: String,
        detail: (symbol: String, text: String),
        accessibility: String,
        @ViewBuilder icon: () -> Icon
    ) -> some View {
        HStack(spacing: 10) {
            icon()
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                HStack(spacing: 4) {
                    Image(systemName: detail.symbol)
                    Text(detail.text)
                }
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .opacity(0.8)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 4)
        .frame(maxWidth: 320)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibility)
    }
}

private extension View {
    /// Reports where this view is on screen, so the backdrop can leave it free of scenery.
    func keepsSceneryClear(_ id: String, in areas: Binding<[String: CGRect]>) -> some View {
        onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { areas.wrappedValue[id] = $0 }
    }
}
