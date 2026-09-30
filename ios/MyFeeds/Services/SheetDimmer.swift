import Observation
import SwiftUI

/// Extra dimming behind a sheet, on top of the system's own. iOS doesn't let
/// an app choose how dark the area behind a sheet gets, so ContentView draws
/// this layer over the whole app (tab bar and navigation bar included) while a
/// screen says one of its sheets is up. Used by the People screen's person sheet.
@Observable
final class SheetDimmer {
    static let shared = SheetDimmer()

    /// How dark the extra layer is, added to the system's dimming.
    static let extraOpacity: Double = 0.55

    private(set) var isActive = false

    private init() {}

    func set(_ active: Bool) {
        guard active != isActive else { return }
        withAnimation(.easeInOut(duration: 0.25)) { isActive = active }
    }
}
