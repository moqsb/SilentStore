import SwiftUI

struct MainTabView: View {
    @ObservedObject var vaultStore: VaultStore

    var body: some View {
        TabView {
            NavigationStack {
                VaultHomeView(vaultStore: vaultStore)
            }
            .tabItem {
                Label("Files", systemImage: "folder")
            }

            NavigationStack {
                RecentsView(vaultStore: vaultStore)
            }
            .tabItem {
                Label("Recents", systemImage: "clock")
            }

            NavigationStack {
                SettingsView(vaultStore: vaultStore)
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape")
            }
        }
    }
}
