import SwiftUI

struct PrivacyPolicyView: View {
    var body: some View {
        SupportScreen(title: "Privacy Policy") {
            Text("Privacy Policy")
                .font(.system(size: 26, weight: .heavy))
                .foregroundStyle(Theme.textPrimary)
            Text("Last updated: June 10, 2026")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textMuted)
                .padding(.top, 4)
                .padding(.bottom, 12)

            SupportParagraph(text: "My Feeds (\"the app\") helps you monitor YouTube channels with research collections and organize the videos they discover. This policy explains what information we collect, how we use it, and the choices you have.")

            SupportHeading(text: "Information We Collect")
            SupportParagraph(text: "We collect the information you provide directly: your account email and password (managed by our authentication provider), the collections, channels, and preferences you configure, and your watch statuses for videos. We also store optional settings such as a default email for digests. If you choose to save API keys, they are stored securely and are write-only — they can never be read back by the app.")

            SupportHeading(text: "How We Use Your Information")
            SupportParagraph(text: "Your data is used solely to operate the app: running your collections, building your research feed, tracking your watch progress, and sending email digests you configure. We do not sell your personal information or use it for advertising.")

            SupportHeading(text: "Third-Party Services")
            SupportParagraph(text: "The app relies on YouTube for video content and metadata, and on our backend provider for authentication, database, and processing. Videos are played through YouTube's embedded player, which is subject to Google's privacy policy. Optional AI analysis may use the provider configured for your account.")

            SupportHeading(text: "Data Storage and Security")
            SupportParagraph(text: "Your data is stored in our secured backend with row-level access controls, so only your authenticated account can access your records. Session tokens are stored securely on your device.")

            SupportHeading(text: "Data Retention and Deletion")
            SupportParagraph(text: "Your data is retained while your account is active. You can delete your account and all associated data at any time from Settings → Delete Account. If you have any trouble, contact us at support@travelone.ca and we will complete the deletion within 30 days.")

            SupportHeading(text: "Children's Privacy")
            SupportParagraph(text: "The app is not directed to children under 13, and we do not knowingly collect personal information from children.")

            SupportHeading(text: "Changes to This Policy")
            SupportParagraph(text: "We may update this policy from time to time. Material changes will be reflected by updating the \"Last updated\" date above.")

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
