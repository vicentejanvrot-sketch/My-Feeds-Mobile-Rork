import SwiftUI

/// Root gate: splash → auth loading → login or tabs.
struct ContentView: View {
    @Environment(AuthStore.self) private var auth
    @Environment(AppRouter.self) private var router
    @State private var splashDone = false

    var body: some View {
        @Bindable var router = router
        ZStack {
            Theme.background.ignoresSafeArea()

            switch auth.status {
            case .loading:
                ProgressView()
                    .controlSize(.large)
                    .tint(Theme.accent)
            case .unauthenticated:
                AuthFlowView()
            case .authenticated:
                MainTabView()
            }

            // Darker background behind sheets that ask for it (see SheetDimmer).
            if SheetDimmer.shared.isActive {
                Color.black.opacity(SheetDimmer.extraOpacity)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }

            ToastHost()
            RunningOverlayView()

            if !splashDone {
                TimedSplashView { splashDone = true }
            }
        }
        .fullScreenCover(item: $router.playerRequest) { request in
            VideoPlayerScreen(request: request)
        }
        .sheet(item: $router.postRequest) { request in
            PostReaderView(request: request)
                .presentationDragIndicator(.visible)
        }
        .task {
            auth.start()
        }
    }
}

/// Branded splash held for 3 seconds after launch, then faded out.
private struct TimedSplashView: View {
    let onDone: () -> Void
    @State private var opacity: Double = 1

    var body: some View {
        ZStack {
            Color(red: 0, green: 1 / 255, blue: 8 / 255).ignoresSafeArea()
            Image("SplashScreen")
                .resizable()
                .scaledToFit()
        }
        .opacity(opacity)
        .allowsHitTesting(false)
        .task {
            try? await Task.sleep(for: .seconds(3))
            withAnimation(.easeOut(duration: 0.4)) { opacity = 0 }
            try? await Task.sleep(for: .seconds(0.45))
            onDone()
        }
    }
}
