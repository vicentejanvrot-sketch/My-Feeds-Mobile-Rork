import SwiftUI

/// Navigation destinations pushed within tabs.
enum AppRoute: Hashable {
    case agentDetail(String)
    case agentForm(String?)
    case faq
    case privacy
    case terms
    case following
    case onboardingTest
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

            NavigationStack {
                AgentsView()
                    .withAppRoutes()
            }
            .tabItem { Label("Agents", image: "TabAgentsIcon") }
            .tag(AppTab.agents)

            NavigationStack {
                FeedView()
                    .withAppRoutes()
            }
            .tabItem { Label("Feed", image: "TabFeedIcon") }
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
                case .onboardingTest:
                    DashboardOnboardingView()
                }
            }
    }
}

extension View {
    func withAppRoutes() -> some View {
        modifier(AppRoutesModifier())
    }
}
