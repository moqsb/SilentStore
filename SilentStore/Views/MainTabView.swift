import SwiftUI

struct MainTabView: View {
    @ObservedObject var vaultStore: VaultStore
    @AppStorage("hasSeenTutorial") private var hasSeenTutorial = false
    @State private var showTutorial = false
    @State private var selectedTab = 0
    @State private var filesInitialFilter: VaultStore.FilterOption?

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                HomeView(vaultStore: vaultStore, selectedTab: $selectedTab, filesInitialFilter: $filesInitialFilter)
            }
            .tabItem {
                Label(NSLocalizedString("Home", comment: ""), systemImage: "house.fill")
            }
            .tag(0)

            NavigationStack {
                VaultHomeView(vaultStore: vaultStore, initialFilter: $filesInitialFilter)
            }
            .tabItem {
                Label(NSLocalizedString("Files", comment: ""), systemImage: "folder.fill")
            }
            .tag(1)

            NavigationStack {
                AIView(vaultStore: vaultStore)
            }
            .tabItem {
                Label("AI", systemImage: "sparkles")
            }
            .tag(2)

            NavigationStack {
                SettingsView(vaultStore: vaultStore)
            }
            .tabItem {
                Label(NSLocalizedString("Settings", comment: ""), systemImage: "gearshape.fill")
            }
            .tag(3)
        }
        .tint(AppTheme.colors.accent)
        .sheet(isPresented: $showTutorial) {
            TutorialView(isPresented: $showTutorial)
        }
        .onAppear {
            if !hasSeenTutorial {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    showTutorial = true
                }
            }
        }
    }
}
