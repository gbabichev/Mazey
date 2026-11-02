//
//  MazeGameView.swift
//  Mazey
//

import SwiftUI

/// The single playable screen for the first milestone.
struct MazeGameView: View {
    @State private var session = MazeGameSession()
    @State private var lastDragLocation: CGPoint?
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 16) {
            topBar
            mazeArea
            Button {
                withAnimation { session.newMaze() }
            } label: {
                Label("New Maze", systemImage: "sparkles")
                    .font(.title2.weight(.bold))
                    .frame(maxWidth: 320)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.extraLarge)
            .tint(MazePalette.player)
        }
        .padding()
        .background(
            LinearGradient(
                colors: [MazePalette.backgroundTop, MazePalette.backgroundBottom],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .focusable()
        .focused($isFocused)
        .focusEffectDisabled()
        .onAppear { isFocused = true }
        .onKeyPress(phases: [.down, .repeat]) { press in
            guard let direction = direction(for: press.key) else { return .ignored }
            session.step(direction)
            return .handled
        }
    }

    // MARK: - Pieces

    private var topBar: some View {
        HStack(spacing: 12) {
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

            Spacer(minLength: 0)

            Button {
                session.restart()
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.title2.weight(.bold))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("Start over")

            Button {
                session.requestHint()
            } label: {
                Image(systemName: session.hintLevel == nil ? "lightbulb" : "lightbulb.fill")
                    .font(.title2.weight(.bold))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.borderedProminent)
            .tint(MazePalette.hint)
            .foregroundStyle(.black.opacity(0.75))
            .accessibilityLabel("Hint")
        }
    }

    private var mazeArea: some View {
        GeometryReader { geometry in
            let layout = MazeLayout(rows: session.maze.rows, columns: session.maze.columns, in: geometry.size)
            MazeCanvas(
                maze: session.maze,
                route: session.path.cells,
                hint: session.hintCells,
                hintLevel: session.hintLevel
            )
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
                    CelebrationView {
                        withAnimation { session.newMaze() }
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(.spring(duration: 0.5), value: session.isComplete)
        }
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
