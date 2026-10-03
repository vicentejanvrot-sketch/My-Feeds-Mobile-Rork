import SwiftUI

/// Timezone list matching the companion apps' schedule picker.
private let timezones: [String] = [
    "America/New_York", "America/Chicago", "America/Denver", "America/Edmonton",
    "America/Los_Angeles", "America/Anchorage", "Pacific/Honolulu", "America/Toronto",
    "America/Vancouver", "America/Mexico_City", "America/Sao_Paulo",
    "America/Argentina/Buenos_Aires", "Europe/London", "Europe/Paris", "Europe/Berlin",
    "Europe/Madrid", "Europe/Rome", "Europe/Amsterdam", "Europe/Stockholm", "Europe/Moscow",
    "Europe/Istanbul", "Africa/Cairo", "Africa/Lagos", "Africa/Johannesburg", "Asia/Dubai",
    "Asia/Kolkata", "Asia/Bangkok", "Asia/Singapore", "Asia/Shanghai", "Asia/Tokyo",
    "Asia/Seoul", "Australia/Sydney", "Australia/Melbourne", "Pacific/Auckland", "Pacific/Fiji",
]

struct AgentFormView: View {
    let agentId: String?

    @Environment(ToastCenter.self) private var toasts
    @Environment(AuthStore.self) private var auth
    @Environment(\.dismiss) private var dismiss

    private var isEdit: Bool { agentId != nil }

    @State private var isLoading = true
    @State private var isSaving = false
    @State private var didPopulate = false

    // Fields
    @State private var name = ""
    @State private var descriptionText = ""
    @State private var runTime = Date()
    @State private var timezone = "America/New_York"
    @State private var lookbackHours = "36"
    // New collections include Shorts and live videos; the user can turn them off.
    @State private var includeShorts = true
    @State private var includeLive = true
    /// Kinds of posts switched off (ContentTypes); only false values are kept.
    @State private var contentTypes: [String: Bool] = [:]
    @State private var minDurationMinutes: Double = 3
    @State private var freshnessWeight: Double = 1.0
    @State private var priorityWeight: Double = 1.0
    @State private var durationWeight: Double = 1.0

    // Hidden but preserved on edit
    @State private var keywordWeight: Double = 0.5
    @State private var keywords: [String] = []

    // Recipients
    @State private var recipientEmails: [String] = []
    @State private var recipientIdMap: [String: String] = [:]
    @State private var newRecipientEmail = ""

    @State private var showTimezonePicker = false

    private var trimmedName: String { name.trimmingCharacters(in: .whitespaces) }
    private var canSave: Bool { !trimmedName.isEmpty && trimmedName.count <= 100 && !isSaving }

    var body: some View {
        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if isLoading {
                        ProgressView()
                            .controlSize(.large)
                            .tint(Theme.accent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 80)
                    } else {
                        basicInfoSection
                        scheduleSection
                        videoFiltersSection
                        recipientsSection
                        actions
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 40)
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)

            if showTimezonePicker {
                PickerModal(title: "Timezone", onDismiss: { showTimezonePicker = false }) {
                    ForEach(timezones, id: \.self) { zone in
                        PickerRow(label: zone, isActive: timezone == zone) {
                            timezone = zone
                            showTimezonePicker = false
                        }
                    }
                }
            }
        }
        .background(Theme.background)
        .navigationTitle(isEdit ? "Edit Collection" : "New Collection")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .task { await populate() }
    }

    // MARK: - Sections

    private var basicInfoSection: some View {
        formSection(title: "Basic Information") {
            fieldLabel("Collection Name", required: true)
            TextField("e.g., Crypto, AI, Power Apps", text: $name)
                .textInputAutocapitalization(.words)
                .modifier(FormInputStyle())
                .onChange(of: name) { _, newValue in
                    if newValue.count > 100 { name = String(newValue.prefix(100)) }
                }
            if trimmedName.count >= 95 {
                Text("\(trimmedName.count)/100")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textMuted)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }

            fieldLabel("Description")
            TextField("What topics does this collection cover?", text: $descriptionText, axis: .vertical)
                .lineLimit(4...8)
                .modifier(FormInputStyle())
                .onChange(of: descriptionText) { _, newValue in
                    if newValue.count > 500 { descriptionText = String(newValue.prefix(500)) }
                }
            if descriptionText.count > 400 {
                Text("\(descriptionText.count)/500")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textMuted)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }

    private var scheduleSection: some View {
        formSection(title: "Schedule — \"When should this collection run?\"") {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 0) {
                    fieldLabel("Run Time")
                    DatePicker("", selection: $runTime, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        .datePickerStyle(.compact)
                        .tint(Theme.accent)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 0) {
                    fieldLabel("Lookback Hours")
                    TextField("36", text: $lookbackHours)
                        .keyboardType(.numberPad)
                        .modifier(FormInputStyle())
                        .onChange(of: lookbackHours) { _, newValue in
                            let filtered = String(newValue.prefix(3).filter(\.isNumber))
                            if let n = Int(filtered), n >= 1, n <= 168 {
                                lookbackHours = filtered
                            } else if filtered.isEmpty {
                                lookbackHours = ""
                            } else {
                                lookbackHours = String(filtered.dropLast())
                            }
                        }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            fieldLabel("Timezone")
            Button {
                showTimezonePicker = true
            } label: {
                HStack {
                    Text(timezone)
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.textMuted)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Theme.input)
                .clipShape(.rect(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Theme.border, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
    }

    private var videoFiltersSection: some View {
        formSection(title: "Content Filters — \"What kinds of posts should be included?\"") {
            contentGroupLabel("YouTube")
            toggleRow(title: "Include Shorts", subtitle: "Include YouTube Shorts in results", isOn: $includeShorts)
            toggleRow(title: "Include Live/Upcoming", subtitle: "Include live streams and premieres", isOn: $includeLive)
            ForEach(ContentTypes.groups) { group in
                contentGroupLabel(group.platform.label)
                ForEach(group.options) { option in
                    toggleRow(
                        title: "Include " + option.label,
                        subtitle: option.help,
                        isOn: Binding(
                            get: { contentTypes[option.key] != false },
                            set: { on in
                                if on { contentTypes.removeValue(forKey: option.key) } else { contentTypes[option.key] = false }
                            }
                        )
                    )
                }
            }
            Text(ContentTypes.liveNote)
                .font(.system(size: 11))
                .foregroundStyle(Theme.textMuted)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 6)
                .padding(.top, 12)
        }
    }

    private var recipientsSection: some View {
        formSection(title: "Email Recipients — \"Who should receive the daily digest?\"") {
            HStack(spacing: 10) {
                TextField("email@example.com", text: $newRecipientEmail)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .onSubmit { addRecipientEmail() }
                    .modifier(FormInputStyle())
                Button {
                    addRecipientEmail()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(Theme.accent)
                        .clipShape(.rect(cornerRadius: 8))
                }
            }

            if !recipientEmails.isEmpty {
                FlowLayoutWrap(spacing: 8) {
                    ForEach(recipientEmails, id: \.self) { email in
                        HStack(spacing: 6) {
                            Text(email)
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.textPrimary)
                                .lineLimit(1)
                            Button {
                                recipientEmails.removeAll { $0 == email }
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(Theme.textMuted)
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Theme.input)
                        .clipShape(Capsule())
                    }
                }
                .padding(.top, 12)
            }
        }
    }

    private var actions: some View {
        VStack(spacing: 10) {
            Button {
                save()
            } label: {
                ZStack {
                    if isSaving {
                        ProgressView().tint(.white)
                    } else {
                        Text(isEdit ? "Save Changes" : "Create Collection")
                            .font(.system(size: 16, weight: .bold))
                    }
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(Theme.accent)
                .clipShape(.rect(cornerRadius: 10))
                .opacity(canSave ? 1 : 0.5)
            }
            .disabled(!canSave)

            Button {
                dismiss()
            } label: {
                Text("Cancel")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Theme.border, lineWidth: 1)
                    )
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Helpers

    private func formSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .bold))
                .kerning(0.5)
                .foregroundStyle(Theme.textSecondary)
                .padding(.bottom, 10)
            VStack(alignment: .leading, spacing: 0) {
                content()
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card)
            .clipShape(.rect(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Theme.cardBorder, lineWidth: 1)
            )
        }
        .padding(.bottom, 24)
    }

    private func fieldLabel(_ text: String, required: Bool = false) -> some View {
        (Text(text) + (required ? Text(" *").foregroundColor(Theme.destructive) : Text("")))
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Theme.textSecondary)
            .padding(.top, 12)
            .padding(.bottom, 6)
    }

    private func contentGroupLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .bold))
            .tracking(0.6)
            .foregroundStyle(Theme.textSecondary)
            .padding(.top, 8)
    }

    private func toggleRow(title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textMuted)
            }
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(Theme.accent)
        }
    }

    private func sliderField(label: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Text(String(format: "%.1f", value.wrappedValue))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.accent)
                    .monospacedDigit()
            }
            Slider(value: value, in: 0...2, step: 0.1)
                .tint(Theme.accent)
        }
        .padding(.bottom, 12)
    }

    private func addRecipientEmail() {
        let email = newRecipientEmail.trimmingCharacters(in: .whitespaces)
        guard isValidEmail(email) else {
            toasts.show("Enter a valid email", type: .error)
            return
        }
        guard !recipientEmails.contains(email) else {
            toasts.show("Recipient already added", type: .error)
            return
        }
        recipientEmails.append(email)
        newRecipientEmail = ""
    }

    private func isValidEmail(_ email: String) -> Bool {
        email.range(of: "^[^\\s@]+@[^\\s@]+\\.[^\\s@]+$", options: .regularExpression) != nil
    }

    // MARK: - Time helpers

    private func timeString(from date: Date) -> String {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", comps.hour ?? 7, comps.minute ?? 0)
    }

    private func date(fromTimeString value: String?) -> Date {
        let parts = (value ?? "07:00").split(separator: ":").compactMap { Int($0) }
        var comps = DateComponents()
        comps.hour = parts.count > 0 ? parts[0] : 7
        comps.minute = parts.count > 1 ? parts[1] : 0
        return Calendar.current.date(from: comps) ?? Date()
    }

    // MARK: - Data

    private func populate() async {
        guard !didPopulate else { return }
        didPopulate = true
        let service = SupabaseService.shared
        if let agentId {
            do {
                async let agentTask = service.fetchAgent(id: agentId)
                async let recipientsTask = service.fetchRecipients(agentId: agentId)
                let (agent, loadedRecipients) = try await (agentTask, recipientsTask)
                name = agent.name
                descriptionText = agent.description ?? ""
                runTime = date(fromTimeString: agent.runTimeLocal)
                timezone = agent.timezone ?? "America/New_York"
                lookbackHours = String(agent.lookbackHours ?? 36)
                includeShorts = agent.includeShorts ?? false
                includeLive = agent.includeLive ?? false
                contentTypes = ContentTypes.normalized(agent.contentTypes)
                minDurationMinutes = Double(agent.minDurationMinutes ?? 3)
                freshnessWeight = agent.freshnessWeight ?? 1.0
                priorityWeight = agent.priorityWeight ?? 1.0
                durationWeight = agent.durationWeight ?? 1.0
                keywordWeight = agent.keywordWeight ?? 0.5
                keywords = agent.keywords ?? []
                recipientEmails = loadedRecipients.map(\.email)
                recipientIdMap = Dictionary(uniqueKeysWithValues: loadedRecipients.map { ($0.email, $0.id) })
            } catch {
                toasts.show("Couldn't load collection", type: .error)
            }
        } else {
            runTime = date(fromTimeString: "07:00")
            // Start with the user's own email: the Default Email from Settings
            // if set, otherwise the sign-in email. They can remove it or add more.
            var defaultEmail: String?
            if let userId = auth.userId,
               let settings = try? await service.fetchUserSettings(userId: userId) {
                defaultEmail = settings.defaultEmail?.trimmingCharacters(in: .whitespaces)
            }
            if defaultEmail?.isEmpty ?? true {
                defaultEmail = auth.userEmail?.trimmingCharacters(in: .whitespaces)
            }
            if let email = defaultEmail, isValidEmail(email), recipientEmails.isEmpty {
                recipientEmails = [email]
            }
        }
        isLoading = false
    }

    private func save() {
        guard !trimmedName.isEmpty else {
            toasts.show("Collection name is required", type: .error)
            return
        }
        guard trimmedName.count <= 100 else {
            toasts.show("Name must be 100 characters or fewer", type: .error)
            return
        }
        let trimmedDescription = descriptionText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedDescription.count <= 500 else {
            toasts.show("Description must be 500 characters or fewer", type: .error)
            return
        }

        var payload = AgentPayload(
            name: trimmedName,
            description: trimmedDescription.isEmpty ? nil : trimmedDescription,
            scheduleFrequency: "daily",
            runTimeLocal: timeString(from: runTime),
            timezone: timezone,
            lookbackHours: Int(lookbackHours) ?? 36,
            aiProvider: "lovable",
            includeShorts: includeShorts,
            includeLive: includeLive,
            contentTypes: contentTypes,
            // Minimum Duration was removed: agents keep every video length.
            minDurationMinutes: 0,
            freshnessWeight: freshnessWeight,
            priorityWeight: priorityWeight,
            durationWeight: durationWeight,
            keywordWeight: keywordWeight,
            keywords: keywords.isEmpty ? nil : keywords,
            userId: nil
        )

        isSaving = true
        Task {
            do {
                let service = SupabaseService.shared
                let validEmails = recipientEmails.filter { isValidEmail($0) }
                if let agentId {
                    _ = try await service.updateAgent(id: agentId, payload: payload)
                    // Recipient diff
                    let removedEmails = recipientIdMap.keys.filter { !validEmails.contains($0) }
                    for email in removedEmails {
                        if let recipientId = recipientIdMap[email] {
                            try? await service.deleteRecipient(id: recipientId)
                        }
                    }
                    for email in validEmails where recipientIdMap[email] == nil {
                        try? await service.addRecipient(agentId: agentId, email: email)
                    }
                    toasts.show("Collection updated")
                } else {
                    payload.userId = auth.userId
                    let created = try await service.createAgent(payload)
                    for email in validEmails {
                        try? await service.addRecipient(agentId: created.id, email: email)
                    }
                    toasts.show("Collection created")
                }
                dismiss()
            } catch {
                toasts.show(error.localizedDescription, type: .error)
            }
            isSaving = false
        }
    }
}

/// Shared form text-field style.
private struct FormInputStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 14))
            .foregroundStyle(Theme.textPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Theme.input)
            .clipShape(.rect(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Theme.border, lineWidth: 1)
            )
    }
}
