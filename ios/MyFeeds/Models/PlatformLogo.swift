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

    /// GitHub Octocat mark.
    static func github(in rect: CGRect) -> Path {
        let p = scaler(rect)
        var path = Path()
        path.move(to: p(12, 0.297))
        path.addCurve(to: p(0, 12.297), control1: p(5.37, 0.297), control2: p(0, 5.67))
        path.addCurve(to: p(8.205, 23.682), control1: p(0, 17.6), control2: p(3.438, 22.097))
        path.addCurve(to: p(9.025, 23.105), control1: p(8.805, 23.795), control2: p(9.025, 23.424))
        path.addCurve(to: p(9.01, 21.065), control1: p(9.025, 22.82), control2: p(9.015, 22.065))
        path.addCurve(to: p(4.968, 19.455), control1: p(5.672, 21.789), control2: p(4.968, 19.455))
        path.addCurve(to: p(3.633, 17.7), control1: p(4.422, 18.07), control2: p(3.633, 17.7))
        path.addCurve(to: p(3.717, 16.971), control1: p(2.546, 16.956), control2: p(3.717, 16.971))
        path.addCurve(to: p(5.555, 18.207), control1: p(4.922, 17.055), control2: p(5.555, 18.207))
        path.addCurve(to: p(9.05, 19.205), control1: p(6.625, 20.042), control2: p(8.364, 19.512))
        path.addCurve(to: p(9.81, 17.6), control1: p(9.158, 18.429), control2: p(9.467, 17.9))
        path.addCurve(to: p(4.344, 11.67), control1: p(7.145, 17.3), control2: p(4.344, 16.268))
        path.addCurve(to: p(5.579, 8.45), control1: p(4.344, 10.36), control2: p(4.809, 9.29))
        path.addCurve(to: p(5.684, 5.274), control1: p(5.444, 8.147), control2: p(5.039, 6.927))
        path.addCurve(to: p(8.984, 6.504), control1: p(5.684, 5.274), control2: p(6.689, 4.952))
        path.addCurve(to: p(11.984, 6.099), control1: p(9.944, 6.237), control2: p(10.964, 6.105))
        path.addCurve(to: p(14.984, 6.504), control1: p(13.004, 6.105), control2: p(14.024, 6.237))
        path.addCurve(to: p(18.269, 5.274), control1: p(17.264, 4.952), control2: p(18.269, 5.274))
        path.addCurve(to: p(18.389, 8.45), control1: p(18.914, 6.927), control2: p(18.509, 8.147))
        path.addCurve(to: p(19.619, 11.67), control1: p(19.154, 9.29), control2: p(19.619, 10.36))
        path.addCurve(to: p(14.144, 17.59), control1: p(19.619, 16.28), control2: p(16.814, 17.295))
        path.addCurve(to: p(14.954, 19.81), control1: p(14.564, 17.95), control2: p(14.954, 18.686))
        path.addCurve(to: p(14.939, 23.096), control1: p(14.954, 21.416), control2: p(14.939, 22.706))
        path.addCurve(to: p(15.764, 23.666), control1: p(14.939, 23.411), control2: p(15.149, 23.786))
        path.addCurve(to: p(24, 12.297), control1: p(20.565, 22.092), control2: p(24, 17.592))
        path.addCurve(to: p(12, 0.297), control1: p(24, 5.67), control2: p(18.627, 0.297))
        path.closeSubpath()
        return path
    }

    /// TikTok note mark.
    static func tiktok(in rect: CGRect) -> Path {
        let p = scaler(rect)
        var path = Path()
        path.move(to: p(12.525, 0.02))
        path.addCurve(to: p(16.435, 0), control1: p(13.835, 0), control2: p(15.135, 0.01))
        path.addCurve(to: p(18.185, 4.17), control1: p(16.515, 1.53), control2: p(17.065, 3.09))
        path.addCurve(to: p(22.425, 5.96), control1: p(19.305, 5.28), control2: p(20.885, 5.79))
        path.addLine(to: p(22.425, 9.99))
        path.addCurve(to: p(18.225, 9.02), control1: p(20.985, 9.94), control2: p(19.535, 9.64))
        path.addCurve(to: p(16.605, 8.09), control1: p(17.655, 8.76), control2: p(17.125, 8.43))
        path.addCurve(to: p(16.585, 16.84), control1: p(16.595, 11.01), control2: p(16.615, 13.93))
        path.addCurve(to: p(15.235, 20.78), control1: p(16.505, 18.24), control2: p(16.045, 19.63))
        path.addCurve(to: p(9.325, 23.99), control1: p(13.925, 22.7), control2: p(11.655, 23.95))
        path.addCurve(to: p(5.245, 22.96), control1: p(7.895, 24.07), control2: p(6.465, 23.68))
        path.addCurve(to: p(1.595, 17.25), control1: p(3.225, 21.77), control2: p(1.805, 19.59))
        path.addCurve(to: p(1.585, 15.76), control1: p(1.575, 16.75), control2: p(1.565, 16.25))
        path.addCurve(to: p(4.165, 10.8), control1: p(1.765, 13.86), control2: p(2.705, 12.04))
        path.addCurve(to: p(10.315, 9.08), control1: p(5.825, 9.36), control2: p(8.145, 8.67))
        path.addCurve(to: p(10.275, 13.52), control1: p(10.335, 10.56), control2: p(10.275, 12.04))
        path.addCurve(to: p(7.255, 13.89), control1: p(9.285, 13.2), control2: p(8.125, 13.29))
        path.addCurve(to: p(5.895, 15.64), control1: p(6.625, 14.3), control2: p(6.145, 14.93))
        path.addCurve(to: p(5.755, 17.25), control1: p(5.685, 16.15), control2: p(5.745, 16.71))
        path.addCurve(to: p(9.255, 20.12), control1: p(5.995, 18.89), control2: p(7.575, 20.27))
        path.addCurve(to: p(12.025, 18.51), control1: p(10.375, 20.11), control2: p(11.445, 19.46))
        path.addCurve(to: p(12.435, 17.45), control1: p(12.215, 18.18), control2: p(12.425, 17.84))
        path.addCurve(to: p(12.505, 12.09), control1: p(12.535, 15.66), control2: p(12.495, 13.88))
        path.addCurve(to: p(12.525, 0.02), control1: p(12.515, 8.06), control2: p(12.495, 4.04))
        path.closeSubpath()
        return path
    }

    /// Apple Music's note, cut out of a rounded square.
    static func appleMusic(in rect: CGRect) -> Path {
        let p = scaler(rect)
        var path = Path()
        path.move(to: p(23.994, 6.124))
        path.addCurve(to: p(23.754, 3.934), control1: p(24.002, 5.387), control2: p(23.921, 4.652))
        path.addCurve(to: p(21.574, 0.891), control1: p(23.437, 2.624), control2: p(22.692, 1.624))
        path.addCurve(to: p(19.697, 0.165), control1: p(21.004, 0.525), control2: p(20.365, 0.278))
        path.addCurve(to: p(18.133, 0.015), control1: p(19.18, 0.076), control2: p(18.657, 0.026))
        path.addCurve(to: p(18.009, 0.002), control1: p(18.093, 0.012), control2: p(18.05, 0.005))
        path.addLine(to: p(5.986, 0.002))
        path.addCurve(to: p(5.531, 0.028), control1: p(5.834, 0.012), control2: p(5.683, 0.019))
        path.addCurve(to: p(3.338, 0.428), control1: p(4.784, 0.071), control2: p(4.041, 0.151))
        path.addCurve(to: p(0.473, 3.208), control1: p(2.002, 0.958), control2: p(1.038, 1.88))
        path.addCurve(to: p(0.11, 4.616), control1: p(0.281, 3.656), control2: p(0.181, 4.133))
        path.addCurve(to: p(0.01, 5.796), control1: p(0.054, 5.008), control2: p(0.022, 5.401))
        path.addCurve(to: p(0, 5.889), control1: p(0.01, 5.828), control2: p(0.003, 5.858))
        path.addLine(to: p(0, 18.112))
        path.addCurve(to: p(0.027, 18.536), control1: p(0.01, 18.252), control2: p(0.017, 18.395))
        path.addCurve(to: p(0.524, 20.909), control1: p(0.077, 19.351), control2: p(0.181, 20.16))
        path.addCurve(to: p(3.758, 23.71), control1: p(1.174, 22.329), control2: p(2.262, 23.262))
        path.addCurve(to: p(5.051, 23.938), control1: p(4.178, 23.837), control2: p(4.614, 23.897))
        path.addCurve(to: p(6.718, 23.998), control1: p(5.606, 23.991), control2: p(6.161, 23.998))
        path.addLine(to: p(17.748, 23.998))
        path.addCurve(to: p(19.318, 23.898), control1: p(18.273, 23.998), control2: p(18.797, 23.964))
        path.addCurve(to: p(21.613, 23.088), control1: p(20.14, 23.792), control2: p(20.914, 23.548))
        path.addCurve(to: p(23.493, 20.881), control1: p(22.442, 22.552), control2: p(23.096, 21.785))
        path.addCurve(to: p(23.863, 19.557), control1: p(23.679, 20.461), control2: p(23.786, 20.011))
        path.addCurve(to: p(24, 17.517), control1: p(23.976, 18.882), control2: p(24.001, 18.199))
        path.addCurve(to: p(23.997, 6.124), control1: p(23.998, 13.717), control2: p(24, 9.922))
        path.closeSubpath()
        path.move(to: p(17.571, 10.114))
        path.addLine(to: p(17.571, 15.826))
        path.addCurve(to: p(17.327, 17.032), control1: p(17.571, 16.243), control2: p(17.513, 16.653))
        path.addCurve(to: p(15.939, 18.172), control1: p(17.037, 17.622), control2: p(16.567, 17.994))
        path.addCurve(to: p(14.869, 18.345), control1: p(15.589, 18.272), control2: p(15.233, 18.329))
        path.addCurve(to: p(12.926, 16.809), control1: p(13.919, 18.39), control2: p(13.096, 17.745))
        path.addCurve(to: p(12.96, 16.002), control1: p(12.879, 16.541), control2: p(12.89, 16.266))
        path.addCurve(to: p(13.328, 15.284), control1: p(13.029, 15.739), control2: p(13.155, 15.494))
        path.addCurve(to: p(13.964, 14.787), control1: p(13.502, 15.074), control2: p(13.719, 14.905))
        path.addCurve(to: p(14.982, 14.463), control1: p(14.287, 14.627), control2: p(14.634, 14.537))
        path.addCurve(to: p(16.116, 14.223), control1: p(15.36, 14.381), control2: p(15.74, 14.31))
        path.addCurve(to: p(16.626, 13.707), control1: p(16.39, 14.16), control2: p(16.573, 13.993))
        path.addCurve(to: p(16.646, 13.514), control1: p(16.64, 13.644), control2: p(16.646, 13.579))
        path.addCurve(to: p(16.644, 8.071), control1: p(16.646, 11.699), control2: p(16.646, 9.884))
        path.addCurve(to: p(16.618, 7.886), control1: p(16.643, 8.008), control2: p(16.635, 7.946))
        path.addCurve(to: p(16.314, 7.652), control1: p(16.578, 7.736), control2: p(16.468, 7.643))
        path.addCurve(to: p(15.839, 7.718), control1: p(16.154, 7.662), control2: p(15.996, 7.687))
        path.addCurve(to: p(13.559, 8.174), control1: p(15.079, 7.868), control2: p(14.319, 8.021))
        path.addLine(to: p(11.234, 8.644))
        path.addLine(to: p(9.86, 8.922))
        path.addCurve(to: p(9.812, 8.935), control1: p(9.844, 8.925), control2: p(9.828, 8.932))
        path.addCurve(to: p(9.422, 9.425), control1: p(9.535, 9.012), control2: p(9.435, 9.138))
        path.addCurve(to: p(9.422, 9.555), control1: p(9.42, 9.467), control2: p(9.422, 9.511))
        path.addCurve(to: p(9.419, 17.36), control1: p(9.42, 12.157), control2: p(9.422, 14.759))
        path.addCurve(to: p(9.204, 18.587), control1: p(9.419, 17.78), control2: p(9.372, 18.196))
        path.addCurve(to: p(7.77, 19.82), control1: p(8.926, 19.227), control2: p(8.434, 19.627))
        path.addCurve(to: p(6.695, 19.992), control1: p(7.42, 19.92), control2: p(7.06, 19.98))
        path.addCurve(to: p(4.775, 18.448), control1: p(5.735, 20.028), control2: p(4.94, 19.392))
        path.addCurve(to: p(5.929, 16.373), control1: p(4.635, 17.636), control2: p(5.005, 16.763))
        path.addCurve(to: p(7.037, 16.063), control1: p(6.286, 16.223), control2: p(6.659, 16.141))
        path.addCurve(to: p(7.897, 15.886), control1: p(7.324, 16.003), control2: p(7.612, 15.947))
        path.addCurve(to: p(8.497, 15.172), control1: p(8.28, 15.803), control2: p(8.48, 15.563))
        path.addLine(to: p(8.497, 15.022))
        path.addCurve(to: p(8.499, 6.14), control1: p(8.497, 12.062), control2: p(8.497, 9.1))
        path.addCurve(to: p(8.541, 5.77), control1: p(8.499, 6.017), control2: p(8.512, 5.89))
        path.addCurve(to: p(9.087, 5.252), control1: p(8.611, 5.485), control2: p(8.814, 5.322))
        path.addCurve(to: p(9.861, 5.087), control1: p(9.342, 5.186), control2: p(9.602, 5.14))
        path.addCurve(to: p(12.061, 4.643), control1: p(10.594, 4.937), control2: p(11.327, 4.791))
        path.addLine(to: p(14.331, 4.183))
        path.addCurve(to: p(16.341, 3.78), control1: p(15.001, 4.049), control2: p(15.671, 3.913))
        path.addCurve(to: p(17.004, 3.674), control1: p(16.561, 3.737), control2: p(16.783, 3.692))
        path.addCurve(to: p(17.558, 4.156), control1: p(17.314, 3.649), control2: p(17.527, 3.844))
        path.addCurve(to: p(17.57, 4.379), control1: p(17.566, 4.229), control2: p(17.57, 4.304))
        path.addCurve(to: p(17.57, 10.111), control1: p(17.572, 6.289), control2: p(17.572, 8.201))
        path.closeSubpath()
        return path
    }

    /// Apple Podcasts' microphone, cut out of a rounded square.
    static func applePodcasts(in rect: CGRect) -> Path {
        let p = scaler(rect)
        var path = Path()
        path.move(to: p(5.34, 0))
        path.addCurve(to: p(2.667, 0.712), control1: p(4.402, -0.002), control2: p(3.48, 0.243))
        path.addCurve(to: p(0.712, 2.667), control1: p(1.855, 1.18), control2: p(1.18, 1.855))
        path.addCurve(to: p(0, 5.34), control1: p(0.243, 3.48), control2: p(-0.002, 4.402))
        path.addLine(to: p(0, 18.66))
        path.addCurve(to: p(0.712, 21.333), control1: p(-0.002, 19.598), control2: p(0.243, 20.52))
        path.addCurve(to: p(2.667, 23.288), control1: p(1.18, 22.145), control2: p(1.855, 22.82))
        path.addCurve(to: p(5.34, 24), control1: p(3.48, 23.757), control2: p(4.402, 24.002))
        path.addLine(to: p(18.66, 24))
        path.addCurve(to: p(21.333, 23.288), control1: p(19.598, 24.002), control2: p(20.52, 23.757))
        path.addCurve(to: p(23.288, 21.333), control1: p(22.145, 22.82), control2: p(22.82, 22.145))
        path.addCurve(to: p(24, 18.66), control1: p(23.757, 20.52), control2: p(24.002, 19.598))
        path.addLine(to: p(24, 5.34))
        path.addCurve(to: p(23.288, 2.667), control1: p(24.002, 4.402), control2: p(23.757, 3.48))
        path.addCurve(to: p(21.333, 0.712), control1: p(22.82, 1.855), control2: p(22.145, 1.18))
        path.addCurve(to: p(18.66, 0), control1: p(20.52, 0.243), control2: p(19.598, -0.002))
        path.closeSubpath()
        path.move(to: p(11.865, 2.568))
        path.addCurve(to: p(17.921, 5.155), control1: p(14.201, 2.568), control2: p(16.313, 3.47))
        path.addCurve(to: p(20.185, 9.547), control1: p(19.145, 6.427), control2: p(19.833, 7.774))
        path.addCurve(to: p(20.192, 12.411), control1: p(20.305, 10.137), control2: p(20.305, 11.747))
        path.addCurve(to: p(19.072, 15.365), control1: p(20.007, 13.457), control2: p(19.627, 14.459))
        path.addCurve(to: p(16.952, 17.707), control1: p(18.518, 16.271), control2: p(17.799, 17.066))
        path.addCurve(to: p(14.616, 18.968), control1: p(16.344, 18.167), control2: p(14.856, 18.968))
        path.addCurve(to: p(14.56, 18.508), control1: p(14.528, 18.968), control2: p(14.52, 18.877))
        path.addCurve(to: p(15.04, 17.652), control1: p(14.632, 17.916), control2: p(14.704, 17.793))
        path.addCurve(to: p(17.048, 16.217), control1: p(15.576, 17.428), control2: p(16.488, 16.778))
        path.addCurve(to: p(19.056, 12.681), control1: p(18.024, 15.241), control2: p(18.718, 14.019))
        path.addCurve(to: p(19.008, 9.177), control1: p(19.264, 11.857), control2: p(19.24, 10.025))
        path.addCurve(to: p(13.384, 3.825), control1: p(18.28, 6.481), control2: p(16.08, 4.385))
        path.addCurve(to: p(10.384, 3.825), control1: p(12.6, 3.665), control2: p(11.176, 3.665))
        path.addCurve(to: p(4.712, 9.353), control1: p(7.656, 4.385), control2: p(5.4, 6.585))
        path.addCurve(to: p(4.712, 12.689), control1: p(4.528, 10.105), control2: p(4.528, 11.937))
        path.addCurve(to: p(7.904, 17.201), control1: p(5.168, 14.521), control2: p(6.352, 16.201))
        path.addCurve(to: p(8.728, 17.673), control1: p(8.208, 17.401), control2: p(8.576, 17.609))
        path.addCurve(to: p(9.2, 18.529), control1: p(9.064, 17.817), control2: p(9.136, 17.937))
        path.addCurve(to: p(9.144, 18.993), control1: p(9.24, 18.889), control2: p(9.23, 18.993))
        path.addCurve(to: p(8.248, 18.609), control1: p(9.088, 18.993), control2: p(8.68, 18.817))
        path.addLine(to: p(8.208, 18.579))
        path.addCurve(to: p(3.576, 12.567), control1: p(5.736, 17.363), control2: p(4.152, 15.305))
        path.addCurve(to: p(3.546, 9.527), control1: p(3.432, 11.861), control2: p(3.408, 10.175))
        path.addCurve(to: p(5.738, 5.223), control1: p(3.906, 7.787), control2: p(4.594, 6.427))
        path.addCurve(to: p(11.866, 2.567), control1: p(7.386, 3.486), control2: p(9.506, 2.567))
        path.closeSubpath()
        path.move(to: p(11.999, 5.378))
        path.addCurve(to: p(13.105, 5.484), control1: p(12.408, 5.382), control2: p(12.802, 5.418))
        path.addCurve(to: p(17.481, 11.658), control1: p(15.889, 6.104), control2: p(17.865, 8.892))
        path.addCurve(to: p(16.265, 14.538), control1: p(17.329, 12.772), control2: p(16.945, 13.688))
        path.addCurve(to: p(14.969, 15.688), control1: p(15.929, 14.968), control2: p(15.113, 15.688))
        path.addCurve(to: p(14.921, 15.085), control1: p(14.946, 15.688), control2: p(14.921, 15.416))
        path.addLine(to: p(14.921, 14.48))
        path.addLine(to: p(15.337, 13.984))
        path.addCurve(to: p(15.081, 7.76), control1: p(16.905, 12.106), control2: p(16.793, 9.482))
        path.addCurve(to: p(12.657, 6.514), control1: p(14.417, 7.09), control2: p(13.649, 6.696))
        path.addCurve(to: p(11.209, 6.506), control1: p(12.017, 6.396), control2: p(11.881, 6.396))
        path.addCurve(to: p(8.697, 7.762), control1: p(10.189, 6.673), control2: p(9.399, 7.068))
        path.addCurve(to: p(8.433, 13.984), control1: p(6.977, 9.466), control2: p(6.865, 12.104))
        path.addLine(to: p(8.846, 14.48))
        path.addLine(to: p(8.846, 15.088))
        path.addCurve(to: p(8.786, 15.696), control1: p(8.846, 15.424), control2: p(8.819, 15.696))
        path.addCurve(to: p(8.274, 15.336), control1: p(8.756, 15.696), control2: p(8.522, 15.536))
        path.addLine(to: p(8.24, 15.325))
        path.addCurve(to: p(6.368, 12.328), control1: p(7.408, 14.661), control2: p(6.672, 13.483))
        path.addCurve(to: p(6.376, 9.608), control1: p(6.184, 11.63), control2: p(6.184, 10.304))
        path.addCurve(to: p(10.184, 5.589), control1: p(6.88, 7.73), control2: p(8.264, 6.273))
        path.addCurve(to: p(11.998, 5.378), control1: p(10.594, 5.444), control2: p(11.317, 5.369))
        path.closeSubpath()
        path.move(to: p(11.869, 8.368))
        path.addCurve(to: p(12.713, 8.546), control1: p(12.179, 8.368), control2: p(12.489, 8.428))
        path.addCurve(to: p(13.753, 9.805), control1: p(13.201, 8.799), control2: p(13.601, 9.291))
        path.addCurve(to: p(11.033, 12.059), control1: p(14.217, 11.383), control2: p(12.545, 12.765))
        path.addLine(to: p(11.018, 12.059))
        path.addCurve(to: p(9.914, 10.289), control1: p(10.306, 11.728), control2: p(9.922, 11.103))
        path.addCurve(to: p(11.026, 8.544), control1: p(9.914, 9.556), control2: p(10.322, 8.918))
        path.addCurve(to: p(11.87, 8.368), control1: p(11.25, 8.427), control2: p(11.56, 8.368))
        path.closeSubpath()
        path.move(to: p(11.858, 13.096))
        path.addCurve(to: p(13.828, 14.066), control1: p(12.846, 13.092), control2: p(13.564, 13.445))
        path.addCurve(to: p(13.61, 18.368), control1: p(14.026, 14.53), control2: p(13.952, 15.998))
        path.addCurve(to: p(12.93, 20.724), control1: p(13.378, 20.024), control2: p(13.25, 20.442))
        path.addCurve(to: p(11.274, 21.012), control1: p(12.49, 21.114), control2: p(11.866, 21.222))
        path.addLine(to: p(11.271, 21.012))
        path.addCurve(to: p(10.107, 18.368), control1: p(10.555, 20.755), control2: p(10.401, 20.407))
        path.addCurve(to: p(9.889, 14.066), control1: p(9.766, 15.998), control2: p(9.691, 14.53))
        path.addCurve(to: p(11.859, 13.096), control1: p(10.151, 13.45), control2: p(10.863, 13.1))
        path.closeSubpath()
        return path
    }

    /// Facebook's round "f" mark: a circle with the f cut out.
    static func facebook(in rect: CGRect) -> Path {
        let p = scaler(rect)
        var path = Path()
        path.move(to: p(9.101, 23.691))
        path.addLine(to: p(9.101, 15.711))
        path.addLine(to: p(6.627, 15.711))
        path.addLine(to: p(6.627, 12.044))
        path.addLine(to: p(9.101, 12.044))
        path.addLine(to: p(9.101, 10.464))
        path.addCurve(to: p(14.959, 4.486), control1: p(9.101, 6.379), control2: p(10.949, 4.486))
        path.addCurve(to: p(16.427, 4.589), control1: p(15.36, 4.486), control2: p(15.914, 4.528))
        path.addCurve(to: p(17.568, 4.784), control1: p(16.811, 4.629), control2: p(17.192, 4.694))
        path.addLine(to: p(17.568, 8.109))
        path.addCurve(to: p(16.915, 8.073), control1: p(17.351, 8.089), control2: p(17.133, 8.077))
        path.addCurve(to: p(16.182, 8.064), control1: p(16.671, 8.067), control2: p(16.426, 8.064))
        path.addCurve(to: p(14.507, 8.373), control1: p(15.475, 8.064), control2: p(14.923, 8.16))
        path.addCurve(to: p(13.828, 8.995), control1: p(14.227, 8.513), control2: p(13.992, 8.729))
        path.addCurve(to: p(13.454, 10.747), control1: p(13.57, 9.415), control2: p(13.454, 9.99))
        path.addLine(to: p(13.454, 12.044))
        path.addLine(to: p(17.373, 12.044))
        path.addLine(to: p(16.987, 14.147))
        path.addLine(to: p(16.7, 15.711))
        path.addLine(to: p(13.454, 15.711))
        path.addLine(to: p(13.454, 23.956))
        path.addCurve(to: p(24, 12.044), control1: p(19.396, 23.238), control2: p(24, 18.179))
        path.addCurve(to: p(12, 0.044), control1: p(24, 5.417), control2: p(18.627, 0.044))
        path.addCurve(to: p(0, 12.044), control1: p(5.373, 0.044), control2: p(0, 5.417))
        path.addCurve(to: p(9.101, 23.691), control1: p(0, 17.672), control2: p(3.874, 22.394))
        path.closeSubpath()
        return path
    }
}

private struct LogoShape: Shape {
    enum Kind { case youtube, youtubePlay, x, reddit, instagram, github, tiktok, facebook, appleMusic, applePodcasts }
    let kind: Kind

    func path(in rect: CGRect) -> Path {
        switch kind {
        case .youtube: return PlatformLogoPaths.youtube(in: rect)
        case .youtubePlay: return PlatformLogoPaths.youtubePlay(in: rect)
        case .x: return PlatformLogoPaths.x(in: rect)
        case .reddit: return PlatformLogoPaths.reddit(in: rect)
        case .instagram: return PlatformLogoPaths.instagram(in: rect)
        case .github: return PlatformLogoPaths.github(in: rect)
        case .tiktok: return PlatformLogoPaths.tiktok(in: rect)
        case .facebook: return PlatformLogoPaths.facebook(in: rect)
        case .appleMusic: return PlatformLogoPaths.appleMusic(in: rect)
        case .applePodcasts: return PlatformLogoPaths.applePodcasts(in: rect)
        }
    }
}

/// The logo as it appears on the platform: red YouTube button with a white play
/// arrow, white X on the dark theme, white Snoo on the orange Reddit bubble,
/// the Instagram camera in its gradient, LinkedIn's blue "in" tile, the
/// GitHub Octocat mark, the TikTok note and Facebook's blue "f".
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
        case .github: return 0.9
        case .tiktok: return 0.86
        case .facebook: return 0.9
        case .appleMusic, .applePodcasts: return 0.84
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
        case .github:
            LogoShape(kind: .github)
                .fill(Theme.textPrimary)
        case .tiktok:
            LogoShape(kind: .tiktok)
                .fill(Theme.textPrimary)
        case .appleMusic, .applePodcasts:
            // Drawn over white, like the app icons: the note or microphone shows white.
            ZStack {
                GeometryReader { geo in
                    let s = min(geo.size.width, geo.size.height) / 24
                    RoundedRectangle(cornerRadius: 4 * s)
                        .fill(Color.white)
                        .frame(width: 19 * s, height: 19 * s)
                        .frame(width: geo.size.width, height: geo.size.height)
                }
                LogoShape(kind: platform == .appleMusic ? .appleMusic : .applePodcasts)
                    .fill(platform == .appleMusic
                          ? Color(red: 250 / 255, green: 36 / 255, blue: 60 / 255)
                          : Color(red: 153 / 255, green: 51 / 255, blue: 204 / 255))
            }
        case .facebook:
            ZStack {
                Circle().fill(Color.white).scaleEffect(20.0 / 24.0)
                LogoShape(kind: .facebook).fill(Color(red: 8 / 255, green: 102 / 255, blue: 1))
            }
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
