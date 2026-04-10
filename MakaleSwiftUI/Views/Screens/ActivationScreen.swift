import SwiftUI

struct ActivationScreen: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var email = ""
    @State private var keyPart1 = ""
    @State private var keyPart2 = ""
    @State private var keyPart3 = ""

    var body: some View {
        AppCanvas {
            GeometryReader { proxy in
                let metrics = layoutMetrics(for: proxy.size)

                ScrollView(.vertical, showsIndicators: false) {
                    Group {
                        if metrics.usesTwoColumnLayout {
                            HStack(alignment: .center, spacing: metrics.columnSpacing) {
                                marketingPanel(titleFontSize: metrics.titleFontSize)
                                    .frame(width: metrics.marketingWidth)

                                activationPanel
                                    .frame(width: metrics.formWidth)
                            }
                        } else {
                            VStack(spacing: metrics.columnSpacing) {
                                marketingPanel(titleFontSize: metrics.titleFontSize)
                                activationPanel
                            }
                        }
                    }
                    .frame(maxWidth: metrics.contentWidth)
                    .padding(.horizontal, metrics.outerPadding)
                    .padding(.vertical, metrics.outerPadding)
                    .frame(maxWidth: .infinity, minHeight: proxy.size.height, alignment: .center)
                }
            }
        }
    }

    private func marketingPanel(titleFontSize: CGFloat) -> some View {
        SectionCard {
            VStack(alignment: .leading, spacing: 18) {
                Text("Makale")
                    .font(.custom("Avenir Next Demi Bold", size: 15))
                    .tracking(1.6)
                    .foregroundStyle(Palette.highlight)

                Text("Legacy library, rebuilt with a calmer and friendlier SwiftUI flow.")
                    .font(.custom("Avenir Next Bold", size: titleFontSize))
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
    }

    private var activationPanel: some View {
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
                    emailField
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Serial")
                        .font(.custom("Avenir Next Demi Bold", size: 13))
                    HStack(spacing: 10) {
                        serialField(text: $keyPart1)
                        serialField(text: $keyPart2)
                        serialField(text: $keyPart3)
                    }
                }

                Button {
                    Task {
                        await appState.activate(
                            email: normalizedEmail(email),
                            keyPart1: keyPart1,
                            keyPart2: keyPart2,
                            keyPart3: keyPart3
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
        }
    }

    private var emailField: some View {
        let field = TextField("name@example.com", text: $email)
            .textFieldStyle(.roundedBorder)
        #if os(iOS)
        return field
            .keyboardType(.emailAddress)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .textContentType(.emailAddress)
        #else
        return field
        #endif
    }

    private func serialField(text: Binding<String>) -> some View {
        let field = TextField("XXXXX", text: text)
            .textFieldStyle(.roundedBorder)
            .font(.custom("Avenir Next Demi Bold", size: 16))
            .onChange(of: text.wrappedValue) { newValue in
                text.wrappedValue = normalizedSerialSegment(newValue)
            }
        #if os(iOS)
        return field
            .keyboardType(.asciiCapable)
            .textInputAutocapitalization(.characters)
            .autocorrectionDisabled()
        #else
        return field
        #endif
    }

    private func normalizedEmail(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func normalizedSerialSegment(_ value: String) -> String {
        let remapped = value
            .replacingOccurrences(of: "ı", with: "i")
            .replacingOccurrences(of: "İ", with: "i")
            .replacingOccurrences(of: "I", with: "i")
            .replacingOccurrences(of: "ç", with: "c")
            .replacingOccurrences(of: "Ç", with: "c")
            .replacingOccurrences(of: "ğ", with: "g")
            .replacingOccurrences(of: "Ğ", with: "g")
            .replacingOccurrences(of: "ö", with: "o")
            .replacingOccurrences(of: "Ö", with: "o")
            .replacingOccurrences(of: "ş", with: "s")
            .replacingOccurrences(of: "Ş", with: "s")
            .replacingOccurrences(of: "ü", with: "u")
            .replacingOccurrences(of: "Ü", with: "u")
        let folded = remapped.folding(options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive], locale: Locale(identifier: "en_US_POSIX"))
        let uppercased = folded.uppercased(with: Locale(identifier: "en_US_POSIX"))
        let allowedScalars = uppercased.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) && $0.isASCII }
        return String(String.UnicodeScalarView(allowedScalars).prefix(5))
    }

    private func layoutMetrics(for size: CGSize) -> ActivationLayoutMetrics {
        let outerPadding: CGFloat = size.width >= 980 ? 42 : 24
        let contentWidth = min(max(size.width - (outerPadding * 2), 320), 1240)
        let prefersTwoColumns = horizontalSizeClass == .regular || contentWidth >= 900
        let columnSpacing: CGFloat = prefersTwoColumns ? 28 : 20
        let usableWidth = contentWidth - (prefersTwoColumns ? columnSpacing : 0)
        let marketingWidth = prefersTwoColumns ? max(usableWidth * 0.56, 430) : contentWidth
        let formWidth = prefersTwoColumns ? max(usableWidth - marketingWidth, 300) : contentWidth
        let titleFontSize: CGFloat = prefersTwoColumns && contentWidth > 1040 ? 40 : 34

        return ActivationLayoutMetrics(
            contentWidth: contentWidth,
            outerPadding: outerPadding,
            columnSpacing: columnSpacing,
            marketingWidth: marketingWidth,
            formWidth: formWidth,
            titleFontSize: titleFontSize,
            usesTwoColumnLayout: prefersTwoColumns
        )
    }
}

private struct ActivationLayoutMetrics {
    let contentWidth: CGFloat
    let outerPadding: CGFloat
    let columnSpacing: CGFloat
    let marketingWidth: CGFloat
    let formWidth: CGFloat
    let titleFontSize: CGFloat
    let usesTwoColumnLayout: Bool
}
