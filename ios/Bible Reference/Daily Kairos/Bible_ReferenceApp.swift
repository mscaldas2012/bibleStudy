//
//  Bible_ReferenceApp.swift
//  Bible Reference
//
//  Created by Marcelo Caldas on 3/19/26.
//

import SwiftUI

@main
struct Bible_ReferenceApp: App {
    @State private var showSplash = true
    @StateObject private var fontSizeStore = FontSizeStore.shared

    init() {
        Prompts.preload()
    }

    // Same dark teal as SplashView's bgEdge — fills the window before the first
    // SwiftUI frame paints, eliminating the black flash on cold launch.
    private static let launchBackground = Color(red: 0.035, green: 0.082, blue: 0.090)

    var body: some Scene {
        WindowGroup {
            ZStack {
                Self.launchBackground.ignoresSafeArea()

                // ContentView loads in the background so it's ready when splash fades
                ContentView(splashVisible: showSplash)
                    .opacity(showSplash ? 0 : 1)

                if showSplash {
                    SplashView()
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .environment(StreakStore.shared)
            .environment(ThemeStore.shared)
            .dynamicTypeSize(fontSizeStore.currentSize)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                    withAnimation(.easeOut(duration: 0.6)) {
                        showSplash = false
                    }
                }
            }
        }
    }
}
