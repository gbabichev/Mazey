//
//  MazeLayout.swift
//  Mazey
//

import SwiftUI

/// Maps between maze cells and points on screen. The canvas draws with it and the
/// gesture reads with it, so what the player sees is exactly what they touch.
nonisolated struct MazeLayout: Sendable {
    let rows: Int
    let columns: Int
    let cellSize: CGFloat
    let origin: CGPoint

    /// Fits the whole grid inside `size`, centered, with square cells.
    init(rows: Int, columns: Int, in size: CGSize) {
        self.rows = rows
        self.columns = columns
        let margin: CGFloat = 16
        let available = CGSize(width: max(1, size.width - margin * 2), height: max(1, size.height - margin * 2))
        cellSize = min(available.width / CGFloat(columns), available.height / CGFloat(rows))
        origin = CGPoint(
            x: (size.width - cellSize * CGFloat(columns)) / 2,
            y: (size.height - cellSize * CGFloat(rows)) / 2
        )
    }

    var mazeRect: CGRect {
        CGRect(x: origin.x, y: origin.y, width: cellSize * CGFloat(columns), height: cellSize * CGFloat(rows))
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
