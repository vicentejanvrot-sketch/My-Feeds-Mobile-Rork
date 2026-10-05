import SwiftUI
import LocalAuthentication

// MARK: - Login palette

fileprivate func mfLoginColor(_ hex: UInt32, _ alpha: Double = 1) -> Color {
    Color(
        red: Double((hex >> 16) & 0xFF) / 255,
        green: Double((hex >> 8) & 0xFF) / 255,
        blue: Double(hex & 0xFF) / 255,
        opacity: alpha
    )
}

fileprivate enum LBColor {
    static let background = mfLoginColor(0x050B1A)
    static let glow = mfLoginColor(0x0E8CE6, 0.20)
    static let iconGlow = mfLoginColor(0x22B8F5)
    static let tagline = mfLoginColor(0xA9B8D6)
    static let formBackground = mfLoginColor(0x0A1428, 0.94)
    static let formBorder = mfLoginColor(0x1C2B4D)
    static let label = mfLoginColor(0xC9D6EE)
    static let link = mfLoginColor(0x7DD3FC)
    static let input = mfLoginColor(0x0E1A33)
    static let inputBorder = mfLoginColor(0x253558)
    static let inputFocus = mfLoginColor(0x38BDF8)
    static let placeholderToggle = mfLoginColor(0x93A6C8)
    static let button = mfLoginColor(0x0A74BD)

    // Background cards
    static let card = mfLoginColor(0x0D1B38)
    static let cardBorder = mfLoginColor(0x22396A)
    static let bar = mfLoginColor(0x34508A)
    static let barStrong = mfLoginColor(0x3A5794)
    static let barDim = mfLoginColor(0x22396A)
    static let icon = mfLoginColor(0x8EA0C2)
    static let media = mfLoginColor(0x16294F)
}

// MARK: - Background platform cards
//
// Faded platform-style cards, iPad only (iPhone shows none). They sit in a rail on
// each side of the sign-in column, and the rails clip them, so they never cover the
// logo, the app name or the sign-in box.

fileprivate struct LBBar: View {
    let width: CGFloat
    var height: CGFloat = 8
    var color: Color = LBColor.bar

    var body: some View {
        RoundedRectangle(cornerRadius: height / 2)
            .fill(color)
            .frame(width: width, height: height)
    }
}

fileprivate struct LBIcon: View {
    let name: String
    var size: CGFloat = 15
    var color: Color = LBColor.icon

    var body: some View {
        Image(systemName: name)
            .font(.system(size: size, weight: .medium))
            .foregroundStyle(color)
    }
}

fileprivate struct LBCardShell: ViewModifier {
    let width: CGFloat
    var padding: CGFloat = 14
    var background: Color = LBColor.card
    var border: Color = LBColor.cardBorder

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(width: width, alignment: .leading)
            .background(background)
            .clipShape(.rect(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(border, lineWidth: 1))
            .shadow(color: .black.opacity(0.45), radius: 25, y: 20)
    }
}

fileprivate struct LBVideoCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack {
                LBColor.media
                Circle()
                    .fill(Color.white.opacity(0.14))
                    .frame(width: 52, height: 52)
                    .overlay(LBIcon(name: "play.fill", size: 18, color: mfLoginColor(0xE8EEF9)))
            }
            .frame(height: 158)
            .overlay(alignment: .bottomTrailing) {
                Text("12:48")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.black.opacity(0.6))
                    .clipShape(.rect(cornerRadius: 4))
                    .padding(.trailing, 8)
                    .padding(.bottom, 12)
            }
            .overlay(alignment: .bottomLeading) {
                ZStack(alignment: .leading) {
                    Rectangle().fill(mfLoginColor(0x24375E))
                    Rectangle().fill(mfLoginColor(0xE5484D)).frame(width: 171)
                }
                .frame(height: 4)
            }
            .clipShape(.rect(cornerRadius: 12))

            HStack(alignment: .top, spacing: 10) {
                Circle().fill(LBColor.barDim).frame(width: 34, height: 34)
                VStack(alignment: .leading, spacing: 7) {
                    LBBar(width: 212)
                    LBBar(width: 161)
                    LBBar(width: 110, height: 7, color: LBColor.barDim)
                }
                .padding(.top, 2)
            }
        }
        .modifier(LBCardShell(width: 300, padding: 12))
    }
}

fileprivate struct LBRedditCard: View {
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(spacing: 4) {
                LBIcon(name: "arrowshape.up", size: 15, color: mfLoginColor(0xFF6A33))
                Text("2.4k")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(LBColor.label)
                LBIcon(name: "arrowshape.down", size: 15, color: mfLoginColor(0x5B7BB0))
            }
            .frame(width: 34)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Circle().fill(mfLoginColor(0xFF6A33)).frame(width: 16, height: 16)
                    LBBar(width: 60, height: 7, color: LBColor.barDim)
                }
                LBBar(width: 166, height: 10, color: LBColor.barStrong)
                LBBar(width: 124, height: 10, color: LBColor.barStrong)
                LBBar(width: 158, height: 7, color: LBColor.barDim)
                LBBar(width: 132, height: 7, color: LBColor.barDim)
                HStack(spacing: 6) {
                    LBIcon(name: "bubble.right", size: 12)
                    LBBar(width: 40, height: 7, color: LBColor.barDim)
                }
            }
        }
        .padding(.leading, -6)
        .modifier(LBCardShell(width: 230))
    }
}

fileprivate struct LBXCard: View {
    var body: some View {
        let iconColor = mfLoginColor(0x6B7FA6)
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Circle().fill(mfLoginColor(0x2A3A5A)).frame(width: 36, height: 36)
                VStack(alignment: .leading, spacing: 6) {
                    LBBar(width: 92, color: mfLoginColor(0x4A5D82))
                    LBBar(width: 66, height: 7, color: mfLoginColor(0x2A3A5A))
                }
            }
            LBBar(width: 252, color: mfLoginColor(0x33466B))
            LBBar(width: 237, color: mfLoginColor(0x33466B))
            LBBar(width: 146, color: mfLoginColor(0x33466B))
            HStack {
                LBIcon(name: "bubble.right", color: iconColor)
                Spacer()
                LBIcon(name: "arrow.2.squarepath", color: iconColor)
                Spacer()
                LBIcon(name: "heart", color: iconColor)
                Spacer()
                LBIcon(name: "chart.bar", color: iconColor)
            }
            .padding(.trailing, 30)
        }
        .modifier(LBCardShell(width: 280, background: mfLoginColor(0x0A101E), border: mfLoginColor(0x22314F)))
    }
}

fileprivate struct LBSpotifyCard: View {
    var body: some View {
        let green = mfLoginColor(0x1ED760)
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(LinearGradient(colors: [mfLoginColor(0x1F3B70), mfLoginColor(0x3A2A5E)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 52, height: 52)
                VStack(alignment: .leading, spacing: 7) {
                    LBBar(width: 120, height: 10, color: LBColor.barStrong)
                    LBBar(width: 78, height: 7, color: LBColor.barDim)
                }
                Spacer(minLength: 0)
                LBIcon(name: "heart.fill", size: 16, color: green)
            }
            HStack(spacing: 8) {
                Text("1:24").font(.system(size: 10)).foregroundStyle(mfLoginColor(0x7F8DAA))
                ZStack(alignment: .leading) {
                    Capsule().fill(LBColor.barDim)
                    Capsule().fill(green).frame(width: 80)
                }
                .frame(height: 4)
                Text("3:51").font(.system(size: 10)).foregroundStyle(mfLoginColor(0x7F8DAA))
            }
            HStack(spacing: 22) {
                LBIcon(name: "shuffle", size: 13, color: mfLoginColor(0x6B7FA6))
                LBIcon(name: "backward.end.fill", size: 15, color: LBColor.label)
                Circle()
                    .fill(green)
                    .frame(width: 40, height: 40)
                    .overlay(LBIcon(name: "play.fill", size: 15, color: mfLoginColor(0x06120B)))
                LBIcon(name: "forward.end.fill", size: 15, color: LBColor.label)
                LBIcon(name: "repeat", size: 13, color: mfLoginColor(0x6B7FA6))
            }
            .frame(maxWidth: .infinity)
        }
        .modifier(LBCardShell(width: 300))
    }
}

fileprivate struct LBGithubCard: View {
    private static let levels: [Int] = [
        0, 2, 0, 1, 3, 0, 1, 4, 0, 2, 1, 0, 3, 2,
        1, 0, 3, 2, 0, 4, 1, 0, 2, 3, 0, 1, 0, 4,
        2, 3, 0, 1, 4, 2, 0, 3, 1, 0, 2, 4, 1, 0,
        0, 1, 2, 0, 3, 0, 4, 2, 0, 1, 3, 0, 2, 1,
        3, 0, 1, 4, 0, 2, 1, 3, 0, 2, 0, 4, 1, 0,
    ]
    private static let greens: [Color] = [
        mfLoginColor(0x10261F), mfLoginColor(0x0E4429), mfLoginColor(0x006D32),
        mfLoginColor(0x26A641), mfLoginColor(0x39D353),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                LBIcon(name: "book.closed", size: 13)
                LBBar(width: 50, color: LBColor.barStrong)
                Text("/").font(.system(size: 12)).foregroundStyle(mfLoginColor(0x5B7BB0))
                LBBar(width: 70, color: mfLoginColor(0x4A6BA8))
            }
            LBBar(width: 198, height: 7, color: LBColor.barDim)
            LBBar(width: 146, height: 7, color: LBColor.barDim)
            VStack(alignment: .leading, spacing: 3) {
                ForEach(0..<5, id: \.self) { row in
                    HStack(spacing: 3) {
                        ForEach(0..<14, id: \.self) { col in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Self.greens[Self.levels[row * 14 + col]])
                                .frame(width: 10, height: 10)
                        }
                    }
                }
            }
            HStack(spacing: 14) {
                HStack(spacing: 5) {
                    Circle().fill(mfLoginColor(0x3178C6)).frame(width: 10, height: 10)
                    Text("TS")
                }
                HStack(spacing: 4) {
                    LBIcon(name: "star", size: 11)
                    Text("1.2k")
                }
                HStack(spacing: 4) {
                    LBIcon(name: "arrow.triangle.branch", size: 11)
                    Text("86")
                }
            }
            .font(.system(size: 11))
            .foregroundStyle(LBColor.icon)
        }
        .modifier(LBCardShell(width: 236, background: mfLoginColor(0x0B1424), border: mfLoginColor(0x23324D)))
    }
}

fileprivate struct LBInstagramCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            colors: [mfLoginColor(0xF9A13B), mfLoginColor(0xE1306C), mfLoginColor(0x8A3AB9)],
                            startPoint: .bottomLeading,
                            endPoint: .topTrailing
                        ))
                    Circle().fill(LBColor.card).padding(2)
                    Circle().fill(LBColor.barDim).padding(4)
                }
                .frame(width: 34, height: 34)
                LBBar(width: 94, color: LBColor.barStrong)
            }
            RoundedRectangle(cornerRadius: 10)
                .fill(LinearGradient(colors: [mfLoginColor(0x1B3A6B), mfLoginColor(0x2B2350)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 236, height: 236)
            HStack(spacing: 14) {
                LBIcon(name: "heart", size: 17, color: mfLoginColor(0xE1306C))
                LBIcon(name: "bubble.right", size: 17)
                LBIcon(name: "paperplane", size: 17)
                Spacer()
                LBIcon(name: "bookmark", size: 17)
            }
            LBBar(width: 83)
        }
        .modifier(LBCardShell(width: 260, padding: 12))
    }
}

fileprivate struct LBFacebookCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Circle().fill(LBColor.barDim).frame(width: 36, height: 36)
                VStack(alignment: .leading, spacing: 6) {
                    LBBar(width: 118, color: LBColor.barStrong)
                    LBBar(width: 60, height: 7, color: LBColor.barDim)
                }
            }
            LBBar(width: 236, color: mfLoginColor(0x2A4272))
            RoundedRectangle(cornerRadius: 8).fill(LBColor.media).frame(height: 120)
            HStack(spacing: 6) {
                HStack(spacing: -5) {
                    Circle()
                        .fill(mfLoginColor(0x1877F2))
                        .frame(width: 18, height: 18)
                        .overlay(LBIcon(name: "hand.thumbsup.fill", size: 8, color: .white))
                        .overlay(Circle().stroke(LBColor.card, lineWidth: 2))
                    Circle()
                        .fill(mfLoginColor(0xF33E58))
                        .frame(width: 18, height: 18)
                        .overlay(LBIcon(name: "heart.fill", size: 8, color: .white))
                        .overlay(Circle().stroke(LBColor.card, lineWidth: 2))
                }
                LBBar(width: 40, height: 7, color: LBColor.barDim)
            }
            Rectangle().fill(LBColor.barDim).frame(height: 1)
            HStack {
                Spacer()
                LBIcon(name: "hand.thumbsup")
                Spacer()
                LBIcon(name: "bubble.right")
                Spacer()
                LBIcon(name: "arrowshape.turn.up.right")
                Spacer()
            }
        }
        .modifier(LBCardShell(width: 290))
    }
}

fileprivate struct LBAppleMusicCard: View {
    private static let covers: [[Color]] = [
        [mfLoginColor(0xFA2D48), mfLoginColor(0x7A1E3A)],
        [mfLoginColor(0x2B4C9B), mfLoginColor(0x162A55)],
        [mfLoginColor(0x8A3AB9), mfLoginColor(0x3B1E5E)],
        [mfLoginColor(0xF27A54), mfLoginColor(0x7A2E2E)],
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                LBIcon(name: "music.note", size: 13, color: mfLoginColor(0xFA2D48))
                LBBar(width: 88, color: LBColor.barStrong)
            }
            VStack(spacing: 8) {
                HStack(spacing: 8) { cover(0); cover(1) }
                HStack(spacing: 8) { cover(2); cover(3) }
            }
            LBBar(width: 118, height: 7, color: LBColor.barDim)
        }
        .modifier(LBCardShell(width: 220, padding: 12))
    }

    private func cover(_ i: Int) -> some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(LinearGradient(colors: Self.covers[i], startPoint: .topLeading, endPoint: .bottomTrailing))
            .frame(width: 94, height: 94)
    }
}

/// Where a card sits, in percent of the band or rail, plus its tilt.
fileprivate struct LBSpot {
    let x: CGFloat
    let y: CGFloat
    let r: Double
}

fileprivate enum LBSpots {
    static let wideLeft = [LBSpot(x: -6, y: 5, r: -8), LBSpot(x: 55, y: 26, r: 5), LBSpot(x: 6, y: 46, r: 6), LBSpot(x: 26, y: 74, r: -4)]
    static let wideRight = [LBSpot(x: 10, y: 9, r: -6), LBSpot(x: 56, y: 3, r: 7), LBSpot(x: 42, y: 50, r: -5), LBSpot(x: 8, y: 70, r: 4)]
}

/// A clipped area holding four faded cards, with a fade toward the sign-in column.
fileprivate struct LBCardField: View {
    enum CardSet { case first, second }   // first: YouTube, X, Reddit, Spotify. second: GitHub, Instagram, Facebook, Apple Music.
    enum FadeEdge { case bottom, top, trailing, leading }

    let cards: CardSet
    let spots: [LBSpot]
    let scale: CGFloat
    let opacity: Double
    let fadeToward: FadeEdge

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                switch cards {
                case .first:
                    placed(0, geo.size) { LBVideoCard() }
                    placed(1, geo.size) { LBXCard() }
                    placed(2, geo.size) { LBRedditCard() }
                    placed(3, geo.size) { LBSpotifyCard() }
                case .second:
                    placed(0, geo.size) { LBGithubCard() }
                    placed(1, geo.size) { LBInstagramCard() }
                    placed(2, geo.size) { LBFacebookCard() }
                    placed(3, geo.size) { LBAppleMusicCard() }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
            .clipped()
            .mask(fade)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func placed<V: View>(_ i: Int, _ size: CGSize, @ViewBuilder _ content: () -> V) -> some View {
        let spot = spots[i]
        return content()
            .fixedSize()
            .scaleEffect(scale, anchor: .topLeading)
            .rotationEffect(.degrees(spot.r), anchor: .topLeading)
            .opacity(opacity)
            .offset(x: size.width * spot.x / 100, y: size.height * spot.y / 100)
    }

    /// Mask that fades the cards out toward the sign-in column (like the web's CSS mask),
    /// so the background and glow show through instead of a painted colour.
    private var fade: LinearGradient {
        let shown = Color.black
        let hidden = Color.clear
        switch fadeToward {
        case .bottom:
            return LinearGradient(colors: [shown, hidden], startPoint: UnitPoint(x: 0.5, y: 0.55), endPoint: .bottom)
        case .top:
            return LinearGradient(colors: [hidden, shown], startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.45))
        case .trailing:
            return LinearGradient(colors: [shown, hidden], startPoint: UnitPoint(x: 0.5, y: 0.5), endPoint: .trailing)
        case .leading:
            return LinearGradient(colors: [hidden, shown], startPoint: .leading, endPoint: UnitPoint(x: 0.5, y: 0.5))
        }
    }
}

// MARK: - Login screen

struct LoginView: View {
    @Binding var path: [AuthRoute]
    @Environment(AuthStore.self) private var auth
    @Environment(VideoPrefs.self) private var prefs

    @State private var email = ""
    @State private var password = ""
    @State private var showPassword = false
    @State private var isLoading = false
    @State private var isBiometricLoading = false
    @State private var toast: AuthToast?
    @State private var legalPage: LegalPage?
    @FocusState private var focusedField: Field?

    private enum Field { case email, password }

    private enum LegalPage: String, Identifiable {
        case privacy, terms
        var id: String { rawValue }
    }

    /// The display name for the available biometric ("Face ID", "Touch ID", etc.), if any.
    private var biometryName: String? { BiometricAuthService.biometryName }

    /// Whether the biometric quick sign-in button should appear.
    private var showsBiometricLogin: Bool {
        auth.isBiometricLoginAvailable && biometryName != nil
    }

    var body: some View {
        GeometryReader { geo in
            let isWide = geo.size.width >= 768

            ZStack(alignment: .top) {
                LBColor.background.ignoresSafeArea()
                // Same glow as the web: an oval 110% of the width by 84% of the height,
                // centred at 22% from the top, fading out at 70% of its radius.
                EllipticalGradient(
                    colors: [LBColor.glow, LBColor.glow.opacity(0)],
                    center: .center,
                    startRadiusFraction: 0,
                    endRadiusFraction: 0.7
                )
                .frame(width: geo.size.width * 1.1, height: geo.size.height * 0.84)
                .position(x: geo.size.width * 0.5, y: geo.size.height * 0.22)
                .allowsHitTesting(false)

                ScrollView {
                    if isWide {
                        wideLayout(geo.size)
                    } else {
                        phoneLayout(geo.size)
                    }
                }
                .scrollDismissesKeyboard(.interactively)
                .scrollBounceBehavior(.basedOnSize)

                if let toast {
                    toastView(toast)
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: toast)
        .onChange(of: toast) { _, newValue in
            guard newValue != nil else { return }
            Task {
                try? await Task.sleep(for: .seconds(3.5))
                withAnimation { toast = nil }
            }
        }
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $legalPage) { page in
            NavigationStack {
                Group {
                    switch page {
                    case .privacy: PrivacyPolicyView()
                    case .terms: TermsView()
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { legalPage = nil }
                            .foregroundStyle(Theme.accent)
                    }
                }
            }
        }
        .task {
            // Pre-fill the email from any saved biometric credentials.
            if email.isEmpty, let saved = auth.biometricSavedEmail {
                email = saved
            }
        }
    }

    // MARK: - Layouts

    /// iPhone: no background cards (too busy on a small screen), just the glow,
    /// with the logo and form centred.
    private func phoneLayout(_ size: CGSize) -> some View {
        VStack(spacing: 0) {
            Spacer(minLength: 24)
            centerColumn
                .padding(.horizontal, 20)
            Spacer(minLength: 24)
        }
        .frame(minHeight: size.height)
    }

    private func wideLayout(_ size: CGSize) -> some View {
        let railWidth = max(0, (size.width - 440) / 2)
        let scale = max(0.5, min(1, railWidth / 480)) * (size.height < 760 ? 0.85 : 1)

        return HStack(spacing: 0) {
            LBCardField(cards: .first, spots: LBSpots.wideLeft, scale: scale, opacity: 0.3, fadeToward: .trailing)
                .frame(maxWidth: .infinity)
                .frame(height: size.height)
            centerColumn
                .padding(.vertical, 24)
                .frame(width: 420)
                .padding(.horizontal, 10)
            LBCardField(cards: .second, spots: LBSpots.wideRight, scale: scale, opacity: 0.3, fadeToward: .leading)
                .frame(maxWidth: .infinity)
                .frame(height: size.height)
        }
        .frame(minHeight: size.height)
    }

    // MARK: - Sign-in column

    private var centerColumn: some View {
        VStack(spacing: 24) {
            VStack(spacing: 0) {
                Image("AppLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 72, height: 72)
                    .clipShape(.rect(cornerRadius: 18))
                    .shadow(color: LBColor.iconGlow.opacity(0.55), radius: 18)
                    .padding(.bottom, 14)
                Text("My Feeds")
                    .font(.system(size: 30, weight: .bold))
                    .kerning(-0.5)
                    .foregroundStyle(.white)
                    .padding(.bottom, 6)
                Text("Your favorite creators, organized for you.")
                    .font(.system(size: 15))
                    .foregroundStyle(LBColor.tagline)
                    .multilineTextAlignment(.center)
            }

            formCard

            // Legal links, same as the web login
            HStack(spacing: 20) {
                Button("Privacy Policy") { legalPage = .privacy }
                Button("Terms of Service") { legalPage = .terms }
            }
            .font(.system(size: 13))
            .foregroundStyle(mfLoginColor(0x8EA0C2))
            .tint(mfLoginColor(0x8EA0C2))
            .frame(minHeight: 32)
        }
        .frame(maxWidth: 420)
    }

    private var formCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Sign in")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)

            if showsBiometricLogin {
                biometricCard
                    .padding(.top, 16)
            }

            fieldLabel("Email")
                .padding(.top, 16)
                .padding(.bottom, 8)
            TextField("", text: $email, prompt: Text("you@example.com").foregroundColor(mfLoginColor(0x7F8DAA)))
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focusedField, equals: .email)
                .submitLabel(.next)
                .onSubmit { focusedField = .password }
                .modifier(LBInputStyle(isFocused: focusedField == .email))
                .disabled(isLoading)

            HStack(alignment: .firstTextBaseline) {
                fieldLabel("Password")
                Spacer()
                Button {
                    path.append(.forgotPassword)
                } label: {
                    Text("Forgot password?")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(LBColor.link)
                }
            }
            .padding(.top, 16)
            .padding(.bottom, 8)

            ZStack(alignment: .trailing) {
                Group {
                    if showPassword {
                        TextField("", text: $password, prompt: Text("Your password").foregroundColor(mfLoginColor(0x7F8DAA)))
                    } else {
                        SecureField("", text: $password, prompt: Text("Your password").foregroundColor(mfLoginColor(0x7F8DAA)))
                    }
                }
                .textContentType(.password)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focusedField, equals: .password)
                .submitLabel(.done)
                .onSubmit { submit() }
                .padding(.trailing, 54)
                .modifier(LBInputStyle(isFocused: focusedField == .password))
                .disabled(isLoading)

                Button {
                    showPassword.toggle()
                } label: {
                    Text(showPassword ? "Hide" : "Show")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(LBColor.placeholderToggle)
                        .frame(minWidth: 56, minHeight: 44)
                }
                .padding(.trailing, 4)
                .accessibilityLabel(showPassword ? "Hide password" : "Show password")
            }

            Button {
                submit()
            } label: {
                ZStack {
                    if isLoading {
                        ProgressView().tint(.white)
                    } else {
                        Text("Sign in")
                            .font(.system(size: 16, weight: .bold))
                    }
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(LBColor.button)
                .clipShape(.rect(cornerRadius: 12))
                .shadow(color: LBColor.button.opacity(0.35), radius: 12, y: 8)
            }
            .disabled(isLoading)
            .padding(.top, 24)

            Rectangle()
                .fill(LBColor.formBorder)
                .frame(height: 1)
                .padding(.top, 20)

            Button {
                path.append(.signup)
            } label: {
                (Text("New to My Feeds? ").foregroundColor(LBColor.tagline)
                    + Text("Create an account").fontWeight(.bold).foregroundColor(LBColor.link))
                    .font(.system(size: 14))
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .padding(.top, 8)
        }
        .padding(24)
        .background(LBColor.formBackground)
        .clipShape(.rect(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(LBColor.formBorder, lineWidth: 1))
        .shadow(color: .black.opacity(0.55), radius: 30, y: 24)
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(LBColor.label)
    }

    // MARK: - Toast

    private func toastView(_ toast: AuthToast) -> some View {
        HStack {
            Text(toast.message)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(toast.isError ? Theme.destructive : Theme.success)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .background(toast.isError ? Theme.destructiveBg : Color(hsl: 142, 30, 12))
        .clipShape(.rect(cornerRadius: 10))
        .overlay(alignment: .leading) {
            UnevenRoundedRectangle(topLeadingRadius: 10, bottomLeadingRadius: 10)
                .fill(toast.isError ? Theme.destructive : Theme.success)
                .frame(width: 3)
        }
        .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    // MARK: - Biometric card

    @ViewBuilder
    private var biometricCard: some View {
        VStack(spacing: 10) {
            Button {
                Task { await biometricSignIn() }
            } label: {
                HStack(spacing: 10) {
                    if isBiometricLoading {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: biometryIcon)
                            .font(.system(size: 18, weight: .semibold))
                    }
                    Text("Sign in with \(biometryName ?? "Biometrics")")
                        .font(.system(size: 15, weight: .bold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(LBColor.button)
                .clipShape(.rect(cornerRadius: 12))
            }
            .disabled(isBiometricLoading || isLoading)

            Text("Use \(biometryName ?? "biometrics") to unlock your saved login.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textMuted)
                .multilineTextAlignment(.center)
        }
        .padding(14)
        .background(Color(hsl: 199, 40, 14, alpha: 0.5))
        .clipShape(.rect(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(LBColor.inputBorder, lineWidth: 0.5)
        )
    }

    /// SF Symbol matching the active biometric type.
    private var biometryIcon: String {
        let context = LAContext()
        var error: NSError?
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            switch context.biometryType {
            case .faceID: return "faceid"
            case .touchID: return "touchid"
            case .opticID: return "opticid"
            case .none: return "lock.fill"
            @unknown default: return "lock.fill"
            }
        }
        return "lock.fill"
    }

    // MARK: - Actions

    private func submit() {
        let trimmedEmail = email.trimmingCharacters(in: .whitespaces)
        guard !trimmedEmail.isEmpty, !password.isEmpty else {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            toast = AuthToast(message: "Please fill in both email and password.", isError: true)
            return
        }
        isLoading = true
        Task {
            let error = await auth.signIn(email: trimmedEmail, password: password)
            isLoading = false
            if let error {
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                toast = AuthToast(message: error, isError: true)
            } else {
                // After a successful manual sign-in, persist credentials for biometric
                // login when the user has opted in (toggle in Settings).
                auth.persistCredentialsForBiometricLogin(email: trimmedEmail, password: password)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                toast = AuthToast(message: "Welcome back!", isError: false)
            }
        }
    }

    private func biometricSignIn() async {
        isBiometricLoading = true
        let error = await auth.signInWithBiometrics()
        isBiometricLoading = false
        if let error {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            toast = AuthToast(message: error, isError: true)
        } else {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            toast = AuthToast(message: "Welcome back!", isError: false)
        }
    }
}

/// Input field style for the login screen.
fileprivate struct LBInputStyle: ViewModifier {
    var isFocused: Bool

    func body(content: Content) -> some View {
        content
            .font(.system(size: 16))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .frame(height: 50)
            .background(LBColor.input)
            .clipShape(.rect(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isFocused ? LBColor.inputFocus : LBColor.inputBorder, lineWidth: 1)
            )
    }
}
