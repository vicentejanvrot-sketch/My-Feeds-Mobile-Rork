import SwiftUI

/// Onboarding walkthrough of how to read, watch and act on content, one platform
/// at a time. Same content as the web ReadWatchTour and the Expo ReadWatchTour:
/// a sample post with three numbered spots that match what the feed, the video
/// player and the post reader actually do.
struct ReadWatchTourView: View {
    @State private var platform: SourcePlatform
    @State private var spot = 0

    init(defaultPlatform: SourcePlatform = .youtube) {
        _platform = State(initialValue: defaultPlatform)
    }

    private var tour: TourContent { TourContent.content(for: platform) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            platformPicker
            sampleCard
            explanations
        }
    }

    // MARK: - Platform picker

    private var platformPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // Spotify releases work like Apple Music's, so the tour leaves it out.
                ForEach(SourcePlatform.addable.filter { $0 != .spotify }, id: \.self) { p in
                    let selected = platform == p
                    Button {
                        platform = p
                        spot = 0
                    } label: {
                        HStack(spacing: 8) {
                            PlatformBadge(platform: p, size: 18)
                            Text(p.label)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Theme.textPrimary)
                        }
                        .padding(.horizontal, 12)
                        .frame(height: 40)
                        .background(Capsule().fill(selected ? Theme.accent.opacity(0.12) : Color.clear))
                        .overlay(Capsule().stroke(selected ? Theme.accent : Theme.border, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
            .padding(.vertical, 2)
        }
    }

    // MARK: - Sample card

    private var sampleCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                PlatformBadge(platform: platform, size: 26)
                VStack(alignment: .leading, spacing: 1) {
                    Text(tour.author)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                    Text("\(tour.handle) · \(tour.when)")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }

            zone(0) { contentZone }
            zone(1) { spotTwo }
            zone(2) { spotThree }
        }
        .padding(12)
        .cardStyle(radius: 12)
    }

    /// Spot 1: the content itself (marker top-left). Spots 2 and 3: action rows (marker top-right).
    private func zone<Content: View>(_ index: Int, @ViewBuilder content: () -> Content) -> some View {
        let active = spot == index
        return content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
            .padding(.top, index == 0 ? 10 : 0)
            .padding(.trailing, index == 0 ? 0 : 40)
            .background(RoundedRectangle(cornerRadius: 10).fill(active ? Theme.accent.opacity(0.06) : Color.clear))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(active ? Theme.accent.opacity(0.6) : Color.clear, lineWidth: 2))
            .overlay(alignment: index == 0 ? .topLeading : .topTrailing) {
                marker(index)
                    .offset(x: index == 0 ? -6 : -4, y: index == 0 ? -6 : 4)
            }
    }

    private func marker(_ index: Int) -> some View {
        let active = spot == index
        return Button {
            spot = index
        } label: {
            Text("\(index + 1)")
                .font(.system(size: 14, weight: .heavy))
                .foregroundStyle(active ? Color.white : Theme.accent)
                .frame(width: 34, height: 34)
                .background(Circle().fill(active ? Theme.accent : Theme.background))
                .overlay(Circle().stroke(Theme.accent, lineWidth: 2))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(index + 1), \(tour.steps[index].title)")
    }

    private var contentZone: some View {
        VStack(alignment: .leading, spacing: 8) {
            if tour.media != .text {
                ZStack {
                    RoundedRectangle(cornerRadius: 8).fill(Theme.input)
                    if tour.media == .video {
                        Circle()
                            .fill(Theme.textPrimary.opacity(0.92))
                            .frame(width: 44, height: 44)
                            .overlay(
                                Image(systemName: "play.fill")
                                    .font(.system(size: 18))
                                    .foregroundStyle(Theme.background)
                            )
                    }
                }
                .frame(height: 130)
                .overlay(alignment: .bottomTrailing) {
                    if tour.media == .photo {
                        Text("1 / 3")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.black.opacity(0.6)))
                            .padding(8)
                    }
                }
            }
            if let title = tour.title {
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
            }
            if let text = tour.text {
                Text(text)
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let quote = tour.quote {
                VStack(alignment: .leading, spacing: 2) {
                    (Text(quote.author).fontWeight(.bold) + Text("  \(quote.handle)").foregroundColor(Theme.textSecondary))
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textPrimary)
                    Text(quote.text)
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 10).fill(Theme.input))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.border, lineWidth: 0.5))
            }
        }
    }

    @ViewBuilder
    private var spotTwo: some View {
        if platform == .youtube {
            VStack(alignment: .leading, spacing: 6) {
                Text("FROM THE TRANSCRIPT")
                    .font(.system(size: 11, weight: .heavy))
                    .kerning(0.6)
                    .foregroundStyle(Theme.accent)
                momentRow(time: "4:10", text: "When small-cap loans reset")
                momentRow(time: "11:32", text: "What would change his view")
            }
        } else {
            pillGrid(tour.saveActions, note: nil)
        }
    }

    @ViewBuilder
    private var spotThree: some View {
        if platform == .youtube {
            pillGrid([
                TourAction(icon: "checkmark.circle", label: "Watched"),
                TourAction(icon: "clock", label: "Watch later"),
                TourAction(icon: "heart", label: "Liked"),
            ], note: nil)
        } else {
            pillGrid(tour.outActions, note: tour.outNote)
        }
    }

    private func momentRow(time: String, text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(time)
                .font(.system(size: 12, weight: .heavy, design: .monospaced))
                .foregroundStyle(Theme.accent)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(RoundedRectangle(cornerRadius: 4).fill(Theme.accent.opacity(0.14)))
            Text(text)
                .font(.system(size: 14))
                .foregroundStyle(Theme.textPrimary)
        }
    }

    private func pillGrid(_ actions: [TourAction], note: String?) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 8, alignment: .leading)], alignment: .leading, spacing: 8) {
            ForEach(actions) { action in
                HStack(spacing: 6) {
                    Image(systemName: action.icon)
                        .font(.system(size: 13, weight: .semibold))
                    Text(action.label)
                        .font(.system(size: 12, weight: .bold))
                        .lineLimit(1)
                }
                .foregroundStyle(Theme.textPrimary)
                .padding(.horizontal, 12)
                .frame(height: 32)
                .background(Capsule().fill(Theme.input))
            }
            if let note {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.right.square")
                        .font(.system(size: 12))
                    Text(note)
                        .font(.system(size: 12))
                        .lineLimit(1)
                }
                .foregroundStyle(Theme.textSecondary)
                .frame(height: 32)
            }
        }
    }

    // MARK: - Explanations

    private var explanations: some View {
        VStack(spacing: 8) {
            ForEach(Array(tour.steps.enumerated()), id: \.offset) { index, step in
                let active = spot == index
                Button {
                    spot = index
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text("\(index + 1)")
                                .font(.system(size: 12, weight: .heavy))
                                .foregroundStyle(active ? Color.white : Theme.accent)
                                .frame(width: 24, height: 24)
                                .background(Circle().fill(active ? Theme.accent : Theme.background))
                                .overlay(Circle().stroke(Theme.accent, lineWidth: 2))
                            Text(step.title)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(Theme.textPrimary)
                        }
                        Text(step.body)
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 10).fill(active ? Theme.accent.opacity(0.1) : Color.clear))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(active ? Theme.accent : Theme.border, lineWidth: 1))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(active ? .isSelected : [])
            }
        }
    }
}

// MARK: - Content

private struct TourAction: Identifiable {
    let icon: String
    let label: String
    var id: String { label }
}

private struct TourStep {
    let title: String
    let body: String
}

private struct TourQuote {
    let author: String
    let handle: String
    let text: String
}

private enum TourMedia {
    case video, photo, text
}

private struct TourContent {
    let author: String
    let handle: String
    let when: String
    let media: TourMedia
    var title: String?
    var text: String?
    var quote: TourQuote?
    let steps: [TourStep]
    var saveActions: [TourAction] = []
    var outActions: [TourAction] = []
    var outNote: String?

    static func content(for platform: SourcePlatform) -> TourContent {
        switch platform {
        case .spotify:
            // Not in the tour (Spotify can't be added as a source).
            return content(for: .youtubeMusic)
        case .youtube:
            return TourContent(
                author: "Two Minute Markets", handle: "YouTube", when: "2h", media: .video,
                title: "Why small caps lag when rates rise",
                steps: [
                    TourStep(title: "Play it here", body: "Tap the video to watch it inside My Feeds. It remembers where you stopped."),
                    TourStep(title: "Jump to the good parts", body: "Under the player, the summary lists the key moments. Tap a time to jump straight there."),
                    TourStep(title: "Keep track", body: "Mark it Watched, Watch later or Liked from the card so your feed stays tidy."),
                ]
            )
        case .x:
            return TourContent(
                author: "Lena Ortiz", handle: "@lena_builds", when: "5h", media: .text,
                text: "Onboarding rewrite is live. A thread on what we cut and why.",
                quote: TourQuote(author: "Design Notes Daily", handle: "@designnotes", text: "The best onboarding asks for one decision per screen."),
                steps: [
                    TourStep(title: "Read the whole post", body: "Tap the post to open it. Photos, videos and quoted posts show in full inside My Feeds."),
                    TourStep(title: "Like or bookmark", body: "Like saves it in My Feeds. Bookmark adds it to Read later."),
                    TourStep(title: "Reply or repost on X", body: "Replying and reposting open X, because they post from your X account."),
                ],
                saveActions: [TourAction(icon: "heart", label: "Like"), TourAction(icon: "bookmark", label: "Bookmark")],
                outActions: [TourAction(icon: "bubble.left", label: "Reply"), TourAction(icon: "arrow.2.squarepath", label: "Repost")],
                outNote: "Opens X"
            )
        case .reddit:
            return TourContent(
                author: "r/PowerApps", handle: "u/canvas_dev", when: "8h", media: .text,
                title: "Patching a collection without the delegation warning?",
                text: "I've got a gallery over 2,000 rows and Patch keeps complaining. What's the cleanest way around it?",
                steps: [
                    TourStep(title: "Open the post", body: "Tap it to read the full post with its photos or video, plus a summary of the thread."),
                    TourStep(title: "Upvote to save", body: "Upvote saves it in My Feeds, downvote marks it as read, and Save adds it to Read later."),
                    TourStep(title: "Comments open on Reddit", body: "Tap the comment count to join the conversation on Reddit."),
                ],
                saveActions: [
                    TourAction(icon: "arrowshape.up", label: "Upvote"),
                    TourAction(icon: "arrowshape.down", label: "Downvote"),
                    TourAction(icon: "bookmark", label: "Save"),
                ],
                outActions: [TourAction(icon: "bubble.left.and.bubble.right", label: "Comments")],
                outNote: "Opens Reddit"
            )
        case .github:
            return TourContent(
                author: "openfeeds", handle: "New release", when: "1d", media: .text,
                title: "openfeeds/parser v1.4.0",
                text: "Release notes for the parser, with a short summary of what changed.",
                steps: [
                    TourStep(title: "See what's new", body: "Tap a new repository or release to read what it is, with a short summary."),
                    TourStep(title: "Star to save", body: "Star saves it in My Feeds. Save adds it to Read later."),
                    TourStep(title: "Fork on GitHub", body: "Forking opens GitHub, since it happens in your GitHub account."),
                ],
                saveActions: [TourAction(icon: "star", label: "Star"), TourAction(icon: "bookmark", label: "Save")],
                outActions: [TourAction(icon: "arrow.triangle.branch", label: "Fork")],
                outNote: "Opens GitHub"
            )
        case .instagram:
            return TourContent(
                author: "Ember Kitchen", handle: "@emberkitchen", when: "3h", media: .photo,
                text: "Three ways to use up leftover rice this week.",
                steps: [
                    TourStep(title: "Photos and reels play here", body: "Tap the post to open it. Swipe through carousels and play reels without leaving."),
                    TourStep(title: "Heart to save", body: "The heart saves it in My Feeds, and the bookmark adds it to Read later."),
                    TourStep(title: "Comments open on Instagram", body: "Commenting opens Instagram, because it posts from your account."),
                ],
                saveActions: [TourAction(icon: "heart", label: "Like"), TourAction(icon: "bookmark", label: "Save")],
                outActions: [TourAction(icon: "bubble.left", label: "Comment")],
                outNote: "Opens Instagram"
            )
        case .linkedin:
            return TourContent(
                author: "Maya Chen", handle: "Product lead", when: "1d", media: .text,
                text: "We cut our onboarding from nine screens to three. Here's what we learned about asking for less up front.",
                steps: [
                    TourStep(title: "Read the full post", body: "Tap it to read the whole post and see its images inside My Feeds."),
                    TourStep(title: "Like to save", body: "Like saves it in My Feeds. Save adds it to Read later."),
                    TourStep(title: "Comment and repost on LinkedIn", body: "Those open LinkedIn, since they post from your account."),
                ],
                saveActions: [TourAction(icon: "hand.thumbsup", label: "Like"), TourAction(icon: "bookmark", label: "Save")],
                outActions: [TourAction(icon: "bubble.left", label: "Comment"), TourAction(icon: "arrow.2.squarepath", label: "Repost")],
                outNote: "Opens LinkedIn"
            )
        case .tiktok:
            return TourContent(
                author: "Ember Kitchen", handle: "@emberkitchen", when: "4h", media: .video,
                text: "Crispy rice in 60 seconds.",
                steps: [
                    TourStep(title: "Watch it here", body: "Tap the video to play it inside My Feeds with TikTok's own player."),
                    TourStep(title: "Like to save", body: "Like saves it in My Feeds. Save adds it to Read later."),
                    TourStep(title: "Comments open on TikTok", body: "Commenting opens TikTok, because it posts from your account."),
                ],
                saveActions: [TourAction(icon: "heart", label: "Like"), TourAction(icon: "bookmark", label: "Save")],
                outActions: [TourAction(icon: "bubble.left", label: "Comment")],
                outNote: "Opens TikTok"
            )
        case .facebook:
            return TourContent(
                author: "City Parks & Rec", handle: "Page", when: "6h", media: .photo,
                text: "The riverside trail reopens Saturday. Here's what changed.",
                steps: [
                    TourStep(title: "Read and watch here", body: "Tap the post to read it in full. Photos open large and videos play inside My Feeds."),
                    TourStep(title: "Like to save", body: "Like saves it in My Feeds. Save adds it to Read later."),
                    TourStep(title: "Comments open on Facebook", body: "Commenting opens Facebook, because it posts from your account."),
                ],
                saveActions: [TourAction(icon: "hand.thumbsup", label: "Like"), TourAction(icon: "bookmark", label: "Save")],
                outActions: [TourAction(icon: "bubble.left", label: "Comment")],
                outNote: "Opens Facebook"
            )
        case .appleMusic:
            return TourContent(
                author: "Nova Lane", handle: "New single", when: "1d", media: .video,
                title: "Paper Lanterns",
                text: "New single by Nova Lane · 1 track · Pop",
                steps: [
                    TourStep(title: "Listen here", body: "Tap it to open Apple Music's player. You hear a preview, or the full songs if you're signed in to Apple Music."),
                    TourStep(title: "Heart to save", body: "The heart saves it in My Feeds. Save adds it to Watch later."),
                    TourStep(title: "Add it to Apple Music", body: "\"Add album to Apple Music\" puts the songs in your My Feeds playlist there, ready to download for offline."),
                ],
                saveActions: [TourAction(icon: "heart", label: "Like"), TourAction(icon: "bookmark", label: "Save")],
                outActions: [TourAction(icon: "arrow.up.right.square", label: "Apple Music")],
                outNote: "Opens Apple Music"
            )
        case .applePodcasts:
            return TourContent(
                author: "The Long Run", handle: "Podcast", when: "5h", media: .video,
                title: "Episode 212: Training through the winter",
                text: "Full episode, played inside My Feeds.",
                steps: [
                    TourStep(title: "Listen to the whole episode", body: "Tap it to play the full episode here. It remembers where you stopped, on every device."),
                    TourStep(title: "Heart to save", body: "The heart saves it in My Feeds. Save adds it to Watch later."),
                    TourStep(title: "Follow the show on Apple Podcasts", body: "Following or rating the show opens Apple Podcasts."),
                ],
                saveActions: [TourAction(icon: "heart", label: "Like"), TourAction(icon: "bookmark", label: "Save")],
                outActions: [TourAction(icon: "arrow.up.right.square", label: "Apple Podcasts")],
                outNote: "Opens Apple Podcasts"
            )
        case .appleBooks:
            return TourContent(
                author: "Maya Ortiz", handle: "Audiobook", when: "2d", media: .photo,
                title: "The Quiet Harbor",
                text: "New audiobook by Maya Ortiz · Fiction",
                steps: [
                    TourStep(title: "Hear a sample", body: "Tap it to see the cover and description, and play Apple's sample right here."),
                    TourStep(title: "Heart to save", body: "The heart saves it in My Feeds. Save adds it to Watch later."),
                    TourStep(title: "Listen in Apple Books", body: "Buying and listening to the whole book opens Apple Books."),
                ],
                saveActions: [TourAction(icon: "heart", label: "Like"), TourAction(icon: "bookmark", label: "Save")],
                outActions: [TourAction(icon: "arrow.up.right.square", label: "Apple Books")],
                outNote: "Opens Apple Books"
            )
        case .youtubeMusic:
            return TourContent(
                author: "Nova Lane", handle: "New album", when: "1d", media: .video,
                title: "Night Garden",
                text: "New album by Nova Lane · 10 tracks",
                steps: [
                    TourStep(title: "Listen here", body: "Tap it to play the songs, or the music video, right inside My Feeds."),
                    TourStep(title: "Heart to save", body: "The heart saves it in My Feeds. Save adds it to Watch later."),
                    TourStep(title: "Add it to YouTube Music", body: "\"Add to YouTube Music\" puts the songs in your My Feeds playlist there, using your connected YouTube account."),
                ],
                saveActions: [TourAction(icon: "heart", label: "Like"), TourAction(icon: "bookmark", label: "Save")],
                outActions: [TourAction(icon: "arrow.up.right.square", label: "YouTube Music")],
                outNote: "Opens YouTube Music"
            )
        }
    }
}
