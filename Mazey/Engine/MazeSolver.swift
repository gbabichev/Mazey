//
//  MazeSolver.swift
//  Mazey
//

import Foundation

/// How much of the route a hint reveals.
nonisolated enum MazeHintLevel: Sendable {
    case small   // the very next step
    case medium  // the next few steps
    case full    // the whole way to the finish

    var stepLimit: Int? {
        switch self {
        case .small: 1
        case .medium: 4
        case .full: nil
        }
    }

    /// The next level when the hint button is tapped again; nil turns hints off.
    var next: MazeHintLevel? {
        switch self {
        case .small: .medium
        case .medium: .full
        case .full: nil
        }
    }
}

/// Breadth-first search over a maze's open passages.
nonisolated enum MazeSolver {
    /// The shortest route from `start` to `goal` (default: the maze's finish),
    /// as an ordered list of cells including both ends. Nil if there is no route.
    static func solve(_ maze: Maze, from start: GridPoint, to goal: GridPoint? = nil) -> [GridPoint]? {
        let goal = goal ?? maze.finish
        guard maze.contains(start), maze.contains(goal) else { return nil }
        if start == goal { return [start] }

        var parent = Array(repeating: -1, count: maze.cellCount)
        var seen = Array(repeating: false, count: maze.cellCount)
        var queue = [maze.index(of: start)]
        var head = 0
        seen[queue[0]] = true
        let goalIndex = maze.index(of: goal)

        while head < queue.count {
            let currentIndex = queue[head]
            head += 1
            let current = maze.point(at: currentIndex)
            for neighbor in maze.openNeighbors(of: current) {
                let neighborIndex = maze.index(of: neighbor)
                guard !seen[neighborIndex] else { continue }
                seen[neighborIndex] = true
                parent[neighborIndex] = currentIndex
                if neighborIndex == goalIndex {
                    return buildPath(to: goalIndex, parent: parent, in: maze)
                }
                queue.append(neighborIndex)
            }
        }
        return nil
    }

    private static func buildPath(to goalIndex: Int, parent: [Int], in maze: Maze) -> [GridPoint] {
        var path: [GridPoint] = []
        var index = goalIndex
        while index != -1 {
            path.append(maze.point(at: index))
            index = parent[index]
        }
        return path.reversed()
    }

    /// Cells that can be reached from `start` without crossing a wall.
    static func reachableCells(in maze: Maze, from start: GridPoint) -> Set<GridPoint> {
        guard maze.contains(start) else { return [] }
        var reached: Set<GridPoint> = [start]
        var stack = [start]
        while let current = stack.popLast() {
            for neighbor in maze.openNeighbors(of: current) where reached.insert(neighbor).inserted {
                stack.append(neighbor)
            }
        }
        return reached
    }

    /// True when the finish can be reached from the start.
    static func isSolvable(_ maze: Maze) -> Bool {
        solve(maze, from: maze.start) != nil
    }

    /// Length and decision points of the start-to-finish route. Nil if unsolvable.
    static func metrics(for maze: Maze) -> MazeMetrics? {
        guard let route = solve(maze, from: maze.start) else { return nil }
        let decisions = route.filter { maze.openNeighbors(of: $0).count >= 3 }.count
        return MazeMetrics(solutionLength: route.count, decisionPoints: decisions)
    }

    /// The cells a hint should highlight, starting at the player's current cell.
    /// Empty when the player is already at the finish or cannot reach it.
    static func hint(in maze: Maze, from position: GridPoint, level: MazeHintLevel) -> [GridPoint] {
        guard let route = solve(maze, from: position), route.count > 1 else { return [] }
        guard let limit = level.stepLimit else { return route }
        return Array(route.prefix(limit + 1))
    }
}
