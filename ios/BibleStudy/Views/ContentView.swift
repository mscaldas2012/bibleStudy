/// ContentView.swift
/// Root view — NavigationSplitView with sidebar (input) and detail (study note).

import SwiftUI

struct ContentView: View {
    @State private var viewModel = StudyViewModel()

    var body: some View {
        NavigationSplitView(columnVisibility: .constant(.all)) {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 300, ideal: 360, max: 420)
        } detail: {
            DetailView()
        }
        .navigationSplitViewStyle(.balanced)
        .environment(viewModel)
    }
}
