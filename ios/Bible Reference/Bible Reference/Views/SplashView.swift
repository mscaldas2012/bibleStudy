/// SplashView.swift
/// Branded launch screen — shown for ~2 seconds on cold open.
/// Works identically on iPhone, iPad, and Mac (Designed for iPad).

import SwiftUI

struct SplashView: View {

    @State private var logoScale:   CGFloat = 0.82
    @State private var logoOpacity: Double  = 0
    @State private var ringOpacity: Double  = 0
    @State private var textOpacity: Double  = 0
    @State private var glowOpacity: Double  = 0

    // Palette — deep forest with sacred gold
    private let bgCenter  = Color(red: 0.091, green: 0.213, blue: 0.229) // logo color at center
    private let bgEdge    = Color(red: 0.035, green: 0.082, blue: 0.090) // darkened edges
    private let goldWarm  = Color(red: 0.929, green: 0.757, blue: 0.443) // #ECC171
    private let goldMuted = Color(red: 0.698, green: 0.533, blue: 0.251) // #B28840
    private let cream     = Color(red: 0.949, green: 0.929, blue: 0.878) // #F2EDDF

    var body: some View {
        ZStack {
            // Radial gradient: logo color at center, darkening to edges
            RadialGradient(
                colors: [bgCenter, bgEdge],
                center: .center,
                startRadius: 0,
                endRadius: 420
            )
            .ignoresSafeArea()

            // Gold ambient haze
            RadialGradient(
                colors: [goldMuted.opacity(0.11), Color.clear],
                center: .center,
                startRadius: 0,
                endRadius: 300
            )
            .ignoresSafeArea()
            .opacity(glowOpacity)

            VStack(spacing: 0) {
                Spacer()

                // Logo with thin halo ring
                ZStack {
                    Circle()
                        .strokeBorder(
                            AngularGradient(
                                colors: [
                                    goldMuted.opacity(0.0),
                                    goldWarm.opacity(0.55),
                                    goldMuted.opacity(0.08),
                                    goldWarm.opacity(0.45),
                                    goldMuted.opacity(0.0)
                                ],
                                center: .center
                            ),
                            lineWidth: 0.75
                        )
                        .frame(width: 228, height: 228)
                        .opacity(ringOpacity)

                    Image("AppLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 164, height: 164)
                        .scaleEffect(logoScale)
                        .opacity(logoOpacity)
                }

                Spacer().frame(height: 54)

                // Ornamental rule
                HStack(spacing: 10) {
                    Rectangle()
                        .fill(goldMuted.opacity(0.4))
                        .frame(width: 38, height: 0.5)
                    Text("✦")
                        .font(.system(size: 7, weight: .light))
                        .foregroundStyle(goldMuted.opacity(0.55))
                    Rectangle()
                        .fill(goldMuted.opacity(0.4))
                        .frame(width: 38, height: 0.5)
                }
                .opacity(textOpacity)

                Spacer().frame(height: 22)

                // App name — "ai" in warm gold, rest in cream
                (
                    Text("Daily K").foregroundStyle(cream) +
                    Text("ai").foregroundStyle(goldWarm) +
                    Text("ros").foregroundStyle(cream)
                )
                .font(.system(size: 36, weight: .ultraLight, design: .serif))
                .tracking(7)
                .opacity(textOpacity)

                Spacer().frame(height: 10)

                Text("SCRIPTURE  ·  STUDY  ·  REFLECTION")
                    .font(.system(size: 9, weight: .regular))
                    .tracking(3)
                    .foregroundStyle(goldMuted.opacity(0.6))
                    .opacity(textOpacity)

                Spacer()
                Spacer()
            }
        }
        .onAppear { animate() }
    }

    private func animate() {
        withAnimation(.easeOut(duration: 1.0)) {
            glowOpacity = 1
        }
        withAnimation(.spring(response: 0.9, dampingFraction: 0.72).delay(0.15)) {
            logoScale   = 1.0
            logoOpacity = 1.0
        }
        withAnimation(.easeOut(duration: 1.1).delay(0.3)) {
            ringOpacity = 1.0
        }
        withAnimation(.easeOut(duration: 0.85).delay(0.55)) {
            textOpacity = 1.0
        }
    }
}

#Preview {
    SplashView()
}
