/// FontSizeStore.swift
/// Persists the user's preferred dynamic type size across launches.

import SwiftUI
import Combine

final class FontSizeStore: ObservableObject {
    static let shared = FontSizeStore()

    static let sizes: [DynamicTypeSize] = [
        .xSmall, .small, .medium, .large, .xLarge, .xxLarge, .xxxLarge
    ]
    private static let scaleFactors: [CGFloat] = [0.82, 0.9, 0.96, 1.0, 1.12, 1.24, 1.38]
    private static let defaultIndex = 3  // .large — the iOS system default

    @Published var sizeIndex: Int {
        didSet { UserDefaults.standard.set(sizeIndex, forKey: "font_size_index") }
    }

    var currentSize: DynamicTypeSize { Self.sizes[sizeIndex] }
    var scaleFactor: CGFloat { Self.scaleFactors[sizeIndex] }
    var canIncrease: Bool { sizeIndex < Self.sizes.count - 1 }
    var canDecrease: Bool { sizeIndex > 0 }

    func increase() { if canIncrease { sizeIndex += 1 } }
    func decrease() { if canDecrease { sizeIndex -= 1 } }
    func scaled(_ size: CGFloat) -> CGFloat { size * scaleFactor }

    private init() {
        if UserDefaults.standard.object(forKey: "font_size_index") != nil {
            let stored = UserDefaults.standard.integer(forKey: "font_size_index")
            sizeIndex = max(0, min(stored, Self.sizes.count - 1))
        } else {
            sizeIndex = Self.defaultIndex
        }
    }
}
