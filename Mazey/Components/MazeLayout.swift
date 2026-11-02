//
//  MazeLayout.swift
//  Mazey
//

import SwiftUI

/// Maps between maze cells and points on screen. The canvas draws with it and the
/// gesture reads with it, so what the player sees is exactly what they touch.
nonisolated struct MazeLayout: Sendable {
    /// Room kept free around the maze, and extra room on the sides that have a
    /// START or FINISH label outside the opening.
    static let baseMargin: CGFloat = 12
    static let labelMargin: CGFloat = 34

    let rows: Int
    let columns: Int
    let cellSize: CGFloat
    let origin: CGPoint
    private let margins: [MazeDirection: CGFloat]

    /// Fits the whole grid inside `size`, centered, with square cells.
    init(maze: Maze, in size: CGSize) {
        rows = maze.rows
        columns = maze.columns
        var margins: [MazeDirection: CGFloat] = [:]
        for direction in MazeDirection.allCases {
            let hasLabel = maze.startSide == direction || maze.finishSide == direction
            margins[direction] = hasLabel ? Self.labelMargin : Self.baseMargin
        }
        self.margins = margins
        let horizontal = margins[.left, default: 0] + margins[.right, default: 0]
        let vertical = margins[.up, default: 0] + margins[.down, default: 0]
        let available = CGSize(width: max(1, size.width - horizontal), height: max(1, size.height - vertical))
        cellSize = min(available.width / CGFloat(columns), available.height / CGFloat(rows))
        origin = CGPoint(
            x: margins[.left, default: 0] + (available.width - cellSize * CGFloat(columns)) / 2,
            y: margins[.up, default: 0] + (available.height - cellSize * CGFloat(rows)) / 2
        )
    }

    var mazeRect: CGRect {
        CGRect(x: origin.x, y: origin.y, width: cellSize * CGFloat(columns), height: cellSize * CGFloat(rows))
    }

    /// The maze plus the labels outside its openings.
    var contentRect: CGRect {
        let extra = Self.labelMargin - Self.baseMargin
        var rect = mazeRect
        for direction in MazeDirection.allCases where margins[direction] == Self.labelMargin {
            switch direction {
            case .up: rect = CGRect(x: rect.minX, y: rect.minY - extra, width: rect.width, height: rect.height + extra)
            case .down: rect.size.height += extra
            case .left: rect = CGRect(x: rect.minX - extra, y: rect.minY, width: rect.width + extra, height: rect.height)
            case .right: rect.size.width += extra
            }
        }
        return rect
    }

    var wallWidth: CGFloat { min(max(cellSize * 0.1, 3), 9) }

    func rect(of point: GridPoint) -> CGRect {
        CGRect(
            x: origin.x + CGFloat(point.column) * cellSize,
            y: origin.y + CGFloat(point.row) * cellSize,
            width: cellSize,
            height: cellSize
        )
    }

    func center(of point: GridPoint) -> CGPoint {
        let rect = rect(of: point)
        return CGPoint(x: rect.midX, y: rect.midY)
    }

    /// A screen point in cell units: x is the column, y is the row, 1.0 is one cell.
    func cellCoordinate(for location: CGPoint) -> CGPoint {
        CGPoint(x: (location.x - origin.x) / cellSize, y: (location.y - origin.y) / cellSize)
    }
}
