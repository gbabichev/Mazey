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
    /// False while the demo is showing: it draws the moving character itself.
    var showsPlayer = true
    /// Where the player is between cells while a pointer is down, so it glides instead of snapping.
    var head: PathHead?
    /// Stars still waiting to be collected.
    var stars: Set<GridPoint> = []

    var body: some View {
        let maze = maze
        let route = route
        let hint = hint
        let hintLevel = hintLevel
        let theme = theme
        let showsPlayer = showsPlayer
        let head = head
        let stars = stars
        Canvas { context, size in
            let layout = MazeLayout(maze: maze, in: size)
            switch maze.style {
            case .circular:
                Self.drawCircularFloor(&context, maze, layout, theme)
                Self.drawCircularTints(&context, maze, layout, theme)
            case .hexagon, .triangle:
                Self.drawTiledFloor(&context, maze, layout, theme)
                Self.drawTiledTints(&context, maze, layout, theme)
            case .grid:
                Self.drawFloor(&context, layout, theme)
                Self.drawEndpointTints(&context, maze, layout, theme)
            }
            Self.drawStars(&context, stars, layout)
            Self.drawHint(&context, hint, hintLevel, layout, theme)
            Self.drawRoute(&context, route, head, layout, theme)
            switch maze.style {
            case .circular:
                Self.drawCircularWalls(&context, maze, layout, theme)
                Self.drawCircularEndpoints(&context, maze, route, layout, theme)
            case .hexagon, .triangle:
                Self.drawTiledWalls(&context, maze, layout, theme)
                Self.drawEndpointEmoji(&context, maze, route, layout, theme)
                Self.drawTiledLabels(&context, maze, layout)
            case .grid:
                Self.drawWalls(&context, maze, layout, theme)
                Self.drawEndpointEmoji(&context, maze, route, layout, theme)
                Self.drawLabels(&context, maze, layout, theme)
            }
            if showsPlayer, let end = route.last {
                let position = head.map { layout.screenPoint(forUnit: $0.point) } ?? layout.center(of: end)
                Self.drawEmoji(&context, theme.playerEmoji, at: position, size: layout.glyphSize * 0.62)
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

    private nonisolated static func drawRoute(
        _ context: inout GraphicsContext,
        _ route: [GridPoint],
        _ head: PathHead?,
        _ layout: MazeLayout,
        _ theme: MazeTheme
    ) {
        // The line runs to the character: out of the end cell, or back from it when undoing a step.
        var cells = route
        if head?.towardPrevious == true, cells.count >= 2 { cells.removeLast() }
        var points = layout.polyline(for: cells)
        if let head { points.append(layout.screenPoint(forUnit: head.point)) }
        guard points.count > 1 else { return }
        context.stroke(
            smoothPath(through: points),
            with: .color(theme.path),
            style: StrokeStyle(lineWidth: layout.glyphSize * 0.36, lineCap: .round, lineJoin: .round)
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
        let width = layout.glyphSize * 0.2
        context.stroke(
            smoothPath(through: layout.polyline(for: hint)),
            with: .color(theme.hint),
            style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round, dash: [width * 0.1, width * 1.8])
        )
        if level == .small, let next = hint.last {
            let radius = layout.glyphSize * 0.22
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
            drawEmoji(&context, theme.startEmoji, at: layout.center(of: maze.start), size: layout.glyphSize * 0.5)
        }
        drawEmoji(&context, theme.finishEmoji, at: layout.center(of: maze.finish), size: layout.glyphSize * 0.55)
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

    // MARK: - Hexagon and triangle mazes

    private nonisolated static func tiledOutline(_ maze: Maze, _ layout: MazeLayout, of point: GridPoint) -> [CGPoint] {
        maze.geometry.vertices(of: point).map(layout.screenPoint(forUnit:))
    }

    private nonisolated static func drawTiledFloor(_ context: inout GraphicsContext, _ maze: Maze, _ layout: MazeLayout, _ theme: MazeTheme) {
        var floor = Path()
        for index in 0..<maze.cellCount {
            floor.addPath(polygon(tiledOutline(maze, layout, of: maze.point(at: index))))
        }
        context.fill(floor, with: .color(theme.paper))
        // Reaches out to the outer edge of the border walls and hides seams between cells.
        context.stroke(floor, with: .color(theme.paper), style: StrokeStyle(lineWidth: layout.wallWidth, lineJoin: .round))
    }

    private nonisolated static func drawTiledTints(_ context: inout GraphicsContext, _ maze: Maze, _ layout: MazeLayout, _ theme: MazeTheme) {
        for (point, color) in [(maze.start, theme.startTint), (maze.finish, theme.finishTint)] {
            context.fill(polygon(tiledOutline(maze, layout, of: point)), with: .color(color.opacity(0.35)))
        }
    }

    private nonisolated static func drawTiledWalls(_ context: inout GraphicsContext, _ maze: Maze, _ layout: MazeLayout, _ theme: MazeTheme) {
        let geometry = maze.geometry
        var walls = Path()
        for index in 0..<maze.cellCount {
            let point = maze.point(at: index)
            let corners = tiledOutline(maze, layout, of: point)
            for edge in 0..<geometry.edgeCount {
                if let other = geometry.neighbor(of: point, edge: edge) {
                    // Each inner wall is shared by two cells, so only one of them draws it.
                    guard maze.index(of: other) > index, !maze.isLinked(point, other) else { continue }
                } else if maze.hasOpening(at: point, edge: edge) {
                    continue
                }
                walls.move(to: corners[edge])
                walls.addLine(to: corners[(edge + 1) % corners.count])
            }
        }
        context.stroke(
            walls,
            with: .color(theme.wall),
            style: StrokeStyle(lineWidth: layout.wallWidth, lineCap: .round, lineJoin: .round)
        )
    }

    /// START and FINISH pills just outside the gaps in the outer wall.
    private nonisolated static func drawTiledLabels(_ context: inout GraphicsContext, _ maze: Maze, _ layout: MazeLayout) {
        let geometry = maze.geometry
        let labels = [
            (maze.start, maze.startEdge, "START", Color(red: 0.13, green: 0.62, blue: 0.32)),
            (maze.finish, maze.finishEdge, "FINISH", Color(red: 0.88, green: 0.22, blue: 0.32)),
        ]
        for (point, edge, title, color) in labels {
            guard let edge else { continue }
            let label = pill(&context, title, color: color, fontSize: 15)
            let middle = layout.screenPoint(forUnit: geometry.edgeMidpoint(of: point, edge: edge))
            let center = layout.center(of: point)
            let length = max(1, hypot(middle.x - center.x, middle.y - center.y))
            let direction = CGPoint(x: (middle.x - center.x) / length, y: (middle.y - center.y) / length)
            // A gap facing mostly sideways gets a pill turned to read along the wall, so it
            // needs little room beside the maze.
            let sideways = abs(direction.x) > abs(direction.y)
            let (width, height) = sideways ? (label.size.height, label.size.width) : (label.size.width, label.size.height)
            let extent = abs(direction.x) * width / 2 + abs(direction.y) * height / 2 + layout.wallWidth / 2 + 3
            var layer = context
            layer.translateBy(x: middle.x + direction.x * extent, y: middle.y + direction.y * extent)
            if sideways { layer.rotate(by: .radians(direction.x > 0 ? .pi / 2 : -.pi / 2)) }
            draw(label, at: .zero, in: &layer)
        }
    }

    // MARK: - Circular mazes

    /// Where a circular maze's cell boundaries are, as points along an arc about the centre.
    private nonisolated static func arc(about center: CGPoint, radius: CGFloat, from start: Double, to end: Double) -> [CGPoint] {
        let steps = max(2, Int((abs(end - start) / 0.06).rounded(.up)))
        return (0...steps).map { step in
            let angle = start + (end - start) * Double(step) / Double(steps)
            return CGPoint(x: center.x + radius * CGFloat(cos(angle)), y: center.y + radius * CGFloat(sin(angle)))
        }
    }

    private nonisolated static func polygon(_ points: [CGPoint]) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        for point in points.dropFirst() { path.addLine(to: point) }
        path.closeSubpath()
        return path
    }

    private nonisolated static func drawCircularFloor(_ context: inout GraphicsContext, _ maze: Maze, _ layout: MazeLayout, _ theme: MazeTheme) {
        let radius = layout.mazeRect.width / 2 + layout.wallWidth / 2
        let rect = CGRect(x: layout.origin.x - radius, y: layout.origin.y - radius, width: radius * 2, height: radius * 2)
        context.fill(Path(ellipseIn: rect), with: .color(theme.paper))
    }

    /// The start cell's wedge and the hub, tinted like the start and finish squares of a grid.
    private nonisolated static func drawCircularTints(_ context: inout GraphicsContext, _ maze: Maze, _ layout: MazeLayout, _ theme: MazeTheme) {
        let geometry = maze.geometry
        let inset = layout.wallWidth / 2
        let hub = CGFloat(CircularShape.hubRadius) * layout.cellSize - inset
        let hubRect = CGRect(x: layout.origin.x - hub, y: layout.origin.y - hub, width: hub * 2, height: hub * 2)
        context.fill(Path(ellipseIn: hubRect), with: .color(theme.finishTint.opacity(0.35)))

        let ring = maze.start.row
        let span = geometry.sectorSpan(ring: ring)
        let first = geometry.centerAngle(of: maze.start) - span / 2
        let outer = CGFloat(geometry.outerRadius(ring: ring)) * layout.cellSize - inset
        let inner = CGFloat(geometry.innerRadius(ring: ring)) * layout.cellSize + inset
        // Pull the sides in by the same inset, measured at each radius.
        let outerPad = Double(inset / outer), innerPad = Double(inset / inner)
        let wedge = arc(about: layout.origin, radius: outer, from: first + outerPad, to: first + span - outerPad)
            + arc(about: layout.origin, radius: inner, from: first + span - innerPad, to: first + innerPad)
        context.fill(polygon(wedge), with: .color(theme.startTint.opacity(0.35)))
    }

    private nonisolated static func drawCircularWalls(_ context: inout GraphicsContext, _ maze: Maze, _ layout: MazeLayout, _ theme: MazeTheme) {
        let geometry = maze.geometry
        let center = layout.origin
        let lastRing = geometry.ringSizes.count - 1
        var walls = Path()
        func add(_ points: [CGPoint]) {
            guard let first = points.first else { return }
            walls.move(to: first)
            for point in points.dropFirst() { walls.addLine(to: point) }
        }
        for ring in 1...lastRing {
            let size = geometry.ringSizes[ring]
            let span = geometry.sectorSpan(ring: ring)
            let inner = CGFloat(geometry.innerRadius(ring: ring)) * layout.cellSize
            let outer = CGFloat(geometry.outerRadius(ring: ring)) * layout.cellSize
            let ratio = size / geometry.ringSizes[ring - 1]
            for sector in 0..<size {
                let cell = GridPoint(row: ring, column: sector)
                let from = -Double.pi / 2 + Double(sector) * span
                let to = from + span
                // The wall on the hub side, unless this cell opens inward.
                if !maze.isLinked(cell, GridPoint(row: ring - 1, column: sector / ratio)) {
                    add(arc(about: center, radius: inner, from: from, to: to))
                }
                // The wall on the clockwise side, unless this cell opens to its neighbour.
                if !maze.isLinked(cell, GridPoint(row: ring, column: (sector + 1) % size)) {
                    add([
                        CGPoint(x: center.x + inner * CGFloat(cos(to)), y: center.y + inner * CGFloat(sin(to))),
                        CGPoint(x: center.x + outer * CGFloat(cos(to)), y: center.y + outer * CGFloat(sin(to))),
                    ])
                }
                // The outer wall, with a gap where the maze starts.
                if ring == lastRing, cell != maze.start {
                    add(arc(about: center, radius: outer, from: from, to: to))
                }
            }
        }
        context.stroke(
            walls,
            with: .color(theme.wall),
            style: StrokeStyle(lineWidth: layout.wallWidth, lineCap: .round, lineJoin: .round)
        )
    }

    /// The finish in the hub with its FINISH label, the start emoji, and the START label
    /// outside the gap in the outer wall.
    private nonisolated static func drawCircularEndpoints(
        _ context: inout GraphicsContext,
        _ maze: Maze,
        _ route: [GridPoint],
        _ layout: MazeLayout,
        _ theme: MazeTheme
    ) {
        let geometry = maze.geometry
        let thickness = layout.cellSize
        if route.count > 1 {
            drawEmoji(&context, theme.startEmoji, at: layout.center(of: maze.start), size: thickness * 0.55)
        }
        drawEmoji(&context, theme.finishEmoji, at: CGPoint(x: layout.origin.x, y: layout.origin.y - thickness * 0.36), size: thickness * 0.95)

        let fontSize = min(15, max(9, thickness * 0.55))
        let finishPill = pill(&context, "FINISH", color: Color(red: 0.88, green: 0.22, blue: 0.32), fontSize: fontSize)
        draw(finishPill, at: CGPoint(x: layout.origin.x, y: layout.origin.y + thickness * 0.62), in: &context)

        // START sits just outside the opening, in line with it, pushed out by its own size.
        let angle = geometry.centerAngle(of: maze.start)
        let direction = CGPoint(x: CGFloat(cos(angle)), y: CGFloat(sin(angle)))
        let startPill = pill(&context, "START", color: Color(red: 0.13, green: 0.62, blue: 0.32), fontSize: 15)
        let outer = layout.mazeRect.width / 2 + layout.wallWidth / 2 + 4
        let extent = abs(direction.x) * startPill.size.width / 2 + abs(direction.y) * startPill.size.height / 2
        draw(
            startPill,
            at: CGPoint(x: layout.origin.x + direction.x * (outer + extent), y: layout.origin.y + direction.y * (outer + extent)),
            in: &context
        )
    }

    private nonisolated struct Pill {
        let text: GraphicsContext.ResolvedText
        let size: CGSize
        let color: Color
    }

    private nonisolated static func pill(_ context: inout GraphicsContext, _ title: String, color: Color, fontSize: CGFloat) -> Pill {
        let text = context.resolve(
            Text(verbatim: title).font(.system(size: fontSize, weight: .heavy, design: .rounded)).foregroundStyle(.white)
        )
        let measured = text.measure(in: CGSize(width: 200, height: 40))
        return Pill(text: text, size: CGSize(width: measured.width + 18, height: measured.height + 6), color: color)
    }

    private nonisolated static func draw(_ pill: Pill, at center: CGPoint, in context: inout GraphicsContext) {
        let rect = CGRect(x: center.x - pill.size.width / 2, y: center.y - pill.size.height / 2, width: pill.size.width, height: pill.size.height)
        context.fill(Path(roundedRect: rect, cornerRadius: pill.size.height / 2), with: .color(pill.color))
        context.draw(pill.text, at: center, anchor: .center)
    }

    /// Gold stars with a soft glow, drawn as shapes so they cannot be mistaken for the emoji scenery.
    private nonisolated static func drawStars(_ context: inout GraphicsContext, _ stars: Set<GridPoint>, _ layout: MazeLayout) {
        for point in stars {
            let center = layout.center(of: point)
            let outer = layout.glyphSize * 0.3
            let glow = CGRect(x: center.x - outer * 1.6, y: center.y - outer * 1.6, width: outer * 3.2, height: outer * 3.2)
            context.fill(
                Path(ellipseIn: glow),
                with: .radialGradient(
                    Gradient(colors: [Color(red: 1.0, green: 0.88, blue: 0.3).opacity(0.55), Color(red: 1.0, green: 0.88, blue: 0.3).opacity(0)]),
                    center: center, startRadius: outer * 0.4, endRadius: outer * 1.6
                )
            )
            let star = starPath(center: center, outer: outer, inner: outer * 0.46)
            context.fill(star, with: .color(Color(red: 1.0, green: 0.8, blue: 0.1)))
            context.stroke(
                star,
                with: .color(.white),
                style: StrokeStyle(lineWidth: max(1.5, outer * 0.14), lineJoin: .round)
            )
        }
    }

    /// A five-pointed star with one point straight up.
    nonisolated static func starPath(center: CGPoint, outer: CGFloat, inner: CGFloat) -> Path {
        var path = Path()
        for index in 0..<10 {
            let radius = index.isMultiple(of: 2) ? outer : inner
            let angle = -Double.pi / 2 + Double(index) * Double.pi / 5
            let point = CGPoint(x: center.x + radius * CGFloat(cos(angle)), y: center.y + radius * CGFloat(sin(angle)))
            if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
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
