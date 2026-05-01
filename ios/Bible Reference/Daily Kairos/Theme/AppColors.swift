/// AppColors.swift
/// Centralized color palette for light and dark appearances.
/// Injected via SwiftUI environment so every view reads a single source of truth.

import SwiftUI

struct AppColors {
    let background: Color
    let cardBackground: Color
    let accent: Color
    let accentSecondary: Color
    let verseTextUIColor: UIColor

    static let light = AppColors(
        background: Color(red: 0.980, green: 0.965, blue: 0.937),
        cardBackground: .white,
        accent: Color(red: 0.45, green: 0.28, blue: 0.08),
        accentSecondary: Color(red: 0.6, green: 0.35, blue: 0.1),
        verseTextUIColor: UIColor(red: 0.18, green: 0.12, blue: 0.06, alpha: 1)
    )

    static let dark = AppColors(
        background: Color(red: 0.09, green: 0.07, blue: 0.05),
        cardBackground: Color(red: 0.15, green: 0.12, blue: 0.09),
        accent: Color(red: 0.87, green: 0.70, blue: 0.38),
        accentSecondary: Color(red: 0.80, green: 0.60, blue: 0.28),
        verseTextUIColor: UIColor(red: 0.90, green: 0.82, blue: 0.68, alpha: 1.0)
    )

    static func resolved(for scheme: ColorScheme) -> AppColors {
        scheme == .dark ? .dark : .light
    }
}

private struct AppColorsKey: EnvironmentKey {
    static let defaultValue = AppColors.light
}

extension EnvironmentValues {
    var appColors: AppColors {
        get { self[AppColorsKey.self] }
        set { self[AppColorsKey.self] = newValue }
    }
}
