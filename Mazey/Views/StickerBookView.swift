//
//  StickerBookView.swift
//  Mazey
//

import SwiftUI

/// Every sticker there is to earn, grouped by theme. Ones not earned yet show as dark
/// silhouettes, which is a gentle reason to try another theme.
struct StickerBookView: View {
    let session: MazeGameSession

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 28) {
                ForEach(MazeTheme.all) { theme in
                    section(for: theme)
                }
            }
            .padding()
        }
        .background {
            LinearGradient(
                colors: [session.theme.backgroundTop, session.theme.backgroundBottom],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()
        }
        .navigationTitle("Sticker Book")
        .themedWindowAppearance(session.theme)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(session.theme.isDark ? .dark : .light, for: .navigationBar)
        #endif
    }

    /// Text that reads on this page: white on a dark theme, the theme's ink on a light one.
    private var pageText: Color { session.theme.isDark ? .white : session.theme.ink }

    private func section(for theme: MazeTheme) -> some View {
        let owned = session.collection.ownedCount(in: theme)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Text(theme.playerEmoji).font(.system(size: 30))
                Text(theme.name)
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                Spacer()
                Text("\(owned) / \(theme.stickers.count)")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    // Gold when the set is complete; otherwise the page's own text color, softened.
                    // (The system "secondary" gray disappears against a dark page.)
                    .foregroundStyle(owned == theme.stickers.count ? Color(red: 1.0, green: 0.8, blue: 0.1) : pageText.opacity(0.75))
            }
            .foregroundStyle(pageText)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 84), spacing: 12)], spacing: 12) {
                ForEach(Array(theme.stickers.enumerated()), id: \.offset) { index, sticker in
                    StickerCell(theme: theme, sticker: sticker, entry: session.collection.entry(themeID: theme.id, index: index))
                }
            }
        }
    }
}

/// One slot in the book.
private struct StickerCell: View {
    let theme: MazeTheme
    let sticker: Sticker
    let entry: StickerEntry?

    private static let gold = Color(red: 1.0, green: 0.8, blue: 0.1)

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            RoundedRectangle(cornerRadius: 18)
                .fill(theme.paper)
            if let entry {
                Text(sticker.emoji)
                    .font(.system(size: 46))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                if entry.gold {
                    RoundedRectangle(cornerRadius: 18)
                        .strokeBorder(Self.gold, lineWidth: 4)
                }
                if entry.count > 1 {
                    Text("×\(entry.count)")
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(theme.accent, in: Capsule())
                        .padding(6)
                }
            } else {
                // A silhouette of the emoji: black on a light page, white on a dark one.
                Text(sticker.emoji)
                    .font(.system(size: 46))
                    .saturation(0)
                    .brightness(theme.isDark ? 1 : -1)
                    .opacity(0.16)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .shadow(color: .black.opacity(0.08), radius: 3, y: 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
    }

    private var label: String {
        guard let entry else { return "Not found yet" }
        return entry.gold ? "\(sticker.name), gold" : sticker.name
    }
}
