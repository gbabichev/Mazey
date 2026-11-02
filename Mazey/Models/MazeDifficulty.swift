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

    /// Grid is `size` × `size`.
    var size: Int {
        switch self {
        case .beginner: 4
        case .easy: 6
        case .medium: 9
        case .hard: 12
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

    var criteria: MazeCriteria {
        switch self {
        case .beginner: MazeCriteria(minimumSolutionLength: 7, minimumDecisionPoints: 0)
        case .easy: MazeCriteria(minimumSolutionLength: 12, minimumDecisionPoints: 1)
        case .medium: MazeCriteria(minimumSolutionLength: 20, minimumDecisionPoints: 3)
        case .hard: MazeCriteria(minimumSolutionLength: 32, minimumDecisionPoints: 5)
        }
    }
}
