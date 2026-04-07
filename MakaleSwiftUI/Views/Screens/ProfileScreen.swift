import SwiftUI

struct ProfileScreen: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                SectionCard {
                    HStack {
                        ScreenHeader(
                            eyebrow: "Profile",
                            title: appState.profile?.fullName.isEmpty == false ? appState.profile?.fullName ?? "Profile" : "Profile",
                            subtitle: "Remote usage counts from the legacy server, plus the new local favorites summary."
                        )
                        Spacer()
                        Button("Refresh Stats") {
                            Task { await appState.refreshProfile() }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Palette.accent)
                    }
                }

                if let profile = appState.profile {
                    SectionCard {
                        VStack(alignment: .leading, spacing: 18) {
                            HStack(spacing: 14) {
                                MetricChip(label: "Articles Opened", value: profile.articleCount, tint: Palette.accent)
                                MetricChip(label: "Chapters Opened", value: profile.chapterCount, tint: Palette.highlight)
                                MetricChip(label: "Videos Opened", value: profile.videoCount, tint: Palette.gold)
                                MetricChip(label: "Set Videos Opened", value: profile.videoSetCount, tint: Palette.accent)
                            }

                            HStack(spacing: 14) {
                                MetricChip(label: "Favorite Journals", value: profile.favoriteJournalCount, tint: Palette.accent)
                                MetricChip(label: "Favorite Books", value: profile.favoriteBookCount, tint: Palette.highlight)
                                MetricChip(label: "Favorite Sets", value: profile.favoriteVideoSetCount, tint: Palette.gold)
                            }
                        }
                    }

                    SectionCard {
                        VStack(alignment: .leading, spacing: 12) {
                            infoRow(label: "E-mail", value: profile.email)
                            infoRow(label: "User ID", value: profile.userID)
                            infoRow(label: "Subject", value: profile.subject)
                            infoRow(label: "Access Until", value: profile.expireDate)
                            infoRow(label: "Serial", value: profile.serial)
                        }
                    }
                } else {
                    EmptyStateView(
                        title: "Profile is not ready yet",
                        message: "Refresh the stats to pull your account information from the legacy server.",
                        symbolName: "person.text.rectangle"
                    )
                }
            }
        }
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.custom("Avenir Next Demi Bold", size: 14))
                .frame(width: 120, alignment: .leading)
            Text(value.isEmpty ? "-" : value)
                .font(.custom("Avenir Next Regular", size: 14))
                .foregroundStyle(Palette.muted)
        }
    }
}
