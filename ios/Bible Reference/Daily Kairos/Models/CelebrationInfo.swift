/// CelebrationInfo.swift
/// Ephemeral value passed to CelebrationView. Created by StreakStore after a qualifying lookup.

import Foundation

struct CelebrationInfo: Identifiable {
    let id = UUID()
    let currentStreak: Int
    /// Number of freeze tokens auto-consumed to bridge a gap. 0 = no freeze used.
    let freezeTokensUsed: Int
    /// Non-nil when the user's streak just reset and they previously held a longer streak.
    let lostRecord: Int?
    let freezeTokensRemaining: Int
}
