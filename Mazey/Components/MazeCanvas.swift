//
//  MazeCanvas.swift
//  Mazey
//

import SwiftUI

/// Draws a maze, the player's route and any hint. It only draws; touch handling
/// lives in the screen that owns it, using the same `MazeLayout`.
struct MazeCanvas: View {
    let maze: Maze
    let route: [GridPoint]
    let hint: [GridPoint]
    let hintLevel: MazeHintLevel?
    let theme: MazeTheme

    var body: some View {
        let maze = maze
        let route = route
        let hint = hint
        let hintLevel = hintLevel
        let theme = theme
        Canvas { context, size in
            let layout = MazeLayout(maze: maze, in: size)
            Self.drawFloor(&context, layout, theme)
            Self.drawEndpointTints(&context, maze, layout, theme)
            Self.drawScenery(&context, maze, route, layout, theme)
            Self.drawHint(&context, hint, hintLevel, layout, theme)
            Self.drawRoute(&context, route, layout, theme)
            Self.drawWalls(&context, maze, layout, theme)
            Self.drawEndpointEmoji(&context, maze, route, layout, theme)
            Self.drawLabels(&context, maze, layout, theme)
            if let end = route.last {
                Self.drawEmoji(&context, theme.playerEmoji, at: layout.center(of: end), size: layout.cellSize * 0.62)
            }
        }
        .accessibilityLabel("Maze")
    }

    // MARK: - Layers

    private nonisolated static func drawFloor(_ context: inout GraphicsContext, _ layout: MazeLayout, _ theme: MazeTheme) {
        // Flush with the outer edge of the border walls, whose corners are round with radius wallWidth / 2.
        let half = layout.wallWidth / 2
        let rect = layout.mazeRect.insetBy(dx: -half, dy: -half)
        context.fill(Path(roundedRect: rect, cornerRadius: half), with: .color(theme.paper))
    }

    private nonisolated static func drawEndpointTints(_ context: inout GraphicsContext, _ maze: Maze, _ layout: MazeLayout, _ theme: MazeTheme) {
        for (point, color) in [(maze.start, theme.startTint), (maze.finish, theme.finishTint)] {
            let rect = layout.rect(of: point).insetBy(dx: layout.wallWidth / 2, dy: layout.wallWidth / 2)
            context.fill(Path(roundedRect: rect, cornerRadius: layout.cellSize * 0.2), with: .color(color.opacity(0.35)))
        }
    }

    private nonisolated static func drawWalls(_ context: inout GraphicsContext, _ maze: Maze, _ layout: MazeLayout, _ theme: MazeTheme) {
        var walls = Path()
        for row in 0..<maze.rows {
            for column in 0..<maze.columns {
                let point = GridPoint(row: row, column: column)
                let cell = maze[point]
                let rect = layout.rect(of: point)
                // Each interior wall is shared by two cells, so draw only right/down walls.
                // Up/left walls are drawn only on the outer border.
                if cell.hasWall(.right), !maze.hasOpening(at: point, .right) {
                    walls.move(to: CGPoint(x: rect.maxX, y: rect.minY))
                    walls.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
                }
                if cell.hasWall(.down), !maze.hasOpening(at: point, .down) {
                    walls.move(to: CGPoint(x: rect.minX, y: rect.maxY))
                    walls.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
                }
                if column == 0, !maze.hasOpening(at: point, .left) {
                    walls.move(to: CGPoint(x: rect.minX, y: rect.minY))
                    walls.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
                }
                if row == 0, !maze.hasOpening(at: point, .up) {
                    walls.move(to: CGPoint(x: rect.minX, y: rect.minY))
                    walls.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
                }
            }
        }
        context.stroke(
            walls,
            with: .color(theme.wall),
            style: StrokeStyle(lineWidth: layout.wallWidth, lineCap: .round, lineJoin: .round)
        )
    }

    private nonisolated static func drawRoute(_ context: inout GraphicsContext, _ route: [GridPoint], _ layout: MazeLayout, _ theme: MazeTheme) {
        guard route.count > 1 else { return }
        context.stroke(
            smoothPath(through: route.map(layout.center(of:))),
            with: .color(theme.path),
            style: StrokeStyle(lineWidth: layout.cellSize * 0.36, lineCap: .round, lineJoin: .round)
        )
    }

    private nonisolated static func drawHint(
        _ context: inout GraphicsContext,
        _ hint: [GridPoint],
        _ level: MazeHintLevel?,
        _ layout: MazeLayout,
        _ theme: MazeTheme
    ) {
        guard hint.count > 1 else { return }
        let width = layout.cellSize * 0.2
        context.stroke(
            smoothPath(through: hint.map(layout.center(of:))),
            with: .color(theme.hint),
            style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round, dash: [width * 0.1, width * 1.8])
        )
        if level == .small, let next = hint.last {
            let radius = layout.cellSize * 0.22
            let center = layout.center(of: next)
            let circle = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
            context.fill(Path(ellipseIn: circle), with: .color(theme.hint))
        }
    }

    /// Start and finish emoji. The start one is hidden under the player until they move away.
    private nonisolated static func drawEndpointEmoji(
        _ context: inout GraphicsContext,
        _ maze: Maze,
        _ route: [GridPoint],
        _ layout: MazeLayout,
        _ theme: MazeTheme
    ) {
        if route.count > 1 {
            drawEmoji(&context, theme.startEmoji, at: layout.center(of: maze.start), size: layout.cellSize * 0.5)
        }
        drawEmoji(&context, theme.finishEmoji, at: layout.center(of: maze.finish), size: layout.cellSize * 0.55)
    }

    /// "START" and "FINISH" pills just outside the openings in the border. Pills on the
    /// left and right sides are turned to read along the wall, like a book spine.
    private nonisolated static func drawLabels(
        _ context: inout GraphicsContext,
        _ maze: Maze,
        _ layout: MazeLayout,
        _ theme: MazeTheme
    ) {
        let labels = [
            (maze.start, maze.startSide, "START", Color(red: 0.13, green: 0.62, blue: 0.32)),
            (maze.finish, maze.finishSide, "FINISH", Color(red: 0.88, green: 0.22, blue: 0.32)),
        ]
        // Always green for START and red for FINISH, whatever the theme, so the meaning never changes.
        for (point, side, title, tint) in labels {
            guard let side else { continue }
            let text = context.resolve(
                Text(verbatim: title)
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
            )
            let textSize = text.measure(in: CGSize(width: 200, height: 40))
            let pill = CGSize(width: textSize.width + 18, height: textSize.height + 6)
            let cell = layout.rect(of: point)
            // Center of the pill: outside the border, in line with the opening.
            let gap = layout.wallWidth / 2 + 3
            let center: CGPoint
            let angle: Double
            switch side {
            case .up: (center, angle) = (CGPoint(x: cell.midX, y: cell.minY - gap - pill.height / 2), 0)
            case .down: (center, angle) = (CGPoint(x: cell.midX, y: cell.maxY + gap + pill.height / 2), 0)
            case .left: (center, angle) = (CGPoint(x: cell.minX - gap - pill.height / 2, y: cell.midY), -.pi / 2)
            case .right: (center, angle) = (CGPoint(x: cell.maxX + gap + pill.height / 2, y: cell.midY), .pi / 2)
            }
            var layer = context
            layer.translateBy(x: center.x, y: center.y)
            layer.rotate(by: .radians(angle))
            let rect = CGRect(x: -pill.width / 2, y: -pill.height / 2, width: pill.width, height: pill.height)
            layer.fill(Path(roundedRect: rect, cornerRadius: pill.height / 2), with: .color(tint))
            layer.draw(text, at: .zero, anchor: .center)
        }
    }

    /// Share of cells (out of 100) that get a piece of scenery.
    private nonisolated static let sceneryChance = 28

    /// Themed scenery scattered over random cells, chosen from the maze seed so it stays put.
    /// Placement ignores the maze's structure, so the scenery never hints at the winning
    /// path or at dead ends. Cells the player has already walked through are left clear.
    private nonisolated static func drawScenery(
        _ context: inout GraphicsContext,
        _ maze: Maze,
        _ route: [GridPoint],
        _ layout: MazeLayout,
        _ theme: MazeTheme
    ) {
        guard !theme.decorations.isEmpty else { return }
        let visited = Set(route)
        for index in 0..<maze.cellCount {
            let point = maze.point(at: index)
            var rng = SeededGenerator(seed: maze.seed ^ UInt64(index + 1) &* 0x9E37_79B9)
            guard rng.next(below: 100) < sceneryChance,
                  point != maze.start, point != maze.finish, !visited.contains(point)
            else { continue }
            let emoji = theme.decorations[rng.next(below: theme.decorations.count)]
            drawEmoji(&context, emoji, at: layout.center(of: point), size: layout.cellSize * 0.42)
        }
    }

    private nonisolated static func drawEmoji(
        _ context: inout GraphicsContext,
        _ emoji: String,
        at center: CGPoint,
        size: CGFloat,
        opacity: Double = 1
    ) {
        var layer = context
        layer.opacity = opacity
        layer.draw(layer.resolve(Text(verbatim: emoji).font(.system(size: size))), at: center, anchor: .center)
    }

    /// A line through `points` with rounded corners: straight along each segment, curving at the cell centers.
    private nonisolated static func smoothPath(through points: [CGPoint]) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        guard points.count > 1 else { return path }
        for index in 1..<points.count - 1 {
            let mid = CGPoint(x: (points[index].x + points[index + 1].x) / 2, y: (points[index].y + points[index + 1].y) / 2)
            let before = CGPoint(x: (points[index - 1].x + points[index].x) / 2, y: (points[index - 1].y + points[index].y) / 2)
            path.addLine(to: before)
            path.addQuadCurve(to: mid, control: points[index])
        }
        path.addLine(to: points[points.count - 1])
        return path
    }
}
