//
//  CelebrationView.swift
//  Mazey
//

import SwiftUI

/// The friendly "you did it" card shown when the finish is reached, with the sticker just earned.
struct CelebrationView: View {
    let theme: MazeTheme
    let reward: FinishReward?
    /// Plays as a friend this maze just unlocked.
    let onChooseFriend: (Friend) -> Void
    let onNext: () -> Void

    @State private var popped = false
    @State private var chosenFriend: Friend?

    var body: some View {
        // Tall spaces stack everything; short ones (a phone on its side) put the sticker beside the
        // words; and when even that is too tall, it scrolls rather than squeezing the text.
        ViewThatFits {
            stacked
            sideBySide(scrolls: false)
            sideBySide(scrolls: true)
        }
        .frame(maxWidth: 560)
        .padding(26)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28))
        .shadow(radius: 12)
        // The material follows the system's light or dark setting, so pin the whole card (the
        // material included, hence after `background`) to the theme's own look. Otherwise dark
        // text can land on a dark card, or the reverse.
        .environment(\.colorScheme, theme.isDark ? .dark : .light)
        .onAppear {
            withAnimation(.spring(duration: 0.7, bounce: 0.55).delay(0.15)) { popped = true }
        }
    }

    private var stacked: some View {
        VStack(spacing: 14) {
            if let reward {
                stickerView(reward)
                StarProgress(collected: reward.starsCollected, total: reward.starsTotal)
                    .font(.title3)
            }
            headline
            details
            nextButton
        }
    }

    /// The sticker on one side and the words on the other. When there is too little height even
    /// for that, the labels scroll but the Next Maze button stays put, so it is always reachable.
    private func sideBySide(scrolls: Bool) -> some View {
        HStack(spacing: 22) {
            if let reward {
                VStack(spacing: 8) {
                    stickerView(reward)
                        .scaleEffect(0.7)
                        .frame(width: 100, height: 100)
                    StarProgress(collected: reward.starsCollected, total: reward.starsTotal)
                        .font(.title3)
                }
            }
            VStack(spacing: 10) {
                if scrolls {
                    ScrollView {
                        VStack(spacing: 10) {
                            headline
                            details
                        }
                        .padding(.bottom, 10)
                    }
                    .scrollBounceBehavior(.basedOnSize)
                } else {
                    headline
                    details
                }
                nextButton
            }
        }
    }

    private var headline: some View {
        Text("You did it!")
            .font(.system(size: 34, weight: .heavy, design: .rounded))
            .foregroundStyle(theme.headlineColor)
    }

    /// The short labels: what was earned and how far the next friend is.
    @ViewBuilder
    private var details: some View {
        if let reward {
            badges(reward)
            ForEach(reward.newFriends) { friend in friendOffer(friend) }
            nextFriendHint(reward)
        }
    }

    private var nextButton: some View {
        Button(action: onNext) {
            Label("Next Maze", systemImage: "arrow.right.circle.fill")
                .font(.title2.weight(.bold))
                .foregroundStyle(theme.accent.readableText)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .tint(theme.accent)
    }

    /// The new sticker, popping in.
    private func stickerView(_ reward: FinishReward) -> some View {
        ZStack {
            Text(reward.sticker.emoji)
                .font(.system(size: 76))
                .shadow(color: .black.opacity(0.2), radius: 4)
        }
        .scaleEffect(popped ? 1 : 0.1)
        .rotationEffect(.degrees(popped ? 0 : -25))
        .accessibilityLabel("Sticker: \(reward.sticker.name)")
    }

    /// Short labels; the pictures do most of the talking.
    @ViewBuilder
    private func badges(_ reward: FinishReward) -> some View {
        HStack(spacing: 8) {
            if reward.isNew { badge("New in your sticker book!", symbol: "book.pages.fill", color: theme.accent) }
            else { badge("Got it again!", symbol: "arrow.2.circlepath", color: theme.accent) }
        }
        if reward.isPersonalBest {
            badge("Faster than ever!", symbol: "hare.fill", color: Color(red: 0.2, green: 0.6, blue: 0.35))
        }
    }

    /// A friend unlocked by this maze, with a button to start playing as them. The two always
    /// stack, so the row is never wider than the card (a wide row would push the whole card
    /// into the side-by-side layout, even on a portrait phone).
    private func friendOffer(_ friend: Friend) -> some View {
        VStack(spacing: 6) {
            Text("\(friend.emoji) New friend: \(friend.name)!")
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundStyle(theme.headlineColor)
                .multilineTextAlignment(.center)
            friendButton(friend)
        }
    }

    @ViewBuilder
    private func friendButton(_ friend: Friend) -> some View {
        if chosenFriend == friend {
            Label("Playing as \(friend.name)", systemImage: "checkmark.circle.fill")
                .font(.footnote.weight(.bold))
                .foregroundStyle(theme.headlineColor)
        } else {
            Button {
                chosenFriend = friend
                onChooseFriend(friend)
            } label: {
                Text("Play as \(friend.emoji)")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(theme.headlineColor)
            }
            .buttonStyle(.bordered)
            .tint(theme.accent)
        }
    }

    /// How far the next friend is, once there is no new one to show.
    @ViewBuilder
    private func nextFriendHint(_ reward: FinishReward) -> some View {
        if reward.newFriends.isEmpty, let next = Friend.next(after: reward.totalStars) {
            Label("\(next.starsNeeded - reward.totalStars) more for a new friend", systemImage: "star.fill")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(theme.isDark ? .white.opacity(0.85) : theme.ink.opacity(0.8))
        }
    }

    private func badge(_ text: String, symbol: String, color: Color) -> some View {
        Label(text, systemImage: symbol)
            .font(.footnote.weight(.bold))
            .foregroundStyle(color.readableText)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(color, in: Capsule())
    }
}
