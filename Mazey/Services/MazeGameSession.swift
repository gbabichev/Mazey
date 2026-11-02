//
//  MazeGameSession.swift
//  Mazey
//

import Foundation
import Observation

/// Everything the maze screen needs: the current maze, the player's route,
/// hints, and completion. Views call into this; the rules live in the engine types.
@MainActor
@Observable
final class MazeGameSession {
    private(set) var maze: Maze
    private(set) var path: MazePath
    private(set) var hintLevel: MazeHintLevel?
    private(set) var isComplete = false
    private(set) var difficulty: MazeDifficulty

    /// True once the current drag has touched the end of the path, which lets
    /// the drag retrace. A drag that starts elsewhere is ignored until then.
    private var isDragLive = false

    init(difficulty: MazeDifficulty = .beginner, seed: UInt64 = .random(in: .min ... .max)) {
        let maze = MazeGenerator.generate(difficulty: difficulty, seed: seed)
        self.difficulty = difficulty
        self.maze = maze
        self.path = MazePath(start: maze.start)
    }

    /// Cells to highlight for the current hint, recalculated from where the player is now.
    var hintCells: [GridPoint] {
        guard let hintLevel, !isComplete else { return [] }
        return MazeSolver.hint(in: maze, from: path.end, level: hintLevel)
    }

    // MARK: - Starting over

    func newMaze(difficulty: MazeDifficulty? = nil, seed: UInt64 = .random(in: .min ... .max)) {
        if let difficulty { self.difficulty = difficulty }
        maze = MazeGenerator.generate(difficulty: self.difficulty, seed: seed)
        restart()
    }

    func restart() {
        path.reset(to: maze.start)
        hintLevel = nil
        isComplete = false
        isDragLive = false
    }

    // MARK: - Hints

    /// Each tap shows more of the route; after the full route, the hint turns off.
    func requestHint() {
        guard !isComplete else { return }
        if let level = hintLevel {
            hintLevel = level.next
        } else {
            hintLevel = .small
        }
    }

    // MARK: - Input

    /// Handles a pointer moving between two positions, measured in cell units
    /// (x = column, y = row; 1.0 is one cell). The segment is sampled finely
    /// so a fast drag cannot skip over cells.
    func drag(from previous: CGPoint, to current: CGPoint) {
        guard !isComplete else { return }
        let distance = hypot(current.x - previous.x, current.y - previous.y)
        let steps = max(1, Int((distance / 0.2).rounded(.up)))
        for step in 1...steps {
            let t = CGFloat(step) / CGFloat(steps)
            visit(CGPoint(
                x: previous.x + (current.x - previous.x) * t,
                y: previous.y + (current.y - previous.y) * t
            ))
        }
    }

    func endDrag() {
        isDragLive = false
    }

    /// Keyboard movement: one step, or back one step if the key points at the previous cell.
    func step(_ direction: MazeDirection) {
        guard !isComplete else { return }
        apply(path.move(to: path.end.moved(direction), in: maze))
    }

    private func visit(_ location: CGPoint) {
        let cell = GridPoint(row: Int(location.y.rounded(.down)), column: Int(location.x.rounded(.down)))
        guard maze.contains(cell) else { return }
        if cell == path.end {
            isDragLive = true
            return
        }
        apply(path.move(to: cell, in: maze, allowRetrace: isDragLive))
    }

    private func apply(_ result: MazePath.MoveResult) {
        switch result {
        case .appended:
            isDragLive = true
            if path.end == maze.finish {
                isComplete = true
                hintLevel = nil
                isDragLive = false
            }
        case .retraced:
            isDragLive = true
        case .ignored:
            break
        }
    }
}
