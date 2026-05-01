/// ContentView.swift
/// Root view — NavigationSplitView with sidebar (input) and detail (study note).

import SwiftUI

struct ContentView: View {
    var splashVisible: Bool = false

    @State private var viewModel = StudyViewModel()
    @State private var columnVisibility = NavigationSplitViewVisibility.all
    @State private var showDetail = false
    @State private var detailPath = NavigationPath()
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.colorScheme) private var colorScheme
    @Environment(StreakStore.self) private var streakStore
    @AppStorage("has_seen_welcome_v1") private var hasSeenWelcome = false
    @State private var showWelcome = false

    private var activeColors: AppColors {
        switch ThemeStore.shared.mode {
        case .light:  return .light
        case .dark:   return .dark
        case .system: return AppColors.resolved(for: colorScheme)
        }
    }

    var body: some View {
        @Bindable var streakStore = streakStore

        Group {
            if sizeClass == .compact {
                NavigationStack(path: $detailPath) {
                    SidebarView()
                        .navigationDestination(isPresented: $showDetail) {
                            DetailView()
                        }
                }
                .onChange(of: viewModel.isLoading) { _, loading in
                    if loading {
                        detailPath = NavigationPath()
                        showDetail = true
                    }
                }
            } else {
                NavigationSplitView(columnVisibility: $columnVisibility) {
                    SidebarView()
                        .navigationSplitViewColumnWidth(min: 300, ideal: 360, max: 420)
                } detail: {
                    NavigationStack(path: $detailPath) {
                        DetailView()
                    }
                }
                .navigationSplitViewStyle(.balanced)
                .onChange(of: viewModel.isLoading) { _, loading in
                    if loading { detailPath = NavigationPath() }
                }
            }
        }
        .preferredColorScheme(ThemeStore.shared.preferredColorScheme)
        .environment(\.appColors, activeColors)
        .environment(viewModel)
        .environment(HistoryStore.shared)
        .sheet(item: Binding(
            get: { showWelcome ? nil : streakStore.pendingCelebration },
            set: { if $0 == nil { streakStore.dismissCelebration() } }
        )) { info in
            CelebrationView(info: info)
        }
        .sheet(isPresented: $showWelcome) {
            WelcomeView()
        }
        .onChange(of: splashVisible) { _, isVisible in
            if !isVisible && !hasSeenWelcome {
                showWelcome = true
            }
        }
    }
}
