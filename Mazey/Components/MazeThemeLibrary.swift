//
//  MazeThemeLibrary.swift
//  Mazey
//

import SwiftUI

/// Every theme the app ships with. A theme is just data: add one here and to `MazeTheme.all`,
/// plus a sound flourish in `SoundSynth`.
///
/// About half are dark (night) themes, with a dark maze floor, light walls and light `ink`.
/// Scenery emoji avoid star shapes, because the collectible stars are drawn as gold stars.
nonisolated extension MazeTheme {
    static let space = MazeTheme(
        id: "space", name: "Space",
        playerEmoji: "🚀", startEmoji: "🌍", finishEmoji: "🪐",
        decorations: ["👽", "☄️", "🛸", "🌙", "🔭"],
        stickers: [
            Sticker("🚀", "Rocket"), Sticker("🛸", "Flying saucer"), Sticker("🪐", "Ringed planet"),
            Sticker("🌍", "Earth"), Sticker("🌙", "Moon"), Sticker("☄️", "Comet"),
            Sticker("👽", "Alien"), Sticker("🛰️", "Satellite"),
        ],
        backgroundTop: Color(red: 0.10, green: 0.08, blue: 0.30),
        backgroundBottom: Color(red: 0.32, green: 0.12, blue: 0.48),
        paper: Color(red: 0.14, green: 0.13, blue: 0.36),
        wall: Color(red: 0.72, green: 0.67, blue: 1.00),
        path: Color(red: 0.30, green: 0.85, blue: 0.95),
        hint: Color(red: 1.00, green: 0.85, blue: 0.30),
        startTint: Color(red: 0.35, green: 0.85, blue: 0.55),
        finishTint: Color(red: 1.00, green: 0.55, blue: 0.70),
        accent: Color(red: 1.00, green: 0.55, blue: 0.20),
        ink: Color(red: 0.88, green: 0.85, blue: 1.00),
        isDark: true
    )

    static let dinosaur = MazeTheme(
        id: "dinosaur", name: "Dinosaur",
        playerEmoji: "🦕", startEmoji: "🌴", finishEmoji: "🥚",
        decorations: ["🌿", "🌴", "🦴", "🌋", "🍃", "🪨"],
        stickers: [
            Sticker("🦕", "Long-neck dinosaur"), Sticker("🦖", "T-rex"), Sticker("🥚", "Dinosaur egg"),
            Sticker("🌋", "Volcano"), Sticker("🌴", "Palm tree"), Sticker("🦴", "Bone"),
            Sticker("🍃", "Leaves"), Sticker("🪨", "Rock"),
        ],
        backgroundTop: Color(red: 0.80, green: 0.93, blue: 0.70),
        backgroundBottom: Color(red: 0.98, green: 0.88, blue: 0.62),
        paper: Color(red: 1.00, green: 0.97, blue: 0.86),
        wall: Color(red: 0.36, green: 0.45, blue: 0.22),
        path: Color(red: 0.40, green: 0.72, blue: 0.33),
        hint: Color(red: 0.95, green: 0.55, blue: 0.15),
        startTint: Color(red: 0.45, green: 0.75, blue: 0.35),
        finishTint: Color(red: 0.95, green: 0.65, blue: 0.35),
        accent: Color(red: 0.85, green: 0.45, blue: 0.15),
        ink: Color(red: 0.30, green: 0.38, blue: 0.18),
        isDark: false
    )

    static let ocean = MazeTheme(
        id: "ocean", name: "Ocean",
        playerEmoji: "🐠", startEmoji: "🌊", finishEmoji: "🐚",
        decorations: ["🫧", "🪸", "🐙", "🐡", "🐬", "🦀"],
        stickers: [
            Sticker("🐠", "Tropical fish"), Sticker("🐟", "Fish"), Sticker("🐡", "Pufferfish"),
            Sticker("🐙", "Octopus"), Sticker("🦀", "Crab"), Sticker("🐬", "Dolphin"),
            Sticker("🐳", "Whale"), Sticker("🦈", "Shark"),
        ],
        backgroundTop: Color(red: 0.02, green: 0.10, blue: 0.28),
        backgroundBottom: Color(red: 0.03, green: 0.30, blue: 0.46),
        paper: Color(red: 0.05, green: 0.17, blue: 0.34),
        wall: Color(red: 0.55, green: 0.90, blue: 1.00),
        path: Color(red: 0.30, green: 0.92, blue: 0.78),
        hint: Color(red: 1.00, green: 0.82, blue: 0.30),
        startTint: Color(red: 0.30, green: 0.80, blue: 0.70),
        finishTint: Color(red: 1.00, green: 0.65, blue: 0.55),
        accent: Color(red: 1.00, green: 0.50, blue: 0.35),
        ink: Color(red: 0.86, green: 0.96, blue: 1.00),
        isDark: true
    )

    static let farm = MazeTheme(
        id: "farm", name: "Farm",
        playerEmoji: "🐰", startEmoji: "🏡", finishEmoji: "🥕",
        decorations: ["🌻", "🌷", "🦋", "🐝", "🌼", "🍄"],
        stickers: [
            Sticker("🐰", "Bunny"), Sticker("🐮", "Cow"), Sticker("🐷", "Pig"),
            Sticker("🐔", "Chicken"), Sticker("🐑", "Sheep"), Sticker("🐴", "Horse"),
            Sticker("🦆", "Duck"), Sticker("🐶", "Dog"),
        ],
        backgroundTop: Color(red: 0.78, green: 0.93, blue: 0.98),
        backgroundBottom: Color(red: 0.80, green: 0.93, blue: 0.55),
        paper: Color(red: 1.00, green: 0.98, blue: 0.88),
        wall: Color(red: 0.55, green: 0.35, blue: 0.20),
        path: Color(red: 0.96, green: 0.60, blue: 0.25),
        hint: Color(red: 0.35, green: 0.65, blue: 0.95),
        startTint: Color(red: 0.55, green: 0.80, blue: 0.40),
        finishTint: Color(red: 1.00, green: 0.70, blue: 0.40),
        accent: Color(red: 0.40, green: 0.70, blue: 0.30),
        ink: Color(red: 0.45, green: 0.28, blue: 0.15),
        isDark: false
    )

    static let unicorn = MazeTheme(
        id: "unicorn", name: "Unicorn",
        playerEmoji: "🦄", startEmoji: "🌈", finishEmoji: "🏰",
        decorations: ["🦋", "🌈", "🍭", "🧁", "🪄", "🌸"],
        stickers: [
            Sticker("🦄", "Unicorn"), Sticker("🌈", "Rainbow"), Sticker("🏰", "Castle"),
            Sticker("🧚", "Fairy"), Sticker("👑", "Crown"), Sticker("🪄", "Magic wand"),
            Sticker("🦋", "Butterfly"), Sticker("🧁", "Cupcake"),
        ],
        backgroundTop: Color(red: 1.00, green: 0.88, blue: 0.95),
        backgroundBottom: Color(red: 0.82, green: 0.80, blue: 1.00),
        paper: Color(red: 1.00, green: 0.97, blue: 0.99),
        wall: Color(red: 0.62, green: 0.32, blue: 0.72),
        path: Color(red: 0.97, green: 0.48, blue: 0.78),
        hint: Color(red: 0.98, green: 0.78, blue: 0.20),
        startTint: Color(red: 0.62, green: 0.86, blue: 0.75),
        finishTint: Color(red: 1.00, green: 0.72, blue: 0.86),
        accent: Color(red: 0.90, green: 0.35, blue: 0.70),
        ink: Color(red: 0.45, green: 0.22, blue: 0.55),
        isDark: false
    )

    static let vehicles = MazeTheme(
        id: "vehicles", name: "Vehicles",
        playerEmoji: "🚗", startEmoji: "🛣️", finishEmoji: "🏁",
        decorations: ["🚦", "🌳", "⛽", "🚧", "🚏", "🏢"],
        stickers: [
            Sticker("🚗", "Car"), Sticker("🚌", "Bus"), Sticker("🚒", "Fire truck"),
            Sticker("🚓", "Police car"), Sticker("🚜", "Tractor"), Sticker("🚂", "Train"),
            Sticker("✈️", "Airplane"), Sticker("🚁", "Helicopter"),
        ],
        backgroundTop: Color(red: 0.70, green: 0.88, blue: 1.00),
        backgroundBottom: Color(red: 0.86, green: 0.88, blue: 0.92),
        paper: Color(red: 0.96, green: 0.96, blue: 0.98),
        wall: Color(red: 0.25, green: 0.30, blue: 0.40),
        path: Color(red: 0.93, green: 0.32, blue: 0.30),
        hint: Color(red: 0.98, green: 0.76, blue: 0.10),
        startTint: Color(red: 0.55, green: 0.80, blue: 0.55),
        finishTint: Color(red: 0.98, green: 0.80, blue: 0.40),
        accent: Color(red: 0.95, green: 0.50, blue: 0.15),
        ink: Color(red: 0.22, green: 0.28, blue: 0.40),
        isDark: false
    )

    static let robots = MazeTheme(
        id: "robots", name: "Robots",
        playerEmoji: "🤖", startEmoji: "🛠️", finishEmoji: "🔋",
        decorations: ["⚙️", "🔩", "💡", "📡", "🔧", "🧲"],
        stickers: [
            Sticker("🤖", "Robot"), Sticker("👾", "Space invader"), Sticker("⚙️", "Gear"),
            Sticker("🔧", "Wrench"), Sticker("🔋", "Battery"), Sticker("💡", "Light bulb"),
            Sticker("🦾", "Robot arm"), Sticker("🧲", "Magnet"),
        ],
        backgroundTop: Color(red: 0.07, green: 0.08, blue: 0.16),
        backgroundBottom: Color(red: 0.13, green: 0.17, blue: 0.30),
        paper: Color(red: 0.10, green: 0.12, blue: 0.22),
        wall: Color(red: 0.40, green: 0.85, blue: 0.95),
        path: Color(red: 0.96, green: 0.36, blue: 0.76),
        hint: Color(red: 1.00, green: 0.85, blue: 0.25),
        startTint: Color(red: 0.35, green: 0.90, blue: 0.55),
        finishTint: Color(red: 1.00, green: 0.80, blue: 0.30),
        accent: Color(red: 0.00, green: 0.72, blue: 0.92),
        ink: Color(red: 0.86, green: 0.93, blue: 1.00),
        isDark: true
    )

    static let spring = MazeTheme(
        id: "spring", name: "Spring",
        playerEmoji: "🐝", startEmoji: "🌱", finishEmoji: "🌷",
        decorations: ["🌸", "🦋", "🌼", "🐛", "🌱", "🌧️"],
        stickers: [
            Sticker("🌷", "Tulip"), Sticker("🌸", "Blossom"), Sticker("🐣", "Chick"),
            Sticker("🐝", "Bee"), Sticker("🦋", "Butterfly"), Sticker("🌱", "Sprout"),
            Sticker("🐛", "Caterpillar"), Sticker("🌼", "Daisy"),
        ],
        backgroundTop: Color(red: 0.85, green: 0.97, blue: 0.88),
        backgroundBottom: Color(red: 1.00, green: 0.88, blue: 0.93),
        paper: Color(red: 1.00, green: 0.99, blue: 0.95),
        wall: Color(red: 0.35, green: 0.55, blue: 0.35),
        path: Color(red: 0.95, green: 0.55, blue: 0.70),
        hint: Color(red: 0.95, green: 0.72, blue: 0.15),
        startTint: Color(red: 0.62, green: 0.85, blue: 0.55),
        finishTint: Color(red: 1.00, green: 0.75, blue: 0.82),
        accent: Color(red: 0.90, green: 0.45, blue: 0.60),
        ink: Color(red: 0.30, green: 0.50, blue: 0.35),
        isDark: false
    )

    static let summer = MazeTheme(
        id: "summer", name: "Summer",
        playerEmoji: "🏄", startEmoji: "🏖️", finishEmoji: "🍦",
        decorations: ["🌞", "🌴", "🍉", "🩴", "🌊", "🐚"],
        stickers: [
            Sticker("🏖️", "Beach"), Sticker("🌞", "Sun"), Sticker("🍦", "Ice cream"),
            Sticker("🏄", "Surfer"), Sticker("🍉", "Watermelon"), Sticker("😎", "Sunglasses"),
            Sticker("🩴", "Flip-flops"), Sticker("🏊", "Swimmer"),
        ],
        backgroundTop: Color(red: 1.00, green: 0.96, blue: 0.70),
        backgroundBottom: Color(red: 0.55, green: 0.88, blue: 0.95),
        paper: Color(red: 1.00, green: 0.98, blue: 0.88),
        wall: Color(red: 0.00, green: 0.50, blue: 0.60),
        path: Color(red: 1.00, green: 0.55, blue: 0.20),
        hint: Color(red: 0.85, green: 0.20, blue: 0.50),
        startTint: Color(red: 0.50, green: 0.85, blue: 0.80),
        finishTint: Color(red: 1.00, green: 0.78, blue: 0.55),
        accent: Color(red: 1.00, green: 0.50, blue: 0.10),
        ink: Color(red: 0.00, green: 0.40, blue: 0.50),
        isDark: false
    )

    static let autumn = MazeTheme(
        id: "autumn", name: "Autumn",
        playerEmoji: "🦊", startEmoji: "🍂", finishEmoji: "🎃",
        decorations: ["🍁", "🍂", "🍄", "🌰", "🍎", "🦔"],
        stickers: [
            Sticker("🍂", "Falling leaf"), Sticker("🍁", "Maple leaf"), Sticker("🎃", "Pumpkin"),
            Sticker("🌰", "Acorn"), Sticker("🍄", "Mushroom"), Sticker("🦊", "Fox"),
            Sticker("🍎", "Apple"), Sticker("🦔", "Hedgehog"),
        ],
        backgroundTop: Color(red: 1.00, green: 0.88, blue: 0.70),
        backgroundBottom: Color(red: 0.85, green: 0.55, blue: 0.35),
        paper: Color(red: 1.00, green: 0.96, blue: 0.88),
        wall: Color(red: 0.45, green: 0.25, blue: 0.12),
        path: Color(red: 0.85, green: 0.40, blue: 0.15),
        hint: Color(red: 0.20, green: 0.55, blue: 0.75),
        startTint: Color(red: 0.80, green: 0.75, blue: 0.40),
        finishTint: Color(red: 1.00, green: 0.70, blue: 0.35),
        accent: Color(red: 0.85, green: 0.35, blue: 0.10),
        ink: Color(red: 0.40, green: 0.22, blue: 0.10),
        isDark: false
    )

    static let winter = MazeTheme(
        id: "winter", name: "Winter",
        playerEmoji: "🐧", startEmoji: "🛷", finishEmoji: "⛄",
        decorations: ["❄️", "🎿", "🧣", "🎄", "🧤", "🦌"],
        stickers: [
            Sticker("⛄", "Snowman"), Sticker("❄️", "Snowflake"), Sticker("🧣", "Scarf"),
            Sticker("🎿", "Skis"), Sticker("🛷", "Sled"), Sticker("🧤", "Mittens"),
            Sticker("🐧", "Penguin"), Sticker("🎄", "Tree"),
        ],
        backgroundTop: Color(red: 0.05, green: 0.09, blue: 0.26),
        backgroundBottom: Color(red: 0.22, green: 0.24, blue: 0.52),
        paper: Color(red: 0.10, green: 0.15, blue: 0.34),
        wall: Color(red: 0.80, green: 0.90, blue: 1.00),
        path: Color(red: 0.45, green: 0.85, blue: 1.00),
        hint: Color(red: 1.00, green: 0.85, blue: 0.35),
        startTint: Color(red: 0.45, green: 0.85, blue: 0.85),
        finishTint: Color(red: 1.00, green: 0.75, blue: 0.85),
        accent: Color(red: 0.95, green: 0.40, blue: 0.45),
        ink: Color(red: 0.92, green: 0.96, blue: 1.00),
        isDark: true
    )

    static let halloween = MazeTheme(
        id: "halloween", name: "Halloween",
        playerEmoji: "👻", startEmoji: "🏚️", finishEmoji: "🎃",
        decorations: ["🦇", "🕸️", "🎃", "👻", "🕷️", "🌙"],
        stickers: [
            Sticker("👻", "Ghost"), Sticker("🎃", "Jack-o'-lantern"), Sticker("🦇", "Bat"),
            Sticker("🕷️", "Spider"), Sticker("🧙", "Witch"), Sticker("🍬", "Candy"),
            Sticker("🌙", "Moon"), Sticker("🐈‍⬛", "Black cat"),
        ],
        backgroundTop: Color(red: 0.09, green: 0.04, blue: 0.17),
        backgroundBottom: Color(red: 0.34, green: 0.13, blue: 0.06),
        paper: Color(red: 0.17, green: 0.10, blue: 0.25),
        wall: Color(red: 1.00, green: 0.62, blue: 0.22),
        path: Color(red: 0.55, green: 0.88, blue: 0.35),
        hint: Color(red: 1.00, green: 0.90, blue: 0.40),
        startTint: Color(red: 0.45, green: 0.80, blue: 0.40),
        finishTint: Color(red: 1.00, green: 0.60, blue: 0.20),
        accent: Color(red: 1.00, green: 0.55, blue: 0.10),
        ink: Color(red: 0.98, green: 0.88, blue: 1.00),
        isDark: true
    )

    static let christmas = MazeTheme(
        id: "christmas", name: "Christmas",
        playerEmoji: "🎅", startEmoji: "🏠", finishEmoji: "🎄",
        decorations: ["🎄", "🎁", "🔔", "🦌", "⛄", "🕯️"],
        stickers: [
            Sticker("🎅", "Santa"), Sticker("🎄", "Christmas tree"), Sticker("🎁", "Present"),
            Sticker("🔔", "Bell"), Sticker("🦌", "Reindeer"), Sticker("🧦", "Stocking"),
            Sticker("🍪", "Cookie"), Sticker("🕯️", "Candle"),
        ],
        backgroundTop: Color(red: 0.03, green: 0.16, blue: 0.14),
        backgroundBottom: Color(red: 0.32, green: 0.07, blue: 0.10),
        paper: Color(red: 0.08, green: 0.22, blue: 0.18),
        wall: Color(red: 0.97, green: 0.86, blue: 0.55),
        path: Color(red: 0.95, green: 0.30, blue: 0.30),
        hint: Color(red: 0.45, green: 0.92, blue: 0.55),
        startTint: Color(red: 0.45, green: 0.85, blue: 0.55),
        finishTint: Color(red: 1.00, green: 0.60, blue: 0.60),
        accent: Color(red: 0.90, green: 0.20, blue: 0.25),
        ink: Color(red: 1.00, green: 0.95, blue: 0.85),
        isDark: true
    )
}
