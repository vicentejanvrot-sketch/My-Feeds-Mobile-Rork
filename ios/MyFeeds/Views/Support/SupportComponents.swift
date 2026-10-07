import SwiftUI

/// Shared scroll scaffold for support screens.
struct SupportScreen<Content: View>: View {
    let title: LocalizedStringKey
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                content
            }
            .padding(16)
            .padding(.bottom, 40)
            .frame(maxWidth: 720, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.background)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
    }
}

struct SupportHeading: View {
    let text: LocalizedStringKey

    var body: some View {
        Text(text)
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(Theme.textPrimary)
            .padding(.top, 18)
            .padding(.bottom, 6)
    }
}

struct SupportParagraph: View {
    let text: LocalizedStringKey

    var body: some View {
        Text(text)
            .font(.system(size: 14))
            .foregroundStyle(Theme.textSecondary)
            .lineSpacing(6)
    }
}

/// Inline tappable support email link.
struct SupportEmailLink: View {
    var body: some View {
        Button {
            if let url = URL(string: "mailto:support@travelone.ca") {
                UIApplication.shared.open(url)
            }
        } label: {
            Text(verbatim: "support@travelone.ca")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.accent)
        }
    }
}
