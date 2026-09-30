import SwiftUI

struct TermsView: View {
    var body: some View {
        SupportScreen(title: "Terms of Service") {
            Text("Terms of Service")
                .font(.system(size: 26, weight: .heavy))
                .foregroundStyle(Theme.textPrimary)
            Text("Last updated: June 10, 2026")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textMuted)
                .padding(.top, 4)
                .padding(.bottom, 12)

            SupportParagraph(text: "By using My Feeds (\"the app\"), you agree to these terms. Please read them carefully.")

            SupportHeading(text: "Use of the App")
            SupportParagraph(text: "You may use the app to create research collections, monitor YouTube channels, and organize videos for personal, non-commercial research. You are responsible for maintaining the confidentiality of your account credentials and for all activity under your account.")

            SupportHeading(text: "Third-Party Services and Credentials")
            SupportParagraph(text: "The app integrates with YouTube and optional AI providers. Your use of those services is governed by their own terms. Any API keys you save must belong to you, and you are responsible for usage and costs incurred under them.")

            SupportHeading(text: "User Content and Conduct")
            SupportParagraph(text: "You agree not to misuse the app, including attempting to access other users' data, circumventing rate limits, or using the app for unlawful purposes.")

            SupportHeading(text: "Intellectual Property")
            SupportParagraph(text: "The app, its design, and its software are owned by us or our licensors. Video content and thumbnails belong to their respective creators and platforms.")

            SupportHeading(text: "Disclaimer of Warranties")
            SupportParagraph(text: "The app is provided \"as is\" without warranties of any kind. We do not guarantee that collections will discover every relevant video or that the service will be uninterrupted or error-free.")

            SupportHeading(text: "Limitation of Liability")
            SupportParagraph(text: "To the maximum extent permitted by law, we are not liable for any indirect, incidental, or consequential damages arising from your use of the app.")

            SupportHeading(text: "Termination")
            SupportParagraph(text: "We may suspend or terminate access for conduct that violates these terms. You may stop using the app and delete your account at any time from Settings.")

            SupportHeading(text: "Changes to These Terms")
            SupportParagraph(text: "We may update these terms from time to time. Continued use of the app after changes take effect constitutes acceptance of the revised terms.")

            SupportHeading(text: "Contact Us")
            HStack(spacing: 4) {
                Text("Questions? Contact us at")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textSecondary)
                SupportEmailLink()
            }
        }
    }
}
