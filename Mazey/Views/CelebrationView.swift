//
//  CelebrationView.swift
//  Mazey
//

import SwiftUI

/// The friendly "you did it" card shown when the finish is reached, with the sticker just earned.
struct CelebrationView: View {
    let theme: MazeTheme
    let reward: FinishReward?
    let onNext: () -> Void

    @State private var popped = false

    var body: some View {
        // Tall spaces stack everything; short ones (a phone on its side) put the sticker beside the words.
        ViewThatFits(in: .vertical) {
            stacked
            sideBySide
        }
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
            words
        }
    }

    private var sideBySide: some View {
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
            VStack(spacing: 10) { words }
        }
    }

    /// The headline, the short labels and the way on.
    @ViewBuilder
    private var words: some View {
        Text("You did it!")
            .font(.system(size: 34, weight: .heavy, design: .rounded))
            .foregroundStyle(theme.headlineColor)
        if let reward {
            badges(reward)
        }
        Button(action: onNext) {
            Label("Next Maze", systemImage: "arrow.right.circle.fill")
                .font(.title2.weight(.bold))
                .foregroundStyle(theme.accent.readableText)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .tint(theme.accent)
    }

    /// The new sticker, popping in. Gold stickers get a golden glow.
    private func stickerView(_ reward: FinishReward) -> some View {
        ZStack {
            if reward.isGold {
                Circle()
                    .fill(RadialGradient(colors: [Color(red: 1, green: 0.88, blue: 0.3).opacity(0.9), .clear], center: .center, startRadius: 5, endRadius: 70))
                    .frame(width: 140, height: 140)
            }
            Text(reward.sticker.emoji)
                .font(.system(size: 76))
                .shadow(color: reward.isGold ? Color(red: 1, green: 0.8, blue: 0.1) : .black.opacity(0.2), radius: reward.isGold ? 10 : 4)
        }
        .scaleEffect(popped ? 1 : 0.1)
        .rotationEffect(.degrees(popped ? 0 : -25))
        .accessibilityLabel(reward.isGold ? "Gold sticker: \(reward.sticker.name)" : "Sticker: \(reward.sticker.name)")
    }

    /// Short labels; the pictures do most of the talking.
    @ViewBuilder
    private func badges(_ reward: FinishReward) -> some View {
        HStack(spacing: 8) {
            if reward.isNew { badge("New sticker!", symbol: "sparkles", color: theme.accent) }
            else { badge("Got it again!", symbol: "arrow.2.circlepath", color: theme.accent) }
            if reward.isGold { badge("Gold!", symbol: "star.fill", color: Color(red: 0.85, green: 0.62, blue: 0.0)) }
        }
        if reward.isPersonalBest {
            badge("Faster than ever!", symbol: "hare.fill", color: Color(red: 0.2, green: 0.6, blue: 0.35))
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
