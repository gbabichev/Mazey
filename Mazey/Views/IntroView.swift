//
//  IntroView.swift
//  Mazey
//

import SwiftUI

/// A short, mostly pictures tour shown on the first launch (and from Settings later): how to
/// play, what the stars are for, and what the sticker book and characters are. Four pages, each
/// with one big picture and one short line, and it can be skipped at any time.
struct IntroView: View {
    let theme: MazeTheme
    let onFinish: () -> Void

    @State private var page = 0
    /// A phone on its side is too short for the picture above the words, so they sit side by side.
    @State private var isCompact = false

    private static let pageCount = 4
    private var isLast: Bool { page == Self.pageCount - 1 }
    private var pageText: Color { theme.isDark ? .white : theme.ink }

    var body: some View {
        GeometryReader { geometry in
            content
                .frame(width: geometry.size.width, height: geometry.size.height)
                .onChange(of: geometry.size.height, initial: true) { _, height in isCompact = height < 520 }
        }
    }

    private var content: some View {
        ZStack {
            LinearGradient(colors: [theme.backgroundTop, theme.backgroundBottom], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: isCompact ? 10 : 24) {
                HStack {
                    Spacer()
                    Button("Skip", action: onFinish)
                        .buttonStyle(.plain)
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(pageText.opacity(0.8))
                        .padding(8)
                        .contentShape(Rectangle())
                        .opacity(isLast ? 0 : 1)
                        .disabled(isLast)
                }

                Spacer(minLength: 0)
                pageContent
                    .id(page)
                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                            removal: .move(edge: .leading).combined(with: .opacity)))
                Spacer(minLength: 0)

                dots
                Button(action: advance) {
                    Label(isLast ? "Let's play!" : "Next", systemImage: isLast ? "play.fill" : "arrow.right")
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                        .foregroundStyle(theme.accent.readableText)
                        .padding(.horizontal, 30)
                        .padding(.vertical, 6)
                        .frame(maxWidth: 360)
                }
                .buttonStyle(.borderedProminent)
                .tint(theme.accent)
                .controlSize(.extraLarge)
            }
            .padding()
            .frame(maxWidth: 700)
        }
        .gesture(
            DragGesture(minimumDistance: 30).onEnded { value in
                if value.translation.width < -40 { advance() }
                else if value.translation.width > 40, page > 0 { go(to: page - 1) }
            }
        )
        .environment(\.colorScheme, theme.isDark ? .dark : .light)
    }

    private func advance() {
        if isLast { onFinish() } else { go(to: page + 1) }
    }

    private func go(to newPage: Int) {
        withAnimation(.spring(duration: 0.45)) { page = newPage }
    }

    private var dots: some View {
        HStack(spacing: 10) {
            ForEach(0..<Self.pageCount, id: \.self) { index in
                Circle()
                    .fill(pageText.opacity(index == page ? 0.9 : 0.25))
                    .frame(width: 10, height: 10)
            }
        }
        .accessibilityHidden(true)
    }

    // MARK: - Pages

    @ViewBuilder
    private var pageContent: some View {
        switch page {
        case 0:
            slide(title: "Drag to the finish", line: "Slide your finger along the path from the start to the end.") {
                DragPicture(theme: theme)
            }
        case 1:
            slide(title: "Collect stars", line: "Pick up the stars on your way. Stars unlock new characters.") {
                StarsPicture()
            }
        case 2:
            slide(title: "Get stickers", line: "Every maze you finish gives you a sticker for your sticker book.") {
                StickersPicture(theme: theme)
            }
        default:
            slide(title: "Meet new characters", line: "Collect enough stars to unlock new characters to play as.") {
                CharactersPicture(theme: theme)
            }
        }
    }

    private func slide<Picture: View>(title: String, line: String, @ViewBuilder picture: () -> Picture) -> some View {
        let words = VStack(spacing: isCompact ? 8 : 22) {
            Text(title)
                .font(.system(size: isCompact ? 30 : 36, weight: .heavy, design: .rounded))
                .foregroundStyle(pageText)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.7)
            Text(line)
                .font(.system(size: isCompact ? 19 : 21, weight: .medium, design: .rounded))
                .foregroundStyle(pageText.opacity(0.85))
                .multilineTextAlignment(.center)
        }
        return Group {
            if isCompact {
                HStack(spacing: 20) {
                    picture().scaleEffect(0.6).frame(width: 200, height: 120)
                    words.fixedSize(horizontal: false, vertical: true)
                }
            } else {
                VStack(spacing: 22) {
                    picture().frame(height: 190)
                    words
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Pictures

/// The theme's character sliding along a path to its goal.
private struct DragPicture: View {
    let theme: MazeTheme
    @State private var moved = false

    var body: some View {
        ZStack {
            Capsule()
                .fill(theme.path.opacity(0.55))
                .frame(width: 230, height: 14)
            HStack {
                Text(theme.startEmoji).font(.system(size: 54))
                Spacer()
                Text(theme.finishEmoji).font(.system(size: 64))
            }
            .frame(width: 330)
            Text(theme.playerEmoji)
                .font(.system(size: 64))
                .offset(x: moved ? 90 : -90)
            Image(systemName: "hand.point.up.left.fill")
                .font(.system(size: 40))
                .foregroundStyle(theme.isDark ? .white : theme.ink)
                .offset(x: moved ? 112 : -68, y: 44)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: false)) { moved = true }
        }
    }
}

/// Gold stars popping in one after another.
private struct StarsPicture: View {
    @State private var shown = 0

    var body: some View {
        HStack(spacing: 14) {
            ForEach(0..<3, id: \.self) { index in
                Image(systemName: "star.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(Color(red: 1.0, green: 0.78, blue: 0.1))
                    .shadow(color: Color(red: 1.0, green: 0.8, blue: 0.1).opacity(0.7), radius: 10)
                    .scaleEffect(index < shown ? 1 : 0.2)
                    .opacity(index < shown ? 1 : 0)
                    .offset(y: index == 1 ? -16 : 0)
            }
        }
        .task {
            for count in 1...3 {
                try? await Task.sleep(for: .milliseconds(350))
                withAnimation(.spring(duration: 0.5, bounce: 0.6)) { shown = count }
            }
        }
    }
}

/// A sticker book page with a new sticker popping in.
private struct StickersPicture: View {
    let theme: MazeTheme
    @State private var popped = false

    var body: some View {
        let stickers = theme.stickers.prefix(4).map(\.emoji)
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 22)
                .fill(theme.paper)
                .frame(width: 270, height: 170)
                .shadow(color: .black.opacity(0.12), radius: 6, y: 3)
                .overlay {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 6) {
                        ForEach(Array(stickers.enumerated()), id: \.offset) { index, emoji in
                            Text(emoji)
                                .font(.system(size: 48))
                                .scaleEffect(index == 3 ? (popped ? 1 : 0.05) : 1)
                                .rotationEffect(.degrees(index == 3 && !popped ? -30 : 0))
                        }
                    }
                    .padding(16)
                }
            Label("New!", systemImage: "sparkles")
                .font(.system(size: 17, weight: .heavy, design: .rounded))
                .foregroundStyle(theme.accent.readableText)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(theme.accent, in: Capsule())
                .offset(x: 16, y: -12)
                .scaleEffect(popped ? 1 : 0.1)
        }
        .task {
            try? await Task.sleep(for: .milliseconds(500))
            withAnimation(.spring(duration: 0.6, bounce: 0.6)) { popped = true }
        }
    }
}

/// A few characters, with the first one's star price.
private struct CharactersPicture: View {
    let theme: MazeTheme
    @State private var shown = false

    var body: some View {
        let characters = Array(PlayerCharacter.all.prefix(3))
        HStack(spacing: 14) {
            ForEach(Array(characters.enumerated()), id: \.element.id) { index, character in
                VStack(spacing: 6) {
                    Text(character.emoji).font(.system(size: 54))
                    Label("\(character.starsNeeded)", systemImage: "star.fill")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(theme.ink)
                }
                .frame(width: 92, height: 120)
                .background(theme.paper, in: RoundedRectangle(cornerRadius: 20))
                .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
                .scaleEffect(shown ? 1 : 0.3)
                .opacity(shown ? 1 : 0)
                .animation(.spring(duration: 0.55, bounce: 0.5).delay(Double(index) * 0.15), value: shown)
            }
        }
        .onAppear { shown = true }
    }
}
