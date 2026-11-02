//
//  MazeGameSession.swift
//  Mazey
//

import Foundation
import Observation

/// Everything the maze screen needs: the current maze, the player's route,
/// hints, and completion. Views call into this; the rules live in the engine types.
@MainActor
@Observable
final class MazeGameSession {
    private(set) var maze: Maze
    private(set) var path: MazePath
    private(set) var hintLevel: MazeHintLevel?
    private(set) var isComplete = false
    private(set) var difficulty: MazeDifficulty
    private(set) var theme: MazeTheme
    /// The space the maze can use, once the screen has reported it. Until then the maze is a
    /// plain square and nothing should be drawn.
    private(set) var space: MazeSpace?
    private var seed: UInt64

    /// Whether sound effects play. Remembered between launches.
    var isSoundOn: Bool {
        didSet {
            defaults.set(isSoundOn, forKey: Self.soundKey)
            if isSoundOn && !oldValue { sounds.play(.soundOn) }
        }
    }

    static let soundKey = "soundEnabled"
    @ObservationIgnored private let sounds: any SoundPlaying
    @ObservationIgnored private let defaults: UserDefaults

    /// True once the current drag has come near the end of the path, which lets
    /// the drag retrace. A drag that starts elsewhere is ignored until then.
    private var isDragLive = false

    init(
        difficulty: MazeDifficulty = .beginner,
        seed: UInt64 = .random(in: .min ... .max),
        sounds: any SoundPlaying = SilentSounds(),
        defaults: UserDefaults = .standard
    ) {
        let maze = MazeGenerator.generate(difficulty: difficulty, seed: seed)
        self.sounds = sounds
        self.defaults = defaults
        self.isSoundOn = defaults.object(forKey: Self.soundKey) as? Bool ?? true
        self.difficulty = difficulty
        self.theme = MazeTheme.theme(for: seed)
        self.seed = seed
        self.maze = maze
        self.path = MazePath(start: maze.start)
    }

    /// True once the player has drawn any of the route.
    var hasProgress: Bool { path.cells.count > 1 }

    /// Called when the screen's usable space changes (first layout, rotation, folding the Duo,
    /// split view). A maze the player has not started yet is regenerated, from the same seed,
    /// in the shape that fits the new space. A maze in progress is left alone and re-fitted.
    func updateSpace(_ newSpace: MazeSpace) {
        guard newSpace != space else { return }
        space = newSpace
        guard !hasProgress else { return }
        let fitted = makeMaze(seed: seed)
        guard fitted != maze else { return }
        maze = fitted
        path.reset(to: maze.start)
    }

    /// A maze for the current difficulty, shaped to fit the screen when its space is known.
    private func makeMaze(seed: UInt64) -> Maze {
        guard let space else { return MazeGenerator.generate(difficulty: difficulty, seed: seed) }
        let shape = MazeFitter.shape(cellCount: difficulty.cellCount, in: space)
        return MazeGenerator.generate(difficulty: difficulty, seed: seed, rows: shape.rows, columns: shape.columns)
    }

    /// Cells to highlight for the current hint, recalculated from where the player is now.
    var hintCells: [GridPoint] {
        guard let hintLevel, !isComplete else { return [] }
        return MazeSolver.hint(in: maze, from: path.end, level: hintLevel)
    }

    // MARK: - Starting over

    func newMaze(difficulty: MazeDifficulty? = nil, seed: UInt64 = .random(in: .min ... .max)) {
        if let difficulty { self.difficulty = difficulty }
        self.seed = seed
        maze = makeMaze(seed: seed)
        theme = MazeTheme.theme(for: seed, avoiding: theme)
        resetRoute()
        play(.newMaze(themeID: theme.id))
    }

    /// Start over on the same maze.
    func restart() {
        resetRoute()
        play(.restart)
    }

    private func resetRoute() {
        path.reset(to: maze.start)
        hintLevel = nil
        isComplete = false
        isDragLive = false
    }

    private func play(_ effect: SoundEffect) {
        if isSoundOn { sounds.play(effect) }
    }

    // MARK: - Hints

    /// Each tap shows more of the route; after the full route, the hint turns off.
    func requestHint() {
        guard !isComplete else { return }
        if let level = hintLevel {
            hintLevel = level.next
        } else {
            hintLevel = .small
        }
        if let hintLevel { play(.hint(hintLevel)) }
    }

    // MARK: - Input

    /// Handles a pointer moving between two positions, measured in cell units
    /// (x = column, y = row; 1.0 is one cell). The segment is sampled finely
    /// so a fast drag cannot skip over cells.
    func drag(from previous: CGPoint, to current: CGPoint) {
        guard !isComplete else { return }
        let distance = hypot(current.x - previous.x, current.y - previous.y)
        let steps = max(1, Int((distance / 0.2).rounded(.up)))
        for step in 1...steps {
            let t = CGFloat(step) / CGFloat(steps)
            visit(CGPoint(
                x: previous.x + (current.x - previous.x) * t,
                y: previous.y + (current.y - previous.y) * t
            ))
        }
    }

    func endDrag() {
        isDragLive = false
    }

    /// Keyboard movement: one step, or back one step if the key points at the previous cell.
    func step(_ direction: MazeDirection) {
        guard !isComplete else { return }
        let before = path.cells.count
        apply(path.move(to: path.end.moved(direction), in: maze))
        playPathSound(from: before)
    }

    private func visit(_ pointer: CGPoint) {
        // Touching down near the end of the path lets the drag pick up where it left off.
        if path.isNearEnd(pointer) { isDragLive = true }
        let before = path.cells.count
        let moved = path.follow(pointer, in: maze, allowRetrace: isDragLive, finish: maze.finish)
        guard moved else { return }
        isDragLive = true
        if path.end == maze.finish {
            isComplete = true
            hintLevel = nil
            isDragLive = false
        }
        playPathSound(from: before)
    }

    /// A step sound when the path grew, a softer one when it shrank, and the fanfare at the finish.
    private func playPathSound(from previousLength: Int) {
        if isComplete {
            play(.finish)
        } else if path.cells.count > previousLength {
            play(.step(path.cells.count - 1))
        } else if path.cells.count < previousLength {
            play(.retrace(path.cells.count - 1))
        }
    }

    private func apply(_ result: MazePath.MoveResult) {
        switch result {
        case .appended:
            isDragLive = true
            if path.end == maze.finish {
                isComplete = true
                hintLevel = nil
                isDragLive = false
            }
        case .retraced:
            isDragLive = true
        case .ignored:
            break
        }
    }
}
