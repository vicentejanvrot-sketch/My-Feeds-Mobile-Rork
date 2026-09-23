import SwiftUI

/// Full-screen video player: YouTube embed + fully custom chrome,
/// matching the companion apps (speed pills, status actions, controls strip,
/// quality/speed sheet, share, resume position, auto-watched on end).
struct VideoPlayerScreen: View {
    let request: PlayerRequest

    @Environment(\.dismiss) private var dismiss
    @Environment(ToastCenter.self) private var toasts
    @Environment(VideoPrefs.self) private var prefs
    @Environment(AppRouter.self) private var router
    @Environment(\.openURL) private var openURL
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    @State private var controller = YouTubePlayerController()
    @State private var isFullscreen = false
    @State private var showGearSheet = false
    @State private var showShareSheet = false
    @State private var showWatchedOverlay = false
    @State private var markedWatchedOnce = false
    @State private var isMuted = false
    @State private var volume: Double = 100
    @State private var isScrubbing = false
    @State private var scrubTime: Double = 0
    @State private var showLoadError = false
    @State private var isDeviceLandscape = false
    @State private var hasManualFullscreenPreference = false
    @State private var areLandscapeControlsVisible = true
    @State private var landscapeControlsHeight: CGFloat = 112
    @State private var landscapeControlsTask: Task<Void, Never>?
    @State private var savePositionTask: Task<Void, Never>?

    private var watchURL: String { "https://www.youtube.com/watch?v=\(request.videoId)" }

    private var displayTime: Double { isScrubbing ? scrubTime : controller.currentTime }

    private var usesPortraitFullscreenLayout: Bool {
        isFullscreen
            && !isDeviceLandscape
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Theme.background.ignoresSafeArea()

                adaptivePlayerLayout(in: geometry.size)

                if showWatchedOverlay {
                    watchedOverlay
                }
            }
            .onAppear { updateFullscreen(for: geometry.size) }
            .onChange(of: geometry.size) { _, newSize in
                updateFullscreen(for: newSize)
            }
        }
        .statusBarHidden(isFullscreen)
        .sheet(isPresented: $showGearSheet) { gearSheet }
        .sheet(isPresented: $showShareSheet) { shareSheet }
        .onAppear { startPlayerLifecycle() }
        .onDisappear {
            landscapeControlsTask?.cancel()
            savePositionTask?.cancel()
            persistPosition()
            if prefs.keepScreenOn {
                UIApplication.shared.isIdleTimerDisabled = false
            }
        }
    }

    // MARK: - Layouts

    private var portraitChrome: some View {
        VStack(spacing: 0) {
            header
            speedPillsRow
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
            if controller.duration > 0 {
                countdownRow
                    .padding(.top, 8)
            }
            statusActionsRow
                .padding(.top, 10)
            openInYouTubeRow
                .padding(.top, 8)
        }
    }

    private func adaptivePlayerLayout(in size: CGSize) -> some View {
        let aspectHeight = size.width * 9 / 16
        let expandedHeight = min(size.height, aspectHeight)
        let expandedWidth = expandedHeight * 16 / 9
        let collapsedAreaHeight = max(
            size.height - landscapeControlsHeight,
            0
        )
        let collapsedHeight = min(collapsedAreaHeight, aspectHeight)
        let isPhoneLandscape = isFullscreen
            && !usesPortraitFullscreenLayout
            && verticalSizeClass == .compact
        let phoneScale = isPhoneLandscape
            && areLandscapeControlsVisible
            && expandedHeight > 0
                ? collapsedHeight / expandedHeight
                : 1
        let playerWidth = isFullscreen
            ? (isPhoneLandscape ? expandedWidth : size.width)
            : size.width
        let playerHeight = isFullscreen
            ? (usesPortraitFullscreenLayout
                ? size.height
                : (isPhoneLandscape ? expandedHeight : collapsedHeight))
            : aspectHeight

        return ZStack {
            Color.black
                .ignoresSafeArea()
                .opacity(isFullscreen ? 1 : 0)

            // This VStack and persistentVideoArea never change identity when
            // orientation changes, so WKWebView keeps playing uninterrupted.
            VStack(spacing: 0) {
                if !isFullscreen {
                    portraitChrome
                }

                // Let iOS animate its continuously changing rotation
                // geometry. Animating every intermediate width/height
                // separately caused stacked, visibly stepped transitions.
                persistentVideoArea
                    .frame(width: playerWidth, height: playerHeight)
                    .scaleEffect(phoneScale, anchor: .top)
                    .padding(.top, isFullscreen ? 0 : 10)
                    .clipShape(
                        UnevenRoundedRectangle(
                            topLeadingRadius: isFullscreen ? 0 : 10,
                            topTrailingRadius: isFullscreen ? 0 : 10
                        )
                    )

                if !isFullscreen {
                    controlsStrip
                }

                Spacer(minLength: 0)
            }

            if isFullscreen {
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    fullscreenControlsLayer
                        .onGeometryChange(for: CGFloat.self) { proxy in
                            proxy.size.height
                        } action: { newHeight in
                            guard !usesPortraitFullscreenLayout, newHeight > 0 else { return }
                            landscapeControlsHeight = newHeight
                        }
                }

                if !areLandscapeControlsVisible {
                    Button {
                        showLandscapeControlsTemporarily()
                    } label: {
                        Color.clear
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Show video controls")
                }

                fullscreenCloseButton
            }
        }
        .animation(.smooth(duration: 0.42), value: isDeviceLandscape)
        .animation(.smooth(duration: 0.35), value: areLandscapeControlsVisible)
        .ignoresSafeArea(edges: isFullscreen ? .all : Edge.Set())
    }

    private var fullscreenCloseButton: some View {
        ZStack {
            VStack {
                HStack {
                    Spacer()
                    Button {
                        isFullscreen = false
                        dismissPlayer()
                    } label: {
                        ZStack {
                            Circle().fill(.black.opacity(0.55)).frame(width: 40, height: 40)
                            Image(systemName: "xmark")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                    }
                    .padding(.trailing, 16)
                    .padding(.top, 8)
                }
                Spacer()
            }
            .opacity(areLandscapeControlsVisible ? 1 : 0)
            .allowsHitTesting(areLandscapeControlsVisible)
        }
    }

    private var fullscreenControlsLayer: some View {
        Group {
            if usesPortraitFullscreenLayout {
                portraitFullscreenControlsPanel
            } else {
                landscapeControlsPanel
            }
        }
            .opacity(areLandscapeControlsVisible ? 1 : 0)
            .allowsHitTesting(areLandscapeControlsVisible)
    }

    // MARK: - Header & rows

    private var header: some View {
        HStack {
            Button {
                dismissPlayer()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                    .frame(width: 36, height: 36)
            }
            Spacer()
            Text("Video Player")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
            Spacer()
            HStack(spacing: 4) {
                Button {
                    showShareSheet = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 17))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 36, height: 36)
                }
                Button {
                    showGearSheet = true
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 18))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 36, height: 36)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var speedPillsRow: some View {
        HStack(spacing: 8) {
            ForEach(VideoSpeed.allCases, id: \.self) { speed in
                Button {
                    prefs.speed = speed
                    controller.setRate(speed.value)
                } label: {
                    Text(speed.pillLabel)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(prefs.speed == speed ? .white : Theme.textPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(prefs.speed == speed ? Theme.accent : .clear)
                        .clipShape(.rect(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(prefs.speed == speed ? Theme.accent : Theme.border, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var countdownRow: some View {
        HStack(spacing: 6) {
            Image(systemName: "clock")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textMuted)
            Text("\(Format.playerTime(max(controller.duration - displayTime, 0))) left")
                .font(.system(size: 13))
                .foregroundStyle(Theme.textMuted)
                .monospacedDigit()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Theme.input)
        .clipShape(.rect(cornerRadius: 8))
    }

    private var statusActionsRow: some View {
        HStack(spacing: 0) {
            statusAction(icon: "circle", color: Theme.textMuted, label: "Not Watched", status: .notWatched)
            statusAction(icon: "checkmark", color: Theme.success, label: "Watched", status: .watched)
            statusAction(icon: "heart.fill", color: Theme.destructive, label: "Liked", status: .liked)
            statusAction(icon: "clock", color: Theme.warning, label: "Watch Later", status: .watchLater)
        }
        .padding(.horizontal, 8)
    }

    private func statusAction(icon: String, color: Color, label: String, status: ItemStatus) -> some View {
        Button {
            setStatus(status)
        } label: {
            VStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 17))
                    .foregroundStyle(color)
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }

    private var openInYouTubeRow: some View {
        Button {
            if let url = URL(string: watchURL) {
                openURL(url)
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "arrow.up.right.square")
                    .font(.system(size: 14))
                Text("Open in YouTube")
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundStyle(Theme.accent)
        }
    }

    // MARK: - Video & controls

    private var persistentVideoArea: some View {
        ZStack {
            Color.black
            if showLoadError {
                VStack(spacing: 10) {
                    Text("Couldn't load video")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Text("This video may have embedding disabled by its owner.")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                    Button {
                        if let url = URL(string: watchURL) { openURL(url) }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.up.right.square")
                                .font(.system(size: 14))
                            Text("Open in YouTube")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Theme.destructive)
                        .clipShape(.rect(cornerRadius: 10))
                    }
                }
                .padding(20)
            } else {
                interactivePlayerView
                if !controller.isReady {
                    ProgressView()
                        .controlSize(.large)
                        .tint(Theme.accent)
                }
            }
        }
    }

    private var playerView: some View {
        YouTubePlayerWebView(videoId: request.videoId, controller: controller)
    }

    private var interactivePlayerView: some View {
        playerView
            .overlay {
                GeometryReader { geometry in
                    Color.clear
                        .contentShape(Rectangle())
                        .gesture(playerTapGesture(in: geometry.size.width))
                        .accessibilityElement()
                        .accessibilityLabel("Video")
                        .accessibilityAction(named: Text("Rewind 15 seconds")) {
                            seekBy15Seconds(forward: false)
                        }
                        .accessibilityAction(named: Text("Forward 15 seconds")) {
                            seekBy15Seconds(forward: true)
                        }
                }
            }
    }

    private func playerTapGesture(in width: CGFloat) -> some Gesture {
        SpatialTapGesture(count: 2)
            .exclusively(before: SpatialTapGesture(count: 1))
            .onEnded { value in
                switch value {
                case .first(let doubleTap):
                    seekBy15Seconds(forward: doubleTap.location.x >= width / 2)
                    if isFullscreen {
                        showLandscapeControlsTemporarily()
                    }
                case .second:
                    if isFullscreen {
                        showLandscapeControlsTemporarily()
                    }
                }
            }
    }

    private func seekBy15Seconds(forward: Bool) {
        guard controller.isReady else { return }
        let delta = forward ? 15.0 : -15.0
        let upperBound = controller.duration > 0 ? controller.duration : .greatestFiniteMagnitude
        let target = max(0, min(controller.currentTime + delta, upperBound))
        controller.seek(to: target)
        controller.currentTime = target
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private var controlsStrip: some View {
        VStack(spacing: 4) {
            progressRow(fullscreen: false)
            transportRow(iconScale: 1)
            volumeControl
                .frame(maxWidth: 260)
                .padding(.bottom, 10)
        }
        .background(Color.black)
        .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: 10, bottomTrailingRadius: 10))
    }

    private var landscapeControlsPanel: some View {
        VStack(spacing: 2) {
            progressRow(fullscreen: true)

            HStack(alignment: .center, spacing: 14) {
                transportButtons(iconScale: 0.9)
                volumeControl
                    .frame(width: 150)

                Spacer(minLength: 12)

                speedPillsRow
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
        .background(Color.black)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(.white.opacity(0.12))
                .frame(height: 1)
        }
    }

    private var portraitFullscreenControlsPanel: some View {
        VStack(spacing: 4) {
            progressRow(fullscreen: true)
            transportRow(iconScale: 1)
            volumeControl
                .frame(maxWidth: 260)
                .padding(.bottom, 14)
        }
        .background(Color.black.opacity(0.88))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(.white.opacity(0.12))
                .frame(height: 1)
        }
    }

    private func progressRow(fullscreen: Bool) -> some View {
        HStack(spacing: 10) {
            Text(Format.playerTime(displayTime))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.textMuted)
                .monospacedDigit()
                .frame(minWidth: 40)

            scrubber

            Text(Format.playerTime(controller.duration))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.textMuted)
                .monospacedDigit()
                .frame(minWidth: 40)

            Button {
                toggleFullscreen()
            } label: {
                Image(systemName: fullscreen
                      ? "arrow.down.right.and.arrow.up.left"
                      : "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 32, height: 32)
                    .background(.white.opacity(0.08))
                    .clipShape(.rect(cornerRadius: 8))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var scrubber: some View {
        GeometryReader { geo in
            let fraction = controller.duration > 0 ? min(max(displayTime / controller.duration, 0), 1) : 0
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.white.opacity(0.15))
                    .frame(height: 4)
                Capsule()
                    .fill(Theme.accent)
                    .frame(width: geo.size.width * fraction, height: 4)
                Circle()
                    .fill(.white)
                    .frame(width: 12, height: 12)
                    .scaleEffect(isScrubbing ? 1.3 : 1)
                    .opacity(isScrubbing ? 1 : 0.6)
                    .shadow(color: .black.opacity(0.4), radius: 2)
                    .offset(x: geo.size.width * fraction - 6)
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard controller.duration > 0 else { return }
                        isScrubbing = true
                        let fraction = min(max(value.location.x / geo.size.width, 0), 1)
                        scrubTime = fraction * controller.duration
                    }
                    .onEnded { _ in
                        controller.seek(to: scrubTime)
                        controller.currentTime = scrubTime
                        isScrubbing = false
                    }
            )
        }
        .frame(height: 32)
    }

    private func transportRow(iconScale: CGFloat) -> some View {
        transportButtons(iconScale: iconScale)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
    }

    private func transportButtons(iconScale: CGFloat) -> some View {
        HStack(spacing: 24) {
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                controller.skip(-10)
            } label: {
                Image(systemName: "gobackward.10")
                    .font(.system(size: 20 * iconScale))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(.white.opacity(0.15))
                    .clipShape(Circle())
            }
            .accessibilityLabel("Go back 10 seconds")

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                controller.togglePlayback()
            } label: {
                Image(systemName: controller.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 22 * iconScale))
                    .foregroundStyle(.white)
                    .frame(width: 52, height: 52)
                    .background(.white.opacity(0.22))
                    .clipShape(Circle())
            }
            .accessibilityLabel(controller.isPlaying ? "Pause" : "Play")

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                controller.skip(10)
            } label: {
                Image(systemName: "goforward.10")
                    .font(.system(size: 20 * iconScale))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(.white.opacity(0.15))
                    .clipShape(Circle())
            }
            .accessibilityLabel("Go forward 10 seconds")
        }
    }

    private var volumeControl: some View {
        HStack(spacing: 8) {
            Button {
                toggleMute()
            } label: {
                Image(systemName: volumeIcon)
                    .font(.system(size: 15))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(.white.opacity(0.12))
                    .clipShape(Circle())
            }
            .accessibilityLabel(isMuted ? "Turn sound on" : "Mute")

            SystemVolumeSlider(value: volumeBinding)
                .frame(height: 36)
                .accessibilityLabel("Video volume")
                .accessibilityValue("\(Int(volume.rounded())) percent")
        }
    }

    private var volumeBinding: Binding<Double> {
        Binding(
            get: { volume },
            set: { newValue in
                volume = newValue
                controller.setVolume(Int(newValue.rounded()))
                if newValue <= 0 {
                    isMuted = true
                    controller.mute()
                } else if isMuted {
                    isMuted = false
                    controller.unmute()
                }
            }
        )
    }

    private var volumeIcon: String {
        if isMuted || volume <= 0 { return "speaker.slash.fill" }
        if volume < 40 { return "speaker.wave.1.fill" }
        return "speaker.wave.2.fill"
    }

    private func toggleMute() {
        isMuted.toggle()
        if isMuted {
            controller.mute()
        } else {
            if volume <= 0 { volume = 50 }
            controller.setVolume(Int(volume.rounded()))
            controller.unmute()
        }
    }

    // MARK: - Overlays & sheets

    private var watchedOverlay: some View {
        VStack(spacing: 8) {
            Text("Marked as Watched")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.white)
            Text("Video has been marked as watched in your library.")
                .font(.system(size: 14))
                .foregroundStyle(Color(red: 0x94 / 255, green: 0xA3 / 255, blue: 0xB8 / 255))
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 20)
        .background(Color(red: 0x1E / 255, green: 0x29 / 255, blue: 0x3B / 255))
        .clipShape(.rect(cornerRadius: 12))
        .shadow(color: .white.opacity(0.2), radius: 16)
        .transition(.opacity)
    }

    private var gearSheet: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 4) {
                sheetSectionTitle("Quality")
                ForEach(VideoQuality.allCases, id: \.self) { quality in
                    sheetRow(label: quality.label, isSelected: prefs.quality == quality) {
                        prefs.quality = quality
                        controller.setQuality(quality.youtubeValue)
                    }
                }
                sheetSectionTitle("Speed")
                    .padding(.top, 12)
                ForEach(VideoSpeed.allCases, id: \.self) { speed in
                    sheetRow(label: speed.label, isSelected: prefs.speed == speed) {
                        prefs.speed = speed
                        controller.setRate(speed.value)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 32)
        }
        .presentationDetents([.medium, .large])
        .presentationContentInteraction(.scrolls)
        .presentationDragIndicator(.visible)
        .presentationBackground(Theme.card)
    }

    private var shareSheet: some View {
        VStack(alignment: .leading, spacing: 4) {
            sheetSectionTitle("Share")

            Text(watchURL)
                .font(.system(size: 14))
                .foregroundStyle(Theme.accent)
                .lineLimit(2)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.input)
                .clipShape(.rect(cornerRadius: 10))
                .padding(.bottom, 8)

            Button {
                UIPasteboard.general.string = watchURL
                showShareSheet = false
                toasts.show("Link copied")
            } label: {
                shareRowContent(icon: "doc.on.doc", label: "Copy link", color: Theme.textSecondary)
            }
            .buttonStyle(.plain)

            Divider().background(Theme.border).padding(.vertical, 6)

            ShareLink(item: URL(string: watchURL)!, message: Text("Check out this video:")) {
                shareRowContent(icon: "square.and.arrow.up", label: "More…", color: Theme.textSecondary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .presentationDetents([.height(280)])
        .presentationDragIndicator(.visible)
        .presentationBackground(Theme.card)
    }

    private func shareRowContent(icon: String, label: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.textPrimary)
            Spacer()
        }
        .padding(.vertical, 13)
        .contentShape(Rectangle())
    }

    private func sheetSectionTitle(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 13, weight: .bold))
            .kerning(0.8)
            .foregroundStyle(Theme.textMuted)
            .padding(.bottom, 6)
    }

    private func sheetRow(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(label)
                    .font(.system(size: 15, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? .white : Theme.textPrimary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .background(isSelected ? Color(hsl: 199, 89, 48, alpha: 0.12) : .clear)
            .clipShape(.rect(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Lifecycle & behavior

    private func toggleFullscreen() {
        let enteringFullscreen = !isFullscreen
        hasManualFullscreenPreference = true

        withAnimation(.smooth(duration: 0.5)) {
            isFullscreen = enteringFullscreen
        }

        if enteringFullscreen {
            showLandscapeControlsTemporarily()
        } else {
            resetLandscapeControls()
        }
    }

    private func updateFullscreen(for size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        let isLandscape = size.width > size.height
        let orientationChanged = isLandscape != isDeviceLandscape

        guard orientationChanged else { return }

        // The system already animates the window geometry during rotation.
        // Update orientation once without starting competing animations for
        // each intermediate size reported by GeometryReader.
        isDeviceLandscape = isLandscape

        // Before the user explicitly chooses Expand or Collapse, retain
        // automatic landscape fullscreen. After a manual choice, rotation
        // only changes the layout and never overrides that choice.
        if !hasManualFullscreenPreference {
            isFullscreen = isLandscape
        }

        if isFullscreen && areLandscapeControlsVisible {
            showLandscapeControlsTemporarily()
        } else if !isFullscreen {
            resetLandscapeControls()
        }
    }

    private func showLandscapeControlsTemporarily() {
        landscapeControlsTask?.cancel()
        withAnimation(.smooth(duration: 0.4)) {
            areLandscapeControlsVisible = true
        }
        landscapeControlsTask = Task {
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled, isFullscreen else { return }
            withAnimation(.smooth(duration: 0.4)) {
                areLandscapeControlsVisible = false
            }
        }
    }

    private func resetLandscapeControls() {
        landscapeControlsTask?.cancel()
        landscapeControlsTask = nil
        areLandscapeControlsVisible = true
    }

    private func startPlayerLifecycle() {
        if prefs.keepScreenOn {
            UIApplication.shared.isIdleTimerDisabled = true
        }

        controller.onReady = {
            if let itemId = request.itemId, controller.duration > 0 {
                let exactDuration = Int(controller.duration.rounded())
                Task {
                    try? await SupabaseService.shared.updateItemDuration(
                        itemId: itemId,
                        durationSeconds: exactDuration
                    )
                }
            }
            // Apply persisted speed + quality, resume saved position
            if prefs.speed != .x1 {
                controller.setRate(prefs.speed.value)
            }
            controller.setQuality(prefs.quality.youtubeValue)
            if let saved = prefs.savedPosition(videoId: request.videoId), saved.duration > 0 {
                if saved.time / saved.duration < 0.95 {
                    controller.seek(to: saved.time)
                } else {
                    prefs.clearPosition(videoId: request.videoId)
                }
            }
        }

        controller.onEnded = {
            prefs.clearPosition(videoId: request.videoId)
            markWatchedAndDismiss()
        }

        // Show load error if the player errors and never starts playing
        Task {
            try? await Task.sleep(for: .seconds(4))
            if controller.loadFailed && !controller.isPlaying {
                showLoadError = true
            }
        }

        // Periodically persist the resume position while playing
        savePositionTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                if controller.isPlaying {
                    persistPosition()
                }
            }
        }
    }

    private func persistPosition() {
        guard controller.duration > 0, controller.currentTime > 0 else { return }
        prefs.savePosition(videoId: request.videoId, time: controller.currentTime, duration: controller.duration)
    }

    private func setStatus(_ status: ItemStatus) {
        UISelectionFeedbackGenerator().selectionChanged()
        if status == .watched {
            markWatchedAndDismiss()
            return
        }
        // Show the popup straight away; the Supabase write runs in the
        // background instead of holding up the feedback.
        toasts.show("Marked as \(status.actionLabel)", type: .info)
        saveStatus(status)
    }

    /// Updates the feed immediately through the router, then writes the
    /// status to Supabase in the background.
    private func saveStatus(_ status: ItemStatus) {
        guard let itemId = request.itemId else { return }
        router.reportStatusChange(itemId: itemId, status: status)
        Task {
            do {
                try await SupabaseService.shared.updateItemStatus(id: itemId, status: status)
            } catch {
                toasts.show("Couldn't update status", type: .error)
            }
            router.settleStatusChange(itemId: itemId)
        }
    }

    private func markWatchedAndDismiss() {
        guard !markedWatchedOnce else { return }
        markedWatchedOnce = true
        saveStatus(.watched)
        showWatchedThenDismiss()
    }

    private func showWatchedThenDismiss() {
        withAnimation(.easeIn(duration: 0.15)) { showWatchedOverlay = true }
        Task {
            try? await Task.sleep(for: .seconds(1.2))
            withAnimation(.easeOut(duration: 0.2)) { showWatchedOverlay = false }
            try? await Task.sleep(for: .seconds(0.2))
            dismiss()
        }
    }

    private func dismissPlayer() {
        persistPosition()
        dismiss()
    }
}
