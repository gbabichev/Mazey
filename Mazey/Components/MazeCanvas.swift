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

    var body: some View {
        let maze = maze
        let route = route
        let hint = hint
        let hintLevel = hintLevel
        Canvas { context, size in
            let layout = MazeLayout(rows: maze.rows, columns: maze.columns, in: size)
            Self.drawFloor(&context, layout)
            Self.drawEndpointTints(&context, maze, layout)
            Self.drawHint(&context, hint, hintLevel, layout)
            Self.drawRoute(&context, route, layout)
            Self.drawWalls(&context, maze, layout)
            Self.drawEndpointIcons(&context, maze, layout)
            if let end = route.last {
                Self.drawPlayer(&context, at: end, layout)
            }
        }
        .accessibilityLabel("Maze")
    }

    // MARK: - Layers

    private nonisolated static func drawFloor(_ context: inout GraphicsContext, _ layout: MazeLayout) {
        let rect = layout.mazeRect.insetBy(dx: -layout.wallWidth, dy: -layout.wallWidth)
        context.fill(Path(roundedRect: rect, cornerRadius: layout.cellSize * 0.3), with: .color(MazePalette.paper))
    }

    private nonisolated static func drawEndpointTints(_ context: inout GraphicsContext, _ maze: Maze, _ layout: MazeLayout) {
        for (point, color) in [(maze.start, MazePalette.start), (maze.finish, MazePalette.finish)] {
            let rect = layout.rect(of: point).insetBy(dx: layout.wallWidth / 2, dy: layout.wallWidth / 2)
            context.fill(Path(roundedRect: rect, cornerRadius: layout.cellSize * 0.2), with: .color(color.opacity(0.35)))
        }
    }

    private nonisolated static func drawWalls(_ context: inout GraphicsContext, _ maze: Maze, _ layout: MazeLayout) {
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
            with: .color(MazePalette.wall),
            style: StrokeStyle(lineWidth: layout.wallWidth, lineCap: .round, lineJoin: .round)
        )
    }

    private nonisolated static func drawRoute(_ context: inout GraphicsContext, _ route: [GridPoint], _ layout: MazeLayout) {
        guard route.count > 1 else { return }
        context.stroke(
            smoothPath(through: route.map(layout.center(of:))),
            with: .color(MazePalette.path),
            style: StrokeStyle(lineWidth: layout.cellSize * 0.36, lineCap: .round, lineJoin: .round)
        )
    }

    private nonisolated static func drawHint(
        _ context: inout GraphicsContext,
        _ hint: [GridPoint],
        _ level: MazeHintLevel?,
        _ layout: MazeLayout
    ) {
        guard hint.count > 1 else { return }
        let width = layout.cellSize * 0.2
        context.stroke(
            smoothPath(through: hint.map(layout.center(of:))),
            with: .color(MazePalette.hint),
            style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round, dash: [width * 0.1, width * 1.8])
        )
        if level == .small, let next = hint.last {
            let radius = layout.cellSize * 0.22
            let center = layout.center(of: next)
            let circle = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
            context.fill(Path(ellipseIn: circle), with: .color(MazePalette.hint))
        }
    }

    private nonisolated static func drawEndpointIcons(_ context: inout GraphicsContext, _ maze: Maze, _ layout: MazeLayout) {
        let icons = [(maze.start, "play.fill", MazePalette.start), (maze.finish, "flag.checkered", MazePalette.finish)]
        for (point, symbol, color) in icons {
            var image = context.resolve(Image(systemName: symbol))
            image.shading = .color(color)
            let side = layout.cellSize * 0.42
            let center = layout.center(of: point)
            context.draw(image, in: CGRect(x: center.x - side / 2, y: center.y - side / 2, width: side, height: side))
        }
    }

    private nonisolated static func drawPlayer(_ context: inout GraphicsContext, at point: GridPoint, _ layout: MazeLayout) {
        let radius = layout.cellSize * 0.27
        let center = layout.center(of: point)
        let circle = Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
        context.fill(circle, with: .color(MazePalette.player))
        context.stroke(circle, with: .color(.white), lineWidth: max(2, radius * 0.25))
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
