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

    /// How far (in cells) the pointer may be from a cell's center and still pull the path onto it.
    static let reach: CGFloat = 1.25
    /// How close to a cell's center (in cells) the pointer must be to count as inside it for a
    /// direct move. A bit more than the half-cell inscribed circle, but less than a corner
    /// (0.71), so a pointer brushing the corner of a wrong branch does not take that branch.
    static let cellInterior: CGFloat = 0.62
    /// How much closer the pointer must be to a neighbour than to the end cell before the
    /// path moves, so a pointer resting on the boundary does not flicker back and forth.
    static let hysteresis: CGFloat = 0.1

    /// True when `pointer` is within a cell of the end of the path.
    func isNearEnd(_ pointer: CGPoint) -> Bool {
        Self.distance(from: pointer, to: end) <= 1
    }

    /// Moves the end of the path toward `pointer`, which is measured in cell units
    /// (x = column, y = row; a cell's center is at +0.5).
    ///
    /// The path only ever moves along open passages, but the pointer does not have to stay
    /// inside the corridor:
    /// 1. If the pointer is inside a connected cell (the next one, or the previous one when
    ///    `allowRetrace`), the path moves there. This is exact, so it picks the right branch
    ///    at junctions. Stepping back needs a small margin past the boundary, so a pointer
    ///    jittering on a cell edge does not make the path flicker.
    /// 2. If the pointer is a few cells ahead (it cut a corner, or moved fast), the path takes
    ///    the first step along the maze's own route to that cell.
    /// 3. Otherwise the path moves to whichever connected neighbour the pointer is nearest to,
    ///    if it is clearly nearer than the end cell. That carries the path along a corridor the
    ///    pointer drifted beside, across a wall.
    ///
    /// Touching a wall simply does nothing. Returns true if the path moved.
    @discardableResult
    mutating func follow(_ pointer: CGPoint, in maze: Maze, allowRetrace: Bool, finish: GridPoint? = nil) -> Bool {
        var moved = false
        let pointerCell = GridPoint(row: Int(pointer.y.rounded(.down)), column: Int(pointer.x.rounded(.down)))
        // A few steps per call lets a fast pointer catch up after skipping cells.
        for _ in 0..<8 {
            var candidates = MazeDirection.allCases
                .compactMap { maze.neighbor(of: end, $0) }
                .filter { !visited.contains($0) }
            if allowRetrace, cells.count >= 2 {
                candidates.append(cells[cells.count - 2])
            }
            let target: GridPoint
            let isRetrace = cells.count >= 2 && pointerCell == cells[cells.count - 2]
            if candidates.contains(pointerCell), Self.distance(from: pointer, to: pointerCell) <= Self.cellInterior,
               !isRetrace || Self.isClearlyCloser(pointer, to: pointerCell, than: end) {
                target = pointerCell
            } else if let next = Self.nextStep(toward: pointerCell, from: end, in: maze, candidates: candidates),
                      next != cells.dropLast().last || Self.isClearlyCloser(pointer, to: next, than: end) {
                target = next
            } else {
                let hereDistance = Self.distance(from: pointer, to: end)
                guard let best = candidates.min(by: { Self.distance(from: pointer, to: $0) < Self.distance(from: pointer, to: $1) }) else { break }
                let bestDistance = Self.distance(from: pointer, to: best)
                guard bestDistance <= Self.reach, bestDistance + Self.hysteresis < hereDistance else { break }
                target = best
            }
            move(to: target, in: maze)
            moved = true
            if end == finish { break }
        }
        return moved
    }

    /// The first step along the maze's route to `goal`, when the goal is two or three cells away
    /// and the route heads straight there without doubling back (a pointer that cut a corner,
    /// for example). A neighbouring cell is handled by the direct move instead. A perfect maze
    /// has exactly one route between two cells, so this picks the right branch at a junction
    /// even when the pointer is exactly between two of them.
    private static func nextStep(toward goal: GridPoint, from end: GridPoint, in maze: Maze, candidates: [GridPoint]) -> GridPoint? {
        let maxSteps = 3
        guard goal != end, end.manhattanDistance(to: goal) >= 2, end.manhattanDistance(to: goal) <= maxSteps,
              let route = MazeSolver.solve(maze, from: end, to: goal),
              route.count - 1 == end.manhattanDistance(to: goal),
              candidates.contains(route[1])
        else { return nil }
        return route[1]
    }

    /// Whether `pointer` is nearer to `cell` than to `other` by more than the hysteresis.
    private static func isClearlyCloser(_ pointer: CGPoint, to cell: GridPoint, than other: GridPoint) -> Bool {
        distance(from: pointer, to: cell) + hysteresis < distance(from: pointer, to: other)
    }

    private static func distance(from pointer: CGPoint, to cell: GridPoint) -> CGFloat {
        hypot(pointer.x - (CGFloat(cell.column) + 0.5), pointer.y - (CGFloat(cell.row) + 0.5))
    }

    mutating func reset(to start: GridPoint) {
        cells = [start]
        visited = [start]
    }
}
