import SwiftUI

/// "Add from link" and myfeeds.ca/open/share links: the same Add to My Feeds
/// card the share extension shows (ios/MyFeedsShare/ShareCardView.swift),
/// over the app.
struct AddFromLinkSheet: View {
    let text: String
    let onClose: () -> Void

    @State private var model = ShareModel()
    @State private var started = false

    var body: some View {
        ShareCardView(model: model)
            .onAppear {
                model.onClose = onClose
                guard !started else { return }
                started = true
                model.start(shared: text, allowTyping: true)
            }
    }
}
