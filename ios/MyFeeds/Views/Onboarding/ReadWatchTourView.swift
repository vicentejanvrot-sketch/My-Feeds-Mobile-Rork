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
                ForEach(SourcePlatform.addable, id: \.self) { p in
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
                    Text(verbatim: "\(tour.handle) · \(tour.when)")
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
            Text(verbatim: "\(index + 1)")
                .font(.system(size: 14, weight: .heavy))
                .foregroundStyle(active ? Color.white : Theme.accent)
                .frame(width: 34, height: 34)
                .background(Circle().fill(active ? Theme.accent : Theme.background))
                .overlay(Circle().stroke(Theme.accent, lineWidth: 2))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(verbatim: "\(index + 1), \(tour.steps[index].title)"))
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
                        Text(verbatim: "1 / 3")
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
                    (Text(quote.author).fontWeight(.bold) + Text(verbatim: "  \(quote.handle)").foregroundColor(Theme.textSecondary))
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
                momentRow(time: "4:10", text: String(localized: "When small-cap loans reset", bundle: .appStrings))
                momentRow(time: "11:32", text: String(localized: "What would change his view", bundle: .appStrings))
            }
        } else {
            pillGrid(tour.saveActions, note: nil)
        }
    }

    @ViewBuilder
    private var spotThree: some View {
        if platform == .youtube {
            pillGrid([
                TourAction(icon: "checkmark.circle", label: ItemStatus.watched.actionLabel),
                TourAction(icon: "clock", label: ItemStatus.watchLater.actionLabel),
                TourAction(icon: "heart", label: ItemStatus.liked.actionLabel),
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
                            Text(verbatim: "\(index + 1)")
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
            return TourContent(
                author: "Nova Lane", handle: String(localized: "New single", bundle: .appStrings), when: String(localized: "\(1)d", bundle: .appStrings), media: .video,
                title: "Paper Lanterns",
                text: String(localized: "New single by Nova Lane · 1 track · Pop", bundle: .appStrings),
                steps: [
                    TourStep(title: String(localized: "Listen here", bundle: .appStrings), body: String(localized: "Tap it to open Spotify's player and hear a preview right inside My Feeds.", bundle: .appStrings)),
                    TourStep(title: String(localized: "Heart to save", bundle: .appStrings), body: String(localized: "The heart saves it in My Feeds. Save adds it to Later.", bundle: .appStrings)),
                    TourStep(title: String(localized: "Play it in Spotify", bundle: .appStrings), body: String(localized: "\"Open in Spotify\" plays the full release in the Spotify app, where you can like it or add it to a playlist.", bundle: .appStrings)),
                ],
                saveActions: [TourAction(icon: "heart", label: String(localized: "Like", bundle: .appStrings)), TourAction(icon: "bookmark", label: String(localized: "Save", bundle: .appStrings))],
                outActions: [TourAction(icon: "arrow.up.right.square", label: "Spotify")],
                outNote: String(localized: "Opens Spotify", bundle: .appStrings)
            )
        case .youtube:
            return TourContent(
                author: "Two Minute Markets", handle: "YouTube", when: String(localized: "\(2)h", bundle: .appStrings), media: .video,
                title: String(localized: "Why small caps lag when rates rise", bundle: .appStrings),
                steps: [
                    TourStep(title: String(localized: "Play it here", bundle: .appStrings), body: String(localized: "Tap the video to watch it inside My Feeds. It remembers where you stopped.", bundle: .appStrings)),
                    TourStep(title: String(localized: "Jump to the good parts", bundle: .appStrings), body: String(localized: "Under the player, the summary lists the key moments. Tap a time to jump straight there.", bundle: .appStrings)),
                    TourStep(title: String(localized: "Keep track", bundle: .appStrings), body: String(localized: "Mark it Seen, Later or Liked from the card so your feed stays tidy.", bundle: .appStrings)),
                ]
            )
        case .x:
            return TourContent(
                author: "Lena Ortiz", handle: "@lena_builds", when: String(localized: "\(5)h", bundle: .appStrings), media: .text,
                text: String(localized: "Onboarding rewrite is live. A thread on what we cut and why.", bundle: .appStrings),
                quote: TourQuote(author: "Design Notes Daily", handle: "@designnotes", text: String(localized: "The best onboarding asks for one decision per screen.", bundle: .appStrings)),
                steps: [
                    TourStep(title: String(localized: "Read the whole post", bundle: .appStrings), body: String(localized: "Tap the post to open it. Photos, videos and quoted posts show in full inside My Feeds.", bundle: .appStrings)),
                    TourStep(title: String(localized: "Like or bookmark", bundle: .appStrings), body: String(localized: "Like saves it in My Feeds. Bookmark adds it to Read later.", bundle: .appStrings)),
                    TourStep(title: String(localized: "Reply or repost on X", bundle: .appStrings), body: String(localized: "Replying and reposting open X, because they post from your X account.", bundle: .appStrings)),
                ],
                saveActions: [TourAction(icon: "heart", label: String(localized: "Like", bundle: .appStrings)), TourAction(icon: "bookmark", label: String(localized: "Bookmark", bundle: .appStrings))],
                outActions: [TourAction(icon: "bubble.left", label: String(localized: "Reply", bundle: .appStrings)), TourAction(icon: "arrow.2.squarepath", label: String(localized: "Repost", bundle: .appStrings))],
                outNote: String(localized: "Opens X", bundle: .appStrings)
            )
        case .reddit:
            return TourContent(
                author: "r/PowerApps", handle: "u/canvas_dev", when: String(localized: "\(8)h", bundle: .appStrings), media: .text,
                title: String(localized: "Patching a collection without the delegation warning?", bundle: .appStrings),
                text: String(localized: "I've got a gallery over 2,000 rows and Patch keeps complaining. What's the cleanest way around it?", bundle: .appStrings),
                steps: [
                    TourStep(title: String(localized: "Open the post", bundle: .appStrings), body: String(localized: "Tap it to read the full post with its photos or video, plus a summary of the thread.", bundle: .appStrings)),
                    TourStep(title: String(localized: "Upvote to save", bundle: .appStrings), body: String(localized: "Upvote saves it in My Feeds, downvote marks it as read, and Save adds it to Read later.", bundle: .appStrings)),
                    TourStep(title: String(localized: "Comments open on Reddit", bundle: .appStrings), body: String(localized: "Tap the comment count to join the conversation on Reddit.", bundle: .appStrings)),
                ],
                saveActions: [
                    TourAction(icon: "arrowshape.up", label: String(localized: "Upvote", bundle: .appStrings)),
                    TourAction(icon: "arrowshape.down", label: String(localized: "Downvote", bundle: .appStrings)),
                    TourAction(icon: "bookmark", label: String(localized: "Save", bundle: .appStrings)),
                ],
                outActions: [TourAction(icon: "bubble.left.and.bubble.right", label: String(localized: "Comments", bundle: .appStrings))],
                outNote: String(localized: "Opens Reddit", bundle: .appStrings)
            )
        case .github:
            return TourContent(
                author: "openfeeds", handle: String(localized: "New release", bundle: .appStrings), when: String(localized: "\(1)d", bundle: .appStrings), media: .text,
                title: "openfeeds/parser v1.4.0",
                text: String(localized: "Release notes for the parser, with a short summary of what changed.", bundle: .appStrings),
                steps: [
                    TourStep(title: String(localized: "See what's new", bundle: .appStrings), body: String(localized: "Tap a new repository or release to read what it is, with a short summary.", bundle: .appStrings)),
                    TourStep(title: String(localized: "Star to save", bundle: .appStrings), body: String(localized: "Star saves it in My Feeds. Save adds it to Read later.", bundle: .appStrings)),
                    TourStep(title: String(localized: "Fork on GitHub", bundle: .appStrings), body: String(localized: "Forking opens GitHub, since it happens in your GitHub account.", bundle: .appStrings)),
                ],
                saveActions: [TourAction(icon: "star", label: String(localized: "Star", bundle: .appStrings)), TourAction(icon: "bookmark", label: String(localized: "Save", bundle: .appStrings))],
                outActions: [TourAction(icon: "arrow.triangle.branch", label: String(localized: "Fork", bundle: .appStrings))],
                outNote: String(localized: "Opens GitHub", bundle: .appStrings)
            )
        case .instagram:
            return TourContent(
                author: "Ember Kitchen", handle: "@emberkitchen", when: String(localized: "\(3)h", bundle: .appStrings), media: .photo,
                text: String(localized: "Three ways to use up leftover rice this week.", bundle: .appStrings),
                steps: [
                    TourStep(title: String(localized: "Photos and reels play here", bundle: .appStrings), body: String(localized: "Tap the post to open it. Swipe through carousels and play reels without leaving.", bundle: .appStrings)),
                    TourStep(title: String(localized: "Heart to save", bundle: .appStrings), body: String(localized: "The heart saves it in My Feeds, and the bookmark adds it to Read later.", bundle: .appStrings)),
                    TourStep(title: String(localized: "Comments open on Instagram", bundle: .appStrings), body: String(localized: "Commenting opens Instagram, because it posts from your account.", bundle: .appStrings)),
                ],
                saveActions: [TourAction(icon: "heart", label: String(localized: "Like", bundle: .appStrings)), TourAction(icon: "bookmark", label: String(localized: "Save", bundle: .appStrings))],
                outActions: [TourAction(icon: "bubble.left", label: String(localized: "Comment", bundle: .appStrings))],
                outNote: String(localized: "Opens Instagram", bundle: .appStrings)
            )
        case .linkedin:
            return TourContent(
                author: "Maya Chen", handle: String(localized: "Product lead", bundle: .appStrings), when: String(localized: "\(1)d", bundle: .appStrings), media: .text,
                text: String(localized: "We cut our onboarding from nine screens to three. Here's what we learned about asking for less up front.", bundle: .appStrings),
                steps: [
                    TourStep(title: String(localized: "Read the full post", bundle: .appStrings), body: String(localized: "Tap it to read the whole post and see its images inside My Feeds.", bundle: .appStrings)),
                    TourStep(title: String(localized: "Like to save", bundle: .appStrings), body: String(localized: "Like saves it in My Feeds. Save adds it to Read later.", bundle: .appStrings)),
                    TourStep(title: String(localized: "Comment and repost on LinkedIn", bundle: .appStrings), body: String(localized: "Those open LinkedIn, since they post from your account.", bundle: .appStrings)),
                ],
                saveActions: [TourAction(icon: "hand.thumbsup", label: String(localized: "Like", bundle: .appStrings)), TourAction(icon: "bookmark", label: String(localized: "Save", bundle: .appStrings))],
                outActions: [TourAction(icon: "bubble.left", label: String(localized: "Comment", bundle: .appStrings)), TourAction(icon: "arrow.2.squarepath", label: String(localized: "Repost", bundle: .appStrings))],
                outNote: String(localized: "Opens LinkedIn", bundle: .appStrings)
            )
        case .tiktok:
            return TourContent(
                author: "Ember Kitchen", handle: "@emberkitchen", when: String(localized: "\(4)h", bundle: .appStrings), media: .video,
                text: String(localized: "Crispy rice in 60 seconds.", bundle: .appStrings),
                steps: [
                    TourStep(title: String(localized: "Watch it here", bundle: .appStrings), body: String(localized: "Tap the video to play it inside My Feeds with TikTok's own player.", bundle: .appStrings)),
                    TourStep(title: String(localized: "Like to save", bundle: .appStrings), body: String(localized: "Like saves it in My Feeds. Save adds it to Read later.", bundle: .appStrings)),
                    TourStep(title: String(localized: "Comments open on TikTok", bundle: .appStrings), body: String(localized: "Commenting opens TikTok, because it posts from your account.", bundle: .appStrings)),
                ],
                saveActions: [TourAction(icon: "heart", label: String(localized: "Like", bundle: .appStrings)), TourAction(icon: "bookmark", label: String(localized: "Save", bundle: .appStrings))],
                outActions: [TourAction(icon: "bubble.left", label: String(localized: "Comment", bundle: .appStrings))],
                outNote: String(localized: "Opens TikTok", bundle: .appStrings)
            )
        case .facebook:
            return TourContent(
                author: "City Parks & Rec", handle: String(localized: "Page", bundle: .appStrings), when: String(localized: "\(6)h", bundle: .appStrings), media: .photo,
                text: String(localized: "The riverside trail reopens Saturday. Here's what changed.", bundle: .appStrings),
                steps: [
                    TourStep(title: String(localized: "Read and watch here", bundle: .appStrings), body: String(localized: "Tap the post to read it in full. Photos open large and videos play inside My Feeds.", bundle: .appStrings)),
                    TourStep(title: String(localized: "Like to save", bundle: .appStrings), body: String(localized: "Like saves it in My Feeds. Save adds it to Read later.", bundle: .appStrings)),
                    TourStep(title: String(localized: "Comments open on Facebook", bundle: .appStrings), body: String(localized: "Commenting opens Facebook, because it posts from your account.", bundle: .appStrings)),
                ],
                saveActions: [TourAction(icon: "hand.thumbsup", label: String(localized: "Like", bundle: .appStrings)), TourAction(icon: "bookmark", label: String(localized: "Save", bundle: .appStrings))],
                outActions: [TourAction(icon: "bubble.left", label: String(localized: "Comment", bundle: .appStrings))],
                outNote: String(localized: "Opens Facebook", bundle: .appStrings)
            )
        case .appleMusic:
            return TourContent(
                author: "Nova Lane", handle: String(localized: "New single", bundle: .appStrings), when: String(localized: "\(1)d", bundle: .appStrings), media: .video,
                title: "Paper Lanterns",
                text: String(localized: "New single by Nova Lane · 1 track · Pop", bundle: .appStrings),
                steps: [
                    TourStep(title: String(localized: "Listen here", bundle: .appStrings), body: String(localized: "Tap it to open Apple Music's player. You hear a preview, or the full songs if you're signed in to Apple Music.", bundle: .appStrings)),
                    TourStep(title: String(localized: "Heart to save", bundle: .appStrings), body: String(localized: "The heart saves it in My Feeds. Save adds it to Later.", bundle: .appStrings)),
                    TourStep(title: String(localized: "Add it to Apple Music", bundle: .appStrings), body: String(localized: "\"Add album to Apple Music\" puts the songs in your My Feeds playlist there, ready to download for offline.", bundle: .appStrings)),
                ],
                saveActions: [TourAction(icon: "heart", label: String(localized: "Like", bundle: .appStrings)), TourAction(icon: "bookmark", label: String(localized: "Save", bundle: .appStrings))],
                outActions: [TourAction(icon: "arrow.up.right.square", label: "Apple Music")],
                outNote: String(localized: "Opens Apple Music", bundle: .appStrings)
            )
        case .applePodcasts:
            return TourContent(
                author: "The Long Run", handle: String(localized: "Podcast", bundle: .appStrings), when: String(localized: "\(5)h", bundle: .appStrings), media: .video,
                title: String(localized: "Episode 212: Training through the winter", bundle: .appStrings),
                text: String(localized: "Full episode, played inside My Feeds.", bundle: .appStrings),
                steps: [
                    TourStep(title: String(localized: "Listen to the whole episode", bundle: .appStrings), body: String(localized: "Tap it to play the full episode here. It remembers where you stopped, on every device.", bundle: .appStrings)),
                    TourStep(title: String(localized: "Heart to save", bundle: .appStrings), body: String(localized: "The heart saves it in My Feeds. Save adds it to Later.", bundle: .appStrings)),
                    TourStep(title: String(localized: "Follow the show on Apple Podcasts", bundle: .appStrings), body: String(localized: "Following or rating the show opens Apple Podcasts.", bundle: .appStrings)),
                ],
                saveActions: [TourAction(icon: "heart", label: String(localized: "Like", bundle: .appStrings)), TourAction(icon: "bookmark", label: String(localized: "Save", bundle: .appStrings))],
                outActions: [TourAction(icon: "arrow.up.right.square", label: "Apple Podcasts")],
                outNote: String(localized: "Opens Apple Podcasts", bundle: .appStrings)
            )
        case .appleBooks:
            return TourContent(
                author: "Maya Ortiz", handle: String(localized: "Audiobook", bundle: .appStrings), when: String(localized: "\(2)d", bundle: .appStrings), media: .photo,
                title: "The Quiet Harbor",
                text: String(localized: "New audiobook by Maya Ortiz · Fiction", bundle: .appStrings),
                steps: [
                    TourStep(title: String(localized: "Hear a sample", bundle: .appStrings), body: String(localized: "Tap it to see the cover and description, and play Apple's sample right here.", bundle: .appStrings)),
                    TourStep(title: String(localized: "Heart to save", bundle: .appStrings), body: String(localized: "The heart saves it in My Feeds. Save adds it to Later.", bundle: .appStrings)),
                    TourStep(title: String(localized: "Listen in Apple Books", bundle: .appStrings), body: String(localized: "Buying and listening to the whole book opens Apple Books.", bundle: .appStrings)),
                ],
                saveActions: [TourAction(icon: "heart", label: String(localized: "Like", bundle: .appStrings)), TourAction(icon: "bookmark", label: String(localized: "Save", bundle: .appStrings))],
                outActions: [TourAction(icon: "arrow.up.right.square", label: "Apple Books")],
                outNote: String(localized: "Opens Apple Books", bundle: .appStrings)
            )
        case .youtubeMusic:
            return TourContent(
                author: "Nova Lane", handle: String(localized: "New album", bundle: .appStrings), when: String(localized: "\(1)d", bundle: .appStrings), media: .video,
                title: "Night Garden",
                text: String(localized: "New album by Nova Lane · 10 tracks", bundle: .appStrings),
                steps: [
                    TourStep(title: String(localized: "Listen here", bundle: .appStrings), body: String(localized: "Tap it to play the songs, or the music video, right inside My Feeds.", bundle: .appStrings)),
                    TourStep(title: String(localized: "Heart to save", bundle: .appStrings), body: String(localized: "The heart saves it in My Feeds. Save adds it to Later.", bundle: .appStrings)),
                    TourStep(title: String(localized: "Add it to YouTube Music", bundle: .appStrings), body: String(localized: "\"Add to YouTube Music\" puts the songs in your My Feeds playlist there, using your connected YouTube account.", bundle: .appStrings)),
                ],
                saveActions: [TourAction(icon: "heart", label: String(localized: "Like", bundle: .appStrings)), TourAction(icon: "bookmark", label: String(localized: "Save", bundle: .appStrings))],
                outActions: [TourAction(icon: "arrow.up.right.square", label: "YouTube Music")],
                outNote: String(localized: "Opens YouTube Music", bundle: .appStrings)
            )
        }
    }
}
