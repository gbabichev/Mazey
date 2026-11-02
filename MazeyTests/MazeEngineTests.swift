//
//  MazeEngineTests.swift
//  MazeyTests
//

import CoreGraphics
import Testing
@testable import Mazey

struct MazeEngineTests {
    private let sizes = [(1, 1), (1, 5), (5, 1), (2, 2), (4, 4), (6, 6), (9, 9), (12, 12), (7, 13)]

    // MARK: - Generation

    @Test func generatedMazesHaveRequestedDimensions() {
        for (rows, columns) in sizes {
            let maze = MazeGenerator.generate(rows: rows, columns: columns, seed: 1)
            #expect(maze.rows == rows)
            #expect(maze.columns == columns)
            #expect(maze.cellCount == rows * columns)
        }
    }

    @Test func difficultiesUseTheirGridSize() {
        for difficulty in MazeDifficulty.allCases {
            let maze = MazeGenerator.generate(difficulty: difficulty, seed: 7)
            #expect(maze.rows == difficulty.size && maze.columns == difficulty.size)
        }
    }

    @Test func everyCellIsReachableFromTheStart() {
        for (rows, columns) in sizes {
            for seed in 0..<25 as Range<UInt64> {
                let maze = MazeGenerator.generate(rows: rows, columns: columns, seed: seed)
                let reached = MazeSolver.reachableCells(in: maze, from: maze.start)
                #expect(reached.count == maze.cellCount)
            }
        }
    }

    @Test func mazesAreWellFormed() {
        for seed in 0..<50 as Range<UInt64> {
            let maze = MazeGenerator.generate(rows: 8, columns: 8, seed: seed)
            var passageEnds = 0
            for index in 0..<maze.cellCount {
                let point = maze.point(at: index)
                for direction in MazeDirection.allCases where maze[point].isOpen(direction) {
                    let other = point.moved(direction)
                    #expect(maze.contains(other), "passage leads out of the grid")
                    #expect(maze[other].isOpen(direction.opposite), "passage is not two-way")
                    passageEnds += 1
                }
            }
            // A perfect maze is a spanning tree: cells - 1 passages, each counted from both ends.
            #expect(passageEnds == 2 * (maze.cellCount - 1))
        }
    }

    @Test func identicalSeedsProduceIdenticalMazes() {
        for difficulty in MazeDifficulty.allCases {
            #expect(MazeGenerator.generate(difficulty: difficulty, seed: 42) == MazeGenerator.generate(difficulty: difficulty, seed: 42))
        }
        #expect(MazeGenerator.generate(rows: 9, columns: 9, seed: 5) == MazeGenerator.generate(rows: 9, columns: 9, seed: 5))
    }

    @Test func differentSeedsProduceDifferentMazes() {
        let first = MazeGenerator.generate(rows: 9, columns: 9, seed: 1)
        let others = (2..<10 as Range<UInt64>).map { MazeGenerator.generate(rows: 9, columns: 9, seed: $0) }
        #expect(others.contains { $0 != first })
    }

    @Test func startAndFinishAreValidEdgeCells() {
        for seed in 0..<200 as Range<UInt64> {
            let maze = MazeGenerator.generate(difficulty: .medium, seed: seed)
            for (point, side) in [(maze.start, maze.startSide), (maze.finish, maze.finishSide)] {
                #expect(maze.contains(point))
                let isEdge = point.row == 0 || point.column == 0 || point.row == maze.rows - 1 || point.column == maze.columns - 1
                #expect(isEdge)
                if let side {
                    #expect(!maze.contains(point.moved(side)), "opening must face outside the grid")
                } else {
                    Issue.record("edge cell is missing its opening")
                }
            }
            #expect(maze.start != maze.finish)
        }
    }

    @Test func customStartAndFinishAreHonoured() {
        let start = GridPoint(row: 2, column: 3)
        let finish = GridPoint(row: 0, column: 0)
        let maze = MazeGenerator.generate(rows: 5, columns: 5, seed: 3, start: start, finish: finish)
        #expect(maze.start == start)
        #expect(maze.finish == finish)
        #expect(maze.startSide == nil)
        #expect(maze.finishSide != nil)
        #expect(MazeSolver.isSolvable(maze))
    }

    @Test func outOfRangeCustomPointsAreClamped() {
        let maze = MazeGenerator.generate(rows: 4, columns: 4, seed: 3, start: GridPoint(row: -5, column: 99), finish: GridPoint(row: 99, column: -1))
        #expect(maze.contains(maze.start) && maze.contains(maze.finish))
        #expect(MazeSolver.isSolvable(maze))
    }

    @Test func difficultyCriteriaAreMetForTypicalSeeds() {
        for difficulty in MazeDifficulty.allCases {
            var met = 0
            for seed in 0..<50 as Range<UInt64> {
                let maze = MazeGenerator.generate(difficulty: difficulty, seed: seed)
                if let metrics = MazeSolver.metrics(for: maze), difficulty.criteria.isSatisfied(by: metrics) { met += 1 }
            }
            #expect(met >= 45, "\(difficulty) met criteria only \(met)/50 times")
        }
    }

    // MARK: - Solver

    @Test func allGeneratedMazesAreSolvable() {
        for difficulty in MazeDifficulty.allCases {
            for seed in 0..<100 as Range<UInt64> {
                #expect(MazeSolver.isSolvable(MazeGenerator.generate(difficulty: difficulty, seed: seed)))
            }
        }
    }

    @Test func solutionIsAValidAdjacentPathWithoutWalls() throws {
        for seed in 0..<100 as Range<UInt64> {
            let maze = MazeGenerator.generate(difficulty: .hard, seed: seed)
            let route = try #require(MazeSolver.solve(maze, from: maze.start))
            #expect(route.first == maze.start)
            #expect(route.last == maze.finish)
            #expect(Set(route).count == route.count, "route revisits a cell")
            for (from, to) in zip(route, route.dropFirst()) {
                #expect(from.manhattanDistance(to: to) == 1)
                #expect(maze.openNeighbors(of: from).contains(to), "route crosses a wall")
            }
        }
    }

    @Test func solverIsShortestInATreeMaze() throws {
        // Hand-built corridor: (0,0) → (0,1) → (0,2), with a dead end at (1,1).
        var maze = Maze(rows: 2, columns: 3, start: GridPoint(row: 0, column: 0), finish: GridPoint(row: 0, column: 2))
        maze.openPassage(from: GridPoint(row: 0, column: 0), .right)
        maze.openPassage(from: GridPoint(row: 0, column: 1), .right)
        maze.openPassage(from: GridPoint(row: 0, column: 1), .down)
        let route = try #require(MazeSolver.solve(maze, from: maze.start))
        #expect(route == [GridPoint(row: 0, column: 0), GridPoint(row: 0, column: 1), GridPoint(row: 0, column: 2)])
    }

    @Test func solverEdgeCases() {
        let maze = MazeGenerator.generate(rows: 5, columns: 5, seed: 9)
        // Already at the goal.
        #expect(MazeSolver.solve(maze, from: maze.finish) == [maze.finish])
        // Off the grid.
        #expect(MazeSolver.solve(maze, from: GridPoint(row: -1, column: 0)) == nil)
        #expect(MazeSolver.solve(maze, from: maze.start, to: GridPoint(row: 5, column: 5)) == nil)
        // A 1x1 maze.
        let tiny = MazeGenerator.generate(rows: 1, columns: 1, seed: 1)
        #expect(MazeSolver.solve(tiny, from: tiny.start) == [GridPoint(row: 0, column: 0)])
        // No passages at all: unsolvable.
        let walled = Maze(rows: 3, columns: 3, start: GridPoint(row: 0, column: 0), finish: GridPoint(row: 2, column: 2))
        #expect(MazeSolver.solve(walled, from: walled.start) == nil)
        #expect(!MazeSolver.isSolvable(walled))
        #expect(MazeSolver.metrics(for: walled) == nil)
    }

    @Test func solverRecalculatesFromAnyCell() throws {
        let maze = MazeGenerator.generate(difficulty: .medium, seed: 11)
        for index in 0..<maze.cellCount {
            let point = maze.point(at: index)
            let route = try #require(MazeSolver.solve(maze, from: point))
            #expect(route.first == point && route.last == maze.finish)
        }
    }

    // MARK: - Hints

    @Test func hintsRevealIncreasingAmountsOfTheRoute() throws {
        let maze = MazeGenerator.generate(difficulty: .hard, seed: 4)
        let full = try #require(MazeSolver.solve(maze, from: maze.start))
        let small = MazeSolver.hint(in: maze, from: maze.start, level: .small)
        let medium = MazeSolver.hint(in: maze, from: maze.start, level: .medium)
        let all = MazeSolver.hint(in: maze, from: maze.start, level: .full)
        #expect(small == Array(full.prefix(2)))
        #expect(medium == Array(full.prefix(5)))
        #expect(all == full)
        #expect(MazeSolver.hint(in: maze, from: maze.finish, level: .full).isEmpty)
    }

    // MARK: - Movement

    @Test func pathRejectsMovesThroughWalls() {
        for seed in 0..<30 as Range<UInt64> {
            let maze = MazeGenerator.generate(rows: 6, columns: 6, seed: seed)
            for index in 0..<maze.cellCount {
                let point = maze.point(at: index)
                for direction in MazeDirection.allCases where maze[point].hasWall(direction) {
                    #expect(!maze.canMove(from: point, direction))
                    var path = MazePath(start: point)
                    #expect(path.move(to: point.moved(direction), in: maze) == .ignored)
                    #expect(path.cells == [point])
                }
            }
        }
    }

    @Test func pathRejectsJumpsAndOffGridCells() {
        let maze = MazeGenerator.generate(rows: 5, columns: 5, seed: 2)
        var path = MazePath(start: maze.start)
        #expect(path.move(to: GridPoint(row: maze.start.row + 3, column: maze.start.column), in: maze) == .ignored)
        #expect(path.move(to: GridPoint(row: -1, column: -1), in: maze) == .ignored)
        #expect(path.cells == [maze.start])
    }

    @Test func followingTheSolutionReachesTheFinish() throws {
        let maze = MazeGenerator.generate(difficulty: .hard, seed: 8)
        var path = MazePath(start: maze.start)
        for cell in try #require(MazeSolver.solve(maze, from: maze.start)).dropFirst() {
            #expect(path.move(to: cell, in: maze) == .appended)
        }
        #expect(path.end == maze.finish)
    }

    @Test func steppingBackRetracesAndRevisitsAreIgnored() throws {
        let maze = MazeGenerator.generate(difficulty: .medium, seed: 6)
        let route = try #require(MazeSolver.solve(maze, from: maze.start))
        var path = MazePath(start: maze.start)
        path.move(to: route[1], in: maze)
        path.move(to: route[2], in: maze)
        #expect(path.move(to: route[1], in: maze) == .retraced)
        #expect(path.cells == [route[0], route[1]])
        #expect(path.move(to: route[0], in: maze) == .retraced)
        // Retrace can be switched off, and the start cell is still "visited".
        path.move(to: route[1], in: maze)
        #expect(path.move(to: route[0], in: maze, allowRetrace: false) == .ignored)
    }

    @Test func sessionCompletesWhenFinishIsReached() throws {
        let session = MazeGameSession(difficulty: .easy, seed: 21)
        let route = try #require(MazeSolver.solve(session.maze, from: session.maze.start))
        #expect(!session.isComplete)
        for (from, to) in zip(route, route.dropFirst()) {
            session.drag(from: CGPoint(x: Double(from.column) + 0.5, y: Double(from.row) + 0.5),
                         to: CGPoint(x: Double(to.column) + 0.5, y: Double(to.row) + 0.5))
        }
        #expect(session.isComplete)
        #expect(session.path.end == session.maze.finish)
    }

    @Test func dragThatStartsAwayFromThePathDoesNotChangeIt() {
        let session = MazeGameSession(difficulty: .easy, seed: 21)
        let far = CGPoint(x: Double(session.maze.finish.column) + 0.5, y: Double(session.maze.finish.row) + 0.5)
        session.drag(from: far, to: far)
        #expect(session.path.cells == [session.maze.start])
    }

    @Test func hintsDoNotChangeProgress() {
        let session = MazeGameSession(difficulty: .easy, seed: 21)
        let before = session.path
        for _ in 0..<5 { session.requestHint() }
        #expect(session.path == before)
    }

    // MARK: - Stress

    @Test func generatingThousandsOfMazesIsSafe() {
        for seed in 0..<3000 as Range<UInt64> {
            let difficulty = MazeDifficulty.allCases[Int(seed) % MazeDifficulty.allCases.count]
            let maze = MazeGenerator.generate(difficulty: difficulty, seed: seed &* 7919)
            #expect(MazeSolver.isSolvable(maze))
        }
    }

    @Test func veryLargeMazeDoesNotOverflowTheStack() {
        let maze = MazeGenerator.generate(rows: 200, columns: 200, seed: 1)
        #expect(MazeSolver.reachableCells(in: maze, from: maze.start).count == 40_000)
        #expect(MazeSolver.isSolvable(maze))
    }
}
