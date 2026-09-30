import SwiftUI

struct FAQView: View {
    private let entries: [(question: String, answer: String)] = [
        ("What does this app do?",
         "My Feeds lets you create collections that follow YouTube channels and other accounts, automatically surface new videos and posts into your Feed, and track which videos you've watched."),
        ("Do I need a YouTube account?",
         "Connecting your YouTube account is optional. It lets the app sync your playlists, watch history, and video actions. You can use the core feed features without connecting."),
        ("Why do you ask for API keys?",
         "API keys (YouTube, OpenAI, Anthropic, Gemini) are optional and let the app fetch video data and run AI analysis on your behalf. Keys are stored securely and are never displayed back to you after saving."),
        ("How is my data stored?",
         "Your settings and saved keys are stored securely in our backend. API keys are write-only — once saved, they cannot be read back by the app or displayed on screen."),
        ("How do I delete my account or data?",
         "You can delete your account at any time from Settings → Delete Account. This permanently removes your account and all your data — your collections, feeds, watch history, and saved settings. The deletion happens immediately within the app and cannot be undone. If you have any trouble, contact us at support@travelone.ca."),
        ("How do I get help?",
         "Contact us any time at support@travelone.ca and we'll respond as soon as possible."),
    ]

    var body: some View {
        SupportScreen(title: "FAQ") {
            ForEach(entries, id: \.question) { entry in
                VStack(alignment: .leading, spacing: 6) {
                    Text(entry.question)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                        .lineSpacing(4)
                    Text(entry.answer)
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.textSecondary)
                        .lineSpacing(5)
                }
                .padding(.bottom, 20)
            }

            Rectangle().fill(Theme.border).frame(height: 0.5)

            HStack(spacing: 4) {
                Text("Still need help? Contact us at")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textSecondary)
                SupportEmailLink()
            }
            .padding(.top, 16)
        }
    }
}
