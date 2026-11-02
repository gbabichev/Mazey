//
//  MazeGameView.swift
//  Mazey
//

import SwiftUI

/// The single playable screen for the first milestone.
struct MazeGameView: View {
    @State private var session = MazeGameSession(sounds: SoundEngine.shared)
    @State private var lastDragLocation: CGPoint?
    @FocusState private var isFocused: Bool
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        NavigationStack {
            content
                .toolbar { toolbarContent }
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(.hidden, for: .navigationBar)
                .toolbarColorScheme(session.theme.isDark ? .dark : .light, for: .navigationBar)
                #endif
        }
    }

    private var content: some View {
        VStack(spacing: 16) {
            mazeArea
        }
        .background {
            ThemeBackdrop(theme: session.theme, seed: session.maze.seed)
                .ignoresSafeArea()
        }
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

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
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
        ToolbarItem(placement: .navigation) {
            Button {
                session.isSoundOn.toggle()
            } label: {
                Image(systemName: session.isSoundOn ? "speaker.wave.2.fill" : "speaker.slash.fill")
            }
            .accessibilityLabel(session.isSoundOn ? "Sound on" : "Sound off")
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
                    theme: session.theme
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
                    if session.isComplete {
                        CelebrationView(theme: session.theme) {
                            withAnimation { session.newMaze() }
                        }
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .animation(.spring(duration: 0.5), value: session.isComplete)
                .offset(x: frame.minX, y: frame.minY)
            }
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

    /// Side space the maze must keep free when it extends under the top bar, so it never sits
    /// under toolbar buttons. Wide (regular) windows also show status bar text such as the
    /// date and app name along the top edge, which needs more room.
    private var toolbarClearance: CGFloat {
        horizontalSizeClass == .regular ? 240 : 200
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
    MazeGameView()
}
