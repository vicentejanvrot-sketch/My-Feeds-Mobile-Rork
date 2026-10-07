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
        // Remember the language this launch uses, and pass the choice to the
        // share extension (it may have been changed in the Settings app).
        _ = AppLanguage.launchChoice
        AppLanguage.syncShareExtension()
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
