/// StreakData.swift
/// Codable model persisted to UserDefaults by StreakStore.

import Foundation

struct StreakData: Codable {
    var currentStreak: Int = 0
    var longestStreak: Int = 0
    var lastLookupDate: Date? = nil
    var freezeTokens: Int = 0
    /// Streak count at which the next freeze token is awarded; resets to 10 on streak break.
    var nextTokenMilestone: Int = 10
    /// Last calendar day the celebration sheet was shown (prevents repeat same day).
    var celebrationShownDate: Date? = nil
    /// Last calendar day the "you lost your record" message was shown.
    var recordLostShownDate: Date? = nil
    /// When true the celebration sheet is never presented.
    var suppressCelebrations: Bool = false
}
