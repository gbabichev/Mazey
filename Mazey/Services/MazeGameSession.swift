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

    /// The character that is dragged to the finish: the chosen character, or the world's own.
    var playerEmoji: String { collection.selectedCharacter?.emoji ?? theme.playerEmoji }
    /// The sticker book and the history of finished mazes, for the player who is playing.
    private(set) var collection: CollectionStore
    /// Who plays on this device. Each player has their own stickers, characters, statistics
    /// and difficulty.
    let roster: PlayerRoster

    /// While a pointer is down, where the character is between cells (see `MazePath.head`).
    private(set) var head: PathHead?

    @ObservationIgnored private var timer = ActivityTimer()
    @ObservationIgnored private var hintFade: Task<Void, Never>?
    @ObservationIgnored private let clock: () -> Date

    /// The master switch: whether any sound plays. Remembered between launches.
    var isSoundOn: Bool {
        didSet {
            defaults.set(isSoundOn, forKey: Self.soundKey)
            if isSoundOn && !oldValue { sounds.play(.soundOn) }
        }
    }

    /// Whether the song plays note by note while dragging. Only matters while sound is on.
    var isDragMusicOn: Bool {
        didSet { defaults.set(isDragMusicOn, forKey: Self.dragMusicKey) }
    }

    /// Whether the clapping plays when a maze is finished. Only matters while sound is on.
    var isApplauseOn: Bool {
        didSet { defaults.set(isApplauseOn, forKey: Self.applauseKey) }
    }

    /// The maze shapes that may be offered. A player can switch off shapes they do not like,
    /// but at least one always stays on.
    private(set) var enabledMazeStyles: Set<MazeStyle>

    func isMazeStyleOn(_ style: MazeStyle) -> Bool { enabledMazeStyles.contains(style) }

    /// Switches a maze shape on or off. The last shape left on cannot be switched off. A maze
    /// the player has not started yet changes shape straight away if its own shape was switched off.
    func setMazeStyle(_ style: MazeStyle, isOn: Bool) {
        var styles = enabledMazeStyles
        if isOn { styles.insert(style) } else { styles.remove(style) }
        guard !styles.isEmpty, styles != enabledMazeStyles else { return }
        enabledMazeStyles = styles
        defaults.set(MazeStyle.allCases.filter(styles.contains).map(\.rawValue), forKey: Self.mazeStylesKey)
        refitUnstartedMaze()
    }

    /// Whether the first-launch intro has been seen (or skipped). It shows once, then only from Settings.
    private(set) var hasSeenIntro: Bool

    /// Closes the intro and remembers that it was seen.
    func finishIntro() {
        hasSeenIntro = true
        defaults.set(true, forKey: Self.introSeenKey)
    }

    /// True while the finger demo is on screen. It shows on the very first launch and again
    /// as a nudge when a new player leaves a maze untouched for a while.
    private(set) var isDemoVisible: Bool
    /// How many mazes have been finished, remembered between launches.
    private(set) var completedMazes: Int

    static let soundKey = "soundEnabled"
    static let dragMusicKey = "dragMusicEnabled"
    static let applauseKey = "applauseEnabled"
    static let mazeStylesKey = "mazeStyles"
    static let introSeenKey = "introSeen"
    /// Saved for each player, under a key that includes their id (see `PlayerRoster.key`).
    static let difficultyKey = PlayerData.difficulty
    static let demoSeenKey = PlayerData.demoSeen
    static let completedKey = PlayerData.completed
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
        let roster = PlayerRoster(defaults: defaults)
        let player = roster.currentID
        // An explicit difficulty wins; otherwise pick up where the player left off.
        let difficulty = difficulty
            ?? defaults.string(forKey: PlayerRoster.key(Self.difficultyKey, for: player)).flatMap(MazeDifficulty.init(rawValue:))
            ?? .beginner
        let maze = MazeGenerator.generate(difficulty: difficulty, seed: seed)
        self.sounds = sounds
        self.defaults = defaults
        self.roster = roster
        self.collection = collection ?? CollectionStore(defaults: defaults, key: PlayerRoster.key(PlayerData.progress, for: player))
        self.clock = clock
        self.stars = StarPlacement.cells(in: maze, count: difficulty.collectibleCount)
        self.isSoundOn = defaults.object(forKey: Self.soundKey) as? Bool ?? true
        self.isDragMusicOn = defaults.object(forKey: Self.dragMusicKey) as? Bool ?? true
        self.isApplauseOn = defaults.object(forKey: Self.applauseKey) as? Bool ?? true
        let savedStyles = Set((defaults.stringArray(forKey: Self.mazeStylesKey) ?? []).compactMap(MazeStyle.init(rawValue:)))
        self.enabledMazeStyles = savedStyles.isEmpty ? Set(MazeStyle.allCases) : savedStyles
        self.isDemoVisible = !defaults.bool(forKey: PlayerRoster.key(Self.demoSeenKey, for: player))
        self.hasSeenIntro = defaults.bool(forKey: Self.introSeenKey)
        self.completedMazes = defaults.integer(forKey: PlayerRoster.key(Self.completedKey, for: player))
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
        defaults.set(true, forKey: playerKey(Self.demoSeenKey))
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
        refitUnstartedMaze()
    }

    /// Regenerates a maze the player has not started, from the same seed, for the current space
    /// and the maze shapes that are switched on.
    private func refitUnstartedMaze() {
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

    /// How likely each shape is: out of every hundred mazes (with every shape on), this many are
    /// circular, hexagon and triangle ones, and the rest are square grids. With some shapes
    /// switched off, the rest share the mazes in the same proportions. The shape is picked from
    /// the seed so a given maze keeps its shape. The other shapes need a roomy space with cells
    /// big enough for fingers; where they do not fit, the next shape that is on is tried, then a grid.
    static let circularShare = 20
    static let hexagonShare = 20
    static let triangleShare = 20
    static let gridShare = 100 - circularShare - hexagonShare - triangleShare

    private static func share(of style: MazeStyle) -> Int {
        switch style {
        case .circular: circularShare
        case .hexagon: hexagonShare
        case .triangle: triangleShare
        case .grid: gridShare
        }
    }

    /// The order shapes are rolled in, which also fixes which seeds get which shape.
    private static let styleOrder: [MazeStyle] = [.circular, .hexagon, .triangle, .grid]

    /// The shape a seed asks for, among those switched on, before checking that the space suits it.
    private func preferredStyle(seed: UInt64) -> MazeStyle {
        let styles = Self.styleOrder.filter(enabledMazeStyles.contains)
        var rng = SeededGenerator(seed: seed ^ 0xC12C_1E5)
        var roll = rng.next(below: styles.reduce(0) { $0 + Self.share(of: $1) })
        for style in styles {
            if roll < Self.share(of: style) { return style }
            roll -= Self.share(of: style)
        }
        return styles.last ?? .grid
    }

    /// A maze for the current difficulty, shaped to fit the screen when its space is known.
    private func makeMaze(seed: UInt64) -> Maze {
        guard let space else { return MazeGenerator.generate(difficulty: difficulty, seed: seed) }
        let preferred = preferredStyle(seed: seed)
        let candidates = [preferred] + Self.styleOrder.filter { $0 != preferred && enabledMazeStyles.contains($0) }
        for style in candidates {
            switch style {
            case .circular where MazeFitter.supportsCircular(cellCount: difficulty.cellCount, in: space):
                let rings = CircularShape.rings(forCellCount: difficulty.cellCount)
                return MazeGenerator.generate(difficulty: difficulty, seed: seed, rings: rings)
            case .hexagon, .triangle:
                let count = difficulty.cellCount(for: style)
                if MazeFitter.supportsTiled(style: style, cellCount: count, in: space) {
                    let shape = MazeFitter.tiledShape(style: style, cellCount: count, in: space)
                    return MazeGenerator.generate(difficulty: difficulty, seed: seed, style: style, rows: shape.rows, columns: shape.columns)
                }
            case .grid:
                return gridMaze(seed: seed, in: space)
            default:
                break
            }
        }
        // Nothing that is switched on fits this space (a phone on its side, say), so a grid it is.
        return gridMaze(seed: seed, in: space)
    }

    private func gridMaze(seed: UInt64, in space: MazeSpace) -> Maze {
        let shape = MazeFitter.shape(cellCount: difficulty.cellCount, in: space)
        return MazeGenerator.generate(difficulty: difficulty, seed: seed, rows: shape.rows, columns: shape.columns)
    }

    /// Cells to highlight for the current hint, recalculated from where the player is now.
    var hintCells: [GridPoint] {
        guard let hintLevel, !isComplete else { return [] }
        return MazeSolver.hint(in: maze, from: path.end, level: hintLevel)
    }

    // MARK: - Players

    /// The key one of the current player's settings is saved under.
    private func playerKey(_ base: String) -> String { PlayerRoster.key(base, for: roster.currentID) }

    /// How many stickers and stars a player has, for the list of players.
    func summary(of player: Player) -> (stickers: Int, stars: Int) {
        if player.id == roster.currentID { return (collection.ownedStickerCount, collection.totalStars) }
        let saved = CollectionStore.savedProgress(defaults: defaults, key: PlayerRoster.key(PlayerData.progress, for: player.id))
        return (saved.stickers.count, saved.lifetimeStars)
    }

    /// Switches to another player, with their stickers, characters and difficulty, on a fresh maze.
    func selectPlayer(_ id: UUID) {
        guard id != roster.currentID else { return }
        roster.select(id)
        loadCurrentPlayer()
    }

    /// Adds a player and switches to them. They start on Beginner and are shown how to play.
    func addPlayer(name: String, avatar: String) {
        guard roster.canAddPlayer else { return }
        roster.add(name: name, avatar: avatar)
        roster.select(roster.players[roster.players.count - 1].id)
        loadCurrentPlayer()
    }

    /// Removes a player and everything they earned (the last one cannot be removed).
    func removePlayer(_ id: UUID) {
        let wasPlaying = id == roster.currentID
        roster.remove(id)
        if wasPlaying { loadCurrentPlayer() }
    }

    /// Loads everything that belongs to the current player and starts a maze for them.
    private func loadCurrentPlayer() {
        collection = CollectionStore(defaults: defaults, key: playerKey(PlayerData.progress))
        difficulty = defaults.string(forKey: playerKey(Self.difficultyKey)).flatMap(MazeDifficulty.init(rawValue:)) ?? .beginner
        completedMazes = defaults.integer(forKey: playerKey(Self.completedKey))
        newMaze()
        // A new player is shown how to play; one who has been shown is not.
        isDemoVisible = !defaults.bool(forKey: playerKey(Self.demoSeenKey))
    }

    // MARK: - Starting over

    /// Wipes the current player's progress (stickers, stars, characters, statistics and
    /// difficulty) and starts them on a fresh beginner maze. Other players are untouched.
    func resetCurrentPlayer() {
        collection.reset()
        for base in [Self.difficultyKey, Self.demoSeenKey, Self.completedKey] {
            defaults.removeObject(forKey: playerKey(base))
        }
        completedMazes = 0
        difficulty = .beginner
        newMaze()
        isDemoVisible = true
    }

    /// Wipes everything remembered (every player and what they earned, plus the settings) and
    /// starts a fresh beginner maze for a new first player, as on the very first launch.
    func resetEverything() {
        roster.resetAll()
        collection = CollectionStore(defaults: defaults, key: playerKey(PlayerData.progress))
        for key in [Self.soundKey, Self.dragMusicKey, Self.applauseKey, Self.mazeStylesKey, Self.introSeenKey] {
            defaults.removeObject(forKey: key)
        }
        completedMazes = 0
        lastReward = nil
        isSoundOn = true
        isDragMusicOn = true
        isApplauseOn = true
        hasSeenIntro = false
        enabledMazeStyles = Set(MazeStyle.allCases)
        difficulty = .beginner
        newMaze()
        isDemoVisible = true
    }

    func newMaze(difficulty: MazeDifficulty? = nil, seed: UInt64 = .random(in: .min ... .max)) {
        if let difficulty {
            self.difficulty = difficulty
            defaults.set(difficulty.rawValue, forKey: playerKey(Self.difficultyKey))
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

    /// Plays an effect unless sound is off, or the switch for its kind of sound is.
    private func play(_ effect: SoundEffect) {
        guard isSoundOn else { return }
        switch effect {
        case .step, .retrace: guard isDragMusicOn else { return }
        case .applause: guard isApplauseOn else { return }
        default: break
        }
        sounds.play(effect)
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
    static let hintDuration: Duration = .seconds(10)
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
        defaults.set(completedMazes, forKey: playerKey(Self.completedKey))
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
            play(.applause)
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
