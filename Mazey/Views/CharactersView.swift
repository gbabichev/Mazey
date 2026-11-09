//
//  CharactersView.swift
//  Mazey
//

import SwiftUI

/// Pick who plays: each world's own character, or a character unlocked by collecting stars.
/// Characters not unlocked yet are silhouettes that say how many more stars they need.
struct CharactersView: View {
    let session: MazeGameSession

    private var collection: CollectionStore { session.collection }
    private var theme: MazeTheme { session.theme }
    private var pageText: Color { theme.isDark ? .white : theme.ink }

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                header
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 14)], spacing: 14) {
                    defaultCell
                    ForEach(PlayerCharacter.all) { character in
                        CharacterCell(
                            character: character,
                            theme: theme,
                            stars: collection.totalStars,
                            isSelected: collection.selectedCharacter == character
                        ) { collection.select(character) }
                    }
                }
            }
            .padding()
        }
        .background {
            LinearGradient(colors: [theme.backgroundTop, theme.backgroundBottom], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        }
        .navigationTitle("Characters")
        .themedWindowAppearance(theme)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(theme.isDark ? .dark : .light, for: .navigationBar)
        #endif
    }

    /// The star count and how far away the next character is.
    private var header: some View {
        VStack(spacing: 8) {
            Label("\(collection.totalStars)", systemImage: "star.fill")
                .font(.system(size: 34, weight: .heavy, design: .rounded))
                .foregroundStyle(Color(red: 0.95, green: 0.7, blue: 0.0))
            if let next = PlayerCharacter.next(after: collection.totalStars) {
                ProgressView(value: Double(collection.totalStars - previousThreshold), total: Double(next.starsNeeded - previousThreshold))
                    .tint(Color(red: 0.95, green: 0.7, blue: 0.0))
                    .frame(maxWidth: 260)
                Text("\(next.starsNeeded - collection.totalStars) more stars for a new character")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(pageText.opacity(0.85))
            } else {
                Text("You found every character!")
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                    .foregroundStyle(pageText)
            }
            Text("Collect stars in mazes to unlock new characters.")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(pageText.opacity(0.7))
        }
    }

    /// Stars needed for the character before the next one, so the bar fills between two characters.
    private var previousThreshold: Int {
        PlayerCharacter.unlocked(by: collection.totalStars).last?.starsNeeded ?? 0
    }

    private var defaultCell: some View {
        Button { collection.select(nil) } label: {
            VStack(spacing: 4) {
                Text(theme.playerEmoji).font(.system(size: 44))
                    .minimumScaleFactor(0.4)
                    .lineLimit(1)
                    .layoutPriority(-1)
                Text("Default")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(theme.ink)
            }
            .padding(10)
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .background(theme.paper, in: RoundedRectangle(cornerRadius: 18))
            .overlay {
                if collection.selectedCharacter == nil {
                    RoundedRectangle(cornerRadius: 18).strokeBorder(theme.accent, lineWidth: 4)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Default character for each world")
        .accessibilityAddTraits(collection.selectedCharacter == nil ? .isSelected : [])
    }
}

/// One character: tappable once unlocked, a silhouette with its star price before that.
private struct CharacterCell: View {
    let character: PlayerCharacter
    let theme: MazeTheme
    let stars: Int
    let isSelected: Bool
    let onChoose: () -> Void

    private var isUnlocked: Bool { character.isUnlocked(by: stars) }

    var body: some View {
        Button(action: onChoose) {
            VStack(spacing: 4) {
                if isUnlocked {
                    Text(character.emoji).font(.system(size: 44))
                    .minimumScaleFactor(0.4)
                    .lineLimit(1)
                    .layoutPriority(-1)
                    Text(character.name)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(theme.ink)
                } else {
                    Text(character.emoji)
                        .font(.system(size: 44))
                    .minimumScaleFactor(0.4)
                    .lineLimit(1)
                    .layoutPriority(-1)
                        .saturation(0)
                        .brightness(theme.isDark ? 1 : -1)
                        .opacity(0.16)
                    Label("\(character.starsNeeded)", systemImage: "star.fill")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(theme.ink.opacity(0.6))
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .background(theme.paper, in: RoundedRectangle(cornerRadius: 18))
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: 18).strokeBorder(theme.accent, lineWidth: 4)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(!isUnlocked)
        .accessibilityLabel(isUnlocked ? character.name : "\(character.name), needs \(character.starsNeeded) stars")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
