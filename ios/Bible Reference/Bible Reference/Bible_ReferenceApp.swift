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

    init() {
        Prompts.preload()
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                // ContentView loads in the background so it's ready when splash fades
                ContentView()
                    .opacity(showSplash ? 0 : 1)

                if showSplash {
                    SplashView()
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .environment(StreakStore.shared)
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
