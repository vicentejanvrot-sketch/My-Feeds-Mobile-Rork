import SwiftUI
import Supabase

/// What the wizard hands back when the user closes it from the last screen.
struct OnboardingResult {
    let agent: Agent
    let runNow: Bool
}

/// Onboarding wizard, same flow as the web and Expo wizards: create an agent
/// (its name is its topic), add its sources, then a per-platform tour of
/// reading and watching in the app. Saves through SupabaseService, so the agent
/// it creates is a normal agent. Shown full screen by DashboardView: by itself
/// until the user ticks "Don't show this again", and from the floating help
/// button any time. "See how it works" jumps straight to the tour.
struct OnboardingWizardView: View {
    /// Called with a result when the user leaves from the last screen, nil otherwise.
    let onClose: (OnboardingResult?) -> Void
    /// Called when the user ticks or clears "Don't show this again".
    let onHiddenChange: (Bool) -> Void

    init(
        hidden: Bool,
        onHiddenChange: @escaping (Bool) -> Void,
        onClose: @escaping (OnboardingResult?) -> Void
    ) {
        self.onHiddenChange = onHiddenChange
        self.onClose = onClose
        _dontShow = State(initialValue: hidden)
    }

    @Environment(AuthStore.self) private var auth

    private struct AddedSource: Identifiable {
        let id: String
        let platform: SourcePlatform
        let name: String
        var isPrivate = false
    }

    private let stepLabels = ["Your collection", "Sources", "Read & watch"]
    private let lastStep = 4

    @State private var step = 0
    @State private var name = ""
    @State private var emailMe = true
    @State private var agentId: String?
    @State private var savedName = ""
    @State private var savedEmailMe = true
    @State private var saving = false
    @State private var finishing = false
    @State private var errorText: String?
    @State private var finishedAgent: Agent?
    /// Opened only to see the reading tour: no agent is created.
    @State private var tourOnly = false
    @State private var dontShow: Bool

    @State private var platform: SourcePlatform = .youtube
    /// Set when a pasted link picked the platform for the user.
    @State private var autoPlatform: SourcePlatform?
    @State private var sourceValue = ""
    /// Set when Instagram says the account is private (or can't be loaded).
    @State private var privateOffer: String?
    @State private var adding = false
    @State private var removingId: String?
    @State private var sources: [AddedSource] = []

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var showFooter: Bool { step >= 1 && step < lastStep }
    private var nextDisabled: Bool {
        finishing
            || (step == 1 && (trimmedName.isEmpty || trimmedName.count > 100 || saving))
            || (step == 2 && sources.isEmpty)
    }
    private var hint: String? {
        if step == 1 && trimmedName.isEmpty { return "Give your collection a name." }
        if step == 2 && sources.isEmpty { return "Add at least one source, or skip for now." }
        return nil
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    switch step {
                    case 0: welcome
                    case 1: agentStep
                    case 2: sourcesStep
                    case 3: tourStep
                    default: doneStep
                    }
                    if let errorText, !showFooter {
                        errorLabel(errorText).padding(.top, 12)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 28)
                .id(step)
                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
            }
            .scrollDismissesKeyboard(.interactively)
            if showFooter { footer }
        }
        .background(Theme.background.ignoresSafeArea())
        .animation(.easeOut(duration: 0.25), value: step)
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            if showFooter && tourOnly {
                Text("HOW IT WORKS")
                    .font(.system(size: 12, weight: .bold))
                    .kerning(0.6)
                    .foregroundStyle(Theme.textSecondary)
            } else if showFooter {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        ForEach(Array(stepLabels.enumerated()), id: \.offset) { index, _ in
                            Capsule()
                                .fill(step >= index + 1 ? Theme.accent : Theme.input)
                                .frame(height: 4)
                        }
                    }
                    Text("STEP \(step) OF \(stepLabels.count) · \(stepLabels[step - 1].uppercased())")
                        .font(.system(size: 12, weight: .bold))
                        .kerning(0.6)
                        .foregroundStyle(Theme.textSecondary)
                }
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "dot.radiowaves.left.and.right")
                        .font(.system(size: 16, weight: .semibold))
                    Text("My Feeds")
                        .font(.system(size: 16, weight: .bold))
                }
                .foregroundStyle(Theme.accent)
            }
            Spacer(minLength: 0)
            Button {
                close(runNow: false)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 36, height: 36)
            }
            .accessibilityLabel("Close")
            .offset(y: -6)
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 6)
    }

    // MARK: - Steps

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text("Everything you follow, in one feed.")
                .font(.system(size: 32, weight: .heavy))
                .foregroundStyle(Theme.textPrimary)
            Text("My Feeds watches the topics you care about across YouTube, X, Reddit and more, sums up what's new, and lets you watch and read it all right here.")
                .font(.system(size: 16))
                .foregroundStyle(Theme.textSecondary)
                .lineSpacing(4)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 8, alignment: .leading)], alignment: .leading, spacing: 8) {
                ForEach(SourcePlatform.addable, id: \.self) { p in
                    HStack(spacing: 8) {
                        PlatformBadge(platform: p, size: 18)
                        Text(p.label)
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.textPrimary)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .overlay(Capsule().stroke(Theme.border, lineWidth: 1))
                }
            }
            VStack(spacing: 10) {
                Button { go(to: 1) } label: { primaryLabel("Get started") }
                    .buttonStyle(.plain)
                Button { startTour() } label: { outlineLabel("See how it works") }
                    .buttonStyle(.plain)
                Button { close(runNow: false) } label: {
                    Text("Skip for now")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            Text("Get started builds a new collection in three quick steps. See how it works only shows how to read and watch.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 6) {
                dontShowBox
                Text("You can open this again any time with the ? button on the Dashboard.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.leading, 32)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 16)
            .overlay(alignment: .top) {
                Rectangle().fill(Theme.border).frame(height: 0.5)
            }
        }
        .padding(.top, 12)
    }

    private var agentStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            stepHeading(
                "Build your first collection",
                "A collection follows one topic and pulls the best posts from its sources into one stream. Its name is the topic, so name it after what you want to follow."
            )
            VStack(alignment: .leading, spacing: 8) {
                fieldLabel("Collection name and topic")
                TextField("", text: $name, prompt: Text("e.g. Crypto, AI, Power Apps").foregroundColor(Theme.textMuted))
                    .modifier(WizardInputStyle())
                    .submitLabel(.next)
                    .onSubmit { if !nextDisabled { next() } }
                    .onChange(of: name) {
                        if name.count > 100 { name = String(name.prefix(100)) }
                    }
                    .accessibilityLabel("Collection name and topic")
            }
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    fieldLabel("Email me a digest after each run")
                    Text("Sent to your account email. You can change it on the collection later.")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer(minLength: 0)
                Toggle("", isOn: $emailMe)
                    .labelsHidden()
                    .tint(Theme.accent)
                    .accessibilityLabel("Email me a digest after each run")
            }
            .padding(14)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.border, lineWidth: 1))

            if !trimmedName.isEmpty {
                HStack(spacing: 12) {
                    Text(String(trimmedName.prefix(1)).uppercased())
                        .font(.system(size: 20, weight: .heavy))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.accent))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(trimmedName)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Theme.textPrimary)
                            .lineLimit(1)
                        Text("Runs daily at 7:00 AM · looks back 36 hours")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    Spacer(minLength: 0)
                }
                .padding(14)
                .cardStyle(radius: 10)
            }
        }
    }

    private var sourcesStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            stepHeading(
                "Add sources to \(savedName.isEmpty ? "your agent" : savedName)",
                "Add the channels, accounts and communities this collection should watch. You can add more later from the collection page."
            )

            VStack(alignment: .leading, spacing: 10) {
                fieldLabel("Platform")
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                    ForEach(SourcePlatform.addable, id: \.self) { p in
                        let selected = platform == p
                        Button {
                            platform = p
                            autoPlatform = nil
                            errorText = nil
                        } label: {
                            VStack(spacing: 6) {
                                PlatformBadge(platform: p, size: 26)
                                HStack(spacing: 3) {
                                    Text(p.label)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(Theme.textPrimary)
                                    if p.isBeta {
                                        Text("BETA")
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundStyle(Theme.textMuted)
                                    }
                                }
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                            }
                            .frame(maxWidth: .infinity, minHeight: 76)
                            .background(RoundedRectangle(cornerRadius: 10).fill(selected ? Theme.accent.opacity(0.12) : Color.clear))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(selected ? Theme.accent : Theme.border, lineWidth: 1))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(selected ? .isSelected : [])
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                fieldLabel(platform.sourceNoun)
                HStack(spacing: 8) {
                    TextField("", text: $sourceValue, prompt: Text(platform.addPlaceholder).foregroundColor(Theme.textMuted))
                        .modifier(WizardInputStyle())
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.done)
                        .onSubmit { addSource() }
                        .accessibilityLabel(platform.sourceNoun)
                        .onChange(of: sourceValue) { _, value in
                            privateOffer = nil
                            if let detected = SourcePlatform.detect(from: value), detected != platform {
                                platform = detected
                                autoPlatform = detected
                                errorText = nil
                            } else if value.trimmingCharacters(in: .whitespaces).isEmpty {
                                autoPlatform = nil
                            }
                        }
                    Button {
                        addSource()
                    } label: {
                        ZStack {
                            if adding {
                                ProgressView().tint(.white)
                            } else {
                                Image(systemName: "plus")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                        }
                        .frame(width: 50, height: 50)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.accent))
                    }
                    .buttonStyle(.plain)
                    .disabled(sourceValue.trimmingCharacters(in: .whitespaces).isEmpty || adding)
                    .opacity(sourceValue.trimmingCharacters(in: .whitespaces).isEmpty || adding ? 0.45 : 1)
                    .accessibilityLabel("Add source")
                }
                if autoPlatform == platform {
                    Text("That's a \(platform.label) link, so \(platform.label) is now selected.")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.accent)
                } else {
                    Text(platform.addHelp)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textSecondary)
                }
                if let privateOffer {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.textSecondary)
                                .padding(.top, 2)
                            Text(privateOffer)
                                .font(.system(size: 13))
                                .foregroundStyle(Theme.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Text("A private account shows up on People with a button to open it in Instagram. Its posts won't appear in your feed.")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Button {
                            addSource(asPrivate: true)
                        } label: {
                            HStack(spacing: 6) {
                                if adding {
                                    ProgressView().tint(Theme.textPrimary)
                                } else {
                                    Image(systemName: "lock.fill").font(.system(size: 12))
                                    Text("Add as private account").font(.system(size: 13, weight: .semibold))
                                }
                            }
                            .foregroundStyle(Theme.textPrimary)
                            .padding(.horizontal, 12)
                            .frame(height: 36)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .disabled(adding)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Theme.input))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.border, lineWidth: 1))
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                fieldLabel(sources.isEmpty ? "Added" : "Added (\(sources.count))")
                if sources.isEmpty {
                    Text("Nothing yet. Add at least one source so the collection has something to watch.")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(16)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.border, style: StrokeStyle(lineWidth: 1, dash: [4])))
                } else {
                    ForEach(sources) { source in
                        HStack(spacing: 10) {
                            PlatformBadge(platform: source.platform, size: 20)
                            Text(source.name)
                                .font(.system(size: 14))
                                .foregroundStyle(Theme.textPrimary)
                                .lineLimit(1)
                            if source.isPrivate {
                                Label("Private", systemImage: "lock.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Theme.textSecondary)
                                    .labelStyle(.titleAndIcon)
                            }
                            Spacer(minLength: 0)
                            Button {
                                remove(source)
                            } label: {
                                ZStack {
                                    if removingId == source.id {
                                        ProgressView().tint(Theme.textSecondary)
                                    } else {
                                        Image(systemName: "trash")
                                            .font(.system(size: 16))
                                            .foregroundStyle(Theme.textSecondary)
                                    }
                                }
                                .frame(width: 44, height: 44)
                            }
                            .buttonStyle(.plain)
                            .disabled(removingId == source.id)
                            .accessibilityLabel("Remove \(source.name)")
                        }
                        .padding(.leading, 12)
                        .padding(.trailing, 4)
                        .frame(minHeight: 48)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.border, lineWidth: 1))
                    }
                }
            }
        }
    }

    private var tourStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            stepHeading(
                "Watch and read without leaving",
                "Pick a platform to see how its posts work in My Feeds, then tap the numbers."
            )
            ReadWatchTourView(defaultPlatform: sources.first?.platform ?? .youtube)
        }
    }

    private var doneStep: some View {
        VStack(alignment: .leading, spacing: 22) {
            Image(systemName: "checkmark")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(Circle().fill(Theme.accent))
            VStack(alignment: .leading, spacing: 8) {
                Text("Your feed is ready")
                    .font(.system(size: 32, weight: .heavy))
                    .foregroundStyle(Theme.textPrimary)
                Text("Run the collection now to fill your feed straight away, or let it run on its own every morning.")
                    .font(.system(size: 16))
                    .foregroundStyle(Theme.textSecondary)
                    .lineSpacing(4)
            }
            VStack(spacing: 0) {
                recapRow("Collection", savedName)
                Rectangle().fill(Theme.border).frame(height: 0.5)
                recapRow("Sources", sources.isEmpty ? "None yet" : "\(sources.count) added")
                Rectangle().fill(Theme.border).frame(height: 0.5)
                recapRow("Email digest", savedEmailMe ? "On" : "Off")
            }
            .cardStyle(radius: 12)
            VStack(spacing: 10) {
                Button { close(runNow: true) } label: { primaryLabel("Run it now", icon: "play.fill") }
                    .buttonStyle(.plain)
                    .disabled(sources.isEmpty)
                    .opacity(sources.isEmpty ? 0.45 : 1)
                Button { close(runNow: false) } label: { outlineLabel("Go to my feed") }
                    .buttonStyle(.plain)
            }
            dontShowBox
                .padding(.top, 16)
                .overlay(alignment: .top) {
                    Rectangle().fill(Theme.border).frame(height: 0.5)
                }
        }
        .padding(.top, 8)
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 10) {
            if let errorText {
                errorLabel(errorText)
            } else if let hint {
                Text(hint)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            if tourOnly {
                dontShowBox
            }
            HStack(spacing: 10) {
                Button {
                    back()
                } label: {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                        .frame(width: 50, height: 50)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.border, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Back")

                if step == 2 && sources.isEmpty {
                    Button { go(to: 3) } label: {
                        Text("Skip for now")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Theme.textPrimary)
                            .padding(.horizontal, 12)
                            .frame(height: 50)
                    }
                    .buttonStyle(.plain)
                }

                Button { next() } label: {
                    primaryLabel(tourOnly ? "Done" : step == lastStep - 1 ? "Finish" : "Continue", busy: saving || finishing)
                }
                .buttonStyle(.plain)
                .disabled(nextDisabled)
                .opacity(nextDisabled ? 0.45 : 1)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .background(Theme.background)
        .overlay(alignment: .top) {
            Rectangle().fill(Theme.border).frame(height: 0.5)
        }
    }

    // MARK: - Pieces

    private var dontShowBox: some View {
        Button {
            dontShow.toggle()
            onHiddenChange(dontShow)
        } label: {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(dontShow ? Theme.accent : Color.clear)
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(dontShow ? Theme.accent : Theme.textSecondary, lineWidth: 1.5)
                    if dontShow {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .heavy))
                            .foregroundStyle(.white)
                    }
                }
                .frame(width: 22, height: 22)
                Text("Don't show this again")
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.textPrimary)
                Spacer(minLength: 0)
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Don't show this again")
        .accessibilityAddTraits(dontShow ? .isSelected : [])
    }

    private func stepHeading(_ title: String, _ lead: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 26, weight: .heavy))
                .foregroundStyle(Theme.textPrimary)
            Text(lead)
                .font(.system(size: 16))
                .foregroundStyle(Theme.textSecondary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(Theme.textPrimary)
    }

    private func errorLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13))
            .foregroundStyle(Theme.destructive)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }

    private func recapRow(_ label: String, _ value: String) -> some View {
        HStack(spacing: 16) {
            Text(label)
                .font(.system(size: 14))
                .foregroundStyle(Theme.textSecondary)
            Spacer(minLength: 0)
            Text(value)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
        }
        .padding(14)
    }

    private func primaryLabel(_ text: String, icon: String? = nil, busy: Bool = false) -> some View {
        HStack(spacing: 8) {
            if busy {
                ProgressView().tint(.white).controlSize(.small)
            } else if let icon {
                Image(systemName: icon).font(.system(size: 15, weight: .semibold))
            }
            Text(text).font(.system(size: 16, weight: .bold))
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .frame(height: 50)
        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.accent))
    }

    private func outlineLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(Theme.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.border, lineWidth: 1))
            .contentShape(Rectangle())
    }

    // MARK: - Actions

    private func go(to newStep: Int) {
        errorText = nil
        step = newStep
    }

    private func startTour() {
        tourOnly = true
        go(to: 3)
    }

    private func back() {
        if tourOnly {
            tourOnly = false
            go(to: 0)
        } else {
            go(to: max(0, step - 1))
        }
    }

    private func next() {
        if tourOnly {
            close(runNow: false)
            return
        }
        switch step {
        case 1: saveAgent()
        case lastStep - 1: finish()
        default: go(to: min(lastStep, step + 1))
        }
    }

    private func close(runNow: Bool) {
        if step == lastStep, let agent = finishedAgent {
            onClose(OnboardingResult(agent: agent, runNow: runNow))
        } else {
            onClose(nil)
        }
    }

    /// Same fields and defaults as a new agent from the agent form.
    private func agentPayload(name: String) -> AgentPayload {
        AgentPayload(
            name: name,
            description: nil,
            scheduleFrequency: "daily",
            runTimeLocal: "07:00",
            timezone: TimeZone.current.identifier,
            lookbackHours: 36,
            aiProvider: "lovable",
            includeShorts: true,
            includeLive: true,
            minDurationMinutes: 0,
            freshnessWeight: 1.0,
            priorityWeight: 1.0,
            durationWeight: 1.0,
            keywordWeight: 0.5,
            keywords: nil,
            userId: auth.userId
        )
    }

    private func recipientEmails(wantEmail: Bool) async -> [String] {
        guard wantEmail, let userId = auth.userId else { return [] }
        let settings = try? await SupabaseService.shared.fetchUserSettings(userId: userId)
        let saved = settings?.defaultEmail?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let email = saved.isEmpty ? (auth.userEmail ?? "") : saved
        return email.isEmpty ? [] : [email]
    }

    /// Replace the agent's recipients, the same way the web app does.
    private func saveRecipients(agentId: String, emails: [String]) async throws {
        let service = SupabaseService.shared
        try await service.client.from("agent_recipients").delete().eq("agent_id", value: agentId).execute()
        for email in emails {
            try await service.addRecipient(agentId: agentId, email: email)
        }
    }

    /// Step 1: create the agent the first time, update it if they come back and
    /// change it. No success message here; the user gets one when they finish.
    private func saveAgent() {
        let newName = trimmedName
        guard !newName.isEmpty, newName.count <= 100, auth.userId != nil else { return }
        saving = true
        errorText = nil
        Task {
            do {
                let service = SupabaseService.shared
                if let agentId {
                    if newName != savedName {
                        _ = try await service.updateAgent(id: agentId, payload: agentPayload(name: newName))
                    }
                    if emailMe != savedEmailMe {
                        try await saveRecipients(agentId: agentId, emails: await recipientEmails(wantEmail: emailMe))
                    }
                } else {
                    let created = try await service.createAgent(agentPayload(name: newName))
                    try await saveRecipients(agentId: created.id, emails: await recipientEmails(wantEmail: emailMe))
                    agentId = created.id
                }
                savedName = newName
                savedEmailMe = emailMe
                go(to: 2)
            } catch {
                errorText = "Couldn't save the collection: \(error.localizedDescription)"
            }
            saving = false
        }
    }

    /// Step 2: YouTube channels go straight into channels (run-agent resolves
    /// them on the first run); every other platform is checked by add-source.
    private func addSource(asPrivate: Bool = false) {
        let value = sourceValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, let agentId, !adding else { return }
        errorText = nil
        privateOffer = nil
        if let detected = SourcePlatform.detect(from: value), detected != platform {
            errorText = "That's a \(detected.label) link. Select \(detected.label) or paste a \(platform.label) link."
            return
        }
        if platform == .youtube,
           value.range(of: #"youtube\.com|youtu\.be|^@"#, options: [.regularExpression, .caseInsensitive]) == nil {
            errorText = "Paste the channel link, like youtube.com/@ChannelName."
            return
        }
        let chosen = platform
        adding = true
        Task {
            do {
                let service = SupabaseService.shared
                if chosen == .youtube {
                    try await service.addChannel(agentId: agentId, url: value, priority: 3)
                    // addChannel doesn't return the row; find it so it can be removed again.
                    let channels = try await service.fetchChannels(agentId: agentId)
                    let known = Set(sources.map(\.id))
                    if let row = channels.first(where: { $0.channelUrl == value && !known.contains($0.id) }) {
                        sources.append(AddedSource(id: row.id, platform: .youtube, name: value))
                    }
                } else {
                    let channel = try await service.addSource(
                        agentId: agentId,
                        platform: chosen,
                        value: value,
                        priority: 3,
                        privateAccount: asPrivate
                    )
                    sources.append(AddedSource(id: channel.id, platform: chosen, name: channel.displayName, isPrivate: channel.isPrivateAccount))
                }
                sourceValue = ""
                autoPlatform = nil
            } catch let error as SourceError where !asPrivate && error.canAddAsPrivate {
                privateOffer = error.message
            } catch {
                errorText = error.localizedDescription
            }
            adding = false
        }
    }

    private func remove(_ source: AddedSource) {
        removingId = source.id
        errorText = nil
        Task {
            do {
                try await SupabaseService.shared.deleteChannel(id: source.id)
                sources.removeAll { $0.id == source.id }
            } catch {
                errorText = "Couldn't remove it: \(error.localizedDescription)"
            }
            removingId = nil
        }
    }

    /// Last step: confirm the agent really is saved before calling it done.
    private func finish() {
        guard let agentId else { return }
        finishing = true
        errorText = nil
        Task {
            do {
                let agent = try await SupabaseService.shared.fetchAgent(id: agentId)
                finishedAgent = agent
                savedName = agent.name
                go(to: lastStep)
            } catch {
                errorText = "Something went wrong saving your collection. Check it on the Dashboard and try again."
            }
            finishing = false
        }
    }
}

/// Text field look for the wizard (same as the agent form's fields, a bit taller).
private struct WizardInputStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 16))
            .foregroundStyle(Theme.textPrimary)
            .padding(.horizontal, 14)
            .frame(height: 50)
            .background(RoundedRectangle(cornerRadius: 10).fill(Theme.input))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.border, lineWidth: 1))
    }
}
