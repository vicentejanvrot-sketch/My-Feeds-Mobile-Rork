import SwiftUI

/// Following: everyone the user follows across their agents, grouped into
/// people and companies, with the other platforms each one is on ("Also on").
/// Same screen as /following on the web and expo/app/following.tsx.
struct FollowingView: View {
    @Environment(ToastCenter.self) private var toasts
    @Environment(\.openURL) private var openURL

    @State private var channels: [Channel] = []
    @State private var links: [IdentityLink] = []
    @State private var scans: [IdentityScan] = []
    @State private var agents: [Agent] = []
    @State private var people: [AlsoOnPerson] = []
    @State private var isLoading = true
    @State private var loadError: String?
    @State private var tab: FollowingTab = .everyone
    @State private var query = ""
    @State private var selectedId: String?
    @State private var progress: ScanProgress?
    @State private var busyKeys: Set<String> = []

    private var isScanning: Bool { progress != nil }

    private var sortedAgents: [Agent] {
        agents.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var agentNames: [String: String] {
        Dictionary(agents.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
    }

    private var filtered: [AlsoOnPerson] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return people }
        return people.filter { person in
            person.name.lowercased().contains(q) || person.following.contains { $0.label.lowercased().contains(q) }
        }
    }

    private var gapCount: Int {
        people.reduce(0) { $0 + $1.also.count + $1.possible.count }
    }

    private var skippedCount: Int {
        channels.filter { !AlsoOn.isPersonSource($0) }.count
    }

    /// Sources never checked, or checked more than 30 days ago.
    private var toScan: [String] {
        let staleBefore = Date().addingTimeInterval(-Double(AlsoOn.rescanAfterDays) * 24 * 60 * 60)
        let scannedIds = Set(scans.map { $0.channelId })
        var scannedAt: [String: Date] = [:]
        for scan in scans {
            if let date = Format.parseDate(scan.scannedAt) { scannedAt[scan.channelId] = date }
        }
        return people.flatMap { $0.sources }.filter { ch in
            guard scannedIds.contains(ch.id) else { return true }
            guard let date = scannedAt[ch.id] else { return false }
            return date < staleBefore
        }.map { $0.id }
    }

    private var maxCost: String {
        String(format: "%.2f", Double(toScan.count * AlsoOn.maxLookupsPerSource) * AlsoOn.aisaPricePerCall)
    }

    private var selectedPerson: AlsoOnPerson? {
        guard let selectedId else { return nil }
        return people.first { $0.id == selectedId }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Everyone you follow across your agents, and where else they are.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.bottom, 14)

                HStack(spacing: 8) {
                    tabSwitcher
                    searchField
                }
                .padding(.bottom, 14)

                if let progress { progressBox(progress) }

                if let loadError {
                    Text("Couldn't load this screen: " + loadError)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.destructive)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(Theme.destructiveBg)
                        .clipShape(.rect(cornerRadius: 10))
                        .padding(.bottom, 12)
                }

                if !isLoading && scans.isEmpty && !people.isEmpty && !isScanning {
                    introCard
                }

                if isLoading {
                    ProgressView()
                        .controlSize(.large)
                        .tint(Theme.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 60)
                } else if tab == .everyone {
                    everyoneList
                } else {
                    gapsList
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 40)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Theme.background)
        .navigationTitle("Following")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .toolbar {
            if showScanButton {
                ToolbarItem(placement: .topBarTrailing) { scanButton }
            }
        }
        .refreshable { await load() }
        .task { await load() }
        .sheet(isPresented: Binding(
            get: { selectedPerson != nil },
            set: { if !$0 { selectedId = nil } }
        )) {
            if let person = selectedPerson {
                PersonSheet(
                    person: person,
                    agents: sortedAgents,
                    agentNames: agentNames,
                    isScanning: isScanning,
                    busyKeys: busyKeys,
                    onFollow: { account, agentId in follow(account, agentId: agentId) },
                    onDecide: { account, same in decide(account, same: same) },
                    onRescan: { Task { await runScan(person.sources.map { $0.id }) } },
                    onClose: { selectedId = nil }
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(Theme.background)
            }
        }
    }

    // MARK: - Header pieces

    /// Shown only while checking or when some sources still need a check.
    private var showScanButton: Bool {
        isScanning || (!isLoading && !toScan.isEmpty)
    }

    /// Plain toolbar button so the nav bar draws it like its other buttons.
    private var scanButton: some View {
        Button {
            Task { await runScan(toScan) }
        } label: {
            HStack(spacing: 6) {
                if isScanning {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 13, weight: .semibold))
                }
                Text(isScanning ? "Checking" : "Check \(toScan.count)")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(Theme.accent)
        }
        .disabled(isScanning)
        .accessibilityLabel(isScanning ? "Checking sources" : "Check \(toScan.count) sources")
    }

    /// Everyone / Gaps switch, styled like the web tabs: a muted track with
    /// the active tab set in the page background colour.
    private var tabSwitcher: some View {
        HStack(spacing: 0) {
            tabButton("Everyone", value: .everyone)
            tabButton("Gaps · \(gapCount)", value: .gaps)
        }
        .padding(3)
        .background(Theme.input)
        .clipShape(.rect(cornerRadius: 9))
        .fixedSize()
    }

    private func tabButton(_ title: String, value: FollowingTab) -> some View {
        let active = tab == value
        return Button {
            tab = value
        } label: {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(active ? Theme.textPrimary : Theme.textSecondary)
                .lineLimit(1)
                .padding(.horizontal, 12)
                .frame(height: 30)
                .background(active ? Theme.background : Color.clear)
                .clipShape(.rect(cornerRadius: 7))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(active ? .isSelected : [])
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13))
                .foregroundStyle(Theme.textMuted)
            TextField("", text: $query, prompt: Text("Search people").foregroundStyle(Theme.textMuted))
                .font(.system(size: 14))
                .foregroundStyle(Theme.textPrimary)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Theme.textMuted)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity)
        .frame(height: 36)
        .background(Theme.input)
        .clipShape(.rect(cornerRadius: 9))
        .overlay(RoundedRectangle(cornerRadius: 9).stroke(Theme.border, lineWidth: 0.5))
    }

    private func progressBox(_ progress: ScanProgress) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ProgressView(value: Double(progress.done), total: Double(max(progress.total, 1)))
                .tint(Theme.accent)
            Text("Checked \(progress.done) of \(progress.total)" + (progress.failed > 0 ? " · \(progress.failed) couldn't be checked" : ""))
                .font(.system(size: 12))
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(.bottom, 12)
    }

    private var introCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Find where the people you follow also post")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
            Text("Checks each of your \(people.count) people and companies once: the links on their profile, their link-in-bio page and website, and the same handle on other platforms. It uses at most \(AlsoOn.maxLookupsPerSource) AIsa lookups per source, so up to about $" + maxCost + " for this first check.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                Task { await runScan(toScan) }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 13, weight: .bold))
                    Text("Check \(toScan.count) sources")
                        .font(.system(size: 14, weight: .bold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 42)
                .background(Theme.accent)
                .clipShape(.rect(cornerRadius: 10))
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .cardStyle(radius: 12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.accent.opacity(0.5), lineWidth: 1))
        .padding(.bottom, 14)
    }

    // MARK: - Everyone

    private var everyoneList: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 14) {
                legendItem("You follow", variant: .following)
                legendItem("Also there", variant: .also)
                legendItem("Possible match", variant: .possible)
                Spacer(minLength: 0)
            }

            VStack(spacing: 0) {
                if filtered.isEmpty {
                    Text(people.isEmpty ? "No people or companies in your agents yet." : "Nobody matches that search.")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(20)
                } else {
                    ForEach(Array(filtered.enumerated()), id: \.element.id) { index, person in
                        if index > 0 {
                            Rectangle().fill(Theme.border).frame(height: 0.5)
                        }
                        PersonRow(person: person, agentNames: rowAgentNames(person)) {
                            selectedId = person.id
                        }
                    }
                }
            }
            .cardStyle(radius: 12)

            if skippedCount > 0 {
                Text("\(skippedCount)" + (skippedCount == 1 ? " subreddit isn't" : " subreddits aren't") + " listed here, since they aren't people or companies.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textMuted)
                    .padding(.top, 4)
            }
        }
    }

    private func legendItem(_ label: String, variant: ChipVariant) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(variant == .following ? Theme.input : Color.clear)
                .overlay(Circle().strokeBorder(variant.border, style: StrokeStyle(lineWidth: 1, dash: variant == .possible ? [2, 2] : [])))
                .frame(width: 12, height: 12)
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(Theme.textSecondary)
        }
    }

    private func rowAgentNames(_ person: AlsoOnPerson) -> String {
        person.agentIds.compactMap { agentNames[$0] }.joined(separator: ", ")
    }

    // MARK: - Gaps

    private var gapsList: some View {
        let withGaps = filtered.filter { !$0.also.isEmpty }
        let checks = filtered.flatMap { person in person.possible.map { GapCheck(person: person, account: $0) } }
        return VStack(alignment: .leading, spacing: 12) {
            if withGaps.isEmpty && checks.isEmpty {
                Text("No gaps. You follow everyone everywhere we found them.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(20)
                    .cardStyle(radius: 12)
            }

            if !withGaps.isEmpty {
                Text("People you follow who are also somewhere you don't follow them yet.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
            }

            ForEach(withGaps) { person in
                VStack(alignment: .leading, spacing: 0) {
                    Button {
                        selectedId = person.id
                    } label: {
                        HStack(spacing: 10) {
                            PersonAvatar(name: person.name, url: person.thumbnail, size: 36)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(person.name)
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(Theme.textPrimary)
                                    .lineLimit(1)
                                Text(gapSubtitle(person))
                                    .font(.system(size: 12))
                                    .foregroundStyle(Theme.textSecondary)
                                    .lineLimit(1)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    ForEach(person.also) { account in
                        Rectangle().fill(Theme.border).frame(height: 0.5)
                        HStack(alignment: .center, spacing: 10) {
                            VStack(alignment: .leading, spacing: 4) {
                                AccountLine(platform: account.platform, label: account.label, url: account.url)
                                if let evidence = account.link.evidence, !evidence.isEmpty {
                                    Text(evidence)
                                        .font(.system(size: 12))
                                        .foregroundStyle(Theme.textSecondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            Spacer(minLength: 0)
                            FollowButton(
                                isBusy: busyKeys.contains(account.key),
                                isEnabled: person.agentIds.first != nil
                            ) {
                                if let agentId = person.agentIds.first { follow(account, agentId: agentId) }
                            }
                        }
                        .padding(12)
                    }
                }
                .cardStyle(radius: 12)
            }

            if !checks.isEmpty {
                SectionHeader(title: "Needs your check")
                ForEach(checks) { item in
                    PossibleMatchCard(
                        question: item.question,
                        account: item.account,
                        isBusy: busyKeys.contains(item.account.link.id)
                    ) { same in
                        decide(item.account, same: same)
                    }
                }
            }
        }
    }

    private func gapSubtitle(_ person: AlsoOnPerson) -> String {
        let platforms: String = person.following.map { $0.platform.label }.joined(separator: " and ")
        let agent: String = person.agentIds.first.flatMap { agentNames[$0] } ?? "agent"
        return "You follow on " + platforms + " · adds to " + agent
    }

    // MARK: - Data

    private func load() async {
        let service = SupabaseService.shared
        do {
            async let channelsTask = service.fetchAllChannels()
            async let linksTask = service.fetchIdentityLinks()
            async let scansTask = service.fetchIdentityScans()
            async let agentsTask = service.fetchAgents()
            let (loadedChannels, loadedLinks, loadedScans, loadedAgents) = try await (channelsTask, linksTask, scansTask, agentsTask)
            channels = loadedChannels
            links = loadedLinks
            scans = loadedScans
            agents = loadedAgents
            loadError = nil
            rebuild()
        } catch {
            loadError = error.localizedDescription
        }
        isLoading = false
    }

    private func reloadIdentity() async {
        let service = SupabaseService.shared
        if let loaded = try? await service.fetchIdentityLinks() { links = loaded }
        if let loaded = try? await service.fetchIdentityScans() { scans = loaded }
        rebuild()
    }

    private func rebuild() {
        people = AlsoOn.buildPeople(channels: channels, links: links, scans: scans)
    }

    /// Checks sources two at a time and shows progress, like the web and Expo apps.
    private func runScan(_ ids: [String]) async {
        guard progress == nil, !ids.isEmpty else { return }
        let total = ids.count
        var done = 0
        var failed = 0
        var firstError: String?
        progress = ScanProgress(done: 0, total: total, failed: 0)

        await withTaskGroup(of: String?.self) { group in
            var pending = ids.makeIterator()
            for _ in 0..<2 {
                guard let id = pending.next() else { break }
                group.addTask { await Self.check(channelId: id) }
            }
            while let result = await group.next() {
                if let result {
                    failed += 1
                    if firstError == nil { firstError = result }
                }
                done += 1
                progress = ScanProgress(done: done, total: total, failed: failed)
                await reloadIdentity()
                if let id = pending.next() {
                    group.addTask { await Self.check(channelId: id) }
                }
            }
        }

        progress = nil
        if failed > 0 {
            toasts.show("\(failed) of \(total) couldn't be checked: " + (firstError ?? ""), type: .error)
        } else {
            toasts.show(total == 1 ? "Checked for other platforms" : "Checked \(total) sources")
        }
    }

    /// Returns nil when the check worked, or the reason it failed.
    private static func check(channelId: String) async -> String? {
        do {
            try await SupabaseService.shared.findAlsoOn(channelId: channelId)
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    /// Adds the account to an agent, then opens it on its own platform so the
    /// user can follow there too (LinkedIn and Instagram don't let apps do that).
    private func follow(_ account: AlsoOnFoundAccount, agentId: String) {
        guard !busyKeys.contains(account.key) else { return }
        busyKeys.insert(account.key)
        Task {
            defer {
                if let link = AlsoOn.platformFollowURL(platform: account.platform, url: account.url) {
                    openURL(link)
                }
            }
            do {
                try await SupabaseService.shared.followAccount(platform: account.platform, url: account.url, agentId: agentId)
                toasts.show("Added. Follow on " + account.platform.label + " to finish")
                if let loaded = try? await SupabaseService.shared.fetchAllChannels() {
                    channels = loaded
                    rebuild()
                }
            } catch {
                toasts.show(error.localizedDescription, type: .error)
            }
            busyKeys.remove(account.key)
        }
    }

    private func decide(_ account: AlsoOnFoundAccount, same: Bool) {
        let busyKey = account.link.id
        guard !busyKeys.contains(busyKey) else { return }
        busyKeys.insert(busyKey)
        Task {
            do {
                try await SupabaseService.shared.decideIdentityLink(id: account.link.id, same: same)
                toasts.show(same ? "Marked as the same person" : "Removed that match")
                await reloadIdentity()
            } catch {
                toasts.show("Couldn't save that: " + error.localizedDescription, type: .error)
            }
            busyKeys.remove(busyKey)
        }
    }
}

/// "Not checked yet" / "Only on X" / "On 3 platforms · 1 you don't follow · 1 to check"
/// Lives here (main actor) because SourcePlatform.label does.
private extension AlsoOnPerson {
    var summary: String {
        var parts: [String] = []
        if lastScannedAt == nil {
            parts.append("Not checked yet")
        } else if platformCount == 1, let only = following.first {
            parts.append("Only on " + only.platform.label)
        } else {
            parts.append("On \(platformCount) platforms")
        }
        if !also.isEmpty { parts.append("\(also.count) you don't follow") }
        if !possible.isEmpty { parts.append("\(possible.count) to check") }
        return parts.joined(separator: " · ")
    }
}

private enum FollowingTab: Hashable {
    case everyone
    case gaps
}

private struct GapCheck: Identifiable {
    let person: AlsoOnPerson
    let account: AlsoOnFoundAccount

    var id: String { account.link.id }

    var question: String {
        let platform: String = account.platform.label
        return "Is \(account.label) on \(platform) the same \(person.name) you follow?"
    }
}

private struct ScanProgress: Equatable {
    var done: Int
    var total: Int
    var failed: Int
}

private enum ChipVariant {
    case following
    case also
    case possible

    var border: Color {
        switch self {
        case .following: return Theme.input
        case .also: return Theme.accent
        case .possible: return Theme.textMuted
        }
    }
}

// MARK: - Person row

private struct PersonRow: View {
    let person: AlsoOnPerson
    let agentNames: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 12) {
                PersonAvatar(name: person.name, url: person.thumbnail)
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(person.name)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.textPrimary)
                            .lineLimit(1)
                        if !agentNames.isEmpty {
                            Text(agentNames)
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.textMuted)
                                .lineLimit(1)
                        }
                    }
                    FlowLayout(spacing: 6) {
                        ForEach(person.following) { account in
                            PlatformChip(platform: account.platform, variant: .following)
                        }
                        ForEach(person.also) { account in
                            PlatformChip(platform: account.platform, variant: .also)
                        }
                        ForEach(person.possible) { account in
                            PlatformChip(platform: account.platform, variant: .possible)
                        }
                    }
                    Text(person.summary)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.textMuted)
                    .padding(.top, 4)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct PlatformChip: View {
    let platform: SourcePlatform
    let variant: ChipVariant

    var body: some View {
        HStack(spacing: 5) {
            PlatformBadge(platform: platform, size: 14)
            Text(platform.label + (variant == .possible ? "?" : ""))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(variant == .possible ? Theme.textSecondary : Theme.textPrimary)
        }
        .padding(.leading, 6)
        .padding(.trailing, 10)
        .padding(.vertical, 4)
        .background(variant == .following ? Theme.input : Color.clear)
        .clipShape(Capsule())
        .overlay(
            Capsule().strokeBorder(variant.border, style: StrokeStyle(lineWidth: 1, dash: variant == .possible ? [3, 3] : []))
        )
        .accessibilityElement(children: .combine)
    }
}

private struct PersonAvatar: View {
    let name: String
    let url: String?
    var size: CGFloat = 40

    var body: some View {
        ZStack {
            Circle().fill(Theme.input)
            Text(AlsoOn.initials(name))
                .font(.system(size: size * 0.34, weight: .bold))
                .foregroundStyle(Theme.textSecondary)
            if let url, let imageURL = URL(string: url) {
                AsyncImage(url: imageURL) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        Color.clear
                    }
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .accessibilityHidden(true)
    }
}

private struct AccountLine: View {
    @Environment(\.openURL) private var openURL
    let platform: SourcePlatform
    let label: String
    let url: String

    var body: some View {
        Button {
            if let link = URL(string: url) { openURL(link) }
        } label: {
            HStack(spacing: 6) {
                PlatformBadge(platform: platform, size: 16)
                Text(platform.label)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text(label)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
                Image(systemName: "arrow.up.right.square")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textMuted)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(platform.label + " " + label)
        .accessibilityAddTraits(.isLink)
    }
}

private struct FollowButton: View {
    let isBusy: Bool
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if isBusy {
                    ProgressView().controlSize(.small).tint(.white)
                } else {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 13))
                    Text("Follow")
                        .font(.system(size: 13, weight: .bold))
                }
            }
            .foregroundStyle(.white)
            .frame(minWidth: 86, minHeight: 36)
            .padding(.horizontal, 12)
            .background(Theme.accent)
            .clipShape(.rect(cornerRadius: 10))
            .opacity(isEnabled ? 1 : 0.5)
        }
        .buttonStyle(.plain)
        .disabled(isBusy || !isEnabled)
    }
}

private struct DecisionButtons: View {
    let isBusy: Bool
    let onDecide: (Bool) -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button {
                onDecide(true)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                    Text("Same person")
                        .font(.system(size: 14, weight: .bold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(Theme.accent)
                .clipShape(.rect(cornerRadius: 10))
            }
            .buttonStyle(.plain)

            Button {
                onDecide(false)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                    Text("Not them")
                        .font(.system(size: 14, weight: .bold))
                }
                .foregroundStyle(Theme.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(Theme.card)
                .clipShape(.rect(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.border, lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .disabled(isBusy)
        .opacity(isBusy ? 0.6 : 1)
    }
}

private struct PossibleMatchCard: View {
    var question: String?
    let account: AlsoOnFoundAccount
    let isBusy: Bool
    let onDecide: (Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let question {
                Text(question)
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            AccountLine(platform: account.platform, label: account.label, url: account.url)
            if let name = account.link.displayName, !name.isEmpty {
                Text("Name on that profile: " + name)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
            }
            if let evidence = account.link.evidence, !evidence.isEmpty {
                Text(evidence)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.warning)
                    .fixedSize(horizontal: false, vertical: true)
            }
            DecisionButtons(isBusy: isBusy, onDecide: onDecide)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Theme.textMuted, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
        )
    }
}

// MARK: - Person sheet

private struct PersonSheet: View {
    let person: AlsoOnPerson
    let agents: [Agent]
    let agentNames: [String: String]
    let isScanning: Bool
    let busyKeys: Set<String>
    let onFollow: (AlsoOnFoundAccount, String) -> Void
    let onDecide: (AlsoOnFoundAccount, Bool) -> Void
    let onRescan: () -> Void
    let onClose: () -> Void

    @State private var agentId: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header

                sectionTitle("You follow")
                VStack(spacing: 0) {
                    ForEach(Array(person.following.enumerated()), id: \.element.id) { index, account in
                        if index > 0 {
                            Rectangle().fill(Theme.border).frame(height: 0.5)
                        }
                        HStack(spacing: 10) {
                            AccountLine(platform: account.platform, label: account.label, url: account.url)
                            Spacer(minLength: 0)
                            Text(agentNames[account.channel.agentId] ?? "Agent")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Theme.textSecondary)
                                .lineLimit(1)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Theme.input)
                                .clipShape(Capsule())
                        }
                        .padding(12)
                    }
                }
                .cardStyle(radius: 10)

                if !person.also.isEmpty { alsoSection }

                if !person.possible.isEmpty {
                    sectionTitle("Possible match")
                    VStack(spacing: 10) {
                        ForEach(person.possible) { account in
                            PossibleMatchCard(
                                account: account,
                                isBusy: busyKeys.contains(account.link.id)
                            ) { same in
                                onDecide(account, same)
                            }
                        }
                    }
                }

                if person.lastScannedAt != nil && person.also.isEmpty && person.possible.isEmpty {
                    Text("No other accounts found. Their profile doesn't link anywhere we can follow, and the same handle isn't on X, Instagram or YouTube.")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 16)
                }

                footer
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .padding(.bottom, 30)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.background)
        .overlay { ToastHost() }
        .onAppear { agentId = person.agentIds.first }
        .onChange(of: person.id) { agentId = person.agentIds.first }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            PersonAvatar(name: person.name, url: person.thumbnail, size: 56)
            VStack(alignment: .leading, spacing: 4) {
                Text(person.name)
                    .font(.system(size: 19, weight: .heavy))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(2)
                Text(person.summary)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer(minLength: 0)
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 32, height: 32)
                    .background(Theme.input)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
        }
    }

    private var alsoSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionTitle("Also on")
            if agents.count > 1 {
                HStack(spacing: 8) {
                    Text("Add to")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textSecondary)
                    Picker("Add to", selection: $agentId) {
                        ForEach(agents) { agent in
                            Text(agent.name).tag(agent.id as String?)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(Theme.accent)
                    Spacer(minLength: 0)
                }
                .padding(.bottom, 8)
            }
            VStack(spacing: 0) {
                ForEach(Array(person.also.enumerated()), id: \.element.id) { index, account in
                    if index > 0 {
                        Rectangle().fill(Theme.border).frame(height: 0.5)
                    }
                    HStack(alignment: .center, spacing: 10) {
                        VStack(alignment: .leading, spacing: 4) {
                            AccountLine(platform: account.platform, label: account.label, url: account.url)
                            if let evidence = account.link.evidence, !evidence.isEmpty {
                                HStack(alignment: .top, spacing: 5) {
                                    Image(systemName: "link")
                                        .font(.system(size: 11))
                                    Text(evidence)
                                        .font(.system(size: 12))
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .foregroundStyle(Theme.success)
                            }
                            Button {
                                onDecide(account, false)
                            } label: {
                                Text("Not them? Remove this match")
                                    .font(.system(size: 12))
                                    .underline()
                                    .foregroundStyle(Theme.textMuted)
                            }
                            .buttonStyle(.plain)
                            .disabled(busyKeys.contains(account.link.id))
                        }
                        Spacer(minLength: 0)
                        FollowButton(
                            isBusy: busyKeys.contains(account.key),
                            isEnabled: agentId != nil
                        ) {
                            if let agentId { onFollow(account, agentId) }
                        }
                    }
                    .padding(12)
                }
            }
            .cardStyle(radius: 10)
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 10) {
            Rectangle().fill(Theme.border).frame(height: 0.5)
            HStack(spacing: 10) {
                Text(person.lastScannedAt.map { "Checked " + Format.relativeTime($0) } ?? "Not checked yet")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
                Spacer(minLength: 0)
                Button(action: onRescan) {
                    HStack(spacing: 6) {
                        if isScanning {
                            ProgressView().controlSize(.small).tint(Theme.accent)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 12, weight: .bold))
                        }
                        Text(person.lastScannedAt == nil ? "Check now" : "Check again")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .foregroundStyle(Theme.textPrimary)
                    .padding(.horizontal, 12)
                    .frame(height: 34)
                    .background(Theme.card)
                    .clipShape(.rect(cornerRadius: 9))
                    .overlay(RoundedRectangle(cornerRadius: 9).stroke(Theme.border, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .disabled(isScanning)
            }
            if let problem = person.scanErrors.first {
                Text("Last check had a problem: " + problem)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.warning)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text("Matches come from links on their own profiles, their link-in-bio page and website, and the same handle on other platforms. A handle alone is only ever a possible match.")
                .font(.system(size: 11))
                .foregroundStyle(Theme.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 20)
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 12, weight: .bold))
            .kerning(0.6)
            .foregroundStyle(Theme.textSecondary)
            .padding(.top, 20)
            .padding(.bottom, 8)
    }
}

// MARK: - Flow layout

/// Lays chips out left to right, wrapping onto new lines.
private struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var widest: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            widest = max(widest, x - spacing)
        }
        let width = maxWidth.isFinite ? maxWidth : widest
        return CGSize(width: width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX && x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
