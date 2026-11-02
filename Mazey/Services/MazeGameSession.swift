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
            if !isSoundOn { sounds.stopSpeaking() }
        }
    }

    /// True while the finger demo is on screen. It shows on the very first launch and again
    /// as a nudge when a new player leaves a maze untouched for a while.
    private(set) var isDemoVisible: Bool
    /// How many mazes have been finished, remembered between launches.
    private(set) var completedMazes: Int

    /// Whether the app speaks (the goal with the demo, and the cheer at the finish).
    /// Remembered between launches, and only matters while sound is on.
    var isVoiceOn: Bool {
        didSet {
            defaults.set(isVoiceOn, forKey: Self.voiceKey)
            if !isVoiceOn { sounds.stopSpeaking() }
        }
    }

    static let soundKey = "soundEnabled"
    static let voiceKey = "voiceEnabled"
    static let demoSeenKey = "demoSeen"
    static let completedKey = "completedMazes"
    /// The idle nudge stops once a child has finished this many mazes: they know what to do.
    static let nudgeUntilCompleted = 3
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
        self.isVoiceOn = defaults.object(forKey: Self.voiceKey) as? Bool ?? true
        self.isDemoVisible = !defaults.bool(forKey: Self.demoSeenKey)
        self.completedMazes = defaults.integer(forKey: Self.completedKey)
        self.difficulty = difficulty
        self.theme = MazeTheme.theme(for: seed)
        self.seed = seed
        self.maze = maze
        self.path = MazePath(start: maze.start)
    }

    /// True once the player has drawn any of the route.
    var hasProgress: Bool { path.cells.count > 1 }

    // MARK: - Demo

    /// The first few cells of the way to the finish, which the demo finger follows.
    var demoRoute: [GridPoint] {
        guard isDemoVisible, let route = MazeSolver.solve(maze, from: path.end) else { return [] }
        return Array(route.prefix(4))
    }

    /// Hides the demo, and remembers that it has been seen. Any touch on the maze does this.
    func dismissDemo() {
        guard isDemoVisible else { return }
        isDemoVisible = false
        defaults.set(true, forKey: Self.demoSeenKey)
        sounds.stopSpeaking()
    }

    /// Brings the demo back for a player who has not started the maze. Called after the
    /// screen has sat idle, but only while the player is still new to the game.
    func nudgeIfIdle() {
        guard !isDemoVisible, !hasProgress, !isComplete, completedMazes < Self.nudgeUntilCompleted else { return }
        isDemoVisible = true
        speak(.goal(themeID: theme.id))
    }

    /// Called when the screen's usable space changes (first layout, rotation, folding the Duo,
    /// split view). A maze the player has not started yet is regenerated, from the same seed,
    /// in the shape that fits the new space. A maze in progress is left alone and re-fitted.
    func updateSpace(_ newSpace: MazeSpace) {
        guard newSpace != space else { return }
        let isFirstLayout = space == nil
        space = newSpace
        defer { if isFirstLayout && isDemoVisible { speak(.goal(themeID: theme.id)) } }
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
        isDemoVisible = false
        sounds.stopSpeaking()
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

    private func speak(_ phrase: SpokenPhrase) {
        if isSoundOn && isVoiceOn { sounds.speak(phrase) }
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
        dismissDemo()
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
        dismissDemo()
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
        if path.end == maze.finish { finishMaze() }
        playPathSound(from: before)
    }

    private func finishMaze() {
        isComplete = true
        hintLevel = nil
        isDragLive = false
        completedMazes += 1
        defaults.set(completedMazes, forKey: Self.completedKey)
    }

    /// A step sound when the path grew, a softer one when it shrank, and the fanfare at the finish.
    private func playPathSound(from previousLength: Int) {
        if isComplete {
            play(.finish)
            speak(.cheer(Int(seed % UInt64(SpokenPhrase.cheers.count))))
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
            if path.end == maze.finish { finishMaze() }
        case .retraced:
            isDragLive = true
        case .ignored:
            break
        }
    }
}
