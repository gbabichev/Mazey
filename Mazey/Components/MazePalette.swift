//
//  MazePalette.swift
//  Mazey
//

import SwiftUI

/// Bright, friendly colors. Fixed (not adaptive) because the maze sits on its own paper-like card.
nonisolated enum MazePalette {
    static let paper = Color(red: 1.00, green: 0.98, blue: 0.92)
    static let wall = Color(red: 0.36, green: 0.27, blue: 0.62)
    static let path = Color(red: 0.25, green: 0.70, blue: 0.95)
    static let player = Color(red: 0.98, green: 0.45, blue: 0.20)
    static let hint = Color(red: 1.00, green: 0.78, blue: 0.10)
    static let start = Color(red: 0.30, green: 0.78, blue: 0.40)
    static let finish = Color(red: 0.95, green: 0.35, blue: 0.45)
    static let backgroundTop = Color(red: 0.74, green: 0.90, blue: 1.00)
    static let backgroundBottom = Color(red: 0.88, green: 0.82, blue: 1.00)
}
