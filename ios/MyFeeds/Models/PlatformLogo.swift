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

    static func instagram(in rect: CGRect) -> Path {
        let p = scaler(rect)
        var path = Path()
        path.move(to: p(7.03, 0.084))
        path.addCurve(to: p(4.119, 0.647), control1: p(5.753, 0.144), control2: p(4.881, 0.348))
        path.addCurve(to: p(1.996, 2.035), control1: p(3.33, 0.955), control2: p(2.662, 1.367))
        path.addCurve(to: p(0.616, 4.162), control1: p(1.331, 2.703), control2: p(0.921, 3.372))
        path.addCurve(to: p(0.064, 7.076), control1: p(0.321, 4.926), control2: p(0.12, 5.799))
        path.addCurve(to: p(0.001, 12.023), control1: p(0.008, 8.354), control2: p(-0.005, 8.764))
        path.addCurve(to: p(0.084, 16.97), control1: p(0.008, 15.282), control2: p(0.022, 15.69))
        path.addCurve(to: p(0.647, 19.881), control1: p(0.145, 18.247), control2: p(0.348, 19.119))
        path.addCurve(to: p(2.035, 22.004), control1: p(0.955, 20.67), control2: p(1.367, 21.338))
        path.addCurve(to: p(4.164, 23.384), control1: p(2.703, 22.669), control2: p(3.372, 23.078))
        path.addCurve(to: p(7.077, 23.936), control1: p(4.927, 23.679), control2: p(5.8, 23.88))
        path.addCurve(to: p(12.024, 23.999), control1: p(8.355, 23.992), control2: p(8.766, 24.005))
        path.addCurve(to: p(16.971, 23.917), control1: p(15.281, 23.992), control2: p(15.692, 23.978))
        path.addCurve(to: p(19.881, 23.354), control1: p(18.251, 23.856), control2: p(19.118, 23.652))
        path.addCurve(to: p(22.004, 21.966), control1: p(20.67, 23.045), control2: p(21.339, 22.634))
        path.addCurve(to: p(23.383, 19.837), control1: p(22.669, 21.298), control2: p(23.078, 20.628))
        path.addCurve(to: p(23.935, 16.925), control1: p(23.679, 19.074), control2: p(23.88, 18.201))
        path.addCurve(to: p(23.998, 11.977), control1: p(23.991, 15.644), control2: p(24.005, 15.235))
        path.addCurve(to: p(23.917, 7.03), control1: p(23.992, 8.719), control2: p(23.977, 8.31))
        path.addCurve(to: p(23.353, 4.119), control1: p(23.856, 5.751), control2: p(23.653, 4.882))
        path.addCurve(to: p(21.966, 1.996), control1: p(23.045, 3.33), control2: p(22.633, 2.662))
        path.addCurve(to: p(19.838, 0.617), control1: p(21.298, 1.33), control2: p(20.628, 0.921))
        path.addCurve(to: p(16.924, 0.065), control1: p(19.074, 0.321), control2: p(18.202, 0.12))
        path.addCurve(to: p(11.977, 0.001), control1: p(15.647, 0.009), control2: p(15.236, -0.005))
        path.addCurve(to: p(7.03, 0.084), control1: p(8.718, 0.008), control2: p(8.31, 0.021))
        path.move(to: p(7.17, 21.777))
        path.addCurve(to: p(4.942, 21.369), control1: p(6.0, 21.726), control2: p(5.365, 21.532))
        path.addCurve(to: p(3.56, 20.474), control1: p(4.381, 21.153), control2: p(3.982, 20.892))
        path.addCurve(to: p(2.66, 19.096), control1: p(3.138, 20.056), control2: p(2.879, 19.655))
        path.addCurve(to: p(2.243, 16.868), control1: p(2.495, 18.673), control2: p(2.297, 18.038))
        path.addCurve(to: p(2.164, 12.02), control1: p(2.183, 15.604), control2: p(2.171, 15.224))
        path.addCurve(to: p(2.224, 7.172), control1: p(2.157, 8.816), control2: p(2.169, 8.437))
        path.addCurve(to: p(2.632, 4.944), control1: p(2.274, 6.003), control2: p(2.47, 5.367))
        path.addCurve(to: p(3.527, 3.562), control1: p(2.848, 4.383), control2: p(3.109, 3.984))
        path.addCurve(to: p(4.906, 2.662), control1: p(3.946, 3.141), control2: p(4.346, 2.881))
        path.addCurve(to: p(7.133, 2.245), control1: p(5.329, 2.497), control2: p(5.963, 2.301))
        path.addCurve(to: p(11.981, 2.166), control1: p(8.398, 2.185), control2: p(8.777, 2.173))
        path.addCurve(to: p(16.83, 2.227), control1: p(15.184, 2.159), control2: p(15.564, 2.171))
        path.addCurve(to: p(19.058, 2.635), control1: p(17.999, 2.277), control2: p(18.635, 2.471))
        path.addCurve(to: p(20.44, 3.53), control1: p(19.619, 2.851), control2: p(20.018, 3.11))
        path.addCurve(to: p(21.34, 4.908), control1: p(20.861, 3.949), control2: p(21.121, 4.347))
        path.addCurve(to: p(21.757, 7.135), control1: p(21.505, 5.33), control2: p(21.702, 5.964))
        path.addCurve(to: p(21.837, 11.983), control1: p(21.817, 8.4), control2: p(21.831, 8.78))
        path.addCurve(to: p(21.776, 16.831), control1: p(21.842, 15.186), control2: p(21.831, 15.566))
        path.addCurve(to: p(21.368, 19.06), control1: p(21.725, 18.001), control2: p(21.531, 18.636))
        path.addCurve(to: p(20.472, 20.441), control1: p(21.152, 19.62), control2: p(20.891, 20.02))
        path.addCurve(to: p(19.094, 21.341), control1: p(20.053, 20.863), control2: p(19.654, 21.123))
        path.addCurve(to: p(16.868, 21.759), control1: p(18.672, 21.506), control2: p(18.036, 21.703))
        path.addCurve(to: p(12.018, 21.838), control1: p(15.602, 21.818), control2: p(15.223, 21.831))
        path.addCurve(to: p(7.17, 21.777), control1: p(8.814, 21.845), control2: p(8.436, 21.832))
        path.move(to: p(16.953, 5.586))
        path.addCurve(to: p(17.111, 6.24), control1: p(16.953, 5.814), control2: p(17.008, 6.038))
        path.addCurve(to: p(17.549, 6.75), control1: p(17.215, 6.442), control2: p(17.365, 6.617))
        path.addCurve(to: p(18.17, 7.007), control1: p(17.733, 6.884), control2: p(17.946, 6.972))
        path.addCurve(to: p(18.84, 6.953), control1: p(18.395, 7.042), control2: p(18.624, 7.023))
        path.addCurve(to: p(19.413, 6.6), control1: p(19.056, 6.882), control2: p(19.253, 6.761))
        path.addCurve(to: p(19.763, 6.026), control1: p(19.574, 6.439), control2: p(19.694, 6.243))
        path.addCurve(to: p(19.815, 5.356), control1: p(19.833, 5.81), control2: p(19.851, 5.58))
        path.addCurve(to: p(19.556, 4.735), control1: p(19.779, 5.132), control2: p(19.69, 4.919))
        path.addCurve(to: p(19.044, 4.3), control1: p(19.422, 4.552), control2: p(19.247, 4.402))
        path.addCurve(to: p(18.39, 4.144), control1: p(18.841, 4.197), control2: p(18.617, 4.144))
        path.addCurve(to: p(17.671, 4.338), control1: p(18.137, 4.145), control2: p(17.889, 4.212))
        path.addCurve(to: p(17.145, 4.866), control1: p(17.452, 4.465), control2: p(17.271, 4.647))
        path.addCurve(to: p(16.953, 5.586), control1: p(17.019, 5.085), control2: p(16.953, 5.334))
        path.move(to: p(5.838, 12.012))
        path.addCurve(to: p(12.011, 18.161), control1: p(5.845, 15.415), control2: p(8.609, 18.168))
        path.addCurve(to: p(18.162, 11.988), control1: p(15.414, 18.155), control2: p(18.169, 15.391))
        path.addCurve(to: p(11.988, 5.838), control1: p(18.156, 8.585), control2: p(15.391, 5.831))
        path.addCurve(to: p(5.838, 12.012), control1: p(8.585, 5.845), control2: p(5.832, 8.609))
        path.move(to: p(8.0, 12.008))
        path.addCurve(to: p(8.532, 10.007), control1: p(7.999, 11.306), control2: p(8.182, 10.615))
        path.addCurve(to: p(9.993, 8.54), control1: p(8.882, 9.398), control2: p(9.386, 8.892))
        path.addCurve(to: p(11.992, 8.0), control1: p(10.6, 8.187), control2: p(11.29, 8.001))
        path.addCurve(to: p(13.993, 8.532), control1: p(12.694, 7.998), control2: p(13.384, 8.182))
        path.addCurve(to: p(15.46, 9.993), control1: p(14.602, 8.882), control2: p(15.108, 9.386))
        path.addCurve(to: p(16.0, 11.992), control1: p(15.812, 10.6), control2: p(15.999, 11.29))
        path.addCurve(to: p(15.468, 13.993), control1: p(16.001, 12.694), control2: p(15.818, 13.384))
        path.addCurve(to: p(14.007, 15.46), control1: p(15.118, 14.602), control2: p(14.614, 15.108))
        path.addCurve(to: p(12.008, 16.0), control1: p(13.4, 15.812), control2: p(12.71, 15.998))
        path.addCurve(to: p(10.477, 15.698), control1: p(11.483, 16.001), control2: p(10.962, 15.899))
        path.addCurve(to: p(9.177, 14.834), control1: p(9.991, 15.498), control2: p(9.549, 15.205))
        path.addCurve(to: p(8.307, 13.538), control1: p(8.805, 14.463), control2: p(8.509, 14.023))
        path.addCurve(to: p(8.0, 12.008), control1: p(8.105, 13.053), control2: p(8.001, 12.533))
        return path
    }
}

private struct LogoShape: Shape {
    enum Kind { case youtube, youtubePlay, x, reddit, instagram }
    let kind: Kind

    func path(in rect: CGRect) -> Path {
        switch kind {
        case .youtube: return PlatformLogoPaths.youtube(in: rect)
        case .youtubePlay: return PlatformLogoPaths.youtubePlay(in: rect)
        case .x: return PlatformLogoPaths.x(in: rect)
        case .reddit: return PlatformLogoPaths.reddit(in: rect)
        case .instagram: return PlatformLogoPaths.instagram(in: rect)
        }
    }
}

/// The logo as it appears on the platform: red YouTube button with a white play
/// arrow, white X on the dark theme, white Snoo on the orange Reddit bubble,
/// the Instagram camera in its gradient and LinkedIn's blue "in" tile.
struct PlatformLogo: View {
    let platform: SourcePlatform

    /// Each logo's scale inside its box, so they all look the same size: the X
    /// glyph fills its corners and the Instagram camera is a full square, while
    /// the YouTube button is only 17 of 24 tall. Same values as web and Expo.
    private var scale: CGFloat {
        switch platform {
        case .youtube: return 1
        case .x: return 0.68
        case .instagram: return 0.82
        case .linkedin: return 0.84
        case .reddit: return 0.92
        }
    }

    var body: some View {
        artwork.scaleEffect(scale)
    }

    @ViewBuilder
    private var artwork: some View {
        switch platform {
        case .youtube:
            ZStack {
                LogoShape(kind: .youtubePlay).fill(Color.white)
                LogoShape(kind: .youtube).fill(Color(red: 1, green: 0, blue: 0))
            }
        case .x:
            LogoShape(kind: .x)
                .fill(Theme.textPrimary)
        case .reddit:
            ZStack {
                Circle().fill(Color.white).scaleEffect(21.0 / 24.0)
                LogoShape(kind: .reddit).fill(Color(red: 1, green: 69 / 255, blue: 0))
            }
        case .instagram:
            LogoShape(kind: .instagram)
                .fill(LinearGradient(
                    stops: [
                        .init(color: Color(red: 254 / 255, green: 218 / 255, blue: 117 / 255), location: 0),
                        .init(color: Color(red: 250 / 255, green: 126 / 255, blue: 30 / 255), location: 0.3),
                        .init(color: Color(red: 214 / 255, green: 41 / 255, blue: 118 / 255), location: 0.55),
                        .init(color: Color(red: 150 / 255, green: 47 / 255, blue: 191 / 255), location: 0.8),
                        .init(color: Color(red: 79 / 255, green: 91 / 255, blue: 213 / 255), location: 1),
                    ],
                    startPoint: .bottomLeading,
                    endPoint: .topTrailing
                ))
        case .linkedin:
            GeometryReader { geo in
                let s = min(geo.size.width, geo.size.height) / 24
                ZStack {
                    RoundedRectangle(cornerRadius: 4.5 * s)
                        .fill(Color(red: 10 / 255, green: 102 / 255, blue: 194 / 255))
                        .frame(width: 24 * s, height: 24 * s)
                    Text("in")
                        .font(.system(size: 16 * s, weight: .bold))
                        .foregroundStyle(Color.white)
                        .offset(y: 0.5 * s)
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
        }
    }
}
