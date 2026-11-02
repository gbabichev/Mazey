//
//  MazePath.swift
//  Mazey
//

import Foundation

/// The route the player has drawn so far. All movement rules live here so every
/// platform (touch, mouse, keyboard) shares the same validation.
nonisolated struct MazePath: Equatable, Sendable {
    enum MoveResult: Sendable {
        case appended
        case retraced
        case ignored
    }

    private(set) var cells: [GridPoint]
    private var visited: Set<GridPoint>

    init(start: GridPoint) {
        cells = [start]
        visited = [start]
    }

    var end: GridPoint { cells[cells.count - 1] }

    func contains(_ point: GridPoint) -> Bool {
        visited.contains(point)
    }

    /// Tries to move the end of the path onto `target`.
    ///
    /// - Stepping into an open, unvisited neighbour extends the path.
    /// - Stepping back onto the previous cell erases the last step (if `allowRetrace`).
    /// - Anything else (walls, jumps, revisits) is ignored and changes nothing.
    @discardableResult
    mutating func move(to target: GridPoint, in maze: Maze, allowRetrace: Bool = true) -> MoveResult {
        if allowRetrace, cells.count >= 2, target == cells[cells.count - 2] {
            visited.remove(cells.removeLast())
            return .retraced
        }
        guard !visited.contains(target),
              MazeDirection.allCases.contains(where: { maze.neighbor(of: end, $0) == target })
        else { return .ignored }
        cells.append(target)
        visited.insert(target)
        return .appended
    }

    mutating func reset(to start: GridPoint) {
        cells = [start]
        visited = [start]
    }
}
