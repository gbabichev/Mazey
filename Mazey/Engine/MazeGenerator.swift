//
//  MazeGenerator.swift
//  Mazey
//

import Foundation

/// Builds mazes with an iterative randomized depth-first search (recursive backtracker).
///
/// The result is a "perfect" maze: exactly one route between any two cells,
/// so every cell is reachable and every maze is solvable.
nonisolated enum MazeGenerator {
    /// How many candidates to try before settling for the best one found.
    static let maximumAttempts = 60

    /// Generates a maze for a difficulty level, retrying with derived seeds
    /// until the difficulty criteria are met. Deterministic for a given seed.
    static func generate(difficulty: MazeDifficulty, seed: UInt64) -> Maze {
        var best: (maze: Maze, length: Int)?
        for attempt in 0..<maximumAttempts {
            let attemptSeed = seed &+ UInt64(attempt) &* 0xD1B5_4A32_D192_ED03
            let maze = generate(rows: difficulty.size, columns: difficulty.size, seed: attemptSeed)
            guard let metrics = MazeSolver.metrics(for: maze) else { continue }
            if difficulty.criteria.isSatisfied(by: metrics) { return maze }
            if metrics.solutionLength > (best?.length ?? 0) {
                best = (maze, metrics.solutionLength)
            }
        }
        return best?.maze ?? generate(rows: difficulty.size, columns: difficulty.size, seed: seed)
    }

    /// Generates a single maze. Pass `start` / `finish` to choose the entrance and exit;
    /// otherwise two distant cells on the outer edge are picked from the seed.
    static func generate(
        rows: Int,
        columns: Int,
        seed: UInt64,
        start: GridPoint? = nil,
        finish: GridPoint? = nil
    ) -> Maze {
        let rows = max(1, rows)
        let columns = max(1, columns)
        var rng = SeededGenerator(seed: seed)

        let startPoint = start.map { clamp($0, rows: rows, columns: columns) }
            ?? randomEdgeCell(rows: rows, columns: columns, using: &rng)
        let finishPoint = finish.map { clamp($0, rows: rows, columns: columns) }
            ?? farEdgeCell(from: startPoint, rows: rows, columns: columns, using: &rng)

        var maze = Maze(
            rows: rows,
            columns: columns,
            start: startPoint,
            finish: finishPoint,
            startSide: edgeSide(of: startPoint, rows: rows, columns: columns, using: &rng),
            finishSide: edgeSide(of: finishPoint, rows: rows, columns: columns, using: &rng),
            seed: seed
        )
        carve(&maze, using: &rng)
        return maze
    }

    // MARK: - Carving

    /// Iterative depth-first search: walk to a random unvisited neighbour, knocking
    /// down the wall as we go, and backtrack along the stack when stuck.
    private static func carve(_ maze: inout Maze, using rng: inout SeededGenerator) {
        var visited = Array(repeating: false, count: maze.cellCount)
        let first = GridPoint(row: rng.next(below: maze.rows), column: rng.next(below: maze.columns))
        visited[maze.index(of: first)] = true
        var stack = [first]

        while let current = stack.last {
            let options = MazeDirection.allCases.filter { direction in
                let next = current.moved(direction)
                return maze.contains(next) && !visited[maze.index(of: next)]
            }
            guard !options.isEmpty else {
                stack.removeLast()
                continue
            }
            let direction = options[rng.next(below: options.count)]
            let next = current.moved(direction)
            maze.openPassage(from: current, direction)
            visited[maze.index(of: next)] = true
            stack.append(next)
        }
    }

    // MARK: - Start and finish placement

    private static func clamp(_ point: GridPoint, rows: Int, columns: Int) -> GridPoint {
        GridPoint(
            row: min(max(point.row, 0), rows - 1),
            column: min(max(point.column, 0), columns - 1)
        )
    }

    private static func edgeCells(rows: Int, columns: Int) -> [GridPoint] {
        var cells: [GridPoint] = []
        for row in 0..<rows {
            for column in 0..<columns where row == 0 || row == rows - 1 || column == 0 || column == columns - 1 {
                cells.append(GridPoint(row: row, column: column))
            }
        }
        return cells
    }

    private static func randomEdgeCell(rows: Int, columns: Int, using rng: inout SeededGenerator) -> GridPoint {
        let cells = edgeCells(rows: rows, columns: columns)
        return cells[rng.next(below: cells.count)]
    }

    /// A random edge cell at least half a grid away from `start` (when one exists).
    private static func farEdgeCell(
        from start: GridPoint,
        rows: Int,
        columns: Int,
        using rng: inout SeededGenerator
    ) -> GridPoint {
        let cells = edgeCells(rows: rows, columns: columns)
        let minimumDistance = (rows + columns) / 2
        let far = cells.filter { $0.manhattanDistance(to: start) >= minimumDistance }
        if !far.isEmpty { return far[rng.next(below: far.count)] }
        let others = cells.filter { $0 != start }
        return others.isEmpty ? start : others[rng.next(below: others.count)]
    }

    /// Which outer wall gets the gap. Corner cells touch two walls, so pick one at random.
    private static func edgeSide(
        of point: GridPoint,
        rows: Int,
        columns: Int,
        using rng: inout SeededGenerator
    ) -> MazeDirection? {
        var sides: [MazeDirection] = []
        if point.row == 0 { sides.append(.up) }
        if point.column == columns - 1 { sides.append(.right) }
        if point.row == rows - 1 { sides.append(.down) }
        if point.column == 0 { sides.append(.left) }
        return sides.isEmpty ? nil : sides[rng.next(below: sides.count)]
    }
}
