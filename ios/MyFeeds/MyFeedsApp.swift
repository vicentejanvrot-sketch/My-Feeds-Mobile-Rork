//
//  MyFeedsApp.swift
//  MyFeeds
//
//  Created by Rork on July 21, 2026.
//

import SwiftUI

@main
struct MyFeedsApp: App {
    @State private var auth = AuthStore()
    @State private var toasts = ToastCenter()
    @State private var overlay = RunningOverlayStore()
    @State private var router = AppRouter()
    @State private var prefs = VideoPrefs()

    init() {
        // Point the app's strings at the chosen language, and pass the choice
        // to the share extension (it may have been changed in the Settings app).
        AppLanguage.start()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(auth)
                .environment(toasts)
                .environment(overlay)
                .environment(router)
                .environment(prefs)
                .preferredColorScheme(.dark)
        }
    }
}
