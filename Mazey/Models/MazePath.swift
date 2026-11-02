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
        guard !visited.contains(target), maze.openNeighbors(of: end).contains(target) else { return .ignored }
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
    /// Going back a step is the more deliberate move, so the pointer must be further into the
    /// previous cell than the hysteresis alone asks. A little wobble across the edge between
    /// two cells then does not undo the step just taken.
    static let retraceMargin: CGFloat = 0.22

    /// True when `pointer` is within a cell of the end of the path.
    func isNearEnd(_ pointer: CGPoint, in maze: Maze) -> Bool {
        maze.distance(from: pointer, to: end) <= 1
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
        let pointerCell = maze.cell(containing: pointer)
        // A few steps per call lets a fast pointer catch up after skipping cells.
        for _ in 0..<8 {
            var candidates = maze.openNeighbors(of: end).filter { !visited.contains($0) }
            if allowRetrace, cells.count >= 2 {
                candidates.append(cells[cells.count - 2])
            }
            let previous = cells.count >= 2 ? cells[cells.count - 2] : nil
            let isRetrace = pointerCell != nil && pointerCell == previous
            let target: GridPoint
            if let pointerCell, candidates.contains(pointerCell),
               maze.distance(from: pointer, to: pointerCell) <= Self.cellInterior,
               !isRetrace || Self.isClearlyCloser(pointer, to: pointerCell, than: end, in: maze, margin: Self.retraceMargin) {
                target = pointerCell
            } else if let pointerCell,
                      let next = Self.nextStep(toward: pointerCell, from: end, in: maze, candidates: candidates),
                      next != previous || Self.isClearlyCloser(pointer, to: next, than: end, in: maze, margin: Self.retraceMargin) {
                target = next
            } else {
                let hereDistance = maze.distance(from: pointer, to: end)
                guard let best = candidates.min(by: { maze.distance(from: pointer, to: $0) < maze.distance(from: pointer, to: $1) }) else { break }
                let bestDistance = maze.distance(from: pointer, to: best)
                guard bestDistance <= Self.reach, bestDistance + Self.hysteresis < hereDistance else { break }
                target = best
            }
            move(to: target, in: maze)
            moved = true
            if end == finish { break }
        }
        return moved
    }

    /// The first step along the maze's route to `goal`, when the goal is two or three steps away
    /// and the route heads straight there without detouring (a pointer that cut a corner, for
    /// example). A neighbouring cell is handled by the direct move instead. A perfect maze has
    /// exactly one route between two cells, so this picks the right branch at a junction even
    /// when the pointer is exactly between two of them.
    private static func nextStep(toward goal: GridPoint, from end: GridPoint, in maze: Maze, candidates: [GridPoint]) -> GridPoint? {
        // A circular maze's inner cell touches two cells of the ring outside it, so cutting
        // from one of those to the inner cell is a two-step route that looks one step long.
        // Triangle steps are counted from distances, which can be a step out.
        let slack = maze.style == .circular || maze.style == .triangle ? 1 : 0
        let straight = maze.straightSteps(from: end, to: goal)
        guard goal != end, straight <= 3, straight + slack >= 2,
              let route = MazeSolver.solve(maze, from: end, to: goal),
              (2...3).contains(route.count - 1), route.count - 1 <= straight + slack,
              candidates.contains(route[1])
        else { return nil }
        return route[1]
    }

    /// Whether `pointer` is nearer to `cell` than to `other` by more than the hysteresis.
    private static func isClearlyCloser(_ pointer: CGPoint, to cell: GridPoint, than other: GridPoint, in maze: Maze, margin: CGFloat = hysteresis) -> Bool {
        maze.distance(from: pointer, to: cell) + margin < maze.distance(from: pointer, to: other)
    }

    mutating func reset(to start: GridPoint) {
        cells = [start]
        visited = [start]
    }
}
