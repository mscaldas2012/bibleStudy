/// ThemeStore.swift
/// Persists the user's appearance preference (Light / Dark / System).

import SwiftUI
import Observation

enum AppearanceMode: String, CaseIterable {
    case light  = "light"
    case dark   = "dark"
    case system = "system"

    var label: String {
        switch self {
        case .light:  return "Light"
        case .dark:   return "Dark"
        case .system: return "System"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .light:  return .light
        case .dark:   return .dark
        case .system: return nil
        }
    }
}

@Observable
final class ThemeStore {
    static let shared = ThemeStore()

    var mode: AppearanceMode {
        didSet { UserDefaults.standard.set(mode.rawValue, forKey: "appearance_mode") }
    }

    var preferredColorScheme: ColorScheme? { mode.colorScheme }

    private init() {
        let stored = UserDefaults.standard.string(forKey: "appearance_mode") ?? ""
        mode = AppearanceMode(rawValue: stored) ?? .system
    }
}
