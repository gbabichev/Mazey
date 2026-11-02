//
//  StarPlacement.swift
//  Mazey
//

import Foundation

/// Decides which cells of a maze hold a collectible star.
///
/// Stars are spread over random cells, with no regard for the maze's layout, so where they
/// are says nothing about the winning route. Some will be on the way and some off in dead ends:
/// collecting them all means exploring.
nonisolated enum StarPlacement {
    /// Up to `count` distinct cells, never the start or the finish. The same maze always gets
    /// the same stars.
    static func cells(in maze: Maze, count: Int) -> Set<GridPoint> {
        var candidates = (0..<maze.cellCount)
            .map { maze.point(at: $0) }
            .filter { $0 != maze.start && $0 != maze.finish }
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
