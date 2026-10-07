import SwiftUI

extension Color {
    /// Create a color from HSL values (hue 0-360, saturation 0-100, lightness 0-100),
    /// matching the CSS hsl() palette used by the companion apps.
    init(hsl hue: Double, _ saturation: Double, _ lightness: Double, alpha: Double = 1) {
        let s = saturation / 100
        let l = lightness / 100
        let brightness = l + s * min(l, 1 - l)
        let sat = brightness == 0 ? 0 : 2 * (1 - l / brightness)
        self.init(hue: hue / 360, saturation: sat, brightness: brightness, opacity: alpha)
    }
}

/// My Feeds design system — deep navy command-center palette with sky-blue accents.
enum Theme {
    static let background = Color(hsl: 220, 30, 8)
    static let card = Color(hsl: 220, 30, 11)
    static let input = Color(hsl: 220, 30, 14)
    static let border = Color(hsl: 220, 15, 22)
    static let cardBorder = Color(hsl: 220, 25, 18)
    static let borderFocus = Color(hsl: 199, 89, 48)

    static let textPrimary = Color(hsl: 220, 20, 92)
    static let textSecondary = Color(hsl: 215, 15, 55)
    static let textMuted = Color(hsl: 220, 10, 42)

    static let accent = Color(hsl: 199, 89, 48)
    static let accentGradient = LinearGradient(
        colors: [Color(hsl: 199, 89, 48), Color(hsl: 199, 89, 40)],
        startPoint: .leading,
        endPoint: .trailing
    )
    static let accentPressed = Color(hsl: 199, 89, 36)

    static let success = Color(hsl: 142, 71, 45)
    static let warning = Color(hsl: 38, 92, 50)
    static let destructive = Color(hsl: 0, 84, 60)
    static let destructiveBg = Color(hsl: 0, 84, 14)

    /// One colour per agent, taken in the alphabetically sorted agent list. Same
    /// list as the web app (src/lib/agentColors.ts) and Expo (AGENT_ACCENTS), so an
    /// agent has the same colour everywhere. 16 hues far enough apart that no two
    /// agents share a colour until there are more than 16.
    static let agentAccents: [Color] = [
        Color(hsl: 199, 89, 48), // sky blue
        Color(hsl: 142, 71, 45), // green
        Color(hsl: 30, 95, 55),  // orange
        Color(hsl: 280, 70, 62), // purple
        Color(hsl: 0, 75, 58),   // red
        Color(hsl: 172, 75, 40), // teal
        Color(hsl: 50, 95, 52),  // yellow
        Color(hsl: 325, 78, 62), // pink
        Color(hsl: 230, 80, 66), // indigo
        Color(hsl: 88, 65, 48),  // lime
        Color(hsl: 258, 90, 76), // lavender
        Color(hsl: 210, 16, 68), // slate
        Color(hsl: 188, 90, 70), // light cyan
        Color(hsl: 12, 90, 72),  // coral
        Color(hsl: 38, 55, 65),  // tan
        Color(hsl: 150, 60, 72), // mint
    ]

    static func agentAccent(_ index: Int) -> Color {
        let i = abs(index)
        if i < agentAccents.count { return agentAccents[i] }
        // 17th agent on: golden-angle hues, so each still differs from its neighbours.
        return Color(hsl: (Double(i) * 137.508).truncatingRemainder(dividingBy: 360), 70, 60)
    }
}

/// Card container used throughout the app.
struct CardBackground: ViewModifier {
    var radius: CGFloat = 12

    func body(content: Content) -> some View {
        content
            .background(Theme.card)
            .clipShape(.rect(cornerRadius: radius))
            .overlay(
                RoundedRectangle(cornerRadius: radius)
                    .stroke(Theme.border, lineWidth: 0.5)
            )
    }
}

extension View {
    func cardStyle(radius: CGFloat = 12) -> some View {
        modifier(CardBackground(radius: radius))
    }
}

/// Uppercase section header used on Dashboard / Agent Detail.
struct SectionHeader: View {
    let title: LocalizedStringKey
    var actionLabel: LocalizedStringKey?
    var action: (() -> Void)?

    var body: some View {
        HStack {
            Text(title)
                .textCase(.uppercase)
                .font(.system(size: 13, weight: .bold))
                .kerning(0.6)
                .foregroundStyle(Theme.textSecondary)
            Spacer()
            if let actionLabel, let action {
                Button(action: action) {
                    Text(actionLabel)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                }
            }
        }
        .padding(.top, 26)
        .padding(.bottom, 12)
    }
}
