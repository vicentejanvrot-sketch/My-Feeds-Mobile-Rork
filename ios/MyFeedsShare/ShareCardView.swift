import LinkPresentation
import SwiftUI
import UIKit

// The Add to My Feeds card, used by the share extension and, in the app, by
// "Add from link" on People and myfeeds.ca/open/share links (this file is in
// both targets). Same flow as the web app's ShareAddCard and the Expo share
// screen: the account (post links show who posted), where it
// already is, a suggested collection, their other confirmed accounts,
// priority, and one Add for several collections or Unsorted, with Undo.

private extension Color {
    init(shareHSL hue: Double, _ saturation: Double, _ lightness: Double, alpha: Double = 1) {
        let s = saturation / 100
        let l = lightness / 100
        let brightness = l + s * min(l, 1 - l)
        let sat = brightness == 0 ? 0 : 2 * (1 - l / brightness)
        self.init(hue: hue / 360, saturation: sat, brightness: brightness, opacity: alpha)
    }
}

/// The app's palette (ios/MyFeeds/Utilities/Theme.swift).
private enum Palette {
    static let card = Color(shareHSL: 220, 30, 11)
    static let input = Color(shareHSL: 220, 30, 14)
    static let border = Color(shareHSL: 220, 15, 22)
    static let textPrimary = Color(shareHSL: 220, 20, 92)
    static let textSecondary = Color(shareHSL: 215, 15, 55)
    static let textMuted = Color(shareHSL: 220, 10, 42)
    static let accent = Color(shareHSL: 199, 89, 48)
    static let accentText = Color(shareHSL: 199, 89, 72)
    static let success = Color(shareHSL: 142, 71, 45)
    static let destructive = Color(shareHSL: 0, 84, 60)
}

@MainActor
@Observable
final class ShareModel {
    enum Step { case input, loading, error, card, picker, adding, done }

    var step: Step = .loading
    var error: String?
    var preview: SharePreview?
    var selected: [String] = []
    var addingMore = false
    var includeAlsoOn = true
    var priority = 3
    var added: [AddedChannel] = []
    var onClose: () -> Void = {}
    /// The link box, for "Add from link".
    var inputText = ""
    /// True when iOS shows the extension in its own sheet (not see-through):
    /// the card then fills the sheet.
    var inSheet = false
    /// "New collection" in the picker.
    var newOpen = false
    var newName = ""
    var creating = false

    private let api = ShareAPI()
    private var shared = ""

    /// allowTyping: with nothing shared, show the link box instead of an error.
    func start(shared: String, allowTyping: Bool = false) {
        self.shared = shared
        inputText = shared
        showQuick(for: shared)
        guard !shared.isEmpty else {
            if allowTyping {
                step = .input
            } else {
                error = "There was no link in what you shared. Share a profile or a post."
                step = .error
            }
            return
        }
        Task { await lookUp() }
    }

    func lookUpTyped() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        shared = text
        showQuick(for: text)
        Task { await lookUp() }
    }

    func lookUp() async {
        step = .loading
        error = nil
        do {
            let p = try await api.preview(shared)
            preview = p
            // Nothing is picked for the user: Add stays off until they choose.
            selected = []
            addingMore = false
            includeAlsoOn = true
            priority = 3
            step = .card
        } catch {
            self.error = error.localizedDescription
            step = .error
        }
    }

    var already: [SharePreview.Placement] { preview?.inCollections ?? [] }
    var alreadyNames: String { Self.join(already.map(\.agentName)) }
    var showAlreadyBox: Bool { step == .card && !already.isEmpty && !addingMore }
    var isSuggested: Bool {
        guard let s = preview?.suggestion, !addingMore else { return false }
        return selected == [s.agentId]
    }
    var alsoNames: String {
        var seen: [String] = []
        for a in preview?.alsoOn ?? [] {
            let label = Self.platformLabel(a.platform)
            if !seen.contains(label) { seen.append(label) }
        }
        return Self.join(seen)
    }

    func name(of id: String) -> String {
        id == ShareAPI.unsortedId ? "Unsorted" : preview?.collections.first { $0.id == id }?.name ?? ""
    }

    /// Collections A to Z, with Unsorted kept at the bottom.
    var pickerRows: [SharePreview.Collection] {
        var list = preview?.collections ?? []
        if !list.contains(where: { $0.name == "Unsorted" }) {
            list.append(SharePreview.Collection(id: ShareAPI.unsortedId, name: "Unsorted"))
        }
        return list.sorted { a, b in
            let au = a.id == ShareAPI.unsortedId || a.name == "Unsorted"
            let bu = b.id == ShareAPI.unsortedId || b.name == "Unsorted"
            if au != bu { return bu }
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }
    }

    func createNew() async {
        let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let current = preview, !name.isEmpty, !creating else { return }
        creating = true
        defer { creating = false }
        do {
            let made = try await api.createCollection(name: name, existing: current.collections)
            if !current.collections.contains(where: { $0.id == made.id }) {
                preview?.collections.append(made)
            }
            if !selected.contains(made.id) {
                selected.removeAll { $0 == ShareAPI.unsortedId }
                selected.append(made.id)
            }
            newName = ""
            newOpen = false
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    func toggle(_ id: String) {
        if already.contains(where: { $0.agentId == id }) { return }
        if let index = selected.firstIndex(of: id) {
            selected.remove(at: index)
        } else if id == ShareAPI.unsortedId {
            selected = [id]
        } else {
            selected.removeAll { $0 == ShareAPI.unsortedId }
            selected.append(id)
        }
    }

    var addLabel: String {
        switch selected.count {
        case 0: return "Pick a collection"
        case 1: return selected[0] == ShareAPI.unsortedId ? "Save to Unsorted" : "Add to \(name(of: selected[0]))"
        default: return "Add to \(selected.count) collections"
        }
    }

    func add() async {
        guard let preview, !selected.isEmpty else { return }
        step = .adding
        do {
            added = try await api.add(preview, agentIds: selected, priority: priority, includeAlsoOn: includeAlsoOn && !preview.alsoOn.isEmpty)
            step = .done
        } catch {
            self.error = error.localizedDescription
            step = .card
        }
    }

    func undo() async {
        do {
            try await api.undo(added)
            added = []
            step = .card
        } catch {
            self.error = error.localizedDescription
        }
    }

    static func join(_ names: [String]) -> String {
        switch names.count {
        case 0, 1: return names.joined()
        case 2: return "\(names[0]) and \(names[1])"
        default: return names.dropLast().joined(separator: ", ") + " and " + names.last!
        }
    }

    static func platformLabel(_ platform: String) -> String {
        [
            "youtube": "YouTube", "x": "X", "reddit": "Reddit", "instagram": "Instagram", "linkedin": "LinkedIn",
            "github": "GitHub", "tiktok": "TikTok", "facebook": "Facebook", "apple_music": "Apple Music",
            "apple_podcasts": "Apple Podcasts", "apple_books": "Apple Books", "youtube_music": "YouTube Music", "spotify": "Spotify",
        ][platform] ?? platform
    }

    static func plainName(_ name: String) -> String {
        name.replacingOccurrences(of: #"\s*\(@[^)]*\)\s*$"#, with: "", options: .regularExpression)
    }

    // MARK: Quick look

    /// Who the link is about, shown while the full lookup runs: the handle and
    /// platform from the link itself right away, then the name and picture from
    /// the page's own preview a moment later.
    var quick: QuickAccount?
    @ObservationIgnored private var quickToken = UUID()
    @ObservationIgnored private var metadataProvider: LPMetadataProvider?

    private func showQuick(for text: String) {
        let token = UUID()
        quickToken = token
        guard let parsed = QuickAccount.parse(text) else {
            quick = nil
            return
        }
        let (url, account) = parsed
        quick = account
        let provider = LPMetadataProvider()
        metadataProvider = provider
        provider.timeout = 8
        provider.startFetchingMetadata(for: url) { [weak self] metadata, _ in
            let title = metadata?.title
            let imageProvider = metadata?.imageProvider
            Task { @MainActor [weak self] in
                guard let self, self.quickToken == token else { return }
                if let title { self.quick?.applyTitle(title) }
            }
            imageProvider?.loadObject(ofClass: UIImage.self) { object, _ in
                let data = (object as? UIImage)?.jpegData(compressionQuality: 0.85)
                Task { @MainActor [weak self] in
                    guard let self, self.quickToken == token, let data else { return }
                    self.quick?.imageData = data
                }
            }
        }
    }
}

/// The account a shared link points to, as far as the link and its page preview tell.
struct QuickAccount {
    var platformLabel: String
    var handle: String?
    var name: String?
    var imageData: Data?

    var displayName: String {
        if let name, !name.isEmpty { return name }
        if let handle { return "@" + handle }
        return platformLabel
    }

    var subtitle: String {
        if let handle, name != nil, !(name ?? "").isEmpty { return "@\(handle) · \(platformLabel)" }
        return platformLabel
    }

    /// Page titles like "Joana Andreiolo (@joanaandreiolo) • Instagram photos and videos",
    /// "Name (@handle) / X", "Name (@handle) | TikTok" or "Name - YouTube".
    mutating func applyTitle(_ title: String) {
        var text = title
        if let range = text.range(of: #"\(@([A-Za-z0-9._]+)\)"#, options: .regularExpression) {
            let inside = text[range].dropFirst(2).dropLast()
            if handle == nil { handle = String(inside) }
            text = String(text[..<range.lowerBound])
        }
        for separator in [" • ", " | ", " / ", " - YouTube", " on Instagram", " on TikTok", " on X"] {
            if let range = text.range(of: separator) { text = String(text[..<range.lowerBound]) }
        }
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // A generic page title ("Instagram", "Log in") isn't a name.
        if !clean.isEmpty, !["instagram", "tiktok", "x", "facebook", "linkedin", "youtube", "reddit", "log in", "login"].contains(clean.lowercased()) {
            name = clean
        }
    }

    static func parse(_ text: String) -> (URL, QuickAccount)? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue),
              let match = detector.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let url = match.url,
              let host = url.host?.lowercased()
        else { return nil }
        let parts = url.path.split(separator: "/").map(String.init)
        func first(_ skip: Set<String>) -> String? {
            guard let p = parts.first, !skip.contains(p.lowercased()) else { return nil }
            return p
        }
        let is_ = { (domain: String) in host == domain || host.hasSuffix("." + domain) }
        if is_("instagram.com") {
            if parts.first?.lowercased() == "stories", parts.count > 1 { return (url, QuickAccount(platformLabel: "Instagram", handle: parts[1])) }
            return (url, QuickAccount(platformLabel: "Instagram", handle: first(["p", "reel", "reels", "tv", "explore", "share", "accounts"])))
        }
        if is_("tiktok.com") {
            let h = parts.first(where: { $0.hasPrefix("@") }).map { String($0.dropFirst()) }
            return (url, QuickAccount(platformLabel: "TikTok", handle: h))
        }
        if is_("x.com") || is_("twitter.com") {
            return (url, QuickAccount(platformLabel: "X", handle: first(["i", "home", "search", "intent", "share", "hashtag", "explore"])))
        }
        if is_("youtube.com") || host == "youtu.be" {
            let h = parts.first(where: { $0.hasPrefix("@") }).map { String($0.dropFirst()) }
            return (url, QuickAccount(platformLabel: "YouTube", handle: h))
        }
        if is_("facebook.com") || is_("fb.com") {
            return (url, QuickAccount(platformLabel: "Facebook", handle: first(["share", "profile.php", "watch", "groups", "events", "reel", "photo", "story.php", "permalink.php"])))
        }
        if is_("linkedin.com") {
            let h = parts.count > 1 && ["in", "company"].contains(parts[0].lowercased()) ? parts[1] : nil
            return (url, QuickAccount(platformLabel: "LinkedIn", handle: h))
        }
        if is_("reddit.com") {
            let h = parts.count > 1 && ["r", "u", "user"].contains(parts[0].lowercased()) ? parts[1] : nil
            return (url, QuickAccount(platformLabel: "Reddit", handle: h))
        }
        return nil
    }
}

struct ShareCardView: View {
    @Bindable var model: ShareModel

    private let priorityNames = [1: "Lowest", 2: "Low", 3: "Normal", 4: "High", 5: "Highest"]

    var body: some View {
        ZStack(alignment: model.inSheet ? .top : .bottom) {
            // See-through: the app behind stays visible. Tapping it closes the card.
            // Inside an iOS sheet there's nothing to see through, so it's the card's colour.
            (model.inSheet ? Palette.card : Color.clear)
                .contentShape(Rectangle())
                .ignoresSafeArea()
                .onTapGesture { if !model.inSheet { model.onClose() } }
                .accessibilityLabel("Close")

            VStack(spacing: 0) {
                Capsule().fill(Palette.border).frame(width: 38, height: 5).padding(.top, 10).padding(.bottom, 12)
                VStack(alignment: .leading, spacing: 18) {
                    header
                    content
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 28)
            }
            .frame(maxWidth: 560)
            .background {
                UnevenRoundedRectangle(topLeadingRadius: 22, topTrailingRadius: 22)
                    .fill(Palette.card)
                    .overlay {
                        // The outline only shows on the floating card. Inside an
                        // iOS sheet it would draw a line where the card ends.
                        if !model.inSheet {
                            UnevenRoundedRectangle(topLeadingRadius: 22, topTrailingRadius: 22)
                                .stroke(Palette.border, lineWidth: 1)
                        }
                    }
                    .ignoresSafeArea(edges: .bottom)
            }
        }
        .preferredColorScheme(.dark)
        .animation(.easeOut(duration: 0.2), value: model.step)
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 10) {
            if model.step == .picker {
                roundButton(systemImage: "chevron.left", label: "Back") { model.step = .card }
            } else {
                Image(systemName: "dot.radiowaves.up.forward")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Palette.accent)
                    .frame(width: 32, height: 32)
                    .background(Palette.input, in: RoundedRectangle(cornerRadius: 8))
            }
            Text(model.step == .picker ? "Choose collections" : "Add to My Feeds")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Palette.textPrimary)
            Spacer()
            roundButton(systemImage: "xmark", label: "Close") { model.onClose() }
        }
    }

    // MARK: Content

    @ViewBuilder
    private var content: some View {
        switch model.step {
        case .input:
            inputView
        case .loading:
            loading
        case .error:
            errorView
        case .card, .adding:
            if let preview = model.preview {
                accountRow(preview)
                if preview.account.isPrivate == true { privateNote(preview) }
                if model.showAlreadyBox { alreadyBox } else { form(preview) }
            }
        case .picker:
            if let preview = model.preview {
                accountRow(preview)
                picker(preview)
            }
        case .done:
            if let preview = model.preview { done(preview) }
        }
    }

    private var inputView: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Paste a profile or post link from YouTube, X, Instagram, LinkedIn, TikTok, Facebook or Reddit.")
                .font(.system(size: 14))
                .foregroundStyle(Palette.textSecondary)
            HStack(spacing: 8) {
                TextField("", text: $model.inputText, prompt: Text("https://www.instagram.com/name").foregroundStyle(Palette.textMuted))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .submitLabel(.go)
                    .onSubmit { model.lookUpTyped() }
                    .font(.system(size: 15))
                    .foregroundStyle(Palette.textPrimary)
                    .padding(.horizontal, 14)
                    .frame(height: 48)
                    .background(Palette.input, in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.border))
                    .accessibilityLabel("Profile or post link")
                PasteButton(payloadType: String.self) { strings in
                    if let text = strings.first {
                        model.inputText = text
                        model.lookUpTyped()
                    }
                }
                .labelStyle(.iconOnly)
                .buttonBorderShape(.roundedRectangle(radius: 12))
                .tint(Palette.input)
                .frame(height: 48)
            }
            primaryButton("Find account") { model.lookUpTyped() }
                .disabled(model.inputText.trimmingCharacters(in: .whitespaces).isEmpty)
                .opacity(model.inputText.trimmingCharacters(in: .whitespaces).isEmpty ? 0.45 : 1)
        }
    }

    private var loading: some View {
        VStack(alignment: .leading, spacing: 18) {
            if let quick = model.quick {
                // What the link already tells: shown while the rest loads.
                HStack(spacing: 14) {
                    Group {
                        if let data = quick.imageData, let image = UIImage(data: data) {
                            Image(uiImage: image).resizable().scaledToFill()
                        } else {
                            Text(String(quick.displayName.replacingOccurrences(of: "@", with: "").prefix(1)).uppercased())
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(Palette.textPrimary)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .background(Palette.input)
                        }
                    }
                    .frame(width: 54, height: 54)
                    .clipShape(Circle())
                    VStack(alignment: .leading, spacing: 3) {
                        Text(quick.displayName)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(Palette.textPrimary)
                            .lineLimit(1)
                        Text(quick.subtitle)
                            .font(.system(size: 14))
                            .foregroundStyle(Palette.textSecondary)
                            .lineLimit(1)
                    }
                }
                .animation(.easeOut(duration: 0.2), value: quick.imageData)
            } else {
                HStack(spacing: 14) {
                    Circle().fill(Palette.input).frame(width: 54, height: 54)
                    VStack(alignment: .leading, spacing: 8) {
                        RoundedRectangle(cornerRadius: 6).fill(Palette.input).frame(width: 160, height: 14)
                        RoundedRectangle(cornerRadius: 6).fill(Palette.input).frame(width: 100, height: 11)
                    }
                }
            }
            HStack(spacing: 10) {
                ProgressView().tint(Palette.accent)
                Text("Looking up the account…").font(.system(size: 14)).foregroundStyle(Palette.textSecondary)
            }
        }
    }

    private var errorView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(model.error ?? "Something went wrong.")
                .font(.system(size: 15))
                .foregroundStyle(Palette.textPrimary)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Palette.destructive.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.destructive.opacity(0.5)))
            HStack(spacing: 10) {
                secondaryButton("Try another link") { model.step = .input }
                primaryButton("Try again") { Task { await model.lookUp() } }
            }
        }
    }

    private func accountRow(_ preview: SharePreview) -> some View {
        HStack(spacing: 14) {
            AsyncImage(url: preview.account.thumbnail.flatMap(URL.init(string:))) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Text(String(ShareModel.plainName(preview.account.name).prefix(1)).uppercased())
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Palette.textPrimary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Palette.input)
            }
            .frame(width: 54, height: 54)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(ShareModel.plainName(preview.account.name))
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Palette.textPrimary)
                    .lineLimit(1)
                Text(handleLine(preview))
                    .font(.system(size: 14))
                    .foregroundStyle(Palette.textSecondary)
                    .lineLimit(1)
                Text(preview.kind == "post" ? "From a post you shared. This is who posted it." : "From the profile you shared.")
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.textMuted)
            }
        }
    }

    /// A private account is added as one: it shows on People, its posts never come in.
    private func privateNote(_ preview: SharePreview) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lock.fill")
                .font(.system(size: 13))
                .foregroundStyle(Palette.textMuted)
            VStack(alignment: .leading, spacing: 2) {
                Text("Private account")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Palette.textPrimary)
                Text("It's added as a private account: it shows on People with a button to open it in \(preview.platformLabel). Its posts won't appear in your feed.")
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(13)
        .background(Palette.input, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.border))
    }

    private func handleLine(_ preview: SharePreview) -> String {
        guard let handle = preview.account.handle, !handle.isEmpty, Int(handle) == nil else { return preview.platformLabel }
        return (preview.platform == "linkedin" ? "" : "@") + handle + " · " + preview.platformLabel
    }

    private var alreadyBox: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "checkmark").font(.system(size: 17, weight: .bold)).foregroundStyle(Palette.success)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Already in \(model.alreadyNames)").font(.system(size: 15, weight: .semibold)).foregroundStyle(Palette.textPrimary)
                    Text("You already get their posts in My Feeds.").font(.system(size: 13)).foregroundStyle(Palette.textSecondary)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.success.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.success.opacity(0.35)))
            HStack(spacing: 10) {
                secondaryButton("Add to another") {
                    model.addingMore = true
                    model.selected = []
                    model.step = .picker
                }
                primaryButton("Done") { model.onClose() }
            }
        }
    }

    private func form(_ preview: SharePreview) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            if model.addingMore {
                Label("Already in \(model.alreadyNames)", systemImage: "checkmark")
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.success)
            }
            if let error = model.error, model.step == .card {
                Text(error).font(.system(size: 13)).foregroundStyle(Palette.destructive)
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    sectionLabel("Collection")
                    Spacer()
                    Button("Change") { model.step = .picker }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Palette.accent)
                }
                FlowChips(items: model.selected.map { model.name(of: $0) }) { model.step = .picker }
                if model.selected.isEmpty {
                    Button { model.step = .picker } label: {
                        Text("Pick a collection")
                            .font(.system(size: 14))
                            .foregroundStyle(Palette.textSecondary)
                            .padding(.horizontal, 14)
                            .frame(height: 38)
                            .overlay(Capsule().stroke(Palette.border, style: StrokeStyle(lineWidth: 1, dash: [4])))
                    }
                }
                if model.isSuggested, let reason = preview.suggestion?.reason {
                    Label {
                        Text("Suggested. \(reason)")
                    } icon: {
                        Image(systemName: "sparkles").foregroundStyle(Palette.accent)
                    }
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.textSecondary)
                }
            }

            if !preview.alsoOn.isEmpty {
                Toggle(isOn: $model.includeAlsoOn) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Also on \(model.alsoNames)").font(.system(size: 14, weight: .semibold)).foregroundStyle(Palette.textPrimary)
                        Text("Same person, matched from their profile links. Add those too?")
                            .font(.system(size: 12))
                            .foregroundStyle(Palette.textSecondary)
                    }
                }
                .tint(Palette.accent)
                .padding(13)
                .background(Palette.input, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.border))
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    sectionLabel("Priority")
                    Spacer()
                    Text("\(model.priority) · \(priorityNames[model.priority] ?? "")")
                        .font(.system(size: 13))
                        .foregroundStyle(Palette.textSecondary)
                }
                HStack(spacing: 8) {
                    ForEach(1...5, id: \.self) { n in
                        Button { model.priority = n } label: {
                            Text("\(n)")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(n == model.priority ? .white : Palette.textPrimary)
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .background(n == model.priority ? Palette.accent : Palette.input, in: RoundedRectangle(cornerRadius: 10))
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(n == model.priority ? Palette.accent : Palette.border))
                        }
                        .accessibilityAddTraits(n == model.priority ? .isSelected : [])
                    }
                }
            }

            Button {
                Task { await model.add() }
            } label: {
                HStack(spacing: 8) {
                    if model.step == .adding { ProgressView().tint(.white) } else { Image(systemName: "plus") }
                    Text(model.addLabel)
                }
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(Palette.accent.opacity(model.selected.isEmpty ? 0.4 : 1), in: RoundedRectangle(cornerRadius: 12))
            }
            .disabled(model.selected.isEmpty || model.step == .adding)
        }
    }

    private func picker(_ preview: SharePreview) -> some View {
        VStack(spacing: 14) {
            if model.newOpen {
                HStack(spacing: 8) {
                    TextField("", text: $model.newName, prompt: Text("New collection name").foregroundStyle(Palette.textMuted))
                        .submitLabel(.done)
                        .onSubmit { Task { await model.createNew() } }
                        .font(.system(size: 15))
                        .foregroundStyle(Palette.textPrimary)
                        .padding(.horizontal, 14)
                        .frame(height: 48)
                        .background(Palette.input, in: RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.border))
                        .accessibilityLabel("New collection name")
                    let canCreate = !model.newName.trimmingCharacters(in: .whitespaces).isEmpty && !model.creating
                    Button {
                        Task { await model.createNew() }
                    } label: {
                        Group {
                            if model.creating { ProgressView().tint(.white) } else { Text("Create") }
                        }
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .frame(minHeight: 48)
                        .background(Palette.accent.opacity(canCreate ? 1 : 0.4), in: RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(!canCreate)
                    roundButton(systemImage: "xmark", label: "Cancel new collection") {
                        model.newOpen = false
                        model.newName = ""
                    }
                }
            } else {
                Button { model.newOpen = true } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                        Text("New collection")
                        Spacer()
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Palette.accent)
                    .padding(.horizontal, 14)
                    .frame(minHeight: 48)
                    .background(Palette.input, in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.border))
                }
            }
            if let error = model.error {
                Text(error).font(.system(size: 13)).foregroundStyle(Palette.destructive)
            }
            ScrollView {
            VStack(spacing: 0) {
                ForEach(Array(model.pickerRows.enumerated()), id: \.element.id) { index, row in
                    let locked = model.already.contains { $0.agentId == row.id }
                    let checked = locked || model.selected.contains(row.id)
                    let note = locked ? "Already here" : row.id == ShareAPI.unsortedId ? "Sort it later" : row.id == preview.suggestion?.agentId ? "Suggested" : ""
                    Button { model.toggle(row.id) } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(checked ? (locked ? Palette.textMuted : Palette.accent) : .clear)
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(checked ? .clear : Palette.textMuted, lineWidth: 1.5)
                                if checked {
                                    Image(systemName: "checkmark").font(.system(size: 12, weight: .heavy)).foregroundStyle(.white)
                                }
                            }
                            .frame(width: 22, height: 22)
                            Text(row.name).font(.system(size: 15)).foregroundStyle(Palette.textPrimary).lineLimit(1)
                            Spacer()
                            if !note.isEmpty {
                                Text(note).font(.system(size: 12)).foregroundStyle(Palette.textSecondary)
                            }
                        }
                        .padding(.horizontal, 14)
                        .frame(minHeight: 52)
                        .contentShape(Rectangle())
                    }
                    .disabled(locked)
                    .accessibilityAddTraits(checked ? .isSelected : [])
                    if index < model.pickerRows.count - 1 { Divider().overlay(Palette.border) }
                }
            }
            }
            .frame(maxHeight: 380)
            .fixedSize(horizontal: false, vertical: model.pickerRows.count <= 7)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.border))
            primaryButton("Done") { model.step = .card }
                .opacity(model.selected.isEmpty ? 0.45 : 1)
                .disabled(model.selected.isEmpty)
        }
    }

    private func done(_ preview: SharePreview) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Palette.success)
                .frame(width: 64, height: 64)
                .background(Palette.success.opacity(0.15), in: Circle())
            Text("Added \(ShareModel.plainName(preview.account.name))")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Palette.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.top, 4)
            Text("to \(ShareModel.join(model.selected.map { model.name(of: $0) }))")
                .font(.system(size: 15))
                .foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.center)
            if model.includeAlsoOn && !preview.alsoOn.isEmpty {
                Text("Their \(model.alsoNames) accounts were added too.")
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.textMuted)
            }
            primaryButton("Close") { model.onClose() }
                .padding(.top, 12)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Pieces

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 12, weight: .semibold))
            .tracking(0.8)
            .foregroundStyle(Palette.textSecondary)
    }

    private func roundButton(systemImage: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Palette.textSecondary)
                .frame(width: 36, height: 36)
                .background(Palette.input, in: Circle())
        }
        .accessibilityLabel(label)
    }

    private func primaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(Palette.accent, in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private func secondaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Palette.textPrimary)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(Palette.input, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.border))
        }
    }
}

/// The chosen collections as chips that wrap onto new lines.
private struct FlowChips: View {
    let items: [String]
    let onTap: () -> Void

    var body: some View {
        WrapLayout(spacing: 8) {
            ForEach(items, id: \.self) { name in
                Button(action: onTap) {
                    Text(name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Palette.accentText)
                        .padding(.horizontal, 14)
                        .frame(height: 38)
                        .background(Palette.accent.opacity(0.14), in: Capsule())
                        .overlay(Capsule().stroke(Palette.accent.opacity(0.55)))
                }
            }
        }
    }
}

private struct WrapLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, maxX: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > width {
                y += rowHeight + spacing
                x = 0
                rowHeight = 0
            }
            x += size.width + spacing
            maxX = max(maxX, x - spacing)
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: proposal.width ?? maxX, height: subviews.isEmpty ? 0 : y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > bounds.minX && x + size.width > bounds.maxX {
                y += rowHeight + spacing
                x = bounds.minX
                rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
