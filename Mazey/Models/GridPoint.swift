//
//  GridPoint.swift
//  Mazey
//

import Foundation

/// A position in the maze grid. Row 0 is the top row, column 0 is the left column.
nonisolated struct GridPoint: Hashable, Sendable {
    var row: Int
    var column: Int

    func moved(_ direction: MazeDirection) -> GridPoint {
        GridPoint(row: row + direction.rowDelta, column: column + direction.columnDelta)
    }

    func manhattanDistance(to other: GridPoint) -> Int {
        abs(row - other.row) + abs(column - other.column)
    }
}
