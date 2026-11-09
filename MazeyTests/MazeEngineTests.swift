//
//  MazeEngineTests.swift
//  MazeyTests
//

import CoreGraphics
import Foundation
import SwiftUI
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

    @Test func defaultGridIsSquareWithTheTargetCellCount() {
        for difficulty in MazeDifficulty.allCases {
            let maze = MazeGenerator.generate(difficulty: difficulty, seed: 7)
            #expect(maze.rows == maze.columns)
            #expect(maze.cellCount == difficulty.cellCount)
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
                let criteria = difficulty.criteria(rows: maze.rows, columns: maze.columns)
                if let metrics = MazeSolver.metrics(for: maze), criteria.isSatisfied(by: metrics) { met += 1 }
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
        let session = MazeGameSession(difficulty: .easy, seed: 21, defaults: isolatedDefaults())
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
        let session = MazeGameSession(difficulty: .easy, seed: 21, defaults: isolatedDefaults())
        let far = CGPoint(x: Double(session.maze.finish.column) + 0.5, y: Double(session.maze.finish.row) + 0.5)
        session.drag(from: far, to: far)
        #expect(session.path.cells == [session.maze.start])
    }

    @Test func hintsDoNotChangeProgress() {
        let session = MazeGameSession(difficulty: .easy, seed: 21, defaults: isolatedDefaults())
        let before = session.path
        for _ in 0..<5 { session.requestHint() }
        #expect(session.path == before)
    }

    @Test func aHintGoesAwayWhenThePlayerMovesOn() throws {
        let session = MazeGameSession(difficulty: .easy, seed: 21, defaults: isolatedDefaults())
        session.requestHint()
        #expect(session.hintLevel == .small)
        let route = try #require(MazeSolver.solve(session.maze, from: session.maze.start))
        dragAlong(Array(route.prefix(2)), in: session)
        #expect(session.path.cells.count == 2)
        #expect(session.hintLevel == nil, "moving takes the hint away without stepping through the bigger ones")
        session.requestHint()
        #expect(session.hintLevel == .small, "and the next hint starts small again")
    }

    @Test func aHintFadesByItself() async throws {
        let session = MazeGameSession(difficulty: .easy, seed: 21, defaults: isolatedDefaults())
        #expect(MazeGameSession.hintDuration >= .seconds(3), "long enough to read")
        session.hintLifetime = .milliseconds(50)
        session.requestHint()
        #expect(session.hintLevel == .small)
        // Other tests can keep the main actor busy, so wait for the fade instead of a fixed time.
        let clock = ContinuousClock()
        let began = clock.now
        while session.hintLevel != nil, clock.now - began < .seconds(60) {
            try await Task.sleep(for: .milliseconds(50))
        }
        #expect(session.hintLevel == nil)
    }

    // MARK: - Dynamic grids

    private let spaces: [CGSize] = [
        CGSize(width: 366, height: 640),   // phone, portrait
        CGSize(width: 800, height: 300),   // phone, landscape
        CGSize(width: 800, height: 1000),  // tablet, portrait
        CGSize(width: 1180, height: 760),  // tablet, landscape
        CGSize(width: 300, height: 300),   // small square window
        CGSize(width: 420, height: 880),   // narrow tall (folded)
        CGSize(width: 1000, height: 400),  // wide short
    ]

    @Test func fittedShapeKeepsTheCellCountNearTheTarget() {
        for size in spaces {
            for difficulty in MazeDifficulty.allCases {
                let shape = MazeFitter.shape(cellCount: difficulty.cellCount, in: MazeSpace(size: size))
                let count = Double(shape.rows * shape.columns)
                #expect(abs(count - Double(difficulty.cellCount)) / Double(difficulty.cellCount) <= 0.25,
                        "\(difficulty) in \(size): \(shape)")
                #expect(shape.rows >= 3 && shape.columns >= 3)
            }
        }
    }

    @Test func fittedShapeFollowsTheScreensOrientation() {
        for difficulty in MazeDifficulty.allCases {
            let wide = MazeFitter.shape(cellCount: difficulty.cellCount, in: MazeSpace(size: CGSize(width: 900, height: 400)))
            let tall = MazeFitter.shape(cellCount: difficulty.cellCount, in: MazeSpace(size: CGSize(width: 400, height: 900)))
            #expect(wide.columns > wide.rows, "\(difficulty) wide: \(wide)")
            #expect(tall.rows > tall.columns, "\(difficulty) tall: \(tall)")
        }
    }

    @Test func fittedShapeFillsTheSpaceBetterThanASquare() {
        for size in spaces {
            for difficulty in MazeDifficulty.allCases {
                let shape = MazeFitter.shape(cellCount: difficulty.cellCount, in: MazeSpace(size: size))
                let fitted = MazeLayout(rows: shape.rows, columns: shape.columns, in: size, startSide: .right, finishSide: .down).cellSize
                let side = difficulty.defaultSize
                let square = MazeLayout(rows: side, columns: side, in: size, startSide: .right, finishSide: .down).cellSize
                #expect(fitted >= square * 0.999, "\(difficulty) in \(size)")
            }
        }
    }

    @Test func extendingUnderTheTopBarOnlyHappensWhenItHelps() {
        let maze = MazeGenerator.generate(rows: 5, columns: 5, seed: 1)
        // No top inset: always the plain area.
        #expect(MazeFitter.frame(for: maze, in: MazeSpace(size: CGSize(width: 600, height: 400))).origin == .zero)
        // A wide, short space with a tall top inset: the taller (narrower) frame wins.
        let wide = MazeSpace(size: CGSize(width: 900, height: 300), topInset: 80, sideClearance: 100)
        let frame = MazeFitter.frame(for: maze, in: wide)
        #expect(frame.minY == -80 && frame.minX == 100)
        // A tall space: the narrower frame would not make the cells bigger.
        let tall = MazeSpace(size: CGSize(width: 300, height: 900), topInset: 40, sideClearance: 100)
        #expect(MazeFitter.frame(for: maze, in: tall).origin == .zero)
    }

    @Test func mazesOfEveryFittedShapeAreSolvableAndMeetTheirCriteria() {
        for size in spaces {
            for difficulty in MazeDifficulty.allCases {
                let shape = MazeFitter.shape(cellCount: difficulty.cellCount, in: MazeSpace(size: size))
                var met = 0
                for seed in 0..<20 as Range<UInt64> {
                    let maze = MazeGenerator.generate(difficulty: difficulty, seed: seed, rows: shape.rows, columns: shape.columns)
                    #expect(maze.rows == shape.rows && maze.columns == shape.columns)
                    #expect(MazeSolver.isSolvable(maze))
                    let criteria = difficulty.criteria(rows: shape.rows, columns: shape.columns)
                    if let metrics = MazeSolver.metrics(for: maze), criteria.isSatisfied(by: metrics) { met += 1 }
                }
                #expect(met >= 17, "\(difficulty) \(shape) met criteria \(met)/20")
            }
        }
    }

    @Test func criteriaScaleWithTheGrid() {
        for difficulty in MazeDifficulty.allCases {
            let small = difficulty.criteria(rows: 4, columns: 4)
            let large = difficulty.criteria(rows: 12, columns: 12)
            #expect(large.minimumSolutionLength > small.minimumSolutionLength)
            #expect(large.minimumDecisionPoints >= small.minimumDecisionPoints)
        }
        #expect(MazeDifficulty.hard.criteria(rows: 10, columns: 10).minimumSolutionLength
                > MazeDifficulty.beginner.criteria(rows: 10, columns: 10).minimumSolutionLength)
    }

    @Test func higherTwistinessMakesMoreTurns() {
        func averageTurnRate(_ twistiness: Double) -> Double {
            var total = 0.0
            for seed in 0..<100 as Range<UInt64> {
                let maze = MazeGenerator.generate(rows: 10, columns: 10, seed: seed, twistiness: twistiness)
                let metrics = MazeSolver.metrics(for: maze)!
                total += Double(metrics.turns) / Double(metrics.solutionLength)
            }
            return total / 100
        }
        let straight = averageTurnRate(0.1)
        let middle = averageTurnRate(0.5)
        let twisty = averageTurnRate(0.9)
        #expect(straight < middle && middle < twisty, "\(straight) \(middle) \(twisty)")
    }

    @Test func twistinessStillGivesPerfectMazes() {
        for twistiness in [0.0, 0.5, 1.0] {
            for seed in 0..<30 as Range<UInt64> {
                let maze = MazeGenerator.generate(rows: 7, columns: 11, seed: seed, twistiness: twistiness)
                #expect(MazeSolver.reachableCells(in: maze, from: maze.start).count == maze.cellCount)
            }
        }
    }

    @Test func aFreshMazeRefitsWhenTheSpaceChanges() {
        let session = MazeGameSession(difficulty: .medium, seed: 33, defaults: isolatedDefaults())
        #expect(session.space == nil)
        let theme = session.theme.id
        session.updateSpace(MazeSpace(size: CGSize(width: 900, height: 400)))
        #expect(session.maze.columns > session.maze.rows)
        session.updateSpace(MazeSpace(size: CGSize(width: 400, height: 900)))
        #expect(session.maze.rows > session.maze.columns)
        #expect(session.theme.id == theme)
        #expect(session.path.cells == [session.maze.start])
    }

    @Test func aMazeInProgressIsKeptWhenTheSpaceChanges() throws {
        let session = MazeGameSession(difficulty: .medium, seed: 33, defaults: isolatedDefaults())
        session.updateSpace(MazeSpace(size: CGSize(width: 900, height: 400)))
        let maze = session.maze
        let route = try #require(MazeSolver.solve(maze, from: maze.start))
        session.drag(from: center(row: route[0].row, column: route[0].column),
                     to: center(row: route[1].row, column: route[1].column))
        #expect(session.hasProgress)
        let path = session.path
        session.updateSpace(MazeSpace(size: CGSize(width: 400, height: 900)))
        #expect(session.maze == maze)
        #expect(session.path == path)
    }

    @Test func newMazeUsesTheCurrentSpace() {
        let session = MazeGameSession(difficulty: .hard, seed: 1, defaults: isolatedDefaults())
        session.updateSpace(MazeSpace(size: CGSize(width: 1000, height: 400)))
        for seed in 0..<10 as Range<UInt64> {
            session.newMaze(seed: seed)
            #expect(session.maze.columns > session.maze.rows)
        }
    }

    // MARK: - Forgiving drags

    /// A 2x2 maze shaped like a corner: (0,0) → (0,1) → (1,1). The cell at (1,0) is walled off.
    private func cornerMaze() -> Maze {
        var maze = Maze(rows: 2, columns: 2, start: GridPoint(row: 0, column: 0), finish: GridPoint(row: 1, column: 1))
        maze.openPassage(from: GridPoint(row: 0, column: 0), .right)
        maze.openPassage(from: GridPoint(row: 0, column: 1), .down)
        return maze
    }

    private func center(row: Int, column: Int) -> CGPoint {
        CGPoint(x: Double(column) + 0.5, y: Double(row) + 0.5)
    }

    @Test func cuttingACornerStillAdvancesThroughTheSkippedCell() {
        let maze = cornerMaze()
        var path = MazePath(start: maze.start)
        // Straight from the first cell to the last, never touching the middle cell's center.
        let moved1 = path.follow(center(row: 1, column: 1), in: maze, allowRetrace: false)
        #expect(moved1)
        #expect(path.cells == [GridPoint(row: 0, column: 0), GridPoint(row: 0, column: 1), GridPoint(row: 1, column: 1)])
    }

    @Test func touchingAWallDoesNothingAndDoesNotBreakTheDrag() {
        let maze = cornerMaze()
        var path = MazePath(start: maze.start)
        // The pointer sits in the walled-off cell below the start.
        let moved2 = path.follow(center(row: 1, column: 0), in: maze, allowRetrace: true)
        #expect(!moved2)
        #expect(path.cells == [maze.start])
        // Moving on from there still works.
        let moved3 = path.follow(center(row: 0, column: 1), in: maze, allowRetrace: true)
        #expect(moved3)
        #expect(path.end == GridPoint(row: 0, column: 1))
    }

    @Test func driftingAlongsideTheCorridorStillFollows() {
        let maze = cornerMaze()
        var path = MazePath(start: maze.start)
        // Pointer travels along the wall side of the first cell, slightly off the corridor.
        for x in stride(from: 0.5, through: 1.5, by: 0.1) {
            path.follow(CGPoint(x: x, y: 0.9), in: maze, allowRetrace: true)
        }
        #expect(path.end == GridPoint(row: 0, column: 1))
    }

    @Test func pointerFarFromThePathIsIgnored() {
        let maze = cornerMaze()
        var path = MazePath(start: maze.start)
        let moved4 = path.follow(CGPoint(x: 9, y: 9), in: maze, allowRetrace: true)
        #expect(!moved4)
        #expect(path.cells == [maze.start])
    }

    @Test func draggingBackRetracesOnlyWhenAllowed() {
        let maze = cornerMaze()
        var path = MazePath(start: maze.start)
        path.follow(center(row: 0, column: 1), in: maze, allowRetrace: false)
        let moved5 = path.follow(center(row: 0, column: 0), in: maze, allowRetrace: false)
        #expect(!moved5)
        #expect(path.cells.count == 2)
        let moved6 = path.follow(center(row: 0, column: 0), in: maze, allowRetrace: true)
        #expect(moved6)
        #expect(path.cells == [maze.start])
    }

    @Test func pointerJitteringOnACellBoundaryDoesNotFlicker() {
        let maze = cornerMaze()
        var path = MazePath(start: maze.start)
        // Crossing into the next cell advances...
        let advanced = path.follow(CGPoint(x: 1.01, y: 0.5), in: maze, allowRetrace: true)
        #expect(advanced)
        #expect(path.end == GridPoint(row: 0, column: 1))
        // ...but a hair back over the line does not undo it.
        let jitter = path.follow(CGPoint(x: 0.99, y: 0.5), in: maze, allowRetrace: true)
        #expect(!jitter)
        #expect(path.end == GridPoint(row: 0, column: 1))
        // Clearly moving back does.
        let back = path.follow(CGPoint(x: 0.7, y: 0.5), in: maze, allowRetrace: true)
        #expect(back)
        #expect(path.cells == [maze.start])
    }

    @Test func cuttingEveryCornerAlongTheSolutionStillFinishes() throws {
        for seed in 0..<40 as Range<UInt64> {
            let session = MazeGameSession(difficulty: .hard, seed: seed, defaults: isolatedDefaults())
            let route = try #require(MazeSolver.solve(session.maze, from: session.maze.start))
            // Straight lines between every other cell of the route, so every turn is cut diagonally.
            var previous = center(row: route[0].row, column: route[0].column)
            for cell in route.dropFirst().enumerated().filter({ $0.offset % 2 == 1 }).map(\.element) {
                let target = center(row: cell.row, column: cell.column)
                session.drag(from: previous, to: target)
                previous = target
            }
            session.drag(from: previous, to: center(row: route.last!.row, column: route.last!.column))
            #expect(session.isComplete, "seed \(seed) did not finish")
        }
    }

    @Test func aWobblyDragWithinTheCorridorStillFinishes() throws {
        for seed in 0..<40 as Range<UInt64> {
            let session = MazeGameSession(difficulty: .hard, seed: seed, defaults: isolatedDefaults())
            let route = try #require(MazeSolver.solve(session.maze, from: session.maze.start))
            var rng = SeededGenerator(seed: seed)
            let phaseX = Double(rng.next(below: 628)) / 100
            let phaseY = Double(rng.next(below: 628)) / 100
            var previous = center(row: route[0].row, column: route[0].column)
            for (index, cell) in route.enumerated().dropFirst() {
                // A hand drifts slowly off-center, up to the edge of the corridor.
                let target = CGPoint(
                    x: Double(cell.column) + 0.5 + 0.45 * sin(0.7 * Double(index) + phaseX),
                    y: Double(cell.row) + 0.5 + 0.45 * sin(0.9 * Double(index) + phaseY)
                )
                session.drag(from: previous, to: target)
                previous = target
            }
            #expect(session.isComplete, "seed \(seed) did not finish")
        }
    }

    // MARK: - Themes

    @Test func everyThemeIsComplete() {
        #expect(Set(MazeTheme.all.map(\.id)).count == MazeTheme.all.count)
        for theme in MazeTheme.all {
            #expect(!theme.playerEmoji.isEmpty && !theme.startEmoji.isEmpty && !theme.finishEmoji.isEmpty)
            #expect(theme.decorations.count >= 3)
        }
    }

    @Test func sameSeedGivesSameTheme() {
        for seed in 0..<100 as Range<UInt64> {
            #expect(MazeTheme.theme(for: seed).id == MazeTheme.theme(for: seed).id)
        }
    }

    @Test func newThemeNeverRepeatsThePreviousOne() {
        for seed in 0..<200 as Range<UInt64> {
            for previous in MazeTheme.all {
                #expect(MazeTheme.theme(for: seed, avoiding: previous).id != previous.id)
            }
        }
    }

    @Test func everyThemeIsUsedAcrossSeeds() {
        let used = Set((0..<100 as Range<UInt64>).map { MazeTheme.theme(for: $0).id })
        #expect(used.count == MazeTheme.all.count)
    }

    @Test func newMazeChangesTheme() {
        let session = MazeGameSession(difficulty: .easy, seed: 5, defaults: isolatedDefaults())
        for seed in 0..<50 as Range<UInt64> {
            let before = session.theme.id
            session.newMaze(seed: seed)
            #expect(session.theme.id != before)
        }
    }

    // MARK: - Sound

    @MainActor
    private final class SoundSpy: SoundPlaying {
        private(set) var played: [SoundEffect] = []
        func play(_ effect: SoundEffect) { played.append(effect) }
    }

    /// A fresh, empty settings store so the saved mute setting never leaks between tests.
    private func isolatedDefaults() -> UserDefaults {
        let name = "MazeyTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    private let allEffects: [SoundEffect] = [
        .step(0), .step(1), .step(9), .step(10), .step(57), .retrace(0), .retrace(4), .finish,
        .hint(.small), .hint(.medium), .hint(.full), .restart, .soundOn, .collect(1), .collect(8),
        .newMaze(themeID: "space"), .newMaze(themeID: "dinosaur"), .newMaze(themeID: "ocean"),
        .newMaze(themeID: "farm"), .newMaze(themeID: "unknown"),
    ] + MazeTheme.all.map { .newMaze(themeID: $0.id) }

    @Test func everySoundIsWellFormed() {
        for effect in allEffects {
            let samples = SoundSynth.samples(for: effect)
            #expect(!samples.isEmpty, "\(effect)")
            #expect(samples.allSatisfy { $0.isFinite }, "\(effect) has non-finite samples")
            let peak = samples.map { abs($0) }.max() ?? 0
            #expect(peak <= 0.9001, "\(effect) clips: \(peak)")
            #expect(peak > 0.05, "\(effect) is nearly silent: \(peak)")
            // Fades in and out, so playback never clicks.
            #expect(abs(samples.first ?? 0) < 0.02, "\(effect) starts with a click")
            #expect(abs(samples.last ?? 0) < 0.02, "\(effect) ends with a click")
        }
    }

    @Test func soundsHaveSensibleLengths() {
        func seconds(_ effect: SoundEffect) -> Double { Double(SoundSynth.samples(for: effect).count) / SoundSynth.sampleRate }
        #expect(seconds(.step(0)) < 0.8)
        #expect(seconds(.retrace(0)) < seconds(.step(0)))
        #expect(seconds(.finish) > 1.0 && seconds(.finish) < 2.5)
        for theme in MazeTheme.all {
            #expect(seconds(.newMaze(themeID: theme.id)) < 1.2, "\(theme.id)")
        }
        // A bigger hint is a longer sparkle.
        #expect(seconds(.hint(.small)) < seconds(.hint(.medium)))
        #expect(seconds(.hint(.medium)) < seconds(.hint(.full)))
    }

    @Test func stepsPlayTheNotesOfTheMelodyInOrder() {
        // Zero crossings per second track pitch for these near-sine notes.
        func crossings(_ position: Int) -> Int {
            let samples = SoundSynth.samples(for: .step(position)).prefix(Int(0.1 * SoundSynth.sampleRate))
            return zip(samples, samples.dropFirst()).filter { ($0 < 0) != ($1 < 0) }.count
        }
        // Ode to Joy opens E E F G: the third note is higher than the second, the first and second match.
        let start = 0
        #expect(Melody.tunes[0].name == "Ode to Joy")
        #expect(abs(crossings(start) - crossings(start + 1)) <= 1)
        #expect(crossings(start + 3) > crossings(start + 2))
        #expect(SoundSynth.samples(for: .step(start)) == SoundSynth.samples(for: .step(start + Melody.count)), "the song wraps")
        #expect(SoundSynth.samples(for: .retrace(4)) != SoundSynth.samples(for: .step(4)), "rewinding is softer")
    }

    @Test func melodiesAreWrittenCorrectly() {
        #expect(Melody.midiNumber("C5") == 72)
        #expect(Melody.midiNumber("A4") == 69)
        #expect(Melody.midiNumber("F#4") == 66)
        #expect(Melody.midiNumber("Bb3") == 58)
        for tune in Melody.tunes {
            #expect(tune.notes.count >= 30, Comment(rawValue: tune.name))
            #expect(tune.notes.allSatisfy { (55...90).contains($0) }, "\(tune.name) stays in a singable range")
        }
        // A maze starts at the beginning of a tune, and different seeds start different tunes.
        let starts = Set((0..<40 as Range<UInt64>).map(Melody.startPosition(for:)))
        let tuneStarts = Set(Melody.tunes.indices.map { index in Melody.tunes[..<index].reduce(0) { $0 + $1.notes.count } })
        #expect(starts.isSubset(of: tuneStarts))
        #expect(starts.count >= 4)
    }

    @Test func themesHaveDifferentFlourishes() {
        let flourishes = MazeTheme.all.map { SoundSynth.samples(for: .newMaze(themeID: $0.id)) }
        for (index, flourish) in flourishes.enumerated() {
            for other in flourishes[(index + 1)...] { #expect(flourish != other) }
        }
    }

    /// Star pickups depend on where the stars happen to be, so tests about steps ignore them.
    private func withoutCollects(_ effects: [SoundEffect]) -> [SoundEffect] {
        effects.filter { if case .collect = $0 { false } else { true } }
    }

    @Test func drawingPlaysRisingStepsAndRetracingPlaysSofterOnes() throws {
        let spy = SoundSpy()
        let session = MazeGameSession(difficulty: .medium, seed: 21, sounds: spy, defaults: isolatedDefaults())
        let route = try #require(MazeSolver.solve(session.maze, from: session.maze.start))
        func at(_ index: Int) -> CGPoint { center(row: route[index].row, column: route[index].column) }
        session.drag(from: at(0), to: at(1))
        session.drag(from: at(1), to: at(2))
        #expect(withoutCollects(spy.played) == [.step(1), .step(2)])
        session.drag(from: at(2), to: at(1))
        #expect(withoutCollects(spy.played).last == .retrace(1))
        #expect(withoutCollects(spy.played).count == 3)
    }

    @Test func nothingPlaysWhenTheDragDoesNotMoveThePath() {
        let spy = SoundSpy()
        let session = MazeGameSession(difficulty: .medium, seed: 21, sounds: spy, defaults: isolatedDefaults())
        let far = CGPoint(x: 99, y: 99)
        session.drag(from: far, to: far)
        #expect(spy.played.isEmpty)
    }

    @Test func finishingPlaysTheFanfareOnce() throws {
        let spy = SoundSpy()
        let session = MazeGameSession(difficulty: .easy, seed: 21, sounds: spy, defaults: isolatedDefaults())
        let route = try #require(MazeSolver.solve(session.maze, from: session.maze.start))
        for (from, to) in zip(route, route.dropFirst()) {
            session.drag(from: center(row: from.row, column: from.column), to: center(row: to.row, column: to.column))
        }
        #expect(session.isComplete)
        #expect(spy.played.filter { $0 == .finish }.count == 1)
        #expect(spy.played.filter { $0 == .applause }.count == 1)
        #expect(Array(spy.played.suffix(2)) == [.finish, .applause], "the clapping follows the fanfare")
        // Once finished, more dragging stays quiet.
        let count = spy.played.count
        session.drag(from: center(row: 0, column: 0), to: center(row: 1, column: 1))
        #expect(spy.played.count == count)
    }

    @Test func newMazeRestartAndHintsHaveTheirOwnSounds() {
        let spy = SoundSpy()
        let session = MazeGameSession(difficulty: .easy, seed: 21, sounds: spy, defaults: isolatedDefaults())
        session.newMaze(seed: 8)
        #expect(spy.played == [.newMaze(themeID: session.theme.id)])
        session.restart()
        #expect(spy.played.last == .restart)
        #expect(spy.played.count == 2)
        session.requestHint()
        session.requestHint()
        session.requestHint()
        session.requestHint()   // the fourth tap turns hints off, silently
        #expect(spy.played.suffix(3) == [.hint(.small), .hint(.medium), .hint(.full)])
        #expect(spy.played.count == 5)
    }

    @Test func mutingSilencesEverythingAndIsRemembered() throws {
        let defaults = isolatedDefaults()
        let spy = SoundSpy()
        let session = MazeGameSession(difficulty: .easy, seed: 21, sounds: spy, defaults: defaults)
        #expect(session.isSoundOn)
        session.isSoundOn = false
        session.newMaze(seed: 3)
        session.restart()
        session.requestHint()
        #expect(spy.played.isEmpty)
        // A new session reads the saved setting.
        #expect(!MazeGameSession(sounds: spy, defaults: defaults).isSoundOn)
        // Turning sound back on confirms with a chime.
        session.isSoundOn = true
        #expect(spy.played == [.soundOn])
        #expect(MazeGameSession(sounds: spy, defaults: defaults).isSoundOn)
    }

    // MARK: - Demo and haptics

    @Test func theDemoShowsOnFirstLaunchAndNeverAgainOnceDismissed() {
        let defaults = isolatedDefaults()
        let first = MazeGameSession(difficulty: .beginner, seed: 4, defaults: defaults)
        #expect(first.isDemoVisible)
        first.dismissDemo()
        #expect(!first.isDemoVisible)
        // A later launch remembers that it was seen.
        #expect(!MazeGameSession(difficulty: .beginner, seed: 4, defaults: defaults).isDemoVisible)
    }

    @Test func touchingTheMazeDismissesTheDemo() {
        let session = MazeGameSession(difficulty: .beginner, seed: 4, defaults: isolatedDefaults())
        #expect(session.isDemoVisible)
        let far = CGPoint(x: 99, y: 99)
        session.drag(from: far, to: far)   // even a touch that moves nothing counts
        #expect(!session.isDemoVisible)
    }

    @Test func theDemoRouteIsTheFirstStepsOfTheSolution() throws {
        let session = MazeGameSession(difficulty: .medium, seed: 12, defaults: isolatedDefaults())
        let route = try #require(MazeSolver.solve(session.maze, from: session.maze.start))
        #expect(session.demoRoute == Array(route.prefix(4)))
        session.dismissDemo()
        #expect(session.demoRoute.isEmpty)
    }

    @Test func anIdleNewPlayerGetsANudge() {
        let defaults = isolatedDefaults()
        let session = MazeGameSession(difficulty: .beginner, seed: 4, defaults: defaults)
        session.dismissDemo()
        session.nudgeIfIdle()
        #expect(session.isDemoVisible)
    }

    @Test func noNudgeOnceThePlayerHasStartedOrIsExperienced() throws {
        // Already drawing: no nudge.
        let started = MazeGameSession(difficulty: .beginner, seed: 4, defaults: isolatedDefaults())
        started.dismissDemo()
        let route = try #require(MazeSolver.solve(started.maze, from: started.maze.start))
        started.drag(from: center(row: route[0].row, column: route[0].column),
                     to: center(row: route[1].row, column: route[1].column))
        started.nudgeIfIdle()
        #expect(!started.isDemoVisible)

        // Finished enough mazes: no nudge.
        let defaults = isolatedDefaults()
        defaults.set(MazeGameSession.nudgeUntilCompleted, forKey: MazeGameSession.completedKey)
        let experienced = MazeGameSession(difficulty: .beginner, seed: 4, defaults: defaults)
        experienced.dismissDemo()
        experienced.nudgeIfIdle()
        #expect(!experienced.isDemoVisible)
    }

    @Test func aNewMazeHidesTheDemoWithoutMarkingItSeen() {
        let defaults = isolatedDefaults()
        let session = MazeGameSession(difficulty: .beginner, seed: 4, defaults: defaults)
        session.newMaze(seed: 9)
        #expect(!session.isDemoVisible)
    }

    @Test func finishedMazesAreCountedAndRemembered() throws {
        let defaults = isolatedDefaults()
        let session = MazeGameSession(difficulty: .easy, seed: 21, defaults: defaults)
        #expect(session.completedMazes == 0)
        let route = try #require(MazeSolver.solve(session.maze, from: session.maze.start))
        for (from, to) in zip(route, route.dropFirst()) {
            session.drag(from: center(row: from.row, column: from.column), to: center(row: to.row, column: to.column))
        }
        #expect(session.completedMazes == 1)
        #expect(MazeGameSession(difficulty: .easy, seed: 1, defaults: defaults).completedMazes == 1)
    }

    /// Drags the player along the solution to the finish.
    private func finishMaze(_ session: MazeGameSession) throws {
        let route = try #require(MazeSolver.solve(session.maze, from: session.maze.start))
        for (from, to) in zip(route, route.dropFirst()) {
            session.drag(from: center(row: from.row, column: from.column), to: center(row: to.row, column: to.column))
        }
        #expect(session.isComplete)
    }

    private func isStep(_ effect: SoundEffect) -> Bool {
        switch effect {
        case .step, .retrace: true
        default: false
        }
    }

    @Test func everySoundPlaysByDefaultAndTheFinishIncludesApplause() throws {
        let spy = SoundSpy()
        let session = MazeGameSession(difficulty: .easy, seed: 21, sounds: spy, defaults: isolatedDefaults())
        #expect(session.isSoundOn && session.isDragMusicOn && session.isApplauseOn)
        try finishMaze(session)
        #expect(spy.played.contains { isStep($0) })
        #expect(spy.played.contains(.finish))
        #expect(spy.played.contains(.applause))
    }

    @Test func dragMusicCanBeSwitchedOffAlone() throws {
        let spy = SoundSpy()
        let session = MazeGameSession(difficulty: .easy, seed: 21, sounds: spy, defaults: isolatedDefaults())
        session.isDragMusicOn = false
        try finishMaze(session)
        #expect(!spy.played.contains { isStep($0) }, "no notes while dragging")
        #expect(spy.played.contains(.finish) && spy.played.contains(.applause), "the finish is unchanged")
    }

    @Test func applauseCanBeSwitchedOffAlone() throws {
        let spy = SoundSpy()
        let session = MazeGameSession(difficulty: .easy, seed: 21, sounds: spy, defaults: isolatedDefaults())
        session.isApplauseOn = false
        try finishMaze(session)
        #expect(spy.played.contains { isStep($0) }, "the music still plays")
        #expect(spy.played.contains(.finish), "and so does the fanfare")
        #expect(!spy.played.contains(.applause))
    }

    @Test func theMasterSwitchSilencesEverythingWhateverTheOthersSay() throws {
        let spy = SoundSpy()
        let session = MazeGameSession(difficulty: .easy, seed: 21, sounds: spy, defaults: isolatedDefaults())
        session.isSoundOn = false
        #expect(session.isDragMusicOn && session.isApplauseOn, "the other switches keep their setting")
        try finishMaze(session)
        #expect(spy.played.isEmpty)
    }

    @Test func soundSwitchesAreRememberedAndResetToOn() {
        let defaults = isolatedDefaults()
        let session = MazeGameSession(difficulty: .easy, seed: 21, defaults: defaults)
        session.isDragMusicOn = false
        session.isApplauseOn = false
        let relaunched = MazeGameSession(difficulty: .easy, seed: 21, defaults: defaults)
        #expect(!relaunched.isDragMusicOn && !relaunched.isApplauseOn && relaunched.isSoundOn)
        session.resetEverything()
        #expect(session.isDragMusicOn && session.isApplauseOn)
        let afterReset = MazeGameSession(difficulty: .easy, seed: 21, defaults: defaults)
        #expect(afterReset.isDragMusicOn && afterReset.isApplauseOn)
    }

    @Test func theIntroShowsOnFirstLaunchAndOnlyOnce() {
        let defaults = isolatedDefaults()
        let first = MazeGameSession(difficulty: .easy, seed: 4, defaults: defaults)
        #expect(!first.hasSeenIntro)
        first.finishIntro()
        #expect(first.hasSeenIntro)
        #expect(MazeGameSession(difficulty: .easy, seed: 4, defaults: defaults).hasSeenIntro)
    }

    @Test func resettingBringsTheIntroBack() {
        let defaults = isolatedDefaults()
        let session = MazeGameSession(difficulty: .easy, seed: 4, defaults: defaults)
        session.finishIntro()
        session.resetEverything()
        #expect(!session.hasSeenIntro)
        #expect(!MazeGameSession(difficulty: .easy, seed: 4, defaults: defaults).hasSeenIntro)
    }

    @Test func everySoundHasAHapticAndStepsGrowStronger() {
        for effect in allEffects {
            switch HapticKind.kind(for: effect) {
            case .tick(let intensity): #expect((0...1).contains(intensity), "\(effect)")
            case .celebrate: #expect(effect == .finish)
            case .none: #expect(effect == .applause)
            }
        }
        let intensities = (0..<SoundSynth.stepScale.count).map { index -> Double in
            if case .tick(let value) = HapticKind.kind(for: .step(index)) { return value }
            return -1
        }
        #expect(intensities == intensities.sorted())
        #expect(intensities.first! < intensities.last!)
        // Retracing is gentler than the quietest step.
        if case .tick(let back) = HapticKind.kind(for: .retrace(3)) { #expect(back < intensities.first!) }
        #expect(HapticKind.kind(for: .finish) == .celebrate)
    }

    // MARK: - Themes and stickers

    @Test func everyThemeHasItsOwnStickersAndNoStarShapedScenery() {
        #expect(MazeTheme.all.count >= 13)
        let starShapes = ["⭐️", "🌟", "✨", "💫"]
        for theme in MazeTheme.all {
            #expect(theme.stickers.count >= 8, "\(theme.id)")
            #expect(Set(theme.stickers.map(\.emoji)).count == theme.stickers.count, "\(theme.id) repeats a sticker")
            #expect(Set(theme.stickers.map(\.name)).count == theme.stickers.count)
            #expect(theme.stickers.allSatisfy { !$0.name.isEmpty })
            for decoration in theme.decorations {
                #expect(!starShapes.contains(decoration), "\(theme.id) scenery \(decoration) looks like a collectible star")
            }
        }
        #expect(MazeTheme.all.map(\.playerEmoji).count == Set(MazeTheme.all.map(\.id)).count)
    }

    @Test func aboutHalfTheThemesAreDark() {
        let dark = MazeTheme.all.filter(\.isDark)
        #expect(dark.count * 100 >= MazeTheme.all.count * 40, "dark themes: \(dark.map(\.id))")
        #expect(dark.count * 100 <= MazeTheme.all.count * 60)
        #expect(MazeTheme.all.contains { $0.id == "halloween" } && MazeTheme.all.contains { $0.id == "christmas" })
    }

    @Test func eachThemesTextAndWallsShowUpOnItsOwnPaper() {
        for theme in MazeTheme.all {
            #expect(Color.contrastRatio(theme.ink, theme.paper) >= 4.5, "\(theme.id) ink on paper")
            #expect(Color.contrastRatio(theme.wall, theme.paper) >= 3, "\(theme.id) wall on paper")
            #expect(Color.contrastRatio(theme.path, theme.paper) >= 1.8, "\(theme.id) route on paper")
            // Dark themes have a dark floor and light walls; light themes the reverse.
            #expect((theme.paper.relativeLuminance < 0.25) == theme.isDark, "\(theme.id) paper does not match isDark")
        }
    }

    @Test func everyThemeIsReachedAcrossSeeds() {
        let used = Set((0..<400 as Range<UInt64>).map { MazeTheme.theme(for: $0).id })
        #expect(used.count == MazeTheme.all.count)
    }

    @Test func awarderHandsOutNewStickersFirst() {
        var progress = Progress()
        var earned: Set<Int> = []
        for seed in 0..<8 as Range<UInt64> {
            let index = StickerAwarder.choose(themeID: "space", stickerCount: 8, in: progress, seed: seed)
            #expect(!earned.contains(index), "gave a duplicate while some were missing")
            earned.insert(index)
            progress.stickers[Progress.key(themeID: "space", index: index)] = StickerEntry(count: 1, firstEarned: Date())
        }
        #expect(earned.count == 8)
    }

    @Test func awarderRepeatsAnyStickerOnceTheBookIsFull() {
        var progress = Progress()
        for index in 0..<8 {
            progress.stickers[Progress.key(themeID: "space", index: index)] = StickerEntry(count: 1, firstEarned: Date())
        }
        let picks = Set((0..<40 as Range<UInt64>).map { StickerAwarder.choose(themeID: "space", stickerCount: 8, in: progress, seed: $0) })
        #expect(picks.count > 1)
    }

    // MARK: - Stars and timing

    @Test func starsAreDistinctDeterministicAndAvoidTheEnds() {
        for difficulty in MazeDifficulty.allCases {
            for seed in 0..<40 as Range<UInt64> {
                let maze = MazeGenerator.generate(difficulty: difficulty, seed: seed)
                let stars = StarPlacement.cells(in: maze, count: difficulty.collectibleCount)
                #expect(stars.count == difficulty.collectibleCount)
                #expect(!stars.contains(maze.start) && !stars.contains(maze.finish))
                #expect(stars.allSatisfy { maze.contains($0) })
                #expect(stars == StarPlacement.cells(in: maze, count: difficulty.collectibleCount))
            }
        }
        let tiny = MazeGenerator.generate(rows: 2, columns: 2, seed: 1)
        #expect(StarPlacement.cells(in: tiny, count: 50).count <= 2, "never more stars than free cells")
        #expect(StarPlacement.cells(in: tiny, count: 0).isEmpty)
    }

    @Test func everyStarCanBeReachedWithoutPassingThroughTheFinish() {
        for difficulty in MazeDifficulty.allCases {
            for seed in 0..<150 as Range<UInt64> {
                let maze = MazeGenerator.generate(difficulty: difficulty, seed: seed)
                let playable = StarPlacement.playableCells(in: maze)
                let stars = StarPlacement.cells(in: maze, count: difficulty.collectibleCount)
                #expect(stars.isSubset(of: playable), "\(difficulty) seed \(seed) has a star behind the finish")
                for star in stars {
                    let route = MazeSolver.solve(maze, from: maze.start, to: star)
                    #expect(route != nil && !route!.dropLast().contains(maze.finish), "route to a star crosses the finish")
                }
            }
        }
    }

    @Test func aMazeWithAPocketBehindTheFinishKeepsStarsOutOfIt() {
        // start(0,0) - (0,1) - finish(0,2) - (0,3) - (1,3): everything past the finish is off limits.
        var maze = Maze(rows: 2, columns: 4, start: GridPoint(row: 0, column: 0), finish: GridPoint(row: 0, column: 2))
        maze.openPassage(from: GridPoint(row: 0, column: 0), .right)
        maze.openPassage(from: GridPoint(row: 0, column: 1), .right)
        maze.openPassage(from: GridPoint(row: 0, column: 2), .right)
        maze.openPassage(from: GridPoint(row: 0, column: 3), .down)
        maze.openPassage(from: GridPoint(row: 0, column: 0), .down)
        let playable = StarPlacement.playableCells(in: maze)
        #expect(!playable.contains(GridPoint(row: 0, column: 3)))
        #expect(!playable.contains(GridPoint(row: 1, column: 3)))
        #expect(playable.contains(GridPoint(row: 1, column: 0)))
        for seed in 0..<20 as Range<UInt64> {
            var seeded = Maze(rows: 2, columns: 4, start: maze.start, finish: maze.finish, seed: seed)
            for index in 0..<maze.cellCount {
                let point = maze.point(at: index)
                for direction in [MazeDirection.right, .down] where maze[point].isOpen(direction) { seeded.openPassage(from: point, direction) }
            }
            let stars = StarPlacement.cells(in: seeded, count: 10)
            #expect(stars.isSubset(of: [GridPoint(row: 0, column: 1), GridPoint(row: 1, column: 0)]))
        }
    }

    @Test func everyStarCanBeCollectedInEveryMaze() throws {
        for difficulty in MazeDifficulty.allCases {
            for seed in 0..<40 as Range<UInt64> {
                let session = MazeGameSession(difficulty: difficulty, seed: seed, defaults: isolatedDefaults())
                for star in session.stars.sorted(by: { ($0.row, $0.column) < ($1.row, $1.column) }) {
                    walk(session, to: star)
                }
                #expect(!session.isComplete, "\(difficulty) seed \(seed) ended before every star was collected")
                #expect(session.uncollectedStars.isEmpty, "\(difficulty) seed \(seed) left stars behind")
                walk(session, to: session.maze.finish)
                #expect(session.lastReward.map { $0.starsCollected == $0.starsTotal } == true)
            }
        }
    }

    @Test func starsGiveNothingAwayAboutTheRoute() throws {
        // If stars avoided (or favoured) the winning route, the share of stars on it would
        // differ from the share of cells on it. Over many mazes the two must agree.
        var starsOnRoute = 0.0, totalStars = 0.0, routeCells = 0.0, freeCells = 0.0
        for seed in 0..<400 as Range<UInt64> {
            let maze = MazeGenerator.generate(difficulty: .medium, seed: seed)
            let route = Set(try #require(MazeSolver.solve(maze, from: maze.start)))
            let stars = StarPlacement.cells(in: maze, count: 6)
            starsOnRoute += Double(stars.filter { route.contains($0) }.count)
            totalStars += Double(stars.count)
            routeCells += Double(route.count - 2)       // minus start and finish
            freeCells += Double(StarPlacement.playableCells(in: maze).count - 1)   // minus the start (the finish is not playable ground)
        }
        let starShare = starsOnRoute / totalStars
        let cellShare = routeCells / freeCells
        #expect(abs(starShare - cellShare) < 0.04, "stars on route \(starShare) vs cells on route \(cellShare)")
    }

    @Test func theTimerCountsBusyTimeAndCapsPauses() {
        var timer = ActivityTimer()
        let start = Date(timeIntervalSince1970: 1_000)
        #expect(!timer.hasStarted)
        timer.record(at: start)
        #expect(timer.hasStarted && timer.total == 0)
        timer.record(at: start.addingTimeInterval(5))
        timer.record(at: start.addingTimeInterval(9))
        #expect(timer.total == 9)
        // A long break only counts up to the cap.
        timer.record(at: start.addingTimeInterval(9 + 600))
        #expect(timer.total == 9 + ActivityTimer.idleCap)
        // A clock that jumps backwards never subtracts.
        timer.record(at: start)
        #expect(timer.total == 9 + ActivityTimer.idleCap)
        timer.reset()
        #expect(!timer.hasStarted && timer.total == 0)
    }

    // MARK: - Collection store and statistics

    private func record(_ store: CollectionStore, theme: MazeTheme = .space, difficulty: MazeDifficulty = .easy,
                        seconds: Double = 30, stars: Int = 1, of total: Int = 4, seed: UInt64 = 0, at date: Date = Date()) -> FinishReward {
        store.recordFinish(theme: theme, difficulty: difficulty, rows: 6, columns: 6, seconds: seconds,
                           starsCollected: stars, starsTotal: total, seed: seed, now: date)
    }

    @Test func theCharacterGlidesAlongTheCorridorWhileDragging() throws {
        let session = MazeGameSession(difficulty: .easy, seed: 21, defaults: isolatedDefaults())
        let route = try #require(MazeSolver.solve(session.maze, from: session.maze.start))
        let (a, b) = (session.maze.unitCenter(of: route[0]), session.maze.unitCenter(of: route[1]))
        // Press on the start, then move a third of the way to the next cell.
        session.drag(from: a, to: a)
        session.drag(from: a, to: CGPoint(x: a.x + (b.x - a.x) / 3, y: a.y + (b.y - a.y) / 3))
        let head = try #require(session.head)
        #expect(session.path.end == route[0], "not yet across")
        #expect(abs(head.point.x - (a.x + (b.x - a.x) / 3)) < 0.01 && abs(head.point.y - (a.y + (b.y - a.y) / 3)) < 0.01)
        session.endDrag()
        #expect(session.head == nil)
    }

    @Test func parentGateSumsAreHardForChildrenAndHaveOneRightAnswer() {
        var generator = SeededGenerator(seed: 9)
        for _ in 0..<200 {
            let gate = ParentGate.make(using: &generator)
            #expect(gate.answer >= 12 && gate.answer <= 18)
            #expect(gate.choices.count == 4 && Set(gate.choices).count == 4)
            #expect(gate.choices.filter(gate.isCorrect).count == 1)
            #expect(gate.choices.allSatisfy { $0 > 0 })
        }
    }

    @Test func resettingEverythingReturnsToAFreshInstall() {
        let defaults = isolatedDefaults()
        let session = MazeGameSession(difficulty: .hard, seed: 5, defaults: defaults)
        _ = record(session.collection)
        session.isSoundOn = false
        session.dismissDemo()
        session.resetEverything()

        #expect(session.collection.ownedStickerCount == 0)
        #expect(session.collection.statistics.totalFinished == 0)
        #expect(session.difficulty == .beginner)
        #expect(session.isSoundOn && session.isDemoVisible)
        #expect(session.completedMazes == 0 && !session.isComplete)

        // A relaunch on the same storage looks brand new too.
        let relaunched = MazeGameSession(seed: 5, defaults: defaults)
        #expect(relaunched.collection.ownedStickerCount == 0)
        #expect(relaunched.difficulty == .beginner && relaunched.isDemoVisible)
    }

    @Test func finishingAwardsAStickerAndAddsUpTheStars() {
        let store = CollectionStore(defaults: isolatedDefaults())
        let first = record(store, stars: 2, of: 4)
        #expect(first.isNew)
        #expect(first.sticker == MazeTheme.space.stickers[first.stickerIndex])
        #expect(first.totalStars == 2)

        let second = record(store, stars: 4, of: 4, seed: 1)
        #expect(second.totalStars == 6 && store.totalStars == 6)
        #expect(store.ownedStickerCount == 2)
        #expect(store.progress.finishes.count == 2)
    }

    @Test func charactersUnlockAsStarsAddUp() {
        let store = CollectionStore(defaults: isolatedDefaults())
        let first = PlayerCharacter.all[0], second = PlayerCharacter.all[1]
        #expect(store.unlockedCharacters.isEmpty)
        let early = record(store, stars: first.starsNeeded - 1, of: 10)
        #expect(early.newCharacters.isEmpty)
        let reached = record(store, stars: 1, of: 10, seed: 1)
        #expect(reached.newCharacters == [first])
        // A big haul can unlock several at once, and each is announced only once.
        let big = record(store, stars: second.starsNeeded - first.starsNeeded + 20, of: 40, seed: 2)
        #expect(big.newCharacters.first == second && big.newCharacters.count >= 2)
        #expect(record(store, stars: 0, of: 4, seed: 3).newCharacters.isEmpty)
    }

    @Test func theCharacterListIsOrderedAndSized() {
        #expect((10...25).contains(PlayerCharacter.all.count))
        #expect(Set(PlayerCharacter.all.map(\.id)).count == PlayerCharacter.all.count)
        #expect(PlayerCharacter.all.map(\.starsNeeded) == PlayerCharacter.all.map(\.starsNeeded).sorted())
        #expect(PlayerCharacter.all.first!.starsNeeded <= 10, "the first character comes quickly")
        #expect(PlayerCharacter.all.last!.starsNeeded <= 750, "and the last is within reach")
        #expect(PlayerCharacter.next(after: 0) == PlayerCharacter.all.first)
        #expect(PlayerCharacter.next(after: PlayerCharacter.all.last!.starsNeeded) == nil)
    }

    @Test func aCharacterReplacesTheWorldsCharacterOnceChosen() {
        let defaults = isolatedDefaults()
        let session = MazeGameSession(difficulty: .easy, seed: 21, defaults: defaults)
        let character = PlayerCharacter.all[0]
        #expect(session.playerEmoji == session.theme.playerEmoji)

        session.collection.select(character)
        #expect(session.collection.selectedCharacter == nil, "a locked character cannot be chosen")
        _ = record(session.collection, stars: character.starsNeeded, of: 10)
        session.collection.select(character)
        #expect(session.playerEmoji == character.emoji)

        // It is remembered, and going back to the default works.
        #expect(MazeGameSession(difficulty: .easy, seed: 1, defaults: defaults).playerEmoji == character.emoji)
        session.collection.select(nil)
        #expect(session.playerEmoji == session.theme.playerEmoji)
    }

    @Test func resettingForgetsStarsAndTheChosenCharacter() {
        let store = CollectionStore(defaults: isolatedDefaults())
        _ = record(store, stars: 30, of: 30)
        store.select(PlayerCharacter.all[0])
        store.reset()
        #expect(store.totalStars == 0 && store.selectedCharacter == nil)
    }

    @Test func oldSavedProgressStillLoadsAndKeepsItsStars() throws {
        let defaults = isolatedDefaults()
        let store = CollectionStore(defaults: defaults)
        _ = record(store, stars: 3, of: 4)
        // Saved before stars were counted separately, and with the old "gold" flag on stickers.
        var json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(store.progress)) as? [String: Any])
        json["lifetimeStars"] = nil
        json["friendID"] = nil
        var stickers = try #require(json["stickers"] as? [String: [String: Any]])
        for key in stickers.keys { stickers[key]?["gold"] = true }
        json["stickers"] = stickers
        defaults.set(try JSONSerialization.data(withJSONObject: json), forKey: CollectionStore.key)
        let reloaded = CollectionStore(defaults: defaults)
        #expect(reloaded.totalStars == 3)
        #expect(reloaded.ownedStickerCount == 1)
    }

    @Test func theBookFillsUpThenRepeatsAreCounted() {
        let store = CollectionStore(defaults: isolatedDefaults())
        for seed in 0..<8 as Range<UInt64> { #expect(record(store, seed: seed).isNew) }
        #expect(store.ownedCount(in: .space) == MazeTheme.space.stickers.count)
        let again = record(store, seed: 99)
        #expect(!again.isNew)
        #expect(store.entry(themeID: "space", index: again.stickerIndex)?.count == 2)
        #expect(store.ownedStickerCount == 8, "a repeat does not add a different sticker")
    }

    @Test func progressIsSavedAndLoadedAgain() {
        let defaults = isolatedDefaults()
        let first = CollectionStore(defaults: defaults)
        _ = record(first, theme: .farm, seconds: 41, stars: 3, of: 3)
        let second = CollectionStore(defaults: defaults)
        #expect(second.progress == first.progress)
        #expect(second.statistics.totalFinished == 1)
        // Damaged data is ignored rather than crashing.
        defaults.set(Data([1, 2, 3]), forKey: CollectionStore.key)
        #expect(CollectionStore(defaults: defaults).progress == Progress())
    }

    @Test func oldRecordsAreTrimmedPastTheLimit() {
        let store = CollectionStore(defaults: isolatedDefaults())
        for index in 0..<(CollectionStore.maximumRecords + 25) { _ = record(store, seconds: Double(index)) }
        #expect(store.progress.finishes.count == CollectionStore.maximumRecords)
        #expect(store.progress.finishes.first?.seconds == 25, "the oldest were dropped")
    }

    @Test func aPersonalBestIsOnlyAnnouncedAfterSomeHistory() {
        let store = CollectionStore(defaults: isolatedDefaults())
        for index in 0..<CollectionStore.bestNeedsHistory {
            #expect(!record(store, difficulty: .easy, seconds: 100 - Double(index)).isPersonalBest, "too early to call it a best")
        }
        #expect(record(store, difficulty: .easy, seconds: 10).isPersonalBest)
        #expect(!record(store, difficulty: .easy, seconds: 50).isPersonalBest)
        // Another level has its own history.
        #expect(!record(store, difficulty: .hard, seconds: 1).isPersonalBest)
    }

    @Test func newestStickersComeNewestFirst() {
        let store = CollectionStore(defaults: isolatedDefaults())
        let base = Date(timeIntervalSince1970: 10_000)
        let first = record(store, theme: .space, at: base)
        let second = record(store, theme: .ocean, at: base.addingTimeInterval(60))
        let third = record(store, theme: .farm, at: base.addingTimeInterval(120))
        let newest = store.newestStickers(2)
        #expect(newest.map(\.sticker) == [third.sticker, second.sticker])
        #expect(store.newestStickers(10).last?.sticker == first.sticker)
    }

    @Test func statisticsAddUp() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let day = 86_400.0
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        func finish(_ offsetDays: Double, _ difficulty: MazeDifficulty, _ seconds: Double, stars: Int, of total: Int) -> FinishRecord {
            FinishRecord(date: start.addingTimeInterval(offsetDays * day), difficulty: difficulty, themeID: "space",
                         rows: 6, columns: 6, seconds: seconds, starsCollected: stars, starsTotal: total, stickerIndex: 0)
        }
        let stats = Statistics(finishes: [
            finish(0, .easy, 40, stars: 4, of: 4),
            finish(0, .easy, 20, stars: 2, of: 4),
            finish(1, .hard, 120, stars: 8, of: 8),
            finish(2, .easy, 30, stars: 0, of: 4),
        ], calendar: calendar)
        #expect(stats.totalFinished == 4)
        #expect(stats.totalStars == 14)
        #expect(stats.perfectMazes == 2)
        #expect(stats.daysPlayed == 3)
        #expect(stats.currentStreak(today: start.addingTimeInterval(2 * day)) == 3)
        #expect(stats.currentStreak(today: start.addingTimeInterval(3 * day)) == 3, "yesterday still counts")
        #expect(stats.currentStreak(today: start.addingTimeInterval(5 * day)) == 0, "a gap breaks the streak")
        let easy = stats.difficulty(.easy)
        #expect(easy == DifficultyStatistics(count: 3, average: 30, fastest: 20))
        #expect(stats.difficulty(.beginner) == nil)
        #expect(stats.recent(2).map(\.seconds) == [30, 120])
        #expect(Statistics.format(65) == "1:05")
        #expect(Statistics.format(7) == "0:07")
        #expect(Statistics.format(-3) == "0:00")
        #expect(Statistics(finishes: []).currentStreak() == 0)
    }

    // MARK: - Stars in the session

    /// Walks the session's path to `cell` along the maze's own route, the way a finger would.
    private func walk(_ session: MazeGameSession, to cell: GridPoint) {
        guard let route = MazeSolver.solve(session.maze, from: session.path.end, to: cell) else { return }
        for (from, to) in zip(route, route.dropFirst()) {
            session.drag(from: center(row: from.row, column: from.column), to: center(row: to.row, column: to.column))
        }
    }

    @Test func eachMazeHasItsStarsAndWalkingOverOneCollectsIt() throws {
        let spy = SoundSpy()
        let session = MazeGameSession(difficulty: .medium, seed: 12, sounds: spy, defaults: isolatedDefaults())
        #expect(session.stars.count == MazeDifficulty.medium.collectibleCount)
        #expect(session.collectedStars.isEmpty)
        let star = try #require(session.stars.sorted { ($0.row, $0.column) < ($1.row, $1.column) }.first)
        walk(session, to: star)
        // The route may have crossed the finish first; either way the star is in hand.
        #expect(session.collectedStars.contains(star))
        #expect(session.uncollectedStars.count == session.stars.count - session.collectedStars.count)
        #expect(spy.played.contains(.collect(1)))
    }

    @Test func collectedStarsStayCollectedWhenTheRouteIsRetraced() throws {
        let session = MazeGameSession(difficulty: .medium, seed: 12, defaults: isolatedDefaults())
        let star = try #require(session.stars.sorted { ($0.row, $0.column) < ($1.row, $1.column) }.first)
        walk(session, to: star)
        let collected = session.collectedStars
        walk(session, to: session.maze.start)
        #expect(session.collectedStars == collected)
    }

    @Test func starsResetWithANewMazeOrARestart() throws {
        let session = MazeGameSession(difficulty: .medium, seed: 12, defaults: isolatedDefaults())
        let star = try #require(session.stars.first)
        walk(session, to: star)
        #expect(!session.collectedStars.isEmpty)
        session.restart()
        #expect(session.collectedStars.isEmpty)
        #expect(session.stars.count == MazeDifficulty.medium.collectibleCount)
        let before = session.stars
        session.newMaze(seed: 5)
        #expect(session.collectedStars.isEmpty)
        #expect(session.stars != before)
    }

    @Test func aFullRunCollectsEveryStarAndAddsThemUp() throws {
        // Find a maze where every star can be picked up before the finish is crossed.
        for seed in 0..<300 as Range<UInt64> {
            let session = MazeGameSession(difficulty: .easy, seed: seed, defaults: isolatedDefaults())
            for star in session.stars.sorted(by: { ($0.row, $0.column) < ($1.row, $1.column) }) where !session.isComplete {
                walk(session, to: star)
            }
            guard !session.isComplete, session.uncollectedStars.isEmpty else { continue }
            walk(session, to: session.maze.finish)
            #expect(session.isComplete)
            let reward = try #require(session.lastReward)
            #expect(reward.starsCollected == reward.starsTotal)
            #expect(session.collection.totalStars == reward.starsTotal)
            return
        }
        Issue.record("no seed allowed a full run")
    }

    @Test func finishingWithoutAllStarsEarnsAPlainStickerAndIsRecorded() throws {
        let session = MazeGameSession(difficulty: .easy, seed: 21, defaults: isolatedDefaults())
        let route = try #require(MazeSolver.solve(session.maze, from: session.maze.start))
        for (from, to) in zip(route, route.dropFirst()) {
            session.drag(from: center(row: from.row, column: from.column), to: center(row: to.row, column: to.column))
        }
        #expect(session.isComplete)
        let reward = try #require(session.lastReward)
        #expect(reward.isNew)
        #expect(reward.themeID == session.theme.id)
        #expect(reward.starsTotal == MazeDifficulty.easy.collectibleCount)
        #expect(session.collection.statistics.totalFinished == 1)
        #expect(session.collection.ownedStickerCount == 1)
        // The reward goes away with the next maze.
        session.newMaze(seed: 3)
        #expect(session.lastReward == nil)
    }

    @Test func theClockMeasuresActiveTimeIntoTheRecord() throws {
        var now = Date(timeIntervalSince1970: 50_000)
        let session = MazeGameSession(difficulty: .easy, seed: 21, defaults: isolatedDefaults(), clock: { now })
        let route = try #require(MazeSolver.solve(session.maze, from: session.maze.start))
        for (index, pair) in zip(route, route.dropFirst()).enumerated() {
            if index > 0 { now = now.addingTimeInterval(2) }
            session.drag(from: center(row: pair.0.row, column: pair.0.column), to: center(row: pair.1.row, column: pair.1.column))
        }
        let record = try #require(session.collection.progress.finishes.first)
        #expect(record.seconds == Double(2 * (route.count - 2)), "two seconds between each of the moves")
    }

    // MARK: - Difficulty memory

    @Test func theChosenDifficultyIsRememberedBetweenLaunches() {
        let defaults = isolatedDefaults()
        #expect(MazeGameSession(defaults: defaults).difficulty == .beginner, "a first launch starts on Beginner")
        let session = MazeGameSession(defaults: defaults)
        session.newMaze(difficulty: .hard)
        #expect(MazeGameSession(defaults: defaults).difficulty == .hard)
        // Changing it again replaces the memory.
        session.newMaze(difficulty: .easy)
        #expect(MazeGameSession(defaults: defaults).difficulty == .easy)
    }

    @Test func aNewMazeWithoutAChoiceKeepsTheRememberedDifficulty() {
        let defaults = isolatedDefaults()
        let session = MazeGameSession(defaults: defaults)
        session.newMaze(difficulty: .medium)
        session.newMaze()
        session.newMaze()
        #expect(session.difficulty == .medium)
        #expect(MazeGameSession(defaults: defaults).difficulty == .medium)
    }

    @Test func theMazeAtLaunchUsesTheRememberedDifficulty() {
        let defaults = isolatedDefaults()
        MazeGameSession(defaults: defaults).newMaze(difficulty: .hard)
        let launched = MazeGameSession(defaults: defaults)
        #expect(launched.maze.cellCount == MazeDifficulty.hard.cellCount)
        #expect(launched.stars.count == MazeDifficulty.hard.collectibleCount)
    }

    @Test func anExplicitDifficultyOverridesTheMemoryWithoutChangingIt() {
        let defaults = isolatedDefaults()
        MazeGameSession(defaults: defaults).newMaze(difficulty: .hard)
        let forced = MazeGameSession(difficulty: .easy, defaults: defaults)
        #expect(forced.difficulty == .easy)
        #expect(MazeGameSession(defaults: defaults).difficulty == .hard, "the saved choice is untouched")
    }

    @Test func aDamagedSavedDifficultyFallsBackToBeginner() {
        let defaults = isolatedDefaults()
        defaults.set("impossible", forKey: MazeGameSession.difficultyKey)
        #expect(MazeGameSession(defaults: defaults).difficulty == .beginner)
    }

    // MARK: - Circular mazes

    private let roomySpace = MazeSpace(size: CGSize(width: 800, height: 700))

    /// Walks a session along `route` the way a finger would, one cell centre to the next.
    private func dragAlong(_ route: [GridPoint], in session: MazeGameSession) {
        for (from, to) in zip(route, route.dropFirst()) {
            session.drag(from: session.maze.unitCenter(of: from), to: session.maze.unitCenter(of: to))
        }
    }

    @Test func ringSizesGrowOutwardAndMatchTheDifficultyTargets() {
        #expect(CircularShape.ringSizes(rings: 3) == [1, 6, 12, 24])
        for rings in 1...CircularShape.maximumRings {
            let sizes = CircularShape.ringSizes(rings: rings)
            #expect(sizes.count == rings + 1 && sizes[0] == 1)
            for (inner, outer) in zip(sizes.dropFirst(), sizes.dropFirst(2)) {
                #expect(outer == inner || outer == inner * 2, "a ring either keeps or doubles its cells")
            }
            #expect(CircularShape.totalCells(rings: rings) == sizes.reduce(0, +))
        }
        for difficulty in MazeDifficulty.allCases {
            let total = CircularShape.totalCells(rings: CircularShape.rings(forCellCount: difficulty.cellCount))
            #expect(abs(Double(total - difficulty.cellCount)) / Double(difficulty.cellCount) <= 0.25, "\(difficulty): \(total) cells")
        }
    }

    @Test func circularGeometryIsConsistent() {
        for rings in 1...CircularShape.maximumRings {
            let geometry = MazeGeometry(ringSizes: CircularShape.ringSizes(rings: rings))
            for index in 0..<geometry.cellCount {
                let point = geometry.point(at: index)
                #expect(geometry.index(of: point) == index)
                #expect(geometry.contains(point))
                #expect(geometry.cell(containing: geometry.unitCenter(of: point)) == point, "\(point) at \(rings) rings")
                #expect(geometry.distance(from: geometry.unitCenter(of: point), to: point) < 0.001)
                // Neighbours are mutual.
                for adjacent in geometry.adjacentCells(of: point) {
                    #expect(geometry.adjacentCells(of: adjacent.point).contains { $0.point == point })
                }
            }
            #expect(!geometry.contains(GridPoint(row: rings + 1, column: 0)))
            #expect(geometry.cell(containing: CGPoint(x: CircularShape.outerRadius(rings: rings) + 0.5, y: 0)) == nil)
        }
    }

    @Test func aPointInsideACellIsWithinItsCornerDistanceOfItsCentre() {
        let geometry = MazeGeometry(ringSizes: CircularShape.ringSizes(rings: 5))
        var rng = SeededGenerator(seed: 5)
        for _ in 0..<500 {
            let radius = Double(CircularShape.outerRadius(rings: 5)) * Double(rng.next(below: 1000)) / 1000
            let angle = 2 * Double.pi * Double(rng.next(below: 1000)) / 1000
            let spot = CGPoint(x: radius * cos(angle), y: radius * sin(angle))
            let home = try! #require(geometry.cell(containing: spot))
            #expect(geometry.distance(from: spot, to: home) <= 0.75, "inside a cell is within its corner distance")
        }
    }

    @Test func circularMazesArePerfectAndSolvable() throws {
        for rings in 1...CircularShape.maximumRings {
            for seed in 0..<25 as Range<UInt64> {
                let maze = MazeGenerator.generateCircular(rings: rings, seed: seed)
                #expect(maze.style == .circular)
                #expect(maze.start.row == rings && maze.finish == GridPoint(row: 0, column: 0))
                #expect(MazeSolver.reachableCells(in: maze, from: maze.start).count == maze.cellCount)
                var ends = 0
                for index in 0..<maze.cellCount {
                    let point = maze.point(at: index)
                    for neighbor in maze.openNeighbors(of: point) {
                        #expect(maze.openNeighbors(of: neighbor).contains(point), "passages are two-way")
                        ends += 1
                    }
                }
                #expect(ends == 2 * (maze.cellCount - 1), "a perfect maze is a spanning tree")
                let route = try #require(MazeSolver.solve(maze, from: maze.start))
                #expect(route.first == maze.start && route.last == maze.finish)
                for (from, to) in zip(route, route.dropFirst()) {
                    #expect(maze.openNeighbors(of: from).contains(to), "route crosses a wall")
                }
            }
        }
    }

    @Test func circularMazesAreRepeatableAndVary() {
        #expect(MazeGenerator.generateCircular(rings: 4, seed: 9) == MazeGenerator.generateCircular(rings: 4, seed: 9))
        #expect(MazeGenerator.generate(difficulty: .hard, seed: 3, rings: 6) == MazeGenerator.generate(difficulty: .hard, seed: 3, rings: 6))
        let first = MazeGenerator.generateCircular(rings: 4, seed: 1)
        #expect((2..<10 as Range<UInt64>).contains { MazeGenerator.generateCircular(rings: 4, seed: $0) != first })
    }

    @Test func circularMazesMeetTheirDifficultyCriteria() {
        for difficulty in MazeDifficulty.allCases {
            let rings = CircularShape.rings(forCellCount: difficulty.cellCount)
            let criteria = difficulty.criteria(rings: rings)
            var met = 0
            for seed in 0..<30 as Range<UInt64> {
                let maze = MazeGenerator.generate(difficulty: difficulty, seed: seed, rings: rings)
                #expect(MazeSolver.isSolvable(maze))
                if let metrics = MazeSolver.metrics(for: maze), criteria.isSatisfied(by: metrics) { met += 1 }
            }
            #expect(met >= 26, "\(difficulty) met criteria \(met)/30")
        }
        #expect(MazeDifficulty.hard.criteria(rings: 6).minimumSolutionLength > MazeDifficulty.beginner.criteria(rings: 6).minimumSolutionLength)
    }

    @Test func aWallBlocksMovementBetweenNeighbouringRingCells() {
        let maze = MazeGenerator.generateCircular(rings: 4, seed: 4)
        var checked = 0
        for index in 0..<maze.cellCount {
            let point = maze.point(at: index)
            for adjacent in maze.geometry.adjacentCells(of: point) where !maze.isLinked(point, adjacent.point) {
                var path = MazePath(start: point)
                #expect(path.move(to: adjacent.point, in: maze) == .ignored)
                #expect(path.cells == [point])
                checked += 1
            }
        }
        #expect(checked > 50)
    }

    @Test func theCircularRouteCurvesRoundTheRings() throws {
        let maze = MazeGenerator.generateCircular(rings: 4, seed: 2)
        let route = try #require(MazeSolver.solve(maze, from: maze.start))
        let line = maze.geometry.polyline(through: route)
        #expect(line.first == maze.unitCenter(of: route.first!) && line.last == maze.unitCenter(of: route.last!))
        #expect(line.count >= route.count)
        // Every point of the line stays inside the maze.
        let outer = Double(CircularShape.outerRadius(rings: 4))
        #expect(line.allSatisfy { Double(hypot($0.x, $0.y)) <= outer })
    }

    @Test func followingACircularSolutionReachesTheHub() throws {
        for rings in [2, 3, 5, 6] {
            for seed in 0..<20 as Range<UInt64> {
                let maze = MazeGenerator.generateCircular(rings: rings, seed: seed)
                var path = MazePath(start: maze.start)
                for cell in try #require(MazeSolver.solve(maze, from: maze.start)).dropFirst() {
                    #expect(path.move(to: cell, in: maze) == .appended)
                }
                #expect(path.end == maze.finish)
            }
        }
    }

    /// Moves a pointer along the maze's winning route the way a finger would: smoothly round the
    /// rings, in small steps, drifting off the line by up to `wobble` of a ring's thickness in
    /// each direction. Returns whether the session finished.
    private func wobblyFinger(_ session: MazeGameSession, wobble: Double, seed: UInt64) throws -> Bool {
        let route = try #require(MazeSolver.solve(session.maze, from: session.maze.start))
        let line = session.maze.geometry.polyline(through: route)
        var rng = SeededGenerator(seed: seed)
        let phase = Double(rng.next(below: 628)) / 100
        var travelled = 0.0
        var previous = line[0]
        var pointer = line[0]
        for point in line.dropFirst() {
            let length = hypot(point.x - previous.x, point.y - previous.y)
            let steps = max(1, Int((length / 0.15).rounded(.up)))
            for step in 1...steps {
                let t = CGFloat(step) / CGFloat(steps)
                travelled += length / Double(steps)
                let target = CGPoint(
                    x: previous.x + (point.x - previous.x) * t + wobble * sin(1.3 * travelled + phase),
                    y: previous.y + (point.y - previous.y) * t + wobble * sin(1.7 * travelled + phase)
                )
                session.drag(from: pointer, to: target)
                pointer = target
            }
            previous = point
        }
        return session.isComplete
    }

    @Test func aSteadyFingerAlwaysFinishesACircularMaze() throws {
        for difficulty in MazeDifficulty.allCases {
            for seed in 0..<25 as Range<UInt64> {
                let session = MazeGameSession(difficulty: difficulty, seed: seed, defaults: isolatedDefaults())
                session.newMaze(seed: circularSeed(from: seed, in: session))
                #expect(session.maze.style == .circular)
                #expect(try wobblyFinger(session, wobble: 0.0, seed: seed), "\(difficulty) seed \(seed)")
            }
        }
    }

    @Test func aWobblyFingerFinishesAlmostEveryCircularMaze() throws {
        var finished = 0, total = 0
        for difficulty in MazeDifficulty.allCases {
            for seed in 0..<30 as Range<UInt64> {
                let session = MazeGameSession(difficulty: difficulty, seed: seed, defaults: isolatedDefaults())
                session.newMaze(seed: circularSeed(from: seed + 100, in: session))
                total += 1
                if try wobblyFinger(session, wobble: 0.3, seed: seed) { finished += 1 }
            }
        }
        // A finger 30% of a ring's thickness off the line now and then wanders into a side
        // branch; it must never stall, and nearly every run still gets to the hub.
        #expect(Double(finished) / Double(total) >= 0.93, "\(finished) of \(total)")
    }

    /// A seed whose maze, in a roomy space, comes out circular.
    private func circularSeed(from start: UInt64, in session: MazeGameSession) -> UInt64 {
        session.updateSpace(roomySpace)
        for seed in start..<(start + 400) {
            session.newMaze(seed: seed)
            if session.maze.style == .circular { return seed }
        }
        return start
    }

    @Test func eachNonGridStyleIsAboutOneMazeInFiveInARoomySpace() {
        let session = MazeGameSession(difficulty: .medium, seed: 1, defaults: isolatedDefaults())
        session.updateSpace(roomySpace)
        var counts: [MazeStyle: Int] = [:]
        for seed in 0..<500 as Range<UInt64> {
            session.newMaze(seed: seed)
            counts[session.maze.style, default: 0] += 1
        }
        for style in [MazeStyle.circular, .hexagon, .triangle] {
            #expect((70...130).contains(counts[style, default: 0]), "\(style): \(counts)")
        }
        #expect((140...260).contains(counts[.grid, default: 0]), "\(counts)")
    }

    // MARK: - Hexagon and triangle mazes

    private let tiledStyles: [MazeStyle] = [.hexagon, .triangle]

    @Test func tiledCellsAreConsistentlyConnected() {
        for style in tiledStyles {
            let geometry = MazeGeometry(style: style, rows: 6, columns: 9)
            for index in 0..<geometry.cellCount {
                let cell = geometry.point(at: index)
                let corners = geometry.vertices(of: cell)
                #expect(corners.count == geometry.edgeCount)
                // The middle of a cell is inside it, and every point near the middle maps back to it.
                #expect(geometry.cell(containing: geometry.unitCenter(of: cell)) == cell, "\(style) \(cell)")
                for edge in 0..<geometry.edgeCount {
                    guard let other = geometry.neighbor(of: cell, edge: edge) else { continue }
                    // Neighbours are mutual, and share the corners of the edge between them.
                    let back = (0..<geometry.edgeCount).filter { geometry.neighbor(of: other, edge: $0) == cell }
                    #expect(back.count == 1, "\(style) \(cell) -> \(other)")
                    let a = geometry.edgeMidpoint(of: cell, edge: edge)
                    let b = geometry.edgeMidpoint(of: other, edge: back[0])
                    #expect(hypot(a.x - b.x, a.y - b.y) < 1e-9, "\(style) \(cell) -> \(other)")
                    #expect(geometry.straightSteps(from: cell, to: other) == 1)
                }
            }
        }
    }

    @Test func tiledPositionsMapToTheCellTheyAreInside() {
        for style in tiledStyles {
            let geometry = MazeGeometry(style: style, rows: 5, columns: 8)
            let size = geometry.unitSize
            var found = 0
            for step in 0..<4000 {
                let position = CGPoint(x: size.width * (Double(step % 80) + 0.5) / 80, y: size.height * (Double(step / 80) + 0.5) / 50)
                guard let cell = geometry.cell(containing: position) else { continue }
                found += 1
                // The nearest middle among all cells is this one (hexagons), or it is close.
                let own = geometry.distance(from: position, to: cell)
                #expect(own <= 1.05, "\(style) \(position)")
            }
            #expect(found > 3200, "\(style) covers most of its extent")
            #expect(geometry.cell(containing: CGPoint(x: -1, y: -1)) == nil)
            #expect(geometry.cell(containing: CGPoint(x: size.width + 1, y: size.height + 1)) == nil)
        }
    }

    @Test func tiledMazesArePerfectAndSolvable() throws {
        for style in tiledStyles {
            for seed in 0..<20 as Range<UInt64> {
                let maze = MazeGenerator.generateTiled(style: style, rows: 7, columns: style == .triangle ? 14 : 8, seed: seed)
                #expect(maze.style == style)
                // A perfect maze joins every cell with exactly cells - 1 passages.
                let links = (0..<maze.cellCount).reduce(0) { $0 + maze.openNeighbors(of: maze.point(at: $1)).count }
                #expect(links == 2 * (maze.cellCount - 1), "\(style) seed \(seed)")
                #expect(MazeSolver.reachableCells(in: maze, from: maze.start).count == maze.cellCount)
                #expect(try #require(MazeSolver.solve(maze, from: maze.start)).count > 3)
                // The gaps are in the outer wall.
                let startEdge = try #require(maze.startEdge), finishEdge = try #require(maze.finishEdge)
                #expect(maze.geometry.neighbor(of: maze.start, edge: startEdge) == nil)
                #expect(maze.geometry.neighbor(of: maze.finish, edge: finishEdge) == nil)
                #expect(maze.start != maze.finish)
            }
        }
    }

    @Test func tiledMazesAreRepeatableForASeed() {
        for style in tiledStyles {
            let a = MazeGenerator.generate(difficulty: .medium, seed: 17, style: style, rows: 8, columns: 12)
            let b = MazeGenerator.generate(difficulty: .medium, seed: 17, style: style, rows: 8, columns: 12)
            #expect(a == b)
        }
    }

    @Test func tiledMazesFitTheScreenAndPlayToTheEnd() throws {
        for style in tiledStyles {
            for difficulty in MazeDifficulty.allCases {
                let session = MazeGameSession(difficulty: difficulty, seed: 1, defaults: isolatedDefaults())
                session.updateSpace(roomySpace)
                var seed: UInt64 = 0
                session.newMaze(seed: seed)
                while session.maze.style != style, seed < 400 {
                    seed += 1
                    session.newMaze(seed: seed)
                }
                // The largest levels are too small for fingers here, and fall back to a grid.
                guard session.maze.style == style else { continue }
                #expect(session.stars.isSubset(of: StarPlacement.playableCells(in: session.maze)))
                let layout = MazeLayout(maze: session.maze, in: roomySpace.size)
                #expect(layout.mazeRect.minX >= 0 && layout.mazeRect.maxX <= roomySpace.size.width)
                #expect(layout.mazeRect.minY >= 0 && layout.mazeRect.maxY <= roomySpace.size.height)
                for star in session.stars.sorted(by: { ($0.row, $0.column) < ($1.row, $1.column) }) {
                    if let route = MazeSolver.solve(session.maze, from: session.path.end, to: star) { dragAlong(route, in: session) }
                }
                #expect(session.uncollectedStars.isEmpty && !session.isComplete, "\(style) \(difficulty)")
                let route = try #require(MazeSolver.solve(session.maze, from: session.path.end, to: session.maze.finish))
                dragAlong(route, in: session)
                #expect(session.isComplete, "\(style) \(difficulty)")
            }
        }
    }

    @Test func tiledStylesAreNotUsedWhereCellsWouldBeTooSmall() {
        for style in tiledStyles {
            #expect(!MazeFitter.supportsTiled(style: style, cellCount: 400, in: MazeSpace(size: CGSize(width: 300, height: 300))))
            #expect(MazeFitter.supportsTiled(style: style, cellCount: 16, in: MazeSpace(size: CGSize(width: 800, height: 700))))
            #expect(!MazeFitter.supportsTiled(style: style, cellCount: 36, in: MazeSpace(size: CGSize(width: 1200, height: 200))))
        }
    }

    @Test func aFingerThatWobblesStillGetsThroughATiledMaze() {
        for style in tiledStyles {
            var finished = 0, total = 0
            for seed in 0..<12 as Range<UInt64> {
                let maze = MazeGenerator.generate(difficulty: .medium, seed: seed, style: style, rows: 7, columns: style == .triangle ? 14 : 8)
                guard let route = MazeSolver.solve(maze, from: maze.start) else { continue }
                var path = MazePath(start: maze.start)
                var rng = SeededGenerator(seed: seed)
                total += 1
                let points = maze.geometry.polyline(through: route)
                for (a, b) in zip(points, points.dropFirst()) {
                    for step in 0...10 {
                        let t = CGFloat(step) / 10
                        let jitterX = CGFloat(rng.next(below: 100)) / 100 * 0.1 - 0.05
                        let jitterY = CGFloat(rng.next(below: 100)) / 100 * 0.1 - 0.05
                        let pointer = CGPoint(x: a.x + (b.x - a.x) * t + jitterX, y: a.y + (b.y - a.y) * t + jitterY)
                        path.follow(pointer, in: maze, allowRetrace: true, finish: maze.finish)
                    }
                }
                if path.end == maze.finish { finished += 1 }
            }
            #expect(Double(finished) / Double(max(total, 1)) >= 0.9, "\(style): \(finished) of \(total)")
        }
    }

    @Test func circularMazesAreNotUsedWhereTheyWouldBeCramped() {
        func circularCount(in size: CGSize, difficulty: MazeDifficulty = .hard) -> Int {
            let session = MazeGameSession(difficulty: difficulty, seed: 1, defaults: isolatedDefaults())
            session.updateSpace(MazeSpace(size: size))
            var count = 0
            for seed in 0..<80 as Range<UInt64> {
                session.newMaze(seed: seed)
                if session.maze.style == .circular { count += 1 }
            }
            return count
        }
        #expect(circularCount(in: CGSize(width: 800, height: 700)) > 0)
        #expect(circularCount(in: CGSize(width: 900, height: 300)) == 0, "too wide and short")
        #expect(circularCount(in: CGSize(width: 150, height: 150)) == 0, "too small for fingers")
        #expect(circularCount(in: CGSize(width: 420, height: 900)) == 0, "too tall and narrow")
    }

    @Test func aMazeKeepsItsStyleForItsSeed() {
        let session = MazeGameSession(difficulty: .medium, seed: 1, defaults: isolatedDefaults())
        session.updateSpace(roomySpace)
        for seed in 0..<40 as Range<UInt64> {
            session.newMaze(seed: seed)
            let style = session.maze.style
            session.newMaze(seed: seed)
            #expect(session.maze.style == style)
        }
    }

    @Test func circularMazesGetStarsThatCanAllBeCollected() throws {
        for difficulty in MazeDifficulty.allCases {
            for seed in 0..<15 as Range<UInt64> {
                let session = MazeGameSession(difficulty: difficulty, seed: seed, defaults: isolatedDefaults())
                session.newMaze(seed: circularSeed(from: seed * 31, in: session))
                #expect(session.maze.style == .circular)
                #expect(session.stars.count == difficulty.collectibleCount)
                #expect(session.stars.isSubset(of: StarPlacement.playableCells(in: session.maze)))
                for star in session.stars.sorted(by: { ($0.row, $0.column) < ($1.row, $1.column) }) {
                    if let route = MazeSolver.solve(session.maze, from: session.path.end, to: star) { dragAlong(route, in: session) }
                }
                #expect(!session.isComplete && session.uncollectedStars.isEmpty, "\(difficulty) seed \(seed)")
                if let route = MazeSolver.solve(session.maze, from: session.path.end, to: session.maze.finish) { dragAlong(route, in: session) }
                #expect(session.lastReward.map { $0.starsCollected == $0.starsTotal } == true)
            }
        }
    }

    @Test func arrowKeysMoveThroughACircularMaze() throws {
        let session = MazeGameSession(difficulty: .easy, seed: 1, defaults: isolatedDefaults())
        session.newMaze(seed: circularSeed(from: 0, in: session))
        let route = try #require(MazeSolver.solve(session.maze, from: session.maze.start))
        // For each step along the solution, press the arrow that points most nearly that way.
        for (from, to) in zip(route, route.dropFirst()) {
            let a = session.maze.unitCenter(of: from), b = session.maze.unitCenter(of: to)
            let direction: MazeDirection = abs(b.x - a.x) > abs(b.y - a.y) ? (b.x > a.x ? .right : .left) : (b.y > a.y ? .down : .up)
            session.step(direction)
        }
        // Arrow keys cannot always tell neighbours apart, but they must never break the path.
        #expect(session.path.cells.count >= 2)
        let cells = session.path.cells
        for (from, to) in zip(cells, cells.dropFirst()) {
            #expect(session.maze.openNeighbors(of: from).contains(to))
        }
    }

    @Test func gridMazesStillWorkTheSameWayThroughTheGeometry() {
        let maze = MazeGenerator.generate(rows: 5, columns: 7, seed: 3)
        #expect(maze.style == .grid)
        for index in 0..<maze.cellCount {
            let point = maze.point(at: index)
            let unit = maze.unitCenter(of: point)
            #expect(unit == CGPoint(x: Double(point.column) + 0.5, y: Double(point.row) + 0.5))
            #expect(maze.cell(containing: unit) == point)
            #expect(maze.distance(from: unit, to: point) == 0)
        }
        #expect(maze.cell(containing: CGPoint(x: -0.1, y: 1)) == nil)
        #expect(maze.cell(containing: CGPoint(x: 7, y: 1)) == nil)
        #expect(maze.straightSteps(from: GridPoint(row: 0, column: 0), to: GridPoint(row: 2, column: 3)) == 5)
    }

    // MARK: - Expert level

    @Test func theFiveLevelsStepUpInEveryWay() {
        let levels = MazeDifficulty.allCases
        #expect(levels.count == 5 && levels.last == .expert)
        #expect(levels.map(\.starCount) == [1, 2, 3, 4, 5])
        #expect(levels.map(\.cellCount) == levels.map(\.cellCount).sorted())
        #expect(Set(levels.map(\.cellCount)).count == 5)
        #expect(levels.map(\.collectibleCount) == levels.map(\.collectibleCount).sorted())
        #expect(levels.map(\.twistiness) == levels.map(\.twistiness).sorted())
        #expect(MazeDifficulty.expert.title == "Expert")
        #expect(Double(MazeDifficulty.expert.cellCount) >= 2.5 * Double(MazeDifficulty.hard.cellCount))
    }

    @Test func expertIsMuchHarderThanHardInBothStyles() throws {
        func average(_ difficulty: MazeDifficulty, circular: Bool) throws -> (route: Double, decisions: Double) {
            var route = 0.0, decisions = 0.0
            for seed in 0..<15 as Range<UInt64> {
                let maze = circular
                    ? MazeGenerator.generate(difficulty: difficulty, seed: seed, rings: CircularShape.rings(forCellCount: difficulty.cellCount))
                    : MazeGenerator.generate(difficulty: difficulty, seed: seed)
                let metrics = try #require(MazeSolver.metrics(for: maze))
                route += Double(metrics.solutionLength)
                decisions += Double(metrics.decisionPoints)
            }
            return (route / 15, decisions / 15)
        }
        for circular in [false, true] {
            let hard = try average(.hard, circular: circular)
            let expert = try average(.expert, circular: circular)
            #expect(expert.route >= 2.5 * hard.route, "circular \(circular): \(expert.route) vs \(hard.route)")
            #expect(expert.decisions >= 2 * hard.decisions, "circular \(circular): \(expert.decisions) vs \(hard.decisions)")
        }
    }

    @Test func expertMazesAreBigPerfectAndSolvableInBothStyles() {
        for seed in 0..<10 as Range<UInt64> {
            let grid = MazeGenerator.generate(difficulty: .expert, seed: seed)
            #expect(grid.cellCount == 400 && MazeSolver.isSolvable(grid))
            #expect(MazeSolver.reachableCells(in: grid, from: grid.start).count == 400)
            let rings = CircularShape.rings(forCellCount: MazeDifficulty.expert.cellCount)
            let circular = MazeGenerator.generate(difficulty: .expert, seed: seed, rings: rings)
            #expect(abs(circular.cellCount - 400) <= 100 && MazeSolver.isSolvable(circular))
            #expect(MazeSolver.reachableCells(in: circular, from: circular.start).count == circular.cellCount)
        }
    }

    @Test func expertIsRememberedAndPlayable() throws {
        let defaults = isolatedDefaults()
        let session = MazeGameSession(defaults: defaults)
        session.newMaze(difficulty: .expert)
        #expect(MazeGameSession(defaults: defaults).difficulty == .expert)
        #expect(session.stars.count == 10)
        session.updateSpace(MazeSpace(size: CGSize(width: 900, height: 700)))
        let route = try #require(MazeSolver.solve(session.maze, from: session.maze.start))
        for (from, to) in zip(route, route.dropFirst()) {
            session.drag(from: session.maze.unitCenter(of: from), to: session.maze.unitCenter(of: to))
        }
        #expect(session.isComplete)
        #expect(session.collection.statistics.difficulty(.expert)?.count == 1)
    }

    // MARK: - Readable text

    @Test func readableTextHasStrongContrastOnAnyColor() {
        #expect(Color.contrastRatio(.black, .white) > 20)
        for step in stride(from: 0.0, through: 1.0, by: 0.1) {
            for tint in [Color(red: step, green: 0.5, blue: 0.2), Color(red: 0.2, green: step, blue: 0.8), Color(white: step)] {
                #expect(Color.contrastRatio(tint, tint.readableText) >= 4.5, "step \(step)")
            }
        }
    }

    @Test func everyThemesButtonAndBadgeTextIsReadable() {
        let badgeColors = [Color(red: 0.2, green: 0.6, blue: 0.35), Color(red: 0.85, green: 0.62, blue: 0.0)]
        for theme in MazeTheme.all {
            #expect(Color.contrastRatio(theme.accent, theme.accent.readableText) >= 4.5, "\(theme.id) accent")
            // The headline sits on a card pinned to the theme's own light or dark look.
            #expect(Color.contrastRatio(theme.cardBackground, theme.headlineColor) >= 4.5, "\(theme.id) headline")
        }
        for color in badgeColors { #expect(Color.contrastRatio(color, color.readableText) >= 4.5) }
    }

    // MARK: - Stress

    @Test func generatingThousandsOfMazesIsSafe() {
        for seed in 0..<2000 as Range<UInt64> {
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
