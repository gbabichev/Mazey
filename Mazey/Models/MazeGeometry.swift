//
//  MazeGeometry.swift
//  Mazey
//

import CoreGraphics
import Foundation

/// The shape of a maze's cells.
nonisolated enum MazeStyle: String, CaseIterable, Sendable, Codable {
    /// Square cells in rows and columns.
    case grid
    /// Rings of wedge-shaped cells around a hub: the start is on the outside, the finish in the middle.
    case circular
}

/// How a circular maze is laid out: a hub in the middle, then rings of cells that get more
/// numerous towards the edge so every cell stays roughly the same size.
nonisolated enum CircularShape {
    /// The hub's radius, where one ring's thickness is 1.
    static let hubRadius: CGFloat = 1.4
    /// How many cells the first ring has.
    static let baseSectors = 6
    static let maximumRings = 12
    /// A ring doubles its cell count once its cells would otherwise be wider than this.
    private static let doublingWidth = 1.6

    /// Cell counts from the hub (always 1) outwards. `rings` counts the rings around the hub.
    static func ringSizes(rings: Int) -> [Int] {
        var sizes = [1]
        guard rings >= 1 else { return sizes }
        sizes.append(baseSectors)
        if rings >= 2 {
            for ring in 2...rings {
                let inner = Double(hubRadius) + Double(ring - 1)
                let previous = sizes[ring - 1]
                let width = 2 * Double.pi * inner / Double(previous)
                sizes.append(width >= doublingWidth ? previous * 2 : previous)
            }
        }
        return sizes
    }

    static func totalCells(rings: Int) -> Int {
        ringSizes(rings: rings).reduce(0, +)
    }

    /// The ring count whose total is nearest to `target` cells.
    static func rings(forCellCount target: Int) -> Int {
        (1...maximumRings).min { abs(totalCells(rings: $0) - target) < abs(totalCells(rings: $1) - target) } ?? 1
    }

    /// Distance from the centre to the outer wall, where one ring's thickness is 1.
    static func outerRadius(rings: Int) -> CGFloat {
        hubRadius + CGFloat(rings)
    }
}

/// Where cells are, how they touch, and how a pointer relates to them: everything that
/// differs between maze styles. Positions are in "maze units": for a grid, one cell is 1 unit
/// and the origin is the top-left corner; for a circular maze, one ring's thickness is 1 unit
/// and the origin is the centre. A cell is a `GridPoint`: for a circular maze `row` is the ring
/// (0 is the hub) and `column` is the cell's place around it, clockwise from the top.
nonisolated struct MazeGeometry: Equatable, Sendable {
    let style: MazeStyle
    let rows: Int
    let columns: Int
    /// Circular only: cells in each ring, hub first.
    let ringSizes: [Int]
    let cellCount: Int
    private let ringOffsets: [Int]

    init(rows: Int, columns: Int) {
        style = .grid
        self.rows = max(1, rows)
        self.columns = max(1, columns)
        ringSizes = []
        ringOffsets = []
        cellCount = self.rows * self.columns
    }

    init(ringSizes: [Int]) {
        style = .circular
        self.ringSizes = ringSizes
        rows = ringSizes.count
        columns = ringSizes.max() ?? 1
        var offsets: [Int] = []
        var total = 0
        for size in ringSizes {
            offsets.append(total)
            total += size
        }
        ringOffsets = offsets
        cellCount = total
    }

    // MARK: - Cells

    func contains(_ point: GridPoint) -> Bool {
        switch style {
        case .grid:
            point.row >= 0 && point.row < rows && point.column >= 0 && point.column < columns
        case .circular:
            point.row >= 0 && point.row < ringSizes.count && point.column >= 0 && point.column < ringSizes[point.row]
        }
    }

    func index(of point: GridPoint) -> Int {
        style == .grid ? point.row * columns + point.column : ringOffsets[point.row] + point.column
    }

    func point(at index: Int) -> GridPoint {
        switch style {
        case .grid:
            return GridPoint(row: index / columns, column: index % columns)
        case .circular:
            let ring = ringOffsets.lastIndex { $0 <= index } ?? 0
            return GridPoint(row: ring, column: index - ringOffsets[ring])
        }
    }

    /// Every neighbouring cell of a circular maze (walls aside), tagged with the kind of move:
    /// 0 anticlockwise, 1 clockwise, 2 inwards, 3 outwards. Empty for a grid.
    func adjacentCells(of point: GridPoint) -> [(point: GridPoint, kind: Int)] {
        guard style == .circular, contains(point) else { return [] }
        var result: [(GridPoint, Int)] = []
        let size = ringSizes[point.row]
        if point.row >= 1 {
            result.append((GridPoint(row: point.row, column: (point.column + size - 1) % size), 0))
            result.append((GridPoint(row: point.row, column: (point.column + 1) % size), 1))
            let inner = ringSizes[point.row - 1]
            result.append((GridPoint(row: point.row - 1, column: point.column / (size / inner)), 2))
        }
        if point.row + 1 < ringSizes.count {
            let ratio = ringSizes[point.row + 1] / size
            for child in 0..<ratio {
                result.append((GridPoint(row: point.row + 1, column: point.column * ratio + child), 3))
            }
        }
        return result
    }

    // MARK: - Positions

    private static let fullTurn = 2 * Double.pi
    /// Sectors start at the top and run clockwise on screen (y grows downwards).
    private static let topAngle = -Double.pi / 2

    func innerRadius(ring: Int) -> Double {
        ring == 0 ? 0 : Double(CircularShape.hubRadius) + Double(ring - 1)
    }

    func outerRadius(ring: Int) -> Double {
        Double(CircularShape.hubRadius) + Double(ring)
    }

    func sectorSpan(ring: Int) -> Double {
        Self.fullTurn / Double(ringSizes[ring])
    }

    /// The angle of the middle of a sector (undefined for the hub).
    func centerAngle(of point: GridPoint) -> Double {
        Self.topAngle + (Double(point.column) + 0.5) * sectorSpan(ring: point.row)
    }

    /// The middle of a cell, in maze units.
    func unitCenter(of point: GridPoint) -> CGPoint {
        switch style {
        case .grid:
            return CGPoint(x: Double(point.column) + 0.5, y: Double(point.row) + 0.5)
        case .circular:
            guard point.row > 0 else { return .zero }
            let radius = (innerRadius(ring: point.row) + outerRadius(ring: point.row)) / 2
            let angle = centerAngle(of: point)
            return CGPoint(x: radius * cos(angle), y: radius * sin(angle))
        }
    }

    /// The cell a position falls in, or nil if it is outside the maze.
    func cell(containing position: CGPoint) -> GridPoint? {
        switch style {
        case .grid:
            let cell = GridPoint(row: Int(position.y.rounded(.down)), column: Int(position.x.rounded(.down)))
            return contains(cell) ? cell : nil
        case .circular:
            let radius = Double(hypot(position.x, position.y))
            if radius < Double(CircularShape.hubRadius) { return GridPoint(row: 0, column: 0) }
            let ring = Int((radius - Double(CircularShape.hubRadius)).rounded(.down)) + 1
            guard ring < ringSizes.count else { return nil }
            var angle = atan2(Double(position.y), Double(position.x)) - Self.topAngle
            angle = angle.truncatingRemainder(dividingBy: Self.fullTurn)
            if angle < 0 { angle += Self.fullTurn }
            let sector = min(ringSizes[ring] - 1, Int(angle / sectorSpan(ring: ring)))
            return GridPoint(row: ring, column: sector)
        }
    }

    /// How far a position is from a cell's middle, in the cell's own size: 0.5 is the edge of
    /// the cell at its middle and about 0.7 is a corner. A circular maze's cells vary in shape,
    /// so each is measured against its own size, which keeps forgiving movement fair everywhere.
    func distance(from position: CGPoint, to point: GridPoint) -> CGFloat {
        switch style {
        case .grid:
            let center = unitCenter(of: point)
            return hypot(position.x - center.x, position.y - center.y)
        case .circular:
            let radius = Double(hypot(position.x, position.y))
            if point.row == 0 { return CGFloat(0.5 * radius / Double(CircularShape.hubRadius)) }
            let middle = (innerRadius(ring: point.row) + outerRadius(ring: point.row)) / 2
            let radial = (radius - middle) / 0.5
            var turn = atan2(Double(position.y), Double(position.x)) - centerAngle(of: point)
            while turn > Double.pi { turn -= Self.fullTurn }
            while turn < -Double.pi { turn += Self.fullTurn }
            let angular = turn / (sectorSpan(ring: point.row) / 2)
            return CGFloat(0.5 * hypot(radial, angular))
        }
    }

    /// A line through the middles of `cells`. Moves around a ring follow the ring's curve
    /// instead of cutting across it.
    func polyline(through cells: [GridPoint]) -> [CGPoint] {
        guard let first = cells.first else { return [] }
        var points = [unitCenter(of: first)]
        for (from, to) in zip(cells, cells.dropFirst()) {
            if style == .circular, from.row == to.row, from.row > 0 {
                var turn = centerAngle(of: to) - centerAngle(of: from)
                while turn > Double.pi { turn -= Self.fullTurn }
                while turn < -Double.pi { turn += Self.fullTurn }
                let radius = (innerRadius(ring: from.row) + outerRadius(ring: from.row)) / 2
                let steps = max(2, Int((abs(turn) / (Double.pi / 24)).rounded(.up)))
                for step in 1..<steps {
                    let angle = centerAngle(of: from) + turn * Double(step) / Double(steps)
                    points.append(CGPoint(x: radius * cos(angle), y: radius * sin(angle)))
                }
            }
            points.append(unitCenter(of: to))
        }
        return points
    }

    /// A rough count of the steps between two cells if no walls were in the way. The movement
    /// code uses it to tell a pointer that cut a corner from one that is across a wall.
    func straightSteps(from a: GridPoint, to b: GridPoint) -> Int {
        switch style {
        case .grid:
            return a.manhattanDistance(to: b)
        case .circular:
            let rings = abs(a.row - b.row)
            guard a.row > 0, b.row > 0 else { return rings }
            var turn = abs(centerAngle(of: a) - centerAngle(of: b))
            turn = turn.truncatingRemainder(dividingBy: Self.fullTurn)
            if turn > Double.pi { turn = Self.fullTurn - turn }
            let coarser = Self.fullTurn / Double(min(ringSizes[a.row], ringSizes[b.row]))
            return rings + Int((turn / coarser).rounded())
        }
    }
}
