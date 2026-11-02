//
//  MazeLayout.swift
//  Mazey
//

import SwiftUI

/// Maps between maze positions and points on screen. The canvas draws with it and the
/// gesture reads with it, so what the player sees is exactly what they touch.
///
/// Maze units are explained in `MazeGeometry`: one cell for a grid, one ring's thickness for a
/// circular maze. `cellSize` is the size of one unit on screen.
nonisolated struct MazeLayout: Sendable {
    /// Room kept free around the maze, and extra room on the sides that have a
    /// START or FINISH label outside the opening.
    static let baseMargin: CGFloat = 12
    static let labelMargin: CGFloat = 34

    let geometry: MazeGeometry
    let rows: Int
    let columns: Int
    /// How many points one maze unit is.
    let cellSize: CGFloat
    /// A grid's top-left corner, or a circular maze's centre.
    let origin: CGPoint
    private let margins: [MazeDirection: CGFloat]

    /// Fits the whole maze inside `size`, centered, with cells of a steady size.
    init(maze: Maze, in size: CGSize) {
        switch maze.style {
        case .grid:
            self.init(rows: maze.rows, columns: maze.columns, in: size, startSide: maze.startSide, finishSide: maze.finishSide)
        case .circular:
            self.init(rings: maze.geometry.ringSizes.count - 1, in: size)
        }
    }

    /// The same fit for a grid that has not been generated yet. `startSide` and `finishSide`
    /// say which sides will carry a label.
    init(rows: Int, columns: Int, in size: CGSize, startSide: MazeDirection?, finishSide: MazeDirection?) {
        geometry = MazeGeometry(rows: rows, columns: columns)
        self.rows = rows
        self.columns = columns
        var margins: [MazeDirection: CGFloat] = [:]
        for direction in MazeDirection.allCases {
            let hasLabel = startSide == direction || finishSide == direction
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

    /// The fit for a circular maze with `rings` rings around its hub. The START label can be on
    /// any side of the circle, so room is kept all the way round.
    init(rings: Int, in size: CGSize) {
        geometry = MazeGeometry(ringSizes: CircularShape.ringSizes(rings: rings))
        rows = geometry.rows
        columns = geometry.columns
        margins = [:]
        let available = CGSize(width: max(1, size.width - Self.labelMargin * 2), height: max(1, size.height - Self.labelMargin * 2))
        cellSize = min(available.width, available.height) / (2 * CircularShape.outerRadius(rings: rings))
        origin = CGPoint(x: size.width / 2, y: size.height / 2)
    }

    var isCircular: Bool { geometry.style == .circular }

    /// The square a circular maze fills, or the grid itself.
    var mazeRect: CGRect {
        if isCircular {
            let radius = CircularShape.outerRadius(rings: geometry.ringSizes.count - 1) * cellSize
            return CGRect(x: origin.x - radius, y: origin.y - radius, width: radius * 2, height: radius * 2)
        }
        return CGRect(x: origin.x, y: origin.y, width: cellSize * CGFloat(columns), height: cellSize * CGFloat(rows))
    }

    /// The maze plus the labels outside its openings.
    var contentRect: CGRect {
        guard !isCircular else { return mazeRect }
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

    /// A grid cell's square. Grid mazes only.
    func rect(of point: GridPoint) -> CGRect {
        CGRect(
            x: origin.x + CGFloat(point.column) * cellSize,
            y: origin.y + CGFloat(point.row) * cellSize,
            width: cellSize,
            height: cellSize
        )
    }

    func center(of point: GridPoint) -> CGPoint {
        screenPoint(forUnit: geometry.unitCenter(of: point))
    }

    /// A line through the middles of `cells`, curving round the rings of a circular maze.
    func polyline(for cells: [GridPoint]) -> [CGPoint] {
        geometry.polyline(through: cells).map(screenPoint(forUnit:))
    }

    func screenPoint(forUnit unit: CGPoint) -> CGPoint {
        CGPoint(x: origin.x + unit.x * cellSize, y: origin.y + unit.y * cellSize)
    }

    /// A screen point in maze units (see `MazeGeometry`).
    func cellCoordinate(for location: CGPoint) -> CGPoint {
        CGPoint(x: (location.x - origin.x) / cellSize, y: (location.y - origin.y) / cellSize)
    }
}
