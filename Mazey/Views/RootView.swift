//
//  RootView.swift
//  Mazey
//

import SwiftUI

/// Where the app can go from the home screen.
enum AppRoute: Hashable {
    case maze
    case stickerBook
    case friends
}

/// Owns the one game session and the navigation: the home screen, with the maze and the
/// sticker book and friends one tap away.
struct RootView: View {
    @State private var session = MazeGameSession(sounds: SoundEngine.shared)
    @State private var path: [AppRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            HomeView(
                session: session,
                onPlay: {
                    session.prepareToPlay()
                    path.append(.maze)
                },
                onStickers: { path.append(.stickerBook) },
                onFriends: { path.append(.friends) }
            )
            .navigationDestination(for: AppRoute.self) { route in
                switch route {
                case .maze: MazeGameView(session: session)
                case .stickerBook: StickerBookView(session: session)
                case .friends: FriendsView(session: session)
                }
            }
        }
    }
}
