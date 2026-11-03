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

    /// Where the stars are in this maze, and which of them have been picked up.
    private(set) var stars: Set<GridPoint> = []
    private(set) var collectedStars: Set<GridPoint> = []
    /// What the last finished maze earned, shown on the celebration card.
    private(set) var lastReward: FinishReward?

    /// The character that is dragged to the finish: the chosen friend, or the world's own.
    var playerEmoji: String { collection.selectedFriend?.emoji ?? theme.playerEmoji }
    /// The sticker book and the history of finished mazes.
    let collection: CollectionStore

    /// While a pointer is down, where the character is between cells (see `MazePath.head`).
    private(set) var head: PathHead?

    @ObservationIgnored private var timer = ActivityTimer()
    @ObservationIgnored private var hintFade: Task<Void, Never>?
    @ObservationIgnored private let clock: () -> Date

    /// Whether sound effects play. Remembered between launches.
    var isSoundOn: Bool {
        didSet {
            defaults.set(isSoundOn, forKey: Self.soundKey)
            if isSoundOn && !oldValue { sounds.play(.soundOn) }
        }
    }

    /// True while the finger demo is on screen. It shows on the very first launch and again
    /// as a nudge when a new player leaves a maze untouched for a while.
    private(set) var isDemoVisible: Bool
    /// How many mazes have been finished, remembered between launches.
    private(set) var completedMazes: Int

    static let soundKey = "soundEnabled"
    static let difficultyKey = "difficulty"
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
        difficulty: MazeDifficulty? = nil,
        seed: UInt64 = .random(in: .min ... .max),
        sounds: any SoundPlaying = SilentSounds(),
        defaults: UserDefaults = .standard,
        collection: CollectionStore? = nil,
        clock: @escaping () -> Date = Date.init
    ) {
        // An explicit difficulty wins; otherwise pick up where the player left off.
        let difficulty = difficulty
            ?? defaults.string(forKey: Self.difficultyKey).flatMap(MazeDifficulty.init(rawValue:))
            ?? .beginner
        let maze = MazeGenerator.generate(difficulty: difficulty, seed: seed)
        self.sounds = sounds
        self.defaults = defaults
        self.collection = collection ?? CollectionStore(defaults: defaults)
        self.clock = clock
        self.stars = StarPlacement.cells(in: maze, count: difficulty.collectibleCount)
        self.isSoundOn = defaults.object(forKey: Self.soundKey) as? Bool ?? true
        self.isDemoVisible = !defaults.bool(forKey: Self.demoSeenKey)
        self.completedMazes = defaults.integer(forKey: Self.completedKey)
        self.difficulty = difficulty
        self.theme = MazeTheme.theme(for: seed)
        self.seed = seed
        self.maze = maze
        self.path = MazePath(start: maze.start)
        sounds.startMelody(at: Melody.startPosition(for: seed))
    }

    /// Stars still waiting to be picked up.
    var uncollectedStars: Set<GridPoint> { stars.subtracting(collectedStars) }

    /// True once the player has drawn any of the route.
    var hasProgress: Bool { path.cells.count > 1 }

    /// Called when the player taps Play on the home screen: keep a maze in progress, but do not
    /// bring back one that was already finished.
    func prepareToPlay() {
        if isComplete { newMaze() }
    }

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
    }

    /// Brings the demo back for a player who has not started the maze. Called after the
    /// screen has sat idle, but only while the player is still new to the game.
    func nudgeIfIdle() {
        guard !isDemoVisible, !hasProgress, !isComplete, completedMazes < Self.nudgeUntilCompleted else { return }
        isDemoVisible = true
    }

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
        placeStars()
    }

    private func placeStars() {
        stars = StarPlacement.cells(in: maze, count: difficulty.collectibleCount)
        collectedStars = []
    }

    /// Out of every hundred mazes, how many are circular, hexagon and triangle ones; the rest
    /// are square grids. The style is picked from the seed so a given maze keeps its style. The
    /// other styles need a roomy space with cells big enough for fingers; otherwise it is a grid.
    static let circularShare = 20
    static let hexagonShare = 20
    static let triangleShare = 20

    /// The style a seed asks for, before checking that the space suits it.
    private func preferredStyle(seed: UInt64) -> MazeStyle {
        var rng = SeededGenerator(seed: seed ^ 0xC12C_1E5)
        let roll = rng.next(below: 100)
        if roll < Self.circularShare { return .circular }
        if roll < Self.circularShare + Self.hexagonShare { return .hexagon }
        if roll < Self.circularShare + Self.hexagonShare + Self.triangleShare { return .triangle }
        return .grid
    }

    /// A maze for the current difficulty, shaped to fit the screen when its space is known.
    private func makeMaze(seed: UInt64) -> Maze {
        guard let space else { return MazeGenerator.generate(difficulty: difficulty, seed: seed) }
        let style = preferredStyle(seed: seed)
        if style == .circular, MazeFitter.supportsCircular(cellCount: difficulty.cellCount, in: space) {
            let rings = CircularShape.rings(forCellCount: difficulty.cellCount)
            return MazeGenerator.generate(difficulty: difficulty, seed: seed, rings: rings)
        }
        if style.isTiled {
            let count = difficulty.cellCount(for: style)
            if MazeFitter.supportsTiled(style: style, cellCount: count, in: space) {
                let shape = MazeFitter.tiledShape(style: style, cellCount: count, in: space)
                return MazeGenerator.generate(difficulty: difficulty, seed: seed, style: style, rows: shape.rows, columns: shape.columns)
            }
        }
        let shape = MazeFitter.shape(cellCount: difficulty.cellCount, in: space)
        return MazeGenerator.generate(difficulty: difficulty, seed: seed, rows: shape.rows, columns: shape.columns)
    }

    /// Cells to highlight for the current hint, recalculated from where the player is now.
    var hintCells: [GridPoint] {
        guard let hintLevel, !isComplete else { return [] }
        return MazeSolver.hint(in: maze, from: path.end, level: hintLevel)
    }

    // MARK: - Starting over

    /// Wipes everything remembered (stickers, statistics, settings, difficulty and the
    /// first-run demo) and starts a fresh beginner maze, as on the very first launch.
    func resetEverything() {
        collection.reset()
        for key in [Self.soundKey, Self.difficultyKey, Self.demoSeenKey, Self.completedKey] {
            defaults.removeObject(forKey: key)
        }
        completedMazes = 0
        lastReward = nil
        isSoundOn = true
        newMaze(difficulty: .beginner)
        defaults.removeObject(forKey: Self.difficultyKey)
        isDemoVisible = true
    }

    func newMaze(difficulty: MazeDifficulty? = nil, seed: UInt64 = .random(in: .min ... .max)) {
        if let difficulty {
            self.difficulty = difficulty
            defaults.set(difficulty.rawValue, forKey: Self.difficultyKey)
        }
        self.seed = seed
        sounds.startMelody(at: Melody.startPosition(for: seed))
        maze = makeMaze(seed: seed)
        placeStars()
        theme = MazeTheme.theme(for: seed, avoiding: theme)
        resetRoute()
        isDemoVisible = false
        play(.newMaze(themeID: theme.id))
    }

    /// Start over on the same maze.
    func restart() {
        resetRoute()
        play(.restart)
    }

    private func resetRoute() {
        head = nil
        path.reset(to: maze.start)
        collectedStars = []
        timer.reset()
        lastReward = nil
        clearHint()
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
        if let hintLevel {
            play(.hint(hintLevel))
            scheduleHintFade()
        } else {
            hintFade?.cancel()
        }
    }

    /// How long a hint stays up. Each tap asks for more, but a hint that is left alone, or that
    /// the player moves on from, goes away by itself, so a small hint never has to be stepped
    /// through the bigger ones to get rid of it.
    static let hintDuration: Duration = .seconds(5)
    /// How long this session's hints stay; tests shorten it.
    @ObservationIgnored var hintLifetime: Duration = MazeGameSession.hintDuration

    private func scheduleHintFade() {
        hintFade?.cancel()
        hintFade = Task { [weak self] in
            try? await Task.sleep(for: self?.hintLifetime ?? Self.hintDuration)
            guard !Task.isCancelled else { return }
            self?.hintLevel = nil
        }
    }

    private func clearHint() {
        hintFade?.cancel()
        hintLevel = nil
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
        head = isComplete ? nil : path.head(for: current, in: maze)
    }

    func endDrag() {
        isDragLive = false
        head = nil
    }

    /// Keyboard movement: one step, or back one step if the key points at the previous cell.
    func step(_ direction: MazeDirection) {
        guard !isComplete else { return }
        head = nil
        dismissDemo()
        let before = path.cells.count
        if let target = keyTarget(for: direction) {
            apply(path.move(to: target, in: maze))
        }
        noteProgress(from: before)
        if path.end == maze.finish && !isComplete { finishMaze() }
        playPathSound(from: before)
    }

    /// The cell an arrow key should move to. In a grid that is the cell in that direction; in a
    /// circular maze it is the open neighbour (or the previous cell) lying most nearly that way.
    private func keyTarget(for direction: MazeDirection) -> GridPoint? {
        if maze.style == .grid { return path.end.moved(direction) }
        let wanted = CGPoint(x: CGFloat(direction.columnDelta), y: CGFloat(direction.rowDelta))
        let here = maze.unitCenter(of: path.end)
        let previous = path.cells.count >= 2 ? path.cells[path.cells.count - 2] : nil
        return maze.openNeighbors(of: path.end)
            .filter { !path.contains($0) || $0 == previous }
            .compactMap { cell -> (GridPoint, CGFloat)? in
                let there = maze.unitCenter(of: cell)
                let (dx, dy) = (there.x - here.x, there.y - here.y)
                let length = hypot(dx, dy)
                guard length > 0 else { return nil }
                let alignment = (dx * wanted.x + dy * wanted.y) / length
                return alignment > 0.4 ? (cell, alignment) : nil
            }
            .max { $0.1 < $1.1 }?.0
    }

    private func visit(_ pointer: CGPoint) {
        // Touching down near the end of the path lets the drag pick up where it left off.
        if path.isNearEnd(pointer, in: maze) { isDragLive = true }
        let before = path.cells.count
        let moved = path.follow(pointer, in: maze, allowRetrace: isDragLive, finish: maze.finish)
        guard moved else { return }
        isDragLive = true
        noteProgress(from: before)
        if path.end == maze.finish { finishMaze() }
        playPathSound(from: before)
    }

    /// Starts or advances the clock, and picks up any stars the path just reached.
    private func noteProgress(from previousLength: Int) {
        if path.cells.count != previousLength { clearHint() }
        timer.record(at: clock())
        guard path.cells.count > previousLength else { return }
        for cell in path.cells[previousLength...] where stars.contains(cell) && !collectedStars.contains(cell) {
            collectedStars.insert(cell)
            play(.collect(collectedStars.count))
        }
    }

    private func finishMaze() {
        isComplete = true
        hintLevel = nil
        isDragLive = false
        completedMazes += 1
        defaults.set(completedMazes, forKey: Self.completedKey)
        lastReward = collection.recordFinish(
            theme: theme,
            difficulty: difficulty,
            rows: maze.rows,
            columns: maze.columns,
            seconds: timer.total,
            starsCollected: collectedStars.count,
            starsTotal: stars.count,
            seed: seed,
            now: clock()
        )
    }

    /// A step sound when the path grew, a softer one when it shrank, and the fanfare and applause at the finish.
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
        case .retraced:
            isDragLive = true
        case .ignored:
            break
        }
    }
}
