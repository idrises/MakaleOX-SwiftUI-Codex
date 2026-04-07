import SwiftUI

struct ActivationScreen: View {
    @EnvironmentObject private var appState: AppState

    @State private var email = ""
    @State private var keyPart1 = ""
    @State private var keyPart2 = ""
    @State private var keyPart3 = ""

    var body: some View {
        AppCanvas {
            HStack(spacing: 32) {
                SectionCard {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("Makale")
                            .font(.custom("Avenir Next Demi Bold", size: 15))
                            .tracking(1.6)
                            .foregroundStyle(Palette.highlight)

                        Text("Legacy library, rebuilt with a calmer and friendlier SwiftUI flow.")
                            .font(.custom("Avenir Next Bold", size: 40))
                            .fixedSize(horizontal: false, vertical: true)

                        Text("Browse journals, books, videos, and protected video sets from one modern workspace.")
                            .font(.custom("Avenir Next Regular", size: 16))
                            .foregroundStyle(Palette.muted)

                        HStack(spacing: 14) {
                            MetricChip(label: "Journal Flow", value: "Cleaner", tint: Palette.accent)
                            MetricChip(label: "Reader", value: "Integrated", tint: Palette.highlight)
                            MetricChip(label: "Discovery", value: "Unified", tint: Palette.gold)
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            Label("Single SwiftUI workspace for all content types", systemImage: "sparkles")
                            Label("Favorites, profile stats, and local history", systemImage: "star.circle")
                            Label("PDF and video playback without storyboard complexity", systemImage: "play.rectangle")
                        }
                        .font(.custom("Avenir Next Medium", size: 15))
                        .foregroundStyle(Palette.ink)
                    }
                }
                .frame(maxWidth: 620)

                SectionCard {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("Activation")
                            .font(.custom("Avenir Next Bold", size: 28))
                        Text("Use the same e-mail and 3-part serial from the legacy app.")
                            .font(.custom("Avenir Next Regular", size: 15))
                            .foregroundStyle(Palette.muted)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("E-mail")
                                .font(.custom("Avenir Next Demi Bold", size: 13))
                            TextField("name@example.com", text: $email)
                                .textFieldStyle(.roundedBorder)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Serial")
                                .font(.custom("Avenir Next Demi Bold", size: 13))
                            HStack {
                                serialField(text: $keyPart1)
                                serialField(text: $keyPart2)
                                serialField(text: $keyPart3)
                            }
                        }

                        Button {
                            Task {
                                await appState.activate(
                                    email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                                    keyPart1: keyPart1.trimmingCharacters(in: .whitespacesAndNewlines),
                                    keyPart2: keyPart2.trimmingCharacters(in: .whitespacesAndNewlines),
                                    keyPart3: keyPart3.trimmingCharacters(in: .whitespacesAndNewlines)
                                )
                            }
                        } label: {
                            HStack {
                                Spacer()
                                Text("Open Library")
                                    .font(.custom("Avenir Next Demi Bold", size: 15))
                                Spacer()
                            }
                            .padding(.vertical, 12)
                            .background(Palette.accent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)
                        .disabled(email.isEmpty || keyPart1.isEmpty || keyPart2.isEmpty || keyPart3.isEmpty)
                        .opacity(email.isEmpty || keyPart1.isEmpty || keyPart2.isEmpty || keyPart3.isEmpty ? 0.55 : 1)

                        Text("Activation is kept in the new app workspace. The original project folder stays untouched.")
                            .font(.custom("Avenir Next Regular", size: 12))
                            .foregroundStyle(Palette.muted)
                    }
                    .frame(width: 380)
                }
            }
            .padding(42)
        }
    }

    private func serialField(text: Binding<String>) -> some View {
        TextField("XXXXX", text: text)
            .textFieldStyle(.roundedBorder)
            .font(.custom("Avenir Next Demi Bold", size: 16))
            .onChange(of: text.wrappedValue) { newValue in
                text.wrappedValue = String(newValue.uppercased().prefix(5))
            }
    }
}
