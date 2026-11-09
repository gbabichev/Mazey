//
//  RootView.swift
//  Mazey
//

import SwiftUI

/// Where the app can go from the home screen.
enum AppRoute: Hashable {
    case maze
    case stickerBook
    case characters
}

/// Owns the one game session and the navigation: the home screen, with the maze and the
/// sticker book and characters one tap away.
struct RootView: View {
    @State private var session = MazeGameSession(sounds: SoundEngine.shared)
    @State private var path: [AppRoute] = []

    var body: some View {
        ZStack {
            navigation
            if !session.hasSeenIntro {
                IntroView(theme: session.theme) { withAnimation { session.finishIntro() } }
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
    }

    private var navigation: some View {
        NavigationStack(path: $path) {
            HomeView(
                session: session,
                onPlay: {
                    session.prepareToPlay()
                    path.append(.maze)
                },
                onStickers: { path.append(.stickerBook) },
                onCharacters: { path.append(.characters) }
            )
            .navigationDestination(for: AppRoute.self) { route in
                switch route {
                case .maze: MazeGameView(session: session)
                case .stickerBook: StickerBookView(session: session)
                case .characters: CharactersView(session: session)
                }
            }
        }
    }
}
