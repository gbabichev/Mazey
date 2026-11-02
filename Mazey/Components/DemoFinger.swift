//
//  DemoFinger.swift
//  Mazey
//

import SwiftUI

/// The first-run demo: a finger drags the character along the first few cells of the way to
/// the finish, leaving a trail, then fades and starts again. No words, just show.
/// It sits over the maze and never takes touches.
struct DemoFinger: View {
    /// Centers of the cells to move through, in the maze's drawing space.
    let points: [CGPoint]
    let cellSize: CGFloat
    let playerEmoji: String
    let trailColor: Color
    let ringColor: Color

    /// Seconds for one loop: finger appears, drags, holds, fades.
    private static let cycle = 3.8
    private static let appear = 0.5
    private static let move = 2.2
    private static let hold = 0.6

    var body: some View {
        let points = points
        let cellSize = cellSize
        let playerEmoji = playerEmoji
        let trailColor = trailColor
        let ringColor = ringColor
        TimelineView(.animation) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: Self.cycle)
            Canvas { context, _ in
                guard points.count >= 2 else { return }
                let frame = Self.frame(at: time)
                let position = Self.point(along: points, at: frame.progress)

                // Trail drawn so far.
                if frame.progress > 0 {
                    context.stroke(
                        Self.trail(along: points, upTo: frame.progress),
                        with: .color(trailColor.opacity(0.75 * frame.opacity)),
                        style: StrokeStyle(lineWidth: cellSize * 0.36, lineCap: .round, lineJoin: .round)
                    )
                }

                // A ring that pulses on the start cell before the drag begins.
                if time < Self.appear + 0.3 {
                    let pulse = 0.5 + 0.5 * sin(time * 9)
                    let radius = cellSize * (0.38 + 0.1 * pulse)
                    let ring = CGRect(x: points[0].x - radius, y: points[0].y - radius, width: radius * 2, height: radius * 2)
                    context.stroke(Path(ellipseIn: ring), with: .color(ringColor.opacity(frame.opacity)), lineWidth: max(3, cellSize * 0.06))
                }

                // The character rides with the finger.
                var layer = context
                layer.opacity = frame.opacity
                layer.draw(
                    layer.resolve(Text(verbatim: playerEmoji).font(.system(size: cellSize * 0.62))),
                    at: position,
                    anchor: .center
                )
                // The fingertip rests on the character; it dips in a little as it presses.
                let press = cellSize * 0.04 * frame.pressure
                layer.draw(
                    layer.resolve(Text(verbatim: "👆").font(.system(size: cellSize * 0.8 * frame.scale))),
                    at: CGPoint(x: position.x, y: position.y + cellSize * 0.1 + press),
                    anchor: .top
                )
            }
        }
        .accessibilityHidden(true)
    }

    // MARK: - Animation

    private struct Frame {
        var progress: Double   // how far along the route, 0...1
        var opacity: Double
        var scale: Double
        var pressure: Double
    }

    private static func frame(at time: Double) -> Frame {
        if time < appear {
            let t = time / appear
            return Frame(progress: 0, opacity: t, scale: 0.6 + 0.4 * t, pressure: 0)
        }
        if time < appear + move {
            let t = (time - appear) / move
            let eased = t * t * (3 - 2 * t)   // smoothstep: eases in and out
            return Frame(progress: eased, opacity: 1, scale: 1, pressure: 1)
        }
        if time < appear + move + hold {
            return Frame(progress: 1, opacity: 1, scale: 1, pressure: 0)
        }
        let t = (time - appear - move - hold) / (cycle - appear - move - hold)
        return Frame(progress: 1, opacity: 1 - t, scale: 1, pressure: 0)
    }

    private static func segmentLengths(_ points: [CGPoint]) -> [Double] {
        zip(points, points.dropFirst()).map { hypot($1.x - $0.x, $1.y - $0.y) }
    }

    /// The point `fraction` of the way along the polyline, by length.
    private static func point(along points: [CGPoint], at fraction: Double) -> CGPoint {
        let lengths = segmentLengths(points)
        var remaining = lengths.reduce(0, +) * min(max(fraction, 0), 1)
        for (index, length) in lengths.enumerated() {
            if remaining <= length || index == lengths.count - 1 {
                let t = length == 0 ? 0 : min(remaining / length, 1)
                return CGPoint(
                    x: points[index].x + (points[index + 1].x - points[index].x) * t,
                    y: points[index].y + (points[index + 1].y - points[index].y) * t
                )
            }
            remaining -= length
        }
        return points[0]
    }

    /// The polyline from the start up to `fraction` of its length.
    private static func trail(along points: [CGPoint], upTo fraction: Double) -> Path {
        let lengths = segmentLengths(points)
        var remaining = lengths.reduce(0, +) * min(max(fraction, 0), 1)
        var path = Path()
        path.move(to: points[0])
        for (index, length) in lengths.enumerated() {
            if remaining >= length {
                path.addLine(to: points[index + 1])
                remaining -= length
            } else {
                let t = length == 0 ? 0 : remaining / length
                path.addLine(to: CGPoint(
                    x: points[index].x + (points[index + 1].x - points[index].x) * t,
                    y: points[index].y + (points[index + 1].y - points[index].y) * t
                ))
                break
            }
        }
        return path
    }
}
