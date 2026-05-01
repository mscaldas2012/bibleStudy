/// CelebrationView.swift
/// Streak celebration sheet. Presented once per day when streak ≥ 3 (or on record loss).

import SwiftUI

struct CelebrationView: View {
    let info: CelebrationInfo
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {

                    // ── Flame + streak count ───────────────────────────────
                    VStack(spacing: 8) {
                        Text("🔥")
                            .font(.system(size: 64))

                        if info.currentStreak >= 3 {
                            Text("\(info.currentStreak)-Day Streak!")
                                .font(.largeTitle.bold())
                        } else {
                            Text("Welcome Back!")
                                .font(.largeTitle.bold())
                        }

                        if info.currentStreak >= 3 {
                            Text("Keep showing up daily to grow your streak.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.top, 8)

                    // ── Freeze token message ───────────────────────────────
                    if info.freezeTokensUsed > 0 {
                        HStack(spacing: 12) {
                            Image(systemName: "snowflake")
                                .font(.title2)
                                .foregroundStyle(.blue)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(info.freezeTokensUsed == 1
                                     ? "A freeze token kept your streak alive!"
                                     : "\(info.freezeTokensUsed) freeze tokens kept your streak alive!")
                                    .font(.subheadline.bold())
                                Text(tokenBalanceLabel)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.blue.opacity(0.08), in: .rect(cornerRadius: 12))
                    }

                    // ── Record loss message ───────────────────────────────
                    if let record = info.lostRecord {
                        HStack(spacing: 12) {
                            Image(systemName: "trophy")
                                .font(.title2)
                                .foregroundStyle(.orange)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Your previous best was \(record) days.")
                                    .font(.subheadline.bold())
                                Text("Start a new streak and beat it!")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.orange.opacity(0.08), in: .rect(cornerRadius: 12))
                    }

                    // ── Freeze token balance (when no freeze was used) ─────
                    if info.freezeTokensUsed == 0 {
                        HStack(spacing: 12) {
                            Image(systemName: "snowflake")
                                .font(.title2)
                                .foregroundStyle(.blue)
                            Text(tokenBalanceLabel)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.secondary.opacity(0.07), in: .rect(cornerRadius: 12))
                    }

                    // ── "Do not show again" toggle ─────────────────────────
                    Toggle(isOn: Binding(
                        get: { StreakStore.shared.data.suppressCelebrations },
                        set: { newValue in
                            StreakStore.shared.setSuppressCelebrations(newValue)
                            if newValue { dismiss() }
                        }
                    )) {
                        Text("Don't show this again")
                            .font(.subheadline)
                    }
                    .padding(.horizontal, 4)
                }
                .padding()
            }
            .navigationTitle("Streak")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Close") {
                        StreakStore.shared.dismissCelebration()
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Helpers

    private var tokenBalanceLabel: String {
        let count = info.freezeTokensRemaining
        switch count {
        case 0: return "No freeze tokens remaining — keep your streak going!"
        case 1: return "1 freeze token available"
        default: return "\(count) freeze tokens available"
        }
    }
}
