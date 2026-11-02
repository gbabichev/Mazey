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

    /// Generates a square maze for a difficulty level (used when there is no screen to fit).
    static func generate(difficulty: MazeDifficulty, seed: UInt64) -> Maze {
        generate(difficulty: difficulty, seed: seed, rows: difficulty.defaultSize, columns: difficulty.defaultSize)
    }

    /// Generates a maze of the given shape for a difficulty level, retrying with derived seeds
    /// until the difficulty criteria are met. Deterministic for a given seed and shape.
    static func generate(difficulty: MazeDifficulty, seed: UInt64, rows: Int, columns: Int) -> Maze {
        search(seed: seed, criteria: difficulty.criteria(rows: rows, columns: columns)) { attemptSeed in
            generate(rows: rows, columns: columns, seed: attemptSeed, twistiness: difficulty.twistiness)
        }
    }

    /// Generates a circular maze with `rings` rings around the hub for a difficulty level.
    static func generate(difficulty: MazeDifficulty, seed: UInt64, rings: Int) -> Maze {
        search(seed: seed, criteria: difficulty.criteria(rings: rings)) { attemptSeed in
            generateCircular(rings: rings, seed: attemptSeed, twistiness: difficulty.twistiness)
        }
    }

    /// Generates a hexagon or triangle maze of the given shape for a difficulty level.
    static func generate(difficulty: MazeDifficulty, seed: UInt64, style: MazeStyle, rows: Int, columns: Int) -> Maze {
        // A triangle row holds about twice as many cells as a hexagon row of the same width.
        let width = style == .triangle ? max(1, columns / 2) : columns
        return search(seed: seed, criteria: difficulty.criteria(rows: rows, columns: width)) { attemptSeed in
            generateTiled(style: style, rows: rows, columns: columns, seed: attemptSeed, twistiness: difficulty.twistiness)
        }
    }

    /// Tries `make` with derived seeds until a maze meets `criteria`, or returns the best one found.
    private static func search(seed: UInt64, criteria: MazeCriteria, make: (UInt64) -> Maze) -> Maze {
        var best: (maze: Maze, length: Int)?
        for attempt in 0..<maximumAttempts {
            let attemptSeed = seed &+ UInt64(attempt) &* 0xD1B5_4A32_D192_ED03
            let maze = make(attemptSeed)
            guard let metrics = MazeSolver.metrics(for: maze) else { continue }
            if criteria.isSatisfied(by: metrics) { return maze }
            if metrics.solutionLength > (best?.length ?? 0) {
                best = (maze, metrics.solutionLength)
            }
        }
        return best?.maze ?? make(seed)
    }

    /// Generates a single maze. Pass `start` / `finish` to choose the entrance and exit;
    /// otherwise two distant cells on the outer edge are picked from the seed.
    /// `twistiness` (0...1) is how much the carving prefers turning to carrying straight on.
    static func generate(
        rows: Int,
        columns: Int,
        seed: UInt64,
        start: GridPoint? = nil,
        finish: GridPoint? = nil,
        twistiness: Double = 0.5
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
        carve(&maze, twistiness: twistiness, using: &rng)
        return maze
    }

    // MARK: - Hexagon and triangle mazes

    /// A hexagon or triangle maze. The start and finish are on the outer boundary, the finish
    /// well away from the start, each with a gap in the wall.
    static func generateTiled(style: MazeStyle, rows: Int, columns: Int, seed: UInt64, twistiness: Double = 0.5) -> Maze {
        let geometry = MazeGeometry(style: style, rows: rows, columns: columns)
        var rng = SeededGenerator(seed: seed)
        let boundary = (0..<geometry.cellCount).map(geometry.point(at:)).filter { !geometry.boundaryEdges(of: $0).isEmpty }
        let start = boundary[rng.next(below: boundary.count)]
        let size = geometry.unitSize
        let minimumDistance = Double(max(size.width, size.height)) / 2
        let startCenter = geometry.unitCenter(of: start)
        let far = boundary.filter { cell in
            let center = geometry.unitCenter(of: cell)
            return Double(hypot(center.x - startCenter.x, center.y - startCenter.y)) >= minimumDistance
        }
        let others = boundary.filter { $0 != start }
        let finishPool = far.isEmpty ? (others.isEmpty ? [start] : others) : far
        let finish = finishPool[rng.next(below: finishPool.count)]
        let startEdges = geometry.boundaryEdges(of: start)
        let finishEdges = geometry.boundaryEdges(of: finish)
        var maze = Maze(
            geometry: geometry,
            start: start,
            finish: finish,
            startEdge: startEdges[rng.next(below: startEdges.count)],
            finishEdge: finishEdges[rng.next(below: finishEdges.count)],
            seed: seed
        )
        carveLinked(&maze, twistiness: twistiness, using: &rng)
        return maze
    }

    // MARK: - Circular mazes

    /// A circular maze: the start is a random cell on the outer ring and the finish is the hub.
    /// `twistiness` is the chance of changing kind of move (round, in or out) when it could
    /// carry on the same way.
    static func generateCircular(rings: Int, seed: UInt64, twistiness: Double = 0.5) -> Maze {
        let sizes = CircularShape.ringSizes(rings: max(1, min(rings, CircularShape.maximumRings)))
        var rng = SeededGenerator(seed: seed)
        let start = GridPoint(row: sizes.count - 1, column: rng.next(below: sizes[sizes.count - 1]))
        var maze = Maze(ringSizes: sizes, start: start, seed: seed)
        carveLinked(&maze, twistiness: twistiness, using: &rng)
        return maze
    }

    /// The same depth-first carving as the grid, over the neighbours of circular, hexagon or triangle cells.
    private static func carveLinked(_ maze: inout Maze, twistiness: Double, using rng: inout SeededGenerator) {
        var visited = Array(repeating: false, count: maze.cellCount)
        let first = maze.point(at: rng.next(below: maze.cellCount))
        visited[maze.index(of: first)] = true
        var stack: [(point: GridPoint, arrivedKind: Int?)] = [(first, nil)]
        let turnChance = Int((min(max(twistiness, 0), 1) * 1000).rounded())

        while let (current, arrivedKind) = stack.last {
            let options = maze.geometry.adjacentCells(of: current).filter { !visited[maze.index(of: $0.point)] }
            guard !options.isEmpty else {
                stack.removeLast()
                continue
            }
            let straight = options.filter { $0.kind == arrivedKind }
            let chosen: (point: GridPoint, kind: Int)
            let turns = options.filter { $0.kind != arrivedKind }
            if options.count > 1, !straight.isEmpty {
                // Turn when asked to and possible (every option may be the same kind of move,
                // such as the two cells outward of a ring that doubles).
                if !turns.isEmpty, rng.next(below: 1000) < turnChance {
                    chosen = turns[rng.next(below: turns.count)]
                } else {
                    chosen = straight[rng.next(below: straight.count)]
                }
            } else {
                chosen = options[rng.next(below: options.count)]
            }
            maze.openLink(from: current, to: chosen.point)
            visited[maze.index(of: chosen.point)] = true
            stack.append((chosen.point, chosen.kind))
        }
    }

    // MARK: - Carving

    /// Iterative depth-first search: walk to a random unvisited neighbour, knocking
    /// down the wall as we go, and backtrack along the stack when stuck. When it could carry
    /// straight on or turn, `twistiness` is the chance it turns.
    private static func carve(_ maze: inout Maze, twistiness: Double, using rng: inout SeededGenerator) {
        var visited = Array(repeating: false, count: maze.cellCount)
        let first = GridPoint(row: rng.next(below: maze.rows), column: rng.next(below: maze.columns))
        visited[maze.index(of: first)] = true
        var stack: [(point: GridPoint, arrivedBy: MazeDirection?)] = [(first, nil)]
        let turnChance = Int((min(max(twistiness, 0), 1) * 1000).rounded())

        while let (current, arrivedBy) = stack.last {
            let options = MazeDirection.allCases.filter { direction in
                let next = current.moved(direction)
                return maze.contains(next) && !visited[maze.index(of: next)]
            }
            guard !options.isEmpty else {
                stack.removeLast()
                continue
            }
            let direction: MazeDirection
            if let arrivedBy, options.count > 1, options.contains(arrivedBy) {
                if rng.next(below: 1000) < turnChance {
                    let turns = options.filter { $0 != arrivedBy }
                    direction = turns[rng.next(below: turns.count)]
                } else {
                    direction = arrivedBy
                }
            } else {
                direction = options[rng.next(below: options.count)]
            }
            let next = current.moved(direction)
            maze.openPassage(from: current, direction)
            visited[maze.index(of: next)] = true
            stack.append((next, direction))
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
