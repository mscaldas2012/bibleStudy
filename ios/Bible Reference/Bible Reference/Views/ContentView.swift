/// ContentView.swift
/// Root view — NavigationSplitView with sidebar (input) and detail (study note).

import SwiftUI

struct ContentView: View {
    @State private var viewModel = StudyViewModel()
    @State private var columnVisibility = NavigationSplitViewVisibility.all
    @State private var showDetail = false           // iPhone: whether DetailView is pushed
    @State private var detailPath = NavigationPath() // tracks cross-ref drill depth
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(StreakStore.self) private var streakStore
    @AppStorage("has_seen_welcome_v1") private var hasSeenWelcome = false
    @State private var showWelcome = false

    var body: some View {
        @Bindable var streakStore = streakStore

        Group {
            if sizeClass == .compact {
                // iPhone: NavigationStack — push DetailView when a lookup starts
                NavigationStack(path: $detailPath) {
                    SidebarView()
                        .navigationDestination(isPresented: $showDetail) {
                            DetailView()
                        }
                }
                .onChange(of: viewModel.isLoading) { _, loading in
                    if loading {
                        detailPath = NavigationPath() // pop any cross-ref views first
                        showDetail = true
                    }
                }
            } else {
                // iPad / Mac Designed for iPad: side-by-side split view
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
                    if loading { detailPath = NavigationPath() } // pop cross-ref views on new lookup
                }
            }
        }
        .environment(viewModel)
        .environment(HistoryStore.shared)
        // Celebration is blocked while the welcome sheet is visible.
        // When welcome dismisses, pendingCelebration is still set → sheet surfaces automatically.
        .sheet(item: Binding(
            get: { showWelcome ? nil : streakStore.pendingCelebration },
            set: { if $0 == nil { streakStore.dismissCelebration() } }
        )) { info in
            CelebrationView(info: info)
        }
        .sheet(isPresented: $showWelcome) {
            WelcomeView()
        }
        .onAppear {
            if !hasSeenWelcome {
                showWelcome = true
            }
        }
    }
}
