//
//  MazeCell.swift
//  Mazey
//

import Foundation

/// A single square of the maze. A cell starts with walls on all four sides;
/// `passages` records the sides where the wall has been knocked down.
nonisolated struct MazeCell: Equatable, Sendable {
    var passages: DirectionSet = []

    func isOpen(_ direction: MazeDirection) -> Bool {
        passages.contains(direction)
    }

    func hasWall(_ direction: MazeDirection) -> Bool {
        !isOpen(direction)
    }
}
