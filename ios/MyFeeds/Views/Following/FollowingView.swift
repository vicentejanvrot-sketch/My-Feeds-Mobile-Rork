import SwiftUI

/// Following: everyone the user follows across their agents, grouped into
/// people and companies, with the other platforms each one is on ("Also on").
/// Same screen as /following on the web and expo/app/following.tsx.
struct FollowingView: View {
    @Environment(ToastCenter.self) private var toasts
    @Environment(AppRouter.self) private var router
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
    /// nil = all agents
    @State private var agentFilter: String?

    /// initialAgentId: opened from a collection or the Feeds tab, showing
    /// that collection's people.
    init(initialAgentId: String? = nil) {
        _agentFilter = State(initialValue: initialAgentId)
    }
    @State private var selectedId: String?
    /// Two cards being combined (or separated) right now.
    @State private var isCombining = false
    @State private var progress: ScanProgress?
    @State private var busyKeys: Set<String> = []

    private var isScanning: Bool { progress != nil }

    private var sortedAgents: [Agent] {
        agents.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var agentNames: [String: String] {
        Dictionary(agents.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
    }

    /// People followed in the chosen agent (a person can be in several).
    private var inAgent: [AlsoOnPerson] {
        guard let agentFilter else { return people }
        return people.filter { $0.agentIds.contains(agentFilter) }
    }

    private var filtered: [AlsoOnPerson] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return inAgent }
        return inAgent.filter { person in
            person.name.lowercased().contains(q) || person.following.contains { $0.label.lowercased().contains(q) }
        }
    }

    private var gapCount: Int {
        inAgent.reduce(0) { $0 + $1.also.count + $1.possible.count }
    }

    private var skippedCount: Int {
        channels.filter { !AlsoOn.isPersonSource($0) }.count
    }

    /// One search per person, covering all of their sources, when any of them
    /// was never checked or was checked more than 30 days ago.
    private var toScan: [ScanJob] {
        let staleBefore = Date().addingTimeInterval(-Double(AlsoOn.rescanAfterDays) * 24 * 60 * 60)
        let scannedIds = Set(scans.map { $0.channelId })
        var scannedAt: [String: Date] = [:]
        for scan in scans {
            if let date = Format.parseDate(scan.scannedAt) { scannedAt[scan.channelId] = date }
        }
        return people.filter { person in
            person.sources.contains { ch in
                guard scannedIds.contains(ch.id) else { return true }
                guard let date = scannedAt[ch.id] else { return false }
                return date < staleBefore
            }
        }.map(Self.job)
    }

    private static func job(for person: AlsoOnPerson) -> ScanJob {
        ScanJob(name: person.name, channelIds: person.sources.map { $0.id })
    }

    private var maxCost: String {
        let lookups = toScan.reduce(0) { $0 + AlsoOn.maxLookups(sources: $1.channelIds.count) }
        return String(format: "%.2f", Double(lookups) * AlsoOn.aisaPricePerCall)
    }

    private var selectedPerson: AlsoOnPerson? {
        guard let selectedId else { return nil }
        return people.first { $0.id == selectedId }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Everyone you follow across your collections, and where else they are.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.bottom, 14)

                HStack(spacing: 8) {
                    tabSwitcher
                    searchField
                }
                .padding(.bottom, 14)

                agentFilterChips

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
        .navigationTitle("People")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    router.shareRequest = ShareRequest(text: "")
                } label: {
                    Image(systemName: "link.badge.plus")
                        .font(.system(size: 15, weight: .semibold))
                }
                .accessibilityLabel("Add from link")
            }
            if showScanButton {
                ToolbarItem(placement: .topBarTrailing) { scanButton }
            }
        }
        // Someone added from a link: show them.
        .onChange(of: router.shareRequest == nil) { _, closed in
            if closed { Task { await load() } }
        }
        .refreshable { await load() }
        .task {
            await load()
            await AccountConnections.shared.load()
        }
        // A darker background behind the person sheet, so the list doesn't
        // pull the eye.
        .onChange(of: selectedPerson != nil) { _, isOpen in SheetDimmer.shared.set(isOpen) }
        .onDisappear { SheetDimmer.shared.set(false) }
        .sheet(isPresented: Binding(
            get: { selectedPerson != nil },
            set: { if !$0 { selectedId = nil } }
        )) {
            if let person = selectedPerson {
                PersonSheet(
                    person: person,
                    people: people,
                    agents: sortedAgents,
                    agentNames: agentNames,
                    isScanning: isScanning,
                    scanStatus: progress?.status,
                    busyKeys: busyKeys,
                    onFollow: { account, agentId in follow(account, agentId: agentId) },
                    onDecide: { account, same in decide(account, same: same) },
                    onRemove: { account in remove(account) },
                    onRescan: { Task { await runScan([Self.job(for: person)]) } },
                    isCombining: isCombining,
                    onCombine: { other in combine(person, with: other) },
                    onSeparate: { separate(person) },
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
                Text(isScanning ? "Searching" : "Find more (\(toScan.count))")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(Theme.accent)
        }
        .disabled(isScanning)
        .accessibilityLabel(isScanning ? "Searching" : "Find more accounts for \(toScan.count) " + (toScan.count == 1 ? "person" : "people"))
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

    /// Filter by agent: "All agents" plus each agent, as chips.
    @ViewBuilder
    private var agentFilterChips: some View {
        if agents.count > 1 {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    agentChip("All collections", id: nil)
                    ForEach(sortedAgents) { agent in
                        agentChip(agent.name, id: agent.id)
                    }
                }
            }
            .padding(.bottom, 14)
        }
    }

    private func agentChip(_ title: String, id: String?) -> some View {
        let active = agentFilter == id
        return Button {
            agentFilter = id
        } label: {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(active ? Theme.textPrimary : Theme.textSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(active ? Theme.accent.opacity(0.15) : Theme.input)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(active ? Theme.accent : Theme.border, lineWidth: 1))
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
            Text(progress.status + (progress.failed > 0 ? " · \(progress.failed) couldn't be searched" : ""))
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
            Text("Checks each of your \(people.count) people and companies once: the links on their profile, their link-in-bio page and website, and handles like theirs on other platforms. Each person is searched once, across all the places you follow them, using at most \(AlsoOn.maxLookupsPerPerson) to 30 AIsa lookups, so up to about $" + maxCost + " for this first check.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                Task { await runScan(toScan) }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 13, weight: .bold))
                    Text("Check \(toScan.count) " + (toScan.count == 1 ? "person" : "people"))
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
                    Text(people.isEmpty ? "No people or companies in your collections yet." : "Nobody matches that search.")
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
                                Text(gapSubtitle(person))
                                    .font(.system(size: 12))
                                    .foregroundStyle(Theme.textSecondary)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    ForEach(person.also) { account in
                        Rectangle().fill(Theme.border).frame(height: 0.5)
                        VStack(alignment: .leading, spacing: 10) {
                            VStack(alignment: .leading, spacing: 4) {
                                AccountLine(platform: account.platform, label: account.label, url: account.url)
                                if let evidence = account.link.evidence, !evidence.isEmpty {
                                    Text(evidence)
                                        .font(.system(size: 12))
                                        .foregroundStyle(Theme.textSecondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            HStack(spacing: 8) {
                                FollowButton(
                                    isBusy: busyKeys.contains(account.key),
                                    isEnabled: person.agentIds.first != nil,
                                    openInstead: SourcePlatform.isFollowableAccount(account.platform, url: account.url)
                                        ? nil
                                        : URL(string: account.url).map { (label: account.platform.openLabel, url: $0) }
                                ) {
                                    if let agentId = person.agentIds.first { follow(account, agentId: agentId) }
                                }
                                DeleteSuggestionButton(isBusy: busyKeys.contains(account.link.id)) {
                                    decide(account, same: false)
                                }
                                Spacer(minLength: 0)
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

    /// Stops following one of a person's accounts: removes that source from its
    /// collection. Posts already in the feed stay.
    private func remove(_ account: AlsoOnFollowedAccount) {
        let removed = account.channel
        channels.removeAll { $0.id == removed.id }
        rebuild()
        Task {
            do {
                try await SupabaseService.shared.deleteChannel(id: removed.id)
                toasts.show("Removed. You no longer follow them on \(account.platform.label) here.")
            } catch {
                channels.append(removed)
                rebuild()
                toasts.show("Couldn't remove it: \(error.localizedDescription)", type: .error)
            }
        }
    }

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
            // A cancelled load (leaving the screen) isn't an error to show.
            if !error.isCancellation { loadError = error.localizedDescription }
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

    /// Searches people two at a time and shows who is being checked, like the
    /// web and Expo apps. Each person is one request with all of their sources.
    private func runScan(_ jobs: [ScanJob]) async {
        let list = jobs.filter { !$0.channelIds.isEmpty }
        guard progress == nil, !list.isEmpty else { return }
        let total = list.count
        var done = 0
        var failed = 0
        var firstError: String?
        var current: [String] = []
        progress = ScanProgress(done: 0, total: total, failed: 0, current: [])

        await withTaskGroup(of: (String, String?).self) { group in
            var pending = list.makeIterator()
            for _ in 0..<2 {
                guard let job = pending.next() else { break }
                current.append(job.name)
                group.addTask { (job.name, await Self.check(channelIds: job.channelIds)) }
            }
            progress = ScanProgress(done: done, total: total, failed: failed, current: current)
            while let finished = await group.next() {
                let (name, result) = finished
                if let result {
                    failed += 1
                    if firstError == nil { firstError = name + ": " + result }
                }
                done += 1
                if let index = current.firstIndex(of: name) { current.remove(at: index) }
                if let job = pending.next() {
                    current.append(job.name)
                    group.addTask { (job.name, await Self.check(channelIds: job.channelIds)) }
                }
                progress = ScanProgress(done: done, total: total, failed: failed, current: current)
                await reloadIdentity()
            }
        }

        progress = nil
        if failed > 0 {
            toasts.show("\(failed) of \(total) couldn't be checked. " + (firstError ?? ""), type: .error)
        } else {
            toasts.show(total == 1 ? "Searched other platforms for \(list[0].name)" : "Searched other platforms for \(total) people")
        }
    }

    /// Returns nil when the check worked, or the reason it failed.
    private static func check(channelIds: [String]) async -> String? {
        do {
            try await SupabaseService.shared.findAlsoOn(channelIds: channelIds)
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    /// "Add": puts the account in the chosen collection, so its posts reach
    /// the feed. Where the user connected that platform (YouTube, GitHub,
    /// Reddit), it also follows the account there; the other platforms don't
    /// let apps follow for their users, and the account's own link (next to
    /// its name) is there for following by hand. Same as the web and Expo.
    private func follow(_ account: AlsoOnFoundAccount, agentId: String) {
        guard !busyKeys.contains(account.key) else { return }
        busyKeys.insert(account.key)
        Task {
            defer { busyKeys.remove(account.key) }
            do {
                try await SupabaseService.shared.followAccount(platform: account.platform, url: account.url, agentId: agentId)
            } catch {
                toasts.show(error.localizedDescription, type: .error)
                return
            }
            if let loaded = try? await SupabaseService.shared.fetchAllChannels() {
                channels = loaded
                rebuild()
            }
            let label = account.platform.label
            if account.platform == .youtube, YouTubeAccount.shared.isConnected {
                do {
                    let already = try await YouTubeAccount.shared.subscribe(channelURL: account.url)
                    toasts.show(already ? "Added. You were already subscribed on YouTube" : "Added and subscribed on YouTube")
                } catch {
                    toasts.show("Added, but couldn't subscribe on YouTube: " + error.localizedDescription, type: .error)
                }
            } else if let provider = AccountConnections.Provider(platform: account.platform),
                      AccountConnections.shared.isConnected(provider) {
                do {
                    let already = try await AccountConnections.shared.follow(provider, url: account.url)
                    toasts.show(already ? "Added. You already follow them on \(label)" : "Added and following on \(label)")
                } catch {
                    toasts.show("Added, but couldn't follow on \(label): " + error.localizedDescription, type: .error)
                }
            } else {
                toasts.show("Added to your collection")
            }
        }
    }

    /// Keeps the sheet on this person after their cards change: their card id
    /// can change when cards are combined or separated, so they're found again
    /// by one of their sources.
    private func reselect(sourceId: String?) {
        guard let sourceId,
              let person = people.first(where: { $0.sources.contains { $0.id == sourceId } }) else { return }
        selectedId = person.id
    }

    /// "Combine": joins two cards that are the same person (someone added twice
    /// under a name the search couldn't tie together). Same as the web and Expo.
    private func combine(_ person: AlsoOnPerson, with other: AlsoOnPerson) {
        guard !isCombining else { return }
        isCombining = true
        Task {
            defer { isCombining = false }
            do {
                try await SupabaseService.shared.combinePeople(person, with: other)
                await reloadIdentity()
                reselect(sourceId: person.sources.first?.id)
                toasts.show("Combined with \(other.name)")
            } catch {
                toasts.show("Couldn't combine them: " + error.localizedDescription, type: .error)
            }
        }
    }

    /// Undoes "Combine": the cards combined into this one become their own again.
    private func separate(_ person: AlsoOnPerson) {
        guard !isCombining else { return }
        isCombining = true
        Task {
            defer { isCombining = false }
            do {
                try await SupabaseService.shared.separatePerson(person)
                await reloadIdentity()
                reselect(sourceId: person.sources.first?.id)
                toasts.show("Separated into their own cards again")
            } catch {
                toasts.show("Couldn't separate them: " + error.localizedDescription, type: .error)
            }
        }
    }

    private func decide(_ account: AlsoOnFoundAccount, same: Bool) {
        let busyKey = account.link.id
        guard !busyKeys.contains(busyKey) else { return }
        busyKeys.insert(busyKey)
        Task {
            do {
                // Every source of this person, so the answer lands on each copy of the match.
                let channelIds = people.first { person in
                    person.sources.contains { $0.id == account.link.channelId }
                }?.sources.map(\.id) ?? [account.link.channelId]
                try await SupabaseService.shared.decideIdentityLink(account.link, channelIds: channelIds, same: same)
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
            parts.append("Not searched yet")
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

/// One search: a person and every source they're followed through.
nonisolated private struct ScanJob: Sendable {
    let name: String
    let channelIds: [String]
}

private struct ScanProgress: Equatable {
    var done: Int
    var total: Int
    var failed: Int
    /// Names of the people being searched right now.
    var current: [String]

    /// "Checking Taylor Swift…", or "Checking Taylor Swift and Madonna…" when
    /// two run at once.
    var status: String {
        let now: String
        switch current.count {
        case 0: now = "Finishing…"
        case 1: now = "Checking \(current[0])…"
        default: now = "Checking " + current.dropLast().joined(separator: ", ") + " and " + (current.last ?? "") + "…"
        }
        return total > 1 ? now + " · \(done) of \(total) people done" : now
    }
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
                        if !agentNames.isEmpty {
                            Text(agentNames)
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.textMuted)
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
            // The platform name never wraps ("YouTub/e"); the handle gives way
            // and truncates instead.
            HStack(spacing: 6) {
                PlatformBadge(platform: platform, size: 16)
                Text(platform.label)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                    .fixedSize()
                Text(label)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
                    .layoutPriority(-1)
                Image(systemName: "arrow.up.right.square")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textMuted)
                    .fixedSize()
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
    /// Spotify artist pages and shows can't be followed as sources: the button
    /// opens them instead (label and link).
    var openInstead: (label: String, url: URL)? = nil
    let action: () -> Void

    @Environment(\.openURL) private var openURL

    var body: some View {
        if let openInstead {
            Button {
                openURL(openInstead.url)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.up.right.square")
                        .font(.system(size: 13))
                    Text(openInstead.label)
                        .font(.system(size: 13, weight: .bold))
                        .lineLimit(1)
                }
                .foregroundStyle(Theme.textPrimary)
                .frame(minHeight: 36)
                .padding(.horizontal, 12)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.border, lineWidth: 1))
            }
            .buttonStyle(.plain)
        } else {
            followButton
        }
    }

    private var followButton: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if isBusy {
                    ProgressView().controlSize(.small).tint(.white)
                } else {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 13))
                    Text("Add")
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
    let people: [AlsoOnPerson]
    let agents: [Agent]
    let agentNames: [String: String]
    let isScanning: Bool
    /// "Checking Taylor Swift…" while a search runs.
    let scanStatus: String?
    let busyKeys: Set<String>
    let onFollow: (AlsoOnFoundAccount, String) -> Void
    let onDecide: (AlsoOnFoundAccount, Bool) -> Void
    let onRemove: (AlsoOnFollowedAccount) -> Void
    let onRescan: () -> Void
    let isCombining: Bool
    /// Combines this person with another card.
    let onCombine: (AlsoOnPerson) -> Void
    let onSeparate: () -> Void
    let onClose: () -> Void

    @Environment(\.openURL) private var openURL
    @State private var agentId: String?
    /// Picking the card to combine with, shown in place of the details.
    @State private var isPicking = false
    @State private var pickId: String?
    @State private var pickQuery = ""
    @State private var confirmSeparate = false

    private var twins: [AlsoOnPerson] { AlsoOn.sameName(as: person, in: people) }

    private func startCombine() {
        pickId = twins.count == 1 ? twins.first?.id : nil
        pickQuery = ""
        isPicking = true
    }
    /// The followed account waiting for "Remove?" to be confirmed.
    @State private var toRemove: AlsoOnFollowedAccount?

    private var removeMessage: String {
        guard let account = toRemove else { return "" }
        let collection = agentNames[account.channel.agentId] ?? "your collection"
        var text = "\(account.label) is removed from \(collection), so new posts from it stop coming in. What's already in your feed stays."
        if person.following.count == 1 {
            text += " This is the only account you follow for them, so they'll leave your People list."
        }
        return text
    }

    var body: some View {
        ScrollView {
            if isPicking {
                combinePicker
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                    .padding(.bottom, 14)
                    .frame(maxWidth: 720)
                    .frame(maxWidth: .infinity)
            } else {
                details
            }
        }
        // Scrolled content stops 16 pt above the sheet's bottom edge, the same
        // gap as the sides, and is clipped with rounded corners there, so the
        // phone's own rounded corners never cut through buttons or text.
        .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: 24, bottomTrailingRadius: 24, style: .continuous))
        .padding(.bottom, 16)
        .ignoresSafeArea(.container, edges: .bottom)
        .background(Theme.background)
        .overlay { ToastHost() }
        .onAppear { agentId = person.agentIds.first }
        .onChange(of: person.id) {
            agentId = person.agentIds.first
            isPicking = false
        }
        // Combined: the picked card's accounts are now on this one.
        .onChange(of: person.sources.count) { isPicking = false }
        .alert("Separate \(person.name)'s cards?", isPresented: $confirmSeparate) {
            Button("Cancel", role: .cancel) {}
            Button("Separate") { onSeparate() }
        } message: {
            Text("The cards you combined go back to being separate cards. Nothing is removed from your collections.")
        }
    }

    private var details: some View {
            VStack(alignment: .leading, spacing: 0) {
                header

                if people.count > 1 {
                    Button(action: startCombine) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.triangle.merge")
                                .font(.system(size: 12, weight: .bold))
                            Text("Combine with another card")
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
                    .padding(.top, 12)
                    .accessibilityLabel("Combine with another card that's the same person")
                }

                if !twins.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("\(twins.count == 1 ? "Another card is" : "\(twins.count) other cards are") also called \(Text(person.name).bold()). If it's the same person, combine them so all their accounts are on one card.")
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        Button(action: startCombine) {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.triangle.merge")
                                    .font(.system(size: 13, weight: .bold))
                                Text(twins.count == 1 ? "Combine with that card" : "Choose which to combine")
                                    .font(.system(size: 14, weight: .bold))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .frame(height: 38)
                            .background(Theme.accent)
                            .clipShape(.rect(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.accent.opacity(0.08))
                    .clipShape(.rect(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.accent.opacity(0.4), lineWidth: 1))
                    .padding(.top, 14)
                }

                sectionTitle("You follow")
                VStack(spacing: 0) {
                    ForEach(Array(person.following.enumerated()), id: \.element.id) { index, account in
                        if index > 0 {
                            Rectangle().fill(Theme.border).frame(height: 0.5)
                        }
                        // Account on the first line, collection underneath, so
                        // nothing has to squeeze onto one line on a narrow phone.
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 4) {
                                AccountLine(platform: account.platform, label: account.label, url: account.url)
                                Text(agentNames[account.channel.agentId] ?? "Collection")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(Theme.textSecondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Theme.input)
                                    .clipShape(Capsule())
                                if account.channel.isPrivateAccount {
                                    Label("Private account. Its posts aren't in your feed.", systemImage: "lock.fill")
                                        .font(.system(size: 11))
                                        .foregroundStyle(Theme.textMuted)
                                        .lineLimit(2)
                                        .fixedSize(horizontal: false, vertical: true)
                                    Button {
                                        if let link = URL(string: account.url) { openURL(link) }
                                    } label: {
                                        Text(account.platform.openLabel)
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundStyle(Theme.textPrimary)
                                            .lineLimit(1)
                                            .padding(.horizontal, 10)
                                            .frame(height: 30)
                                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border, lineWidth: 1))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            Button {
                                toRemove = account
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 14))
                                    .foregroundStyle(Theme.textMuted)
                                    .frame(width: 36, height: 36)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Remove \(account.platform.label) \(account.label)")
                        }
                        .padding(.vertical, 6)
                        .padding(.leading, 12)
                        .padding(.trailing, 4)
                    }
                }
                .cardStyle(radius: 10)
                .alert(
                    "Remove \(person.name) on \(toRemove?.platform.label ?? "")?",
                    isPresented: Binding(get: { toRemove != nil }, set: { if !$0 { toRemove = nil } })
                ) {
                    Button("Cancel", role: .cancel) { toRemove = nil }
                    Button("Remove", role: .destructive) {
                        if let account = toRemove { onRemove(account) }
                        toRemove = nil
                    }
                } message: {
                    Text(removeMessage)
                }

                if !person.merges.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.triangle.merge")
                            .font(.system(size: 11))
                        Text("You combined separate cards into this one.")
                            .font(.system(size: 12))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Button("Separate them") { confirmSeparate = true }
                            .font(.system(size: 12))
                            .underline()
                            .buttonStyle(.plain)
                            .disabled(isCombining)
                    }
                    .foregroundStyle(Theme.textMuted)
                    .padding(.top, 8)
                }

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
                    Text("No other accounts found. Their profile doesn't link anywhere we can follow, and no handle or name like theirs turned up on X, Instagram, YouTube, LinkedIn or Reddit.")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 16)
                }

                footer
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .padding(.bottom, 14)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
    }

    /// "Combine with…": picks the card that's the same person. Same-name cards
    /// come first.
    private var combinePicker: some View {
        let twinIds = Set(twins.map(\.id))
        let q = pickQuery.trimmingCharacters(in: .whitespaces).lowercased()
        let candidates = people
            .filter { $0.id != person.id }
            .filter { p in q.isEmpty || p.name.lowercased().contains(q) || p.following.contains { $0.label.lowercased().contains(q) } }
            .sorted { a, b in
                let ta = twinIds.contains(a.id), tb = twinIds.contains(b.id)
                return ta != tb ? ta : a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
            }
        let pick = people.first { $0.id == pickId }

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                Text("Combine \(person.name) with…")
                    .font(.system(size: 19, weight: .heavy))
                    .foregroundStyle(Theme.textPrimary)
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
            Text("Pick the card that's the same person. Their accounts end up together on one card. You can separate them again later.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textMuted)
                TextField("Search people", text: $pickQuery)
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textPrimary)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            .padding(.horizontal, 10)
            .frame(height: 36)
            .background(Theme.input)
            .clipShape(.rect(cornerRadius: 9))

            VStack(spacing: 0) {
                if candidates.isEmpty {
                    Text("Nobody matches that search.")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                }
                ForEach(Array(candidates.enumerated()), id: \.element.id) { index, p in
                    if index > 0 {
                        Rectangle().fill(Theme.border).frame(height: 0.5)
                    }
                    Button {
                        pickId = p.id
                    } label: {
                        HStack(spacing: 12) {
                            PersonAvatar(name: p.name, url: p.thumbnail)
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 8) {
                                    Text(p.name)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(Theme.textPrimary)
                                    if twinIds.contains(p.id) {
                                        Text("Same name")
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundStyle(Theme.textSecondary)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 2)
                                            .background(Theme.input)
                                            .clipShape(Capsule())
                                    }
                                }
                                FlowLayout(spacing: 6) {
                                    ForEach(p.following) { account in
                                        PlatformChip(platform: account.platform, variant: .following)
                                    }
                                }
                            }
                            Spacer(minLength: 0)
                            if pickId == p.id {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(Theme.accent)
                            }
                        }
                        .padding(12)
                        .background(pickId == p.id ? Theme.accent.opacity(0.15) : Color.clear)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(pickId == p.id ? .isSelected : [])
                }
            }
            .cardStyle(radius: 10)

            HStack(spacing: 8) {
                Button {
                    isPicking = false
                } label: {
                    Text("Cancel")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background(Theme.card)
                        .clipShape(.rect(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.border, lineWidth: 1))
                }
                .buttonStyle(.plain)

                Button {
                    guard let pick else { return }
                    onCombine(pick)
                } label: {
                    HStack(spacing: 6) {
                        if isCombining {
                            ProgressView().controlSize(.small).tint(.white)
                        } else {
                            Image(systemName: "arrow.triangle.merge")
                                .font(.system(size: 13, weight: .bold))
                        }
                        Text("Combine")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .background(Theme.accent)
                    .clipShape(.rect(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .disabled(pick == nil || isCombining)
                .opacity(pick == nil || isCombining ? 0.5 : 1)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            PersonAvatar(name: person.name, url: person.thumbnail, size: 56)
            VStack(alignment: .leading, spacing: 4) {
                Text(person.name)
                    .font(.system(size: 19, weight: .heavy))
                    .foregroundStyle(Theme.textPrimary)
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
                    // A Menu with its own one-line label: the plain menu Picker
                    // wraps long collection names onto the card below.
                    Menu {
                        Picker("Add to", selection: $agentId) {
                            ForEach(agents) { agent in
                                Text(agent.name).tag(agent.id as String?)
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(agents.first { $0.id == agentId }?.name ?? "Choose a collection")
                                .font(.system(size: 13, weight: .semibold))
                                .lineLimit(1)
                                .truncationMode(.tail)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 10, weight: .semibold))
                                .fixedSize()
                        }
                        .foregroundStyle(Theme.accent)
                        .padding(.horizontal, 10)
                        .frame(height: 30)
                        .background(Theme.input)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Theme.border, lineWidth: 1))
                    }
                    .accessibilityLabel("Add to collection")
                    Spacer(minLength: 0)
                }
                .padding(.bottom, 8)
            }
            VStack(spacing: 0) {
                ForEach(Array(person.also.enumerated()), id: \.element.id) { index, account in
                    if index > 0 {
                        Rectangle().fill(Theme.border).frame(height: 0.5)
                    }
                    VStack(alignment: .leading, spacing: 10) {
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
                                    .foregroundStyle(Theme.destructive)
                            }
                            .buttonStyle(.plain)
                            .disabled(busyKeys.contains(account.link.id))
                        }
                        HStack(spacing: 8) {
                            FollowButton(
                                isBusy: busyKeys.contains(account.key),
                                isEnabled: agentId != nil,
                                openInstead: SourcePlatform.isFollowableAccount(account.platform, url: account.url)
                                    ? nil
                                    : URL(string: account.url).map { (label: account.platform.openLabel, url: $0) }
                            ) {
                                if let agentId { onFollow(account, agentId) }
                            }
                            DeleteSuggestionButton(isBusy: busyKeys.contains(account.link.id)) {
                                onDecide(account, false)
                            }
                            Spacer(minLength: 0)
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
                Text(person.lastScannedAt.map { "Last searched " + Format.relativeTime($0) } ?? "Not searched yet")
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
                        Text(person.lastScannedAt == nil ? "Find accounts" : "Find more accounts")
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
            if isScanning, let scanStatus {
                Text(scanStatus)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
            }
            if let problem = person.scanErrors.first {
                Text("Last check had a problem: " + problem)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.warning)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text("Matches come from links on their own profiles, their link-in-bio page and website, and handles like theirs on other platforms. A handle alone is only ever a possible match.")
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

/// Removes a suggested account: same as "Not them", so a later search won't
/// suggest it again. Same as the web and Expo apps.
private struct DeleteSuggestionButton: View {
    let isBusy: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: "trash")
                    .font(.system(size: 12, weight: .semibold))
                Text("Delete")
                    .font(.system(size: 13, weight: .bold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .frame(height: 34)
            .background(Theme.destructive, in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .disabled(isBusy)
        .opacity(isBusy ? 0.5 : 1)
        .accessibilityLabel("Delete this suggestion")
    }
}
