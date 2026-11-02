//
//  Maze.swift
//  Mazey
//

import Foundation

/// A rectangular grid of cells plus an entrance and an exit.
///
/// `startSide` / `finishSide` name the outer wall that has a gap at the start
/// or finish cell, so the maze can be drawn like a paper maze with openings.
nonisolated struct Maze: Equatable, Sendable {
    let rows: Int
    let columns: Int
    let start: GridPoint
    let finish: GridPoint
    let startSide: MazeDirection?
    let finishSide: MazeDirection?
    let seed: UInt64
    private(set) var cells: [MazeCell]

    init(
        rows: Int,
        columns: Int,
        start: GridPoint,
        finish: GridPoint,
        startSide: MazeDirection? = nil,
        finishSide: MazeDirection? = nil,
        seed: UInt64 = 0
    ) {
        self.rows = max(1, rows)
        self.columns = max(1, columns)
        self.start = start
        self.finish = finish
        self.startSide = startSide
        self.finishSide = finishSide
        self.seed = seed
        self.cells = Array(repeating: MazeCell(), count: self.rows * self.columns)
    }

    func contains(_ point: GridPoint) -> Bool {
        point.row >= 0 && point.row < rows && point.column >= 0 && point.column < columns
    }

    func index(of point: GridPoint) -> Int {
        point.row * columns + point.column
    }

    func point(at index: Int) -> GridPoint {
        GridPoint(row: index / columns, column: index % columns)
    }

    var cellCount: Int { rows * columns }

    /// The cell at `point`. The point must be inside the grid.
    subscript(point: GridPoint) -> MazeCell {
        cells[index(of: point)]
    }

    /// True when there is an open passage leaving `point` in `direction`
    /// that leads to another cell inside the grid.
    func canMove(from point: GridPoint, _ direction: MazeDirection) -> Bool {
        contains(point) && self[point].isOpen(direction) && contains(point.moved(direction))
    }

    /// The reachable neighbour in `direction`, or nil if a wall is in the way.
    func neighbor(of point: GridPoint, _ direction: MazeDirection) -> GridPoint? {
        canMove(from: point, direction) ? point.moved(direction) : nil
    }

    /// Every cell you can step into from `point` without crossing a wall.
    func openNeighbors(of point: GridPoint) -> [GridPoint] {
        MazeDirection.allCases.compactMap { neighbor(of: point, $0) }
    }

    /// Knocks down the wall between `point` and its neighbour in `direction`.
    mutating func openPassage(from point: GridPoint, _ direction: MazeDirection) {
        let other = point.moved(direction)
        guard contains(point), contains(other) else { return }
        cells[index(of: point)].passages.insert(direction.set)
        cells[index(of: other)].passages.insert(direction.opposite.set)
    }

    /// True if the outer wall has a gap on `direction` side of `point`.
    func hasOpening(at point: GridPoint, _ direction: MazeDirection) -> Bool {
        (point == start && startSide == direction) || (point == finish && finishSide == direction)
    }
}
