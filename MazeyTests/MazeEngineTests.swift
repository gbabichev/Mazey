//
//  MazeEngineTests.swift
//  MazeyTests
//

import CoreGraphics
import Foundation
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
        let session = MazeGameSession(difficulty: .medium, seed: 33)
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
        let session = MazeGameSession(difficulty: .medium, seed: 33)
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
        let session = MazeGameSession(difficulty: .hard, seed: 1)
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
            let session = MazeGameSession(difficulty: .hard, seed: seed)
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
            let session = MazeGameSession(difficulty: .hard, seed: seed)
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
        let session = MazeGameSession(difficulty: .easy, seed: 5)
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
        .hint(.small), .hint(.medium), .hint(.full), .restart, .soundOn,
        .newMaze(themeID: "space"), .newMaze(themeID: "dinosaur"), .newMaze(themeID: "ocean"),
        .newMaze(themeID: "farm"), .newMaze(themeID: "unknown"),
    ]

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
        #expect(seconds(.step(0)) < 0.3)
        #expect(seconds(.retrace(0)) < 0.3)
        #expect(seconds(.finish) > 1.0 && seconds(.finish) < 2.5)
        for theme in MazeTheme.all {
            #expect(seconds(.newMaze(themeID: theme.id)) < 1.2, "\(theme.id)")
        }
        // A bigger hint is a longer sparkle.
        #expect(seconds(.hint(.small)) < seconds(.hint(.medium)))
        #expect(seconds(.hint(.medium)) < seconds(.hint(.full)))
    }

    @Test func stepPitchRisesAlongTheScale() {
        // Zero crossings per second track pitch for these near-sine notes.
        func crossings(_ effect: SoundEffect) -> Int {
            let samples = SoundSynth.samples(for: effect).prefix(Int(0.1 * SoundSynth.sampleRate))
            return zip(samples, samples.dropFirst()).filter { ($0 < 0) != ($1 < 0) }.count
        }
        let rates = (0..<SoundSynth.stepScale.count).map { crossings(.step($0)) }
        #expect(rates == rates.sorted())
        #expect(rates.first! < rates.last!)
        // The scale repeats, so a long route never runs out of notes.
        #expect(SoundSynth.samples(for: .step(3)) == SoundSynth.samples(for: .step(3 + SoundSynth.stepScale.count)))
    }

    @Test func themesHaveDifferentFlourishes() {
        let flourishes = MazeTheme.all.map { SoundSynth.samples(for: .newMaze(themeID: $0.id)) }
        for (index, flourish) in flourishes.enumerated() {
            for other in flourishes[(index + 1)...] { #expect(flourish != other) }
        }
    }

    @Test func drawingPlaysRisingStepsAndRetracingPlaysSofterOnes() throws {
        let spy = SoundSpy()
        let session = MazeGameSession(difficulty: .medium, seed: 21, sounds: spy, defaults: isolatedDefaults())
        let route = try #require(MazeSolver.solve(session.maze, from: session.maze.start))
        func at(_ index: Int) -> CGPoint { center(row: route[index].row, column: route[index].column) }
        session.drag(from: at(0), to: at(1))
        session.drag(from: at(1), to: at(2))
        #expect(spy.played == [.step(1), .step(2)])
        session.drag(from: at(2), to: at(1))
        #expect(spy.played.last == .retrace(1))
        #expect(spy.played.count == 3)
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
        #expect(spy.played.last == .finish)
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
