//
//  MazeGameView.swift
//  Mazey
//

import SwiftUI

/// The single playable screen for the first milestone.
struct MazeGameView: View {
    let session: MazeGameSession
    @State private var lastDragLocation: CGPoint?
    @State private var showsSettings = false
    @FocusState private var isFocused: Bool
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        content
            .toolbar { toolbarContent }
            .sheet(isPresented: $showsSettings) { SettingsView(session: session) }
            .themedWindowAppearance(session.theme)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(session.theme.isDark ? .dark : .light, for: .navigationBar)
            #endif
    }

    private var content: some View {
        VStack(spacing: 6) {
            mazeArea
            // Not a control, so it lives with the maze instead of in the toolbar.
            if !session.stars.isEmpty {
                StarProgress(collected: session.collectedStars.count, total: session.stars.count)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(.regularMaterial, in: Capsule())
                    .padding(.bottom, 6)
            }
        }
        .background {
            ThemeBackdrop(theme: session.theme, seed: session.maze.seed)
                .ignoresSafeArea()
        }
        // Over the whole screen, not just the maze: after a rotation the maze can be a narrow
        // strip, and the card must still have room.
        .overlay {
            if session.isComplete {
                CelebrationView(
                    theme: session.theme,
                    reward: session.lastReward,
                    onChooseFriend: { session.collection.select($0) },
                    onNext: { withAnimation { session.newMaze() } }
                )
                .padding(12)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.5), value: session.isComplete)
        #if os(macOS)
        // Arrow-key play. Skipped on iOS, where a focusable view summons the on-screen keyboard.
        .focusable()
        .focused($isFocused)
        .focusEffectDisabled()
        .onAppear { isFocused = true }
        .onKeyPress(phases: [.down, .repeat]) { press in
            guard let direction = direction(for: press.key) else { return .ignored }
            session.step(direction)
            return .handled
        }
        #endif
    }

    // MARK: - Pieces

    /// Where the difficulty menu and settings sit. On iPhone and iPad they must be pinned to the
    /// leading side, or they get pulled into the trailing group beside the back button.
    private var leadingPlacement: ToolbarItemPlacement {
        #if os(iOS)
        .topBarLeading
        #else
        .navigation
        #endif
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: leadingPlacement) {
            Picker("Difficulty", selection: Binding(
                get: { session.difficulty },
                set: { session.newMaze(difficulty: $0) }
            )) {
                ForEach(MazeDifficulty.allCases) { difficulty in
                    Text(String(repeating: "⭐️", count: difficulty.starCount)).tag(difficulty)
                }
            }
            .pickerStyle(.menu)
            .accessibilityLabel("Difficulty")
        }
        ToolbarItem(placement: leadingPlacement) {
            Button {
                showsSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
            }
            .accessibilityLabel("Settings")
        }
        ToolbarItemGroup(placement: .primaryAction) {
            Button {
                withAnimation { session.newMaze() }
            } label: {
                Image(systemName: "sparkles")
            }
            .tint(session.theme.accent)
            .accessibilityLabel("New maze")

            Button {
                session.restart()
            } label: {
                Image(systemName: "arrow.counterclockwise")
            }
            .accessibilityLabel("Start over")

            Button {
                session.requestHint()
            } label: {
                Image(systemName: session.hintLevel == nil ? "lightbulb" : "lightbulb.fill")
            }
            .tint(session.theme.hint)
            .accessibilityLabel("Hint")
        }
    }

    private var mazeArea: some View {
        let clearance = toolbarClearance
        return GeometryReader { geometry in
            // Nothing is drawn until the screen has reported its space, so a maze in the wrong
            // shape never flashes up.
            if let space = session.space {
                let frame = MazeFitter.frame(for: session.maze, in: space)
                let layout = MazeLayout(maze: session.maze, in: frame.size)
                MazeCanvas(
                    maze: session.maze,
                    route: session.path.cells,
                    hint: session.hintCells,
                    hintLevel: session.hintLevel,
                    theme: session.theme,
                    playerEmoji: session.playerEmoji,
                    showsPlayer: !session.isDemoVisible,
                    head: session.head,
                    stars: session.uncollectedStars
                )
                .frame(width: frame.width, height: frame.height)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let current = layout.cellCoordinate(for: value.location)
                            let previous = lastDragLocation ?? current
                            session.drag(from: previous, to: current)
                            lastDragLocation = current
                        }
                        .onEnded { _ in
                            lastDragLocation = nil
                            session.endDrag()
                        }
                )
                .overlay {
                    if session.isDemoVisible {
                        DemoFinger(
                            points: layout.polyline(for: session.demoRoute),
                            cellSize: layout.glyphSize,
                            playerEmoji: session.playerEmoji,
                            trailColor: session.theme.path,
                            ringColor: session.theme.hint
                        )
                        .allowsHitTesting(false)
                    }
                }
                .offset(x: frame.minX, y: frame.minY)
            }
        }
        .task(id: IdleKey(
            seed: session.maze.seed,
            hasLayout: session.space != nil,
            hasProgress: session.hasProgress,
            isDemoVisible: session.isDemoVisible,
            isComplete: session.isComplete
        )) {
            // A new player who leaves a fresh maze alone for a while gets shown how to play.
            guard session.space != nil, !session.hasProgress, !session.isDemoVisible, !session.isComplete else { return }
            try? await Task.sleep(for: .seconds(Self.idleSeconds))
            guard !Task.isCancelled else { return }
            session.nudgeIfIdle()
        }
        .onGeometryChange(for: MazeSpace.self) { proxy in
            #if os(iOS)
            let top = proxy.safeAreaInsets.top
            #else
            let top: CGFloat = 0
            #endif
            return MazeSpace(size: proxy.size, topInset: top, sideClearance: clearance)
        } action: { space in
            session.updateSpace(space)
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
    }

    private static let idleSeconds = 10.0

    /// Everything that restarts the idle countdown when it changes.
    private struct IdleKey: Hashable {
        var seed: UInt64
        var hasLayout: Bool
        var hasProgress: Bool
        var isDemoVisible: Bool
        var isComplete: Bool
    }

    /// Side space the maze must keep free when it extends under the top bar, so it never sits
    /// under toolbar buttons. Wide (regular) windows also show status bar text such as the
    /// date and app name along the top edge, which needs more room.
    private var toolbarClearance: CGFloat {
        horizontalSizeClass == .regular ? 260 : 240
    }

    private func direction(for key: KeyEquivalent) -> MazeDirection? {
        switch key {
        case .upArrow: .up
        case .downArrow: .down
        case .leftArrow: .left
        case .rightArrow: .right
        default: nil
        }
    }
}

#Preview {
    NavigationStack { MazeGameView(session: MazeGameSession()) }
}
