//
//  MazeDirection.swift
//  Mazey
//

import Foundation

/// One of the four ways to travel between neighbouring cells.
nonisolated enum MazeDirection: Int, CaseIterable, Sendable {
    case up, right, down, left

    var rowDelta: Int {
        switch self {
        case .up: -1
        case .down: 1
        case .left, .right: 0
        }
    }

    var columnDelta: Int {
        switch self {
        case .left: -1
        case .right: 1
        case .up, .down: 0
        }
    }

    var opposite: MazeDirection {
        switch self {
        case .up: .down
        case .down: .up
        case .left: .right
        case .right: .left
        }
    }

    var set: DirectionSet {
        DirectionSet(rawValue: 1 << rawValue)
    }
}

/// A compact set of directions, used to remember which sides of a cell are open.
nonisolated struct DirectionSet: OptionSet, Hashable, Sendable {
    let rawValue: Int

    static let up = MazeDirection.up.set
    static let right = MazeDirection.right.set
    static let down = MazeDirection.down.set
    static let left = MazeDirection.left.set

    func contains(_ direction: MazeDirection) -> Bool {
        contains(direction.set)
    }
}
