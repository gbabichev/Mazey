//
//  StarPlacement.swift
//  Mazey
//

import Foundation

/// Decides which cells of a maze hold a collectible star.
///
/// Stars are spread over random cells, with no regard for the winning route, so where they
/// are says nothing about it. Some will be on the way and some off in dead ends: collecting
/// them all means exploring. They are only ever placed where the player can actually get them.
nonisolated enum StarPlacement {
    /// Cells the player can step on before the maze ends. Reaching the finish completes the
    /// maze, so anything that can only be reached by going through the finish is out of play.
    static func playableCells(in maze: Maze) -> Set<GridPoint> {
        var reached: Set<GridPoint> = [maze.start]
        var stack = [maze.start]
        while let current = stack.popLast() {
            if current == maze.finish { continue }   // the maze is over here; do not walk on
            for neighbor in maze.openNeighbors(of: current) where reached.insert(neighbor).inserted {
                stack.append(neighbor)
            }
        }
        return reached
    }

    /// Up to `count` distinct cells, never the start or the finish, all reachable without
    /// passing through the finish. The same maze always gets the same stars.
    static func cells(in maze: Maze, count: Int) -> Set<GridPoint> {
        var candidates = playableCells(in: maze)
            .filter { $0 != maze.start && $0 != maze.finish }
            .sorted { ($0.row, $0.column) < ($1.row, $1.column) }   // a fixed order, so the shuffle is repeatable
        var rng = SeededGenerator(seed: maze.seed ^ 0x57A2_5EED_C0DE_1234)
        // Fisher-Yates shuffle, stopping once enough cells are fixed.
        let wanted = min(max(0, count), candidates.count)
        for index in 0..<wanted {
            let swap = index + rng.next(below: candidates.count - index)
            candidates.swapAt(index, swap)
        }
        return Set(candidates.prefix(wanted))
    }
}
