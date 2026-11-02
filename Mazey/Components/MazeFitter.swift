//
//  MazeFitter.swift
//  Mazey
//

import SwiftUI

/// The space the maze can use: the area inside the safe area, plus the option of extending up
/// under the (empty) top bar when the maze stays clear of the toolbar items on both sides.
nonisolated struct MazeSpace: Equatable, Sendable {
    /// Size of the area inside the safe area.
    var size: CGSize
    /// Height of the top safe area that the maze may extend into (0 where that is not allowed).
    var topInset: CGFloat = 0
    /// Room the maze must leave on each side when it extends under the top bar.
    var sideClearance: CGFloat = 100

    /// Areas the maze could fill, relative to the safe area's top-leading corner.
    var candidateFrames: [CGRect] {
        var frames = [CGRect(origin: .zero, size: size)]
        if topInset > 0, size.width - sideClearance * 2 > 0 {
            frames.append(CGRect(
                x: sideClearance,
                y: -topInset,
                width: size.width - sideClearance * 2,
                height: size.height + topInset
            ))
        }
        return frames
    }
}

/// Chooses a grid shape and an area for the maze so it uses as much of the screen as it can,
/// with square cells.
nonisolated enum MazeFitter {
    /// Extending under the top bar has to beat the plain area by this much to be worth it.
    private static let extendedAdvantage: CGFloat = 1.03
    private static let minimumSide = 3
    private static let maximumSide = 30
    /// The longest side may be at most this many times the shortest.
    private static let maximumAspect = 3.5
    /// Cell counts within this share of the target are acceptable.
    private static let countTolerance = 0.25

    /// The rows and columns for a new maze of about `cellCount` cells: the shape whose cells
    /// come out biggest (so it fills the space best) while staying near the cell count, and
    /// among those the one with the most cells.
    static func shape(cellCount: Int, in space: MazeSpace) -> (rows: Int, columns: Int) {
        var best: (rows: Int, columns: Int, cell: CGFloat, count: Int)?
        let frames = space.candidateFrames
        for (index, frame) in frames.enumerated() {
            let bonus: CGFloat = index == 0 ? extendedAdvantage : 1
            for rows in minimumSide...maximumSide {
                let ideal = Double(cellCount) / Double(rows)
                for columns in Set([Int(ideal.rounded(.down)), Int(ideal.rounded(.up))]) where columns >= minimumSide && columns <= maximumSide {
                    let count = rows * columns
                    let error = abs(Double(count - cellCount)) / Double(cellCount)
                    let aspect = Double(max(rows, columns)) / Double(min(rows, columns))
                    guard error <= countTolerance, aspect <= maximumAspect else { continue }
                    // Compare by how big the cells come out; a plain frame gets a small head start.
                    let cell = estimatedCellSize(rows: rows, columns: columns, in: frame.size) * bonus
                    // When the cells come out the same size (the space is limited by one side), take
                    // the grid with more cells: it fills the other side better.
                    if let current = best, (cell, count) <= (current.cell, current.count) { continue }
                    best = (rows, columns, cell, count)
                }
            }
        }
        // Tiny or odd spaces: fall back to a square grid rather than nothing.
        let side = max(minimumSide, Int(Double(cellCount).squareRoot().rounded()))
        return best.map { ($0.rows, $0.columns) } ?? (side, side)
    }

    // MARK: - Circular mazes

    /// A circular maze's cells must be at least this big (in points) to be worth drawing.
    static let minimumCircularCell: CGFloat = 22
    /// A circle wastes too much of a space this much longer than it is wide.
    static let maximumCircularAspect: CGFloat = 1.8

    /// The size of one ring's thickness a circular maze of about `cellCount` cells would have
    /// in the best area `space` offers.
    static func circularCellSize(cellCount: Int, in space: MazeSpace) -> CGFloat {
        let rings = CircularShape.rings(forCellCount: cellCount)
        return space.candidateFrames.map { MazeLayout(rings: rings, in: $0.size).cellSize }.max() ?? 0
    }

    /// True when a circular maze of about `cellCount` cells would look good in `space`.
    static func supportsCircular(cellCount: Int, in space: MazeSpace) -> Bool {
        let (long, short) = (max(space.size.width, space.size.height), min(space.size.width, space.size.height))
        guard short > 0, long / short <= maximumCircularAspect else { return false }
        return circularCellSize(cellCount: cellCount, in: space) >= minimumCircularCell
    }

    // MARK: - Hexagon and triangle mazes

    /// Hexagons must be at least this wide, and triangles this long a side, in points.
    static func minimumTiledCell(_ style: MazeStyle) -> CGFloat { style == .triangle ? 46 : 34 }

    /// The rows and columns of a hexagon or triangle maze of about `cellCount` cells whose cells
    /// come out biggest in the best area `space` offers, and the size of one unit there.
    static func tiledShape(style: MazeStyle, cellCount: Int, in space: MazeSpace) -> (rows: Int, columns: Int, cell: CGFloat) {
        var best: (rows: Int, columns: Int, cell: CGFloat, count: Int)?
        for (index, frame) in space.candidateFrames.enumerated() {
            let bonus: CGFloat = index == 0 ? extendedAdvantage : 1
            for rows in 2...maximumSide {
                let ideal = Double(cellCount) / Double(rows)
                for columns in Set([Int(ideal.rounded(.down)), Int(ideal.rounded(.up))]) where columns >= 3 && columns <= maximumSide * 2 {
                    let count = rows * columns
                    guard abs(Double(count - cellCount)) / Double(cellCount) <= countTolerance else { continue }
                    let geometry = MazeGeometry(style: style, rows: rows, columns: columns)
                    let extent = geometry.unitSize
                    let aspect = Double(max(extent.width, extent.height) / min(extent.width, extent.height))
                    guard aspect <= maximumAspect else { continue }
                    let cell = MazeLayout(tiled: geometry, in: frame.size).cellSize * bonus
                    if let current = best, (cell, count) <= (current.cell, current.count) { continue }
                    best = (rows, columns, cell, count)
                }
            }
        }
        if let best { return (best.rows, best.columns, best.cell) }
        let side = max(3, Int(Double(cellCount).squareRoot().rounded()))
        return (side, side, 0)
    }

    /// True when a hexagon or triangle maze of about `cellCount` cells would have cells big
    /// enough for fingers in `space`, and the space is not so long and thin that it wastes it.
    static func supportsTiled(style: MazeStyle, cellCount: Int, in space: MazeSpace) -> Bool {
        let (long, short) = (max(space.size.width, space.size.height), min(space.size.width, space.size.height))
        guard short > 0, long / short <= maximumCircularAspect * 1.4 else { return false }
        return tiledShape(style: style, cellCount: cellCount, in: space).cell >= minimumTiledCell(style)
    }

    /// The area inside `space` that fits `maze` best: the plain safe area, or the taller one
    /// under the top bar when that makes the cells noticeably bigger.
    static func frame(for maze: Maze, in space: MazeSpace) -> CGRect {
        let frames = space.candidateFrames
        var best = frames[0]
        var bestCell = MazeLayout(maze: maze, in: best.size).cellSize * extendedAdvantage
        for frame in frames.dropFirst() {
            let cell = MazeLayout(maze: maze, in: frame.size).cellSize
            if cell > bestCell {
                best = frame
                bestCell = cell
            }
        }
        return best
    }

    /// Cell size for a grid that is not generated yet, assuming labels on one horizontal and
    /// one vertical side (the usual case).
    private static func estimatedCellSize(rows: Int, columns: Int, in size: CGSize) -> CGFloat {
        MazeLayout(rows: rows, columns: columns, in: size, startSide: .right, finishSide: .down).cellSize
    }
}
