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
