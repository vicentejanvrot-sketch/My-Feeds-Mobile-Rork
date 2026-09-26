import SwiftUI

/// Official platform logos (Simple Icons, 24x24 viewBox), drawn natively so no
/// image assets are needed. Same shapes as the web and Expo PlatformBadge.
nonisolated enum PlatformLogoPaths {
    /// Maps a point in the 24x24 logo grid into `rect`.
    private static func scaler(_ rect: CGRect) -> (CGFloat, CGFloat) -> CGPoint {
        let scale = min(rect.width, rect.height) / 24
        let dx = rect.midX - 12 * scale
        let dy = rect.midY - 12 * scale
        return { x, y in CGPoint(x: dx + x * scale, y: dy + y * scale) }
    }

    static func youtube(in rect: CGRect) -> Path {
        let p = scaler(rect)
        var path = Path()
        path.move(to: p(23.498, 6.186))
        path.addCurve(to: p(22.723, 4.834), control1: p(23.362, 5.675), control2: p(23.095, 5.209))
        path.addCurve(to: p(21.376, 4.05), control1: p(22.35, 4.459), control2: p(21.886, 4.189))
        path.addCurve(to: p(12, 3.545), control1: p(19.505, 3.545), control2: p(12, 3.545))
        path.addCurve(to: p(2.623, 4.05), control1: p(12, 3.545), control2: p(4.495, 3.545))
        path.addCurve(to: p(1.277, 4.835), control1: p(2.113, 4.189), control2: p(1.649, 4.46))
        path.addCurve(to: p(0.502, 6.186), control1: p(0.905, 5.209), control2: p(0.638, 5.675))
        path.addCurve(to: p(0, 12), control1: p(0, 8.07), control2: p(0, 12))
        path.addCurve(to: p(0.502, 17.814), control1: p(0, 12), control2: p(0, 15.93))
        path.addCurve(to: p(1.277, 19.166), control1: p(0.638, 18.325), control2: p(0.905, 18.791))
        path.addCurve(to: p(2.624, 19.95), control1: p(1.65, 19.541), control2: p(2.114, 19.811))
        path.addCurve(to: p(12, 20.455), control1: p(4.495, 20.455), control2: p(12, 20.455))
        path.addCurve(to: p(21.377, 19.95), control1: p(12, 20.455), control2: p(19.505, 20.455))
        path.addCurve(to: p(22.724, 19.166), control1: p(21.887, 19.811), control2: p(22.351, 19.541))
        path.addCurve(to: p(23.499, 17.814), control1: p(23.096, 18.791), control2: p(23.364, 18.325))
        path.addCurve(to: p(24, 12), control1: p(24, 15.93), control2: p(24, 12))
        path.addCurve(to: p(23.498, 6.186), control1: p(24, 12), control2: p(24, 8.07))
        path.closeSubpath()
        path.move(to: p(9.545, 15.568))
        path.addLine(to: p(9.545, 8.432))
        path.addLine(to: p(15.818, 12))
        path.addLine(to: p(9.545, 15.568))
        path.closeSubpath()
        return path
    }

    static func youtubePlay(in rect: CGRect) -> Path {
        let p = scaler(rect)
        var path = Path()
        path.move(to: p(9.545, 15.568))
        path.addLine(to: p(9.545, 8.432))
        path.addLine(to: p(15.818, 12))
        path.addLine(to: p(9.545, 15.568))
        path.closeSubpath()
        return path
    }

    static func x(in rect: CGRect) -> Path {
        let p = scaler(rect)
        var path = Path()
        path.move(to: p(14.234, 10.162))
        path.addLine(to: p(22.977, 0))
        path.addLine(to: p(20.905, 0))
        path.addLine(to: p(13.314, 8.824))
        path.addLine(to: p(7.251, 0))
        path.addLine(to: p(0.258, 0))
        path.addLine(to: p(9.426, 13.343))
        path.addLine(to: p(0.258, 24))
        path.addLine(to: p(2.33, 24))
        path.addLine(to: p(10.346, 14.682))
        path.addLine(to: p(16.749, 24))
        path.addLine(to: p(23.742, 24))
        path.closeSubpath()
        path.move(to: p(11.397, 13.461))
        path.addLine(to: p(10.468, 12.132))
        path.addLine(to: p(3.076, 1.56))
        path.addLine(to: p(6.258, 1.56))
        path.addLine(to: p(12.223, 10.092))
        path.addLine(to: p(13.152, 11.421))
        path.addLine(to: p(20.906, 22.511))
        path.addLine(to: p(17.724, 22.511))
        path.closeSubpath()
        return path
    }

    static func reddit(in rect: CGRect) -> Path {
        let p = scaler(rect)
        var path = Path()
        path.move(to: p(12, 0))
        path.addCurve(to: p(0, 12), control1: p(5.373, 0), control2: p(0, 5.373))
        path.addCurve(to: p(3.515, 20.485), control1: p(0, 15.314), control2: p(1.343, 18.314))
        path.addLine(to: p(1.229, 22.771))
        path.addCurve(to: p(1.738, 24), control1: p(0.775, 23.225), control2: p(1.097, 24))
        path.addLine(to: p(12, 24))
        path.addCurve(to: p(24, 12), control1: p(18.627, 24), control2: p(24, 18.627))
        path.addCurve(to: p(12, 0), control1: p(24, 5.373), control2: p(18.627, 0))
        path.closeSubpath()
        path.move(to: p(16.388, 3.199))
        path.addCurve(to: p(18.387, 5.198), control1: p(17.492, 3.199), control2: p(18.387, 4.094))
        path.addCurve(to: p(16.388, 7.198), control1: p(18.387, 6.303), control2: p(17.492, 7.198))
        path.addCurve(to: p(14.441, 5.659), control1: p(15.442, 7.198), control2: p(14.649, 6.541))
        path.addLine(to: p(14.441, 5.661))
        path.addCurve(to: p(12.409, 8.002), control1: p(13.294, 5.823), control2: p(12.409, 6.811))
        path.addLine(to: p(12.409, 8.009))
        path.addCurve(to: p(17.095, 9.372), control1: p(14.185, 8.076), control2: p(15.809, 8.576))
        path.addCurve(to: p(18.802, 8.792), control1: p(17.568, 9.009), control2: p(18.159, 8.792))
        path.addCurve(to: p(21.604, 11.594), control1: p(20.349, 8.792), control2: p(21.604, 10.046))
        path.addCurve(to: p(20.003, 14.125), control1: p(21.604, 12.711), control2: p(20.949, 13.675))
        path.addCurve(to: p(12.006, 20.001), control1: p(19.915, 17.381), control2: p(16.366, 20.001))
        path.addCurve(to: p(4.008, 14.131), control1: p(7.645, 20.001), control2: p(4.101, 17.384))
        path.addCurve(to: p(2.394, 11.593), control1: p(3.054, 13.684), control2: p(2.394, 12.716))
        path.addCurve(to: p(5.197, 8.791), control1: p(2.394, 10.045), control2: p(3.649, 8.791))
        path.addCurve(to: p(6.909, 9.376), control1: p(5.842, 8.791), control2: p(6.436, 9.009))
        path.addCurve(to: p(11.549, 8.011), control1: p(8.184, 8.586), control2: p(9.79, 8.085))
        path.addLine(to: p(11.549, 8.001))
        path.addCurve(to: p(14.429, 4.794), control1: p(11.549, 6.338), control2: p(12.812, 4.967))
        path.addCurve(to: p(16.388, 3.199), control1: p(14.617, 3.883), control2: p(15.422, 3.199))
        path.closeSubpath()
        path.move(to: p(8.303, 11.575))
        path.addCurve(to: p(6.797, 13.372), control1: p(7.519, 11.575), control2: p(6.844, 12.355))
        path.addCurve(to: p(8.223, 14.801), control1: p(6.75, 14.388), control2: p(7.437, 14.801))
        path.addCurve(to: p(9.641, 13.416), control1: p(9.009, 14.801), control2: p(9.594, 14.432))
        path.addCurve(to: p(8.303, 11.575), control1: p(9.688, 12.399), control2: p(9.088, 11.575))
        path.closeSubpath()
        path.move(to: p(15.709, 11.575))
        path.addCurve(to: p(14.371, 13.416), control1: p(14.923, 11.575), control2: p(14.324, 12.399))
        path.addCurve(to: p(15.789, 14.801), control1: p(14.418, 14.433), control2: p(15.005, 14.801))
        path.addCurve(to: p(17.215, 13.372), control1: p(16.574, 14.801), control2: p(17.262, 14.388))
        path.addCurve(to: p(15.709, 11.575), control1: p(17.169, 12.355), control2: p(16.494, 11.575))
        path.closeSubpath()
        path.move(to: p(12.006, 15.588))
        path.addCurve(to: p(9.236, 15.723), control1: p(11.032, 15.588), control2: p(10.099, 15.636))
        path.addCurve(to: p(9.053, 16.028), control1: p(9.089, 15.738), control2: p(8.995, 15.891))
        path.addCurve(to: p(12.006, 17.992), control1: p(9.536, 17.182), control2: p(10.675, 17.992))
        path.addCurve(to: p(14.959, 16.028), control1: p(13.336, 17.992), control2: p(14.476, 17.182))
        path.addCurve(to: p(14.775, 15.723), control1: p(15.016, 15.891), control2: p(14.922, 15.738))
        path.addCurve(to: p(12.006, 15.588), control1: p(13.912, 15.636), control2: p(12.98, 15.588))
        path.closeSubpath()
        return path
    }
}

private struct LogoShape: Shape {
    enum Kind { case youtube, youtubePlay, x, reddit }
    let kind: Kind

    func path(in rect: CGRect) -> Path {
        switch kind {
        case .youtube: return PlatformLogoPaths.youtube(in: rect)
        case .youtubePlay: return PlatformLogoPaths.youtubePlay(in: rect)
        case .x: return PlatformLogoPaths.x(in: rect)
        case .reddit: return PlatformLogoPaths.reddit(in: rect)
        }
    }
}

/// The logo as it appears on the platform: red YouTube button with a white play
/// arrow, white X on the dark theme, white Snoo on the orange Reddit bubble.
struct PlatformLogo: View {
    let platform: SourcePlatform

    var body: some View {
        switch platform {
        case .youtube:
            ZStack {
                LogoShape(kind: .youtubePlay).fill(Color.white)
                LogoShape(kind: .youtube).fill(Color(red: 1, green: 0, blue: 0))
            }
        case .x:
            LogoShape(kind: .x)
                .fill(Theme.textPrimary)
                .scaleEffect(0.8)
        case .reddit:
            ZStack {
                Circle().fill(Color.white).scaleEffect(21.0 / 24.0)
                LogoShape(kind: .reddit).fill(Color(red: 1, green: 69 / 255, blue: 0))
            }
        }
    }
}
