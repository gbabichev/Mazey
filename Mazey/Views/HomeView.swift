//
//  HomeView.swift
//  Mazey
//

import SwiftUI

/// The first screen: a big Play button, the sticker book with a peek at the newest stickers,
/// and a few friendly milestones. Wide screens put the title beside the buttons.
struct HomeView: View {
    let session: MazeGameSession
    let onPlay: () -> Void
    let onStickers: () -> Void
    let onFriends: () -> Void

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

    /// Play, then the sticker book and friends, then the milestones. When there is not enough
    /// height (a phone on its side) the sticker book and friends sit side by side.
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

                Button(action: onFriends) { friendsButtonLabel }
                    .buttonStyle(.bordered)
                    .controlSize(.extraLarge)
                    .tint(titleColor)
                    .keepsSceneryClear("friends", in: $clearAreas)
            }
            .frame(maxWidth: sideBySide ? 360 : nil)

            milestones
                .keepsSceneryClear("milestones", in: $clearAreas)
        }
    }

    /// A peek at the newest stickers, then how full the book is.
    private var stickerButtonLabel: some View {
        let newest = session.collection.newestStickers(4)
        return HStack(spacing: 10) {
            if newest.isEmpty {
                Image(systemName: "book.pages.fill").font(.title)
            } else {
                HStack(spacing: -6) {
                    ForEach(Array(newest.enumerated()), id: \.offset) { _, item in
                        Text(item.sticker.emoji).font(.system(size: 30))
                    }
                }
            }
            Text("\(session.collection.ownedStickerCount) / \(CollectionStore.totalStickerCount)")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .padding(.vertical, 4)
        .frame(maxWidth: 320)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Sticker book, \(session.collection.ownedStickerCount) of \(CollectionStore.totalStickerCount) stickers")
    }

    /// Who is playing now, and how far the next friend is.
    private var friendsButtonLabel: some View {
        let collection = session.collection
        return HStack(spacing: 10) {
            Text(session.playerEmoji).font(.system(size: 30))
            if let next = Friend.next(after: collection.totalStars) {
                Label("\(collection.totalStars) / \(next.starsNeeded)", systemImage: "star.fill")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            } else {
                Text("Friends")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
            }
        }
        .padding(.vertical, 4)
        .frame(maxWidth: 320)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Friends, \(collection.unlockedFriends.count) of \(Friend.all.count) unlocked")
    }

    /// Positive-only numbers: how many mazes, how many stars, how many days in a row.
    @ViewBuilder
    private var milestones: some View {
        let stats = session.collection.statistics
        if stats.totalFinished > 0 {
            HStack(spacing: 10) {
                milestone("flag.checkered", "\(stats.totalFinished)", .green)
                milestone("star.fill", "\(session.collection.totalStars)", Color(red: 0.95, green: 0.7, blue: 0.0))
                let streak = stats.currentStreak()
                if streak > 1 { milestone("flame.fill", "\(streak)", .orange) }
            }
        }
    }

    private func milestone(_ symbol: String, _ value: String, _ color: Color) -> some View {
        Label(value, systemImage: symbol)
            .font(.system(size: 18, weight: .bold, design: .rounded))
            .foregroundStyle(color)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.regularMaterial, in: Capsule())
    }
}

private extension View {
    /// Reports where this view is on screen, so the backdrop can leave it free of scenery.
    func keepsSceneryClear(_ id: String, in areas: Binding<[String: CGRect]>) -> some View {
        onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { areas.wrappedValue[id] = $0 }
    }
}
