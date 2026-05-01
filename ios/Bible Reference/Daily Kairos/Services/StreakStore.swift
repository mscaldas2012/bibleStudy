/// StreakStore.swift
/// Tracks the user's daily lookup streak, freeze tokens, and triggers celebration sheets.
/// Follows the same @Observable singleton + UserDefaults pattern as HistoryStore.

import Foundation
import Observation

@Observable
final class StreakStore {
    static let shared = StreakStore()

    private(set) var data: StreakData = StreakData()
    /// Non-nil when a celebration sheet should be presented. Set by recordLookup(),
    /// cleared by dismissCelebration() when the sheet is dismissed.
    var pendingCelebration: CelebrationInfo? = nil

    private let storageKey = "streak_data_v1"
    private let calendar = Calendar.current

    private init() {
        load()
    }

    // MARK: - Public API

    /// Call after every successful lookup. Idempotent within a calendar day.
    func recordLookup() {
        let today = calendar.startOfDay(for: Date())

        // Guard: already counted today — do not re-trigger streak or celebration
        if let last = data.lastLookupDate, calendar.isDate(last, inSameDayAs: today) {
            return
        }

        // ── Compute streak delta ───────────────────────────────────────────
        var freezeTokensUsed = 0

        if let last = data.lastLookupDate {
            let dayGap = calendar.dateComponents([.day], from: last, to: today).day ?? 0
            let missedDays = dayGap - 1

            if missedDays == 0 {
                // Perfect consecutive day
                data.currentStreak += 1
            } else if missedDays > 0 && data.freezeTokens >= missedDays {
                // Freeze tokens cover the gap
                freezeTokensUsed = missedDays
                data.freezeTokens -= missedDays
                data.currentStreak += 1
            } else {
                // Streak broken — record best before resetting
                if data.currentStreak > data.longestStreak {
                    data.longestStreak = data.currentStreak
                }
                data.currentStreak = 1
                data.nextTokenMilestone = 10
            }
        } else {
            // Very first lookup ever
            data.currentStreak = 1
        }

        data.lastLookupDate = today

        // ── Update all-time best ───────────────────────────────────────────
        if data.currentStreak > data.longestStreak {
            data.longestStreak = data.currentStreak
        }

        // ── Award freeze token at milestone ───────────────────────────────
        if data.currentStreak >= data.nextTokenMilestone && data.freezeTokens < 3 {
            data.freezeTokens = min(data.freezeTokens + 1, 3)
            data.nextTokenMilestone += 10
        }

        save()

        // ── Decide whether to show celebration ────────────────────────────
        guard !data.suppressCelebrations else { return }

        // Only once per calendar day
        if let shown = data.celebrationShownDate, calendar.isDate(shown, inSameDayAs: today) {
            return
        }

        // Determine "lost record" message:
        // Only when streak just reset (currentStreak == 1) and longestStreak > 1,
        // and we haven't shown it today yet.
        var lostRecord: Int? = nil
        if data.currentStreak == 1 && data.longestStreak > 1 {
            let alreadyShown = data.recordLostShownDate.map {
                calendar.isDate($0, inSameDayAs: today)
            } ?? false
            if !alreadyShown {
                lostRecord = data.longestStreak
                data.recordLostShownDate = today
            }
        }

        // Require streak ≥ 3 unless there's a record-loss message to surface
        guard data.currentStreak >= 3 || lostRecord != nil else {
            save()
            return
        }

        data.celebrationShownDate = today
        save()

        pendingCelebration = CelebrationInfo(
            currentStreak: data.currentStreak,
            freezeTokensUsed: freezeTokensUsed,
            lostRecord: lostRecord,
            freezeTokensRemaining: data.freezeTokens
        )
    }

    /// Call when the celebration sheet is dismissed.
    func dismissCelebration() {
        pendingCelebration = nil
    }

    /// Forces the celebration sheet to appear with sample data — for UI testing only.
    func showTestCelebration() {
        pendingCelebration = CelebrationInfo(
            currentStreak: 7,
            freezeTokensUsed: 1,
            lostRecord: 14,
            freezeTokensRemaining: 2
        )
    }

    /// Permanently suppresses (or re-enables) the celebration sheet.
    func setSuppressCelebrations(_ suppress: Bool) {
        data.suppressCelebrations = suppress
        save()
    }

    // MARK: - Persistence

    private func save() {
        guard let encoded = try? JSONEncoder().encode(data) else { return }
        UserDefaults.standard.set(encoded, forKey: storageKey)
    }

    private func load() {
        guard let stored = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode(StreakData.self, from: stored) else { return }
        data = decoded
    }
}
