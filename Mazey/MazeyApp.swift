//
//  MazeyApp.swift
//  Mazey
//
//  Created by George Babichev on 11/1/26.
//

import SwiftUI

@main
struct MazeyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                #if os(macOS)
                .modifier(MacAboutPresentation())
                #endif
        }
        #if os(macOS)
        .commands { MazeyAboutCommands() }
        #endif
    }
}
