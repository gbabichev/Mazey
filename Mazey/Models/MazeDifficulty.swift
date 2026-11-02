//
//  MazeDifficulty.swift
//  Mazey
//

import Foundation

/// Measurements of a finished maze, used to accept or reject generated candidates.
nonisolated struct MazeMetrics: Equatable, Sendable {
    /// Number of cells on the shortest route from start to finish (both included).
    var solutionLength: Int
    /// Cells on the shortest route that offer a choice (three or more open sides).
    var decisionPoints: Int
    /// Times the shortest route changes direction.
    var turns: Int
}

/// Minimum requirements a generated maze must meet to be accepted.
nonisolated struct MazeCriteria: Equatable, Sendable {
    var minimumSolutionLength: Int
    var minimumDecisionPoints: Int

    func isSatisfied(by metrics: MazeMetrics) -> Bool {
        metrics.solutionLength >= minimumSolutionLength
            && metrics.decisionPoints >= minimumDecisionPoints
    }
}

nonisolated enum MazeDifficulty: String, CaseIterable, Identifiable, Sendable {
    case beginner, easy, medium, hard

    var id: String { rawValue }

    /// Roughly how many cells the grid has. The rows and columns are chosen to fit the
    /// screen, so the shape varies but the amount of maze stays about the same.
    var cellCount: Int {
        switch self {
        case .beginner: 16
        case .easy: 36
        case .medium: 81
        case .hard: 144
        }
    }

    /// The square grid used when there is no screen to fit (tests, previews).
    var defaultSize: Int { Int(Double(cellCount).squareRoot().rounded()) }

    /// How much the generator prefers turning over carving straight on, from 0 (long straight
    /// corridors) to 1 (turns whenever possible). Harder levels wind more.
    var twistiness: Double {
        switch self {
        case .beginner: 0.3
        case .easy: 0.45
        case .medium: 0.6
        case .hard: 0.75
        }
    }

    var title: String {
        switch self {
        case .beginner: "Beginner"
        case .easy: "Easy"
        case .medium: "Medium"
        case .hard: "Hard"
        }
    }

    /// Number of stars shown as a reading-free difficulty indicator.
    var starCount: Int {
        switch self {
        case .beginner: 1
        case .easy: 2
        case .medium: 3
        case .hard: 4
        }
    }

    /// What a generated maze must meet. Scaled by the grid's size and shape, not fixed numbers,
    /// so a long thin grid counts as the level it says.
    func criteria(rows: Int, columns: Int) -> MazeCriteria {
        let routeFactor: Double
        let decisionRate: Double
        switch self {
        case .beginner: (routeFactor, decisionRate) = (0.9, 0)
        case .easy: (routeFactor, decisionRate) = (1.0, 0.03)
        case .medium: (routeFactor, decisionRate) = (1.1, 0.035)
        case .hard: (routeFactor, decisionRate) = (1.25, 0.035)
        }
        return MazeCriteria(
            minimumSolutionLength: Int(Double(rows + columns) * routeFactor),
            minimumDecisionPoints: Int(Double(rows * columns) * decisionRate)
        )
    }
}
