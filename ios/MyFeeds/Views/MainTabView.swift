import SwiftUI

/// Navigation destinations pushed within tabs.
enum AppRoute: Hashable {
    case agentDetail(String)
    case agentForm(String?)
    case faq
    case privacy
    case terms
    case following
    /// People, showing one collection's people.
    case followingIn(String)
    case downloads
}

struct MainTabView: View {
    @Environment(AppRouter.self) private var router

    var body: some View {
        @Bindable var router = router
        TabView(selection: $router.selectedTab) {
            NavigationStack {
                DashboardView()
                    .withAppRoutes()
            }
            .tabItem { Label("Dashboard", image: "TabDashboardIcon") }
            .tag(AppTab.dashboard)

            NavigationStack(path: $router.agentsPath) {
                AgentsView()
                    .withAppRoutes()
            }
            .tabItem { Label("Collections", image: "TabAgentsIcon") }
            .tag(AppTab.agents)

            NavigationStack {
                FeedView()
                    .withAppRoutes()
            }
            .tabItem { Label("Feeds", image: "TabFeedIcon") }
            .tag(AppTab.feed)

            NavigationStack {
                HistoryView()
                    .withAppRoutes()
            }
            .tabItem { Label("History", image: "TabHistoryIcon") }
            .tag(AppTab.history)

            NavigationStack {
                SettingsView()
                    .withAppRoutes()
            }
            .tabItem { Label("Settings", image: "TabSettingsIcon") }
            .tag(AppTab.settings)
        }
        .tint(Theme.accent)
        // A web link that arrived while signing in opens once the tabs show.
        .onAppear { router.openPendingLink() }
    }
}

private struct AppRoutesModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .navigationDestination(for: AppRoute.self) { route in
                switch route {
                case .agentDetail(let agentId):
                    AgentDetailView(agentId: agentId)
                case .agentForm(let agentId):
                    AgentFormView(agentId: agentId)
                case .faq:
                    FAQView()
                case .privacy:
                    PrivacyPolicyView()
                case .terms:
                    TermsView()
                case .following:
                    FollowingView()
                case .followingIn(let agentId):
                    FollowingView(initialAgentId: agentId)
                case .downloads:
                    DownloadsView()
                }
            }
    }
}

extension View {
    func withAppRoutes() -> some View {
        modifier(AppRoutesModifier())
    }
}
