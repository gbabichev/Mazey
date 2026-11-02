//
//  Maze.swift
//  Mazey
//

import Foundation

/// A set of cells plus an entrance and an exit. Either a rectangular grid, or rings of cells
/// around a hub (see `MazeGeometry`).
///
/// For a grid, `startSide` / `finishSide` name the outer wall that has a gap at the start
/// or finish cell, so the maze can be drawn like a paper maze with openings. A circular maze
/// starts at a gap in its outer wall and finishes in the hub.
nonisolated struct Maze: Equatable, Sendable {
    let geometry: MazeGeometry
    let rows: Int
    let columns: Int
    let start: GridPoint
    let finish: GridPoint
    let startSide: MazeDirection?
    let finishSide: MazeDirection?
    let seed: UInt64
    /// Grid only: which sides of each cell are open.
    private(set) var cells: [MazeCell]
    /// Circular only: for each cell, the cells it is open to.
    private var links: [[Int]]

    var style: MazeStyle { geometry.style }

    init(
        rows: Int,
        columns: Int,
        start: GridPoint,
        finish: GridPoint,
        startSide: MazeDirection? = nil,
        finishSide: MazeDirection? = nil,
        seed: UInt64 = 0
    ) {
        geometry = MazeGeometry(rows: rows, columns: columns)
        self.rows = geometry.rows
        self.columns = geometry.columns
        self.start = start
        self.finish = finish
        self.startSide = startSide
        self.finishSide = finishSide
        self.seed = seed
        self.cells = Array(repeating: MazeCell(), count: geometry.cellCount)
        self.links = []
    }

    /// A circular maze with every wall up. `start` must be on the outer ring; the finish is the hub.
    init(ringSizes: [Int], start: GridPoint, seed: UInt64 = 0) {
        geometry = MazeGeometry(ringSizes: ringSizes)
        rows = geometry.rows
        columns = geometry.columns
        self.start = start
        finish = GridPoint(row: 0, column: 0)
        startSide = nil
        finishSide = nil
        self.seed = seed
        cells = []
        links = Array(repeating: [], count: geometry.cellCount)
    }

    func contains(_ point: GridPoint) -> Bool { geometry.contains(point) }
    func index(of point: GridPoint) -> Int { geometry.index(of: point) }
    func point(at index: Int) -> GridPoint { geometry.point(at: index) }
    var cellCount: Int { geometry.cellCount }

    // MARK: - Movement

    /// The grid cell at `point`. Grid mazes only.
    subscript(point: GridPoint) -> MazeCell {
        cells[index(of: point)]
    }

    /// True when there is an open passage leaving `point` in `direction`
    /// that leads to another cell inside the grid. Grid mazes only.
    func canMove(from point: GridPoint, _ direction: MazeDirection) -> Bool {
        style == .grid && contains(point) && self[point].isOpen(direction) && contains(point.moved(direction))
    }

    /// The reachable neighbour in `direction`, or nil if a wall is in the way. Grid mazes only.
    func neighbor(of point: GridPoint, _ direction: MazeDirection) -> GridPoint? {
        canMove(from: point, direction) ? point.moved(direction) : nil
    }

    /// Every cell you can step into from `point` without crossing a wall.
    func openNeighbors(of point: GridPoint) -> [GridPoint] {
        switch style {
        case .grid:
            return MazeDirection.allCases.compactMap { neighbor(of: point, $0) }
        case .circular:
            guard contains(point) else { return [] }
            return links[index(of: point)].map(self.point(at:))
        }
    }

    /// Knocks down the wall between `point` and its neighbour in `direction`. Grid mazes only.
    mutating func openPassage(from point: GridPoint, _ direction: MazeDirection) {
        let other = point.moved(direction)
        guard style == .grid, contains(point), contains(other) else { return }
        cells[index(of: point)].passages.insert(direction.set)
        cells[index(of: other)].passages.insert(direction.opposite.set)
    }

    /// Knocks down the wall between two neighbouring cells. Circular mazes only.
    mutating func openLink(from a: GridPoint, to b: GridPoint) {
        guard style == .circular, contains(a), contains(b) else { return }
        let (first, second) = (index(of: a), index(of: b))
        guard !links[first].contains(second) else { return }
        links[first].append(second)
        links[second].append(first)
    }

    /// True when the wall between two cells is open. Circular mazes only.
    func isLinked(_ a: GridPoint, _ b: GridPoint) -> Bool {
        style == .circular && contains(a) && contains(b) && links[index(of: a)].contains(index(of: b))
    }

    /// True if the outer wall has a gap on `direction` side of `point`. Grid mazes only.
    func hasOpening(at point: GridPoint, _ direction: MazeDirection) -> Bool {
        (point == start && startSide == direction) || (point == finish && finishSide == direction)
    }

    // MARK: - Geometry

    func unitCenter(of point: GridPoint) -> CGPoint { geometry.unitCenter(of: point) }
    func cell(containing position: CGPoint) -> GridPoint? { geometry.cell(containing: position) }
    func distance(from position: CGPoint, to point: GridPoint) -> CGFloat { geometry.distance(from: position, to: point) }
    func straightSteps(from a: GridPoint, to b: GridPoint) -> Int { geometry.straightSteps(from: a, to: b) }
}
