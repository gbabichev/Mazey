//
//  TiledGeometry.swift
//  Mazey
//

import CoreGraphics
import Foundation

/// The maths of hexagon and triangle mazes. Both are rows by columns of polygons.
///
/// Hexagons point up and sit in offset rows (odd rows are pushed half a cell right). A hexagon
/// is 1 unit wide, flat side to flat side. Triangles have sides of 1 unit; in each row they
/// point up and down alternately, and a cell is pointing up when `row + column` is even.
///
/// Edge `i` of a polygon runs from vertex `i` to vertex `i + 1`. Hexagon edges go clockwise
/// from the upper right (upper right, right, lower right, lower left, left, upper left).
/// Triangle edges are: up-pointing: right side, bottom, left side; down-pointing: top, right
/// side, left side.
nonisolated extension MazeGeometry {
    private static let hexRadius = 1 / 3.0.squareRoot()
    private static let hexRowStep = hexRadius * 1.5
    private static let triangleHeight = 3.0.squareRoot() / 2

    /// How many sides a cell has.
    var edgeCount: Int {
        switch style {
        case .hexagon: 6
        case .triangle: 3
        case .grid: 4
        case .circular: 0
        }
    }

    /// How big characters and lines drawn in a cell are, against the unit: a triangle is
    /// small for its side length.
    var glyphScale: CGFloat { style == .triangle ? 0.6 : 1 }

    /// Width and height of the whole maze in maze units.
    var unitSize: CGSize {
        switch style {
        case .grid:
            return CGSize(width: columns, height: rows)
        case .hexagon:
            return CGSize(
                width: Double(columns) + (rows > 1 ? 0.5 : 0),
                height: 2 * Self.hexRadius + Double(rows - 1) * Self.hexRowStep
            )
        case .triangle:
            return CGSize(width: Double(columns + 1) / 2, height: Double(rows) * Self.triangleHeight)
        case .circular:
            let diameter = 2 * Double(CircularShape.outerRadius(rings: rows - 1))
            return CGSize(width: diameter, height: diameter)
        }
    }

    /// A triangle that points up.
    func pointsUp(_ point: GridPoint) -> Bool {
        (point.row + point.column) % 2 == 0
    }

    /// The cell across edge `edge`, or nil at the edge of the maze.
    func neighbor(of point: GridPoint, edge: Int) -> GridPoint? {
        let (row, column) = (point.row, point.column)
        let result: GridPoint
        switch style {
        case .hexagon:
            let shift = row % 2 == 1 ? 1 : 0
            switch edge {
            case 0: result = GridPoint(row: row - 1, column: column + shift)
            case 1: result = GridPoint(row: row, column: column + 1)
            case 2: result = GridPoint(row: row + 1, column: column + shift)
            case 3: result = GridPoint(row: row + 1, column: column + shift - 1)
            case 4: result = GridPoint(row: row, column: column - 1)
            default: result = GridPoint(row: row - 1, column: column + shift - 1)
            }
        case .triangle:
            let up = pointsUp(point)
            switch edge {
            case 0: result = up ? GridPoint(row: row, column: column + 1) : GridPoint(row: row - 1, column: column)
            case 1: result = up ? GridPoint(row: row + 1, column: column) : GridPoint(row: row, column: column + 1)
            default: result = GridPoint(row: row, column: column - 1)
            }
        default:
            return nil
        }
        return contains(result) ? result : nil
    }

    /// The kind of move across `edge` (see `adjacentCells`).
    func moveKind(of point: GridPoint, edge: Int) -> Int {
        guard style == .triangle else { return edge }
        switch edge {
        case 0: return pointsUp(point) ? 0 : 1
        case 1: return pointsUp(point) ? 1 : 0
        default: return 2
        }
    }

    /// The corners of a cell, in order.
    func vertices(of point: GridPoint) -> [CGPoint] {
        switch style {
        case .hexagon:
            let center = tiledCenter(of: point)
            return (0..<6).map { corner in
                let angle = Double.pi * (-90 + 60 * Double(corner)) / 180
                return CGPoint(x: center.x + Self.hexRadius * cos(angle), y: center.y + Self.hexRadius * sin(angle))
            }
        case .triangle:
            let left = Double(point.column) / 2
            let top = Double(point.row) * Self.triangleHeight
            let bottom = top + Self.triangleHeight
            if pointsUp(point) {
                return [CGPoint(x: left + 0.5, y: top), CGPoint(x: left + 1, y: bottom), CGPoint(x: left, y: bottom)]
            }
            return [CGPoint(x: left, y: top), CGPoint(x: left + 1, y: top), CGPoint(x: left + 0.5, y: bottom)]
        default:
            return []
        }
    }

    /// The middle of edge `edge` of a cell.
    func edgeMidpoint(of point: GridPoint, edge: Int) -> CGPoint {
        let corners = vertices(of: point)
        guard !corners.isEmpty else { return unitCenter(of: point) }
        let (a, b) = (corners[edge], corners[(edge + 1) % corners.count])
        return CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
    }

    /// Edges of a cell that lie on the maze's outer boundary.
    func boundaryEdges(of point: GridPoint) -> [Int] {
        (0..<edgeCount).filter { neighbor(of: point, edge: $0) == nil }
    }

    // MARK: - Used by `MazeGeometry`

    func tiledCenter(of point: GridPoint) -> CGPoint {
        switch style {
        case .hexagon:
            let shift = point.row % 2 == 1 ? 0.5 : 0
            return CGPoint(x: Double(point.column) + 0.5 + shift, y: Self.hexRadius + Double(point.row) * Self.hexRowStep)
        default:
            let top = Double(point.row) * Self.triangleHeight
            let offset = pointsUp(point) ? 2.0 / 3 : 1.0 / 3
            return CGPoint(x: Double(point.column) / 2 + 0.5, y: top + Self.triangleHeight * offset)
        }
    }

    /// Scales a distance in units so that 0.5 is the edge of the cell at its middle.
    var tiledDistanceScale: CGFloat {
        // The distance from a triangle's middle to a side is 1 / (2 * sqrt 3) of its side.
        style == .triangle ? 3.0.squareRoot() : 1
    }

    func tiledCell(containing position: CGPoint) -> GridPoint? {
        let rowGuess: Int
        let columnGuess: Int
        if style == .hexagon {
            rowGuess = Int(((Double(position.y) - Self.hexRadius) / Self.hexRowStep).rounded())
            columnGuess = Int(Double(position.x).rounded(.down))
        } else {
            rowGuess = Int((Double(position.y) / Self.triangleHeight).rounded(.down))
            columnGuess = Int((Double(position.x) * 2).rounded(.down)) - 1
        }
        for row in (rowGuess - 1)...(rowGuess + 1) {
            for column in (columnGuess - 1)...(columnGuess + 2) {
                let cell = GridPoint(row: row, column: column)
                if contains(cell), polygonContains(vertices(of: cell), position) { return cell }
            }
        }
        return nil
    }

    private func polygonContains(_ corners: [CGPoint], _ position: CGPoint) -> Bool {
        var sign = 0.0
        for index in corners.indices {
            let (a, b) = (corners[index], corners[(index + 1) % corners.count])
            let cross = Double((b.x - a.x) * (position.y - a.y) - (b.y - a.y) * (position.x - a.x))
            if abs(cross) < 1e-9 { continue }
            if sign == 0 { sign = cross.sign == .minus ? -1 : 1 }
            else if (cross < 0) != (sign < 0) { return false }
        }
        return true
    }

    func tiledSteps(from a: GridPoint, to b: GridPoint) -> Int {
        if style == .hexagon {
            func cube(_ point: GridPoint) -> (x: Int, y: Int, z: Int) {
                let x = point.column - (point.row - (point.row & 1)) / 2
                return (x, -x - point.row, point.row)
            }
            let (p, q) = (cube(a), cube(b))
            return max(abs(p.x - q.x), abs(p.y - q.y), abs(p.z - q.z))
        }
        // Neighbouring triangle middles are 0.5 to 0.58 apart.
        let (p, q) = (tiledCenter(of: a), tiledCenter(of: b))
        return Int((Double(hypot(p.x - q.x, p.y - q.y)) / 0.54).rounded())
    }
}
