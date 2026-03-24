/// SplashView.swift
/// Branded launch screen — shown for ~2 seconds on cold open.
/// Works identically on iPhone, iPad, and Mac (Designed for iPad).

import SwiftUI

struct SplashView: View {

    // Colors sampled from the logo
    private let bgColor   = Color(red: 0.051, green: 0.282, blue: 0.227) // forest green #0D4839
    private let goldColor = Color(red: 0.784, green: 0.592, blue: 0.224) // gold       #C89738
    private let sandColor = Color(red: 0.627, green: 0.471, blue: 0.282) // sand       #A07848

    var body: some View {
        bgColor
            .ignoresSafeArea()
            .overlay {
                VStack(spacing: 32) {
                    Image("AppLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 200, height: 200)

                    // "Daily Kairos" — "ai" in sand, rest in gold
                    Group {
                        Text("Daily K")
                            .foregroundStyle(goldColor)
                        + Text("ai")
                            .foregroundStyle(sandColor)
                        + Text("ros")
                            .foregroundStyle(goldColor)
                    }
                    .font(.system(size: 38, weight: .light, design: .serif))
                    .tracking(4)
                }
            }
    }
}

#Preview {
    SplashView()
}
