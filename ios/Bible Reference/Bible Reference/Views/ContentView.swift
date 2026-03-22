/// ContentView.swift
/// Root view — NavigationSplitView with sidebar (input) and detail (study note).

import SwiftUI

struct ContentView: View {
    @State private var viewModel = StudyViewModel()
    @State private var columnVisibility = NavigationSplitViewVisibility.all
    @State private var showDetail = false           // iPhone stack navigation flag
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        Group {
            if sizeClass == .compact {
                // iPhone: NavigationStack — push DetailView when a lookup starts
                NavigationStack {
                    SidebarView()
                        .navigationDestination(isPresented: $showDetail) {
                            DetailView()
                        }
                }
                .onChange(of: viewModel.isLoading) { _, loading in
                    if loading { showDetail = true }
                }
            } else {
                // iPad / Mac Designed for iPad: side-by-side split view
                NavigationSplitView(columnVisibility: $columnVisibility) {
                    SidebarView()
                        .navigationSplitViewColumnWidth(min: 300, ideal: 360, max: 420)
                } detail: {
                    DetailView()
                }
                .navigationSplitViewStyle(.balanced)
            }
        }
        .environment(viewModel)
    }
}
