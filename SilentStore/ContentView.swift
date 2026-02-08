//
//  ContentView.swift
//  SilentStore
//
//  Created by Mohammed Alqassab on 08-02-2026.
//

import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var authManager = AuthManager()
    @StateObject private var permissionsManager = PermissionsManager()
    @StateObject private var vaultStore: VaultStore
    @State private var showPermissions = false
    @AppStorage("faceIdEnabled") private var faceIdEnabled = true
    @AppStorage("didOnboard") private var didOnboard = false
    @State private var isUnlocking = false

    init(context: NSManagedObjectContext = PersistenceController.shared.container.viewContext) {
        _vaultStore = StateObject(wrappedValue: VaultStore(context: context))
    }

    var body: some View {
        ZStack {
            if didOnboard {
                VaultHomeView(vaultStore: vaultStore)
                    .environmentObject(vaultStore)
                    .opacity(shouldHideContent ? 0 : 1)
                    .allowsHitTesting(!shouldHideContent)
            } else {
                OnboardingView()
            }

            if shouldHideContent {
                AppTheme.gradients.background
                    .ignoresSafeArea()
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(AppTheme.colors.cardBackground)
                            .frame(width: 64, height: 64)
                        Image(systemName: "lock.fill")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(AppTheme.colors.accent)
                    }
                    Text("SilentStore")
                        .font(AppTheme.fonts.title)
                        .foregroundStyle(AppTheme.colors.primaryText)
                    Button("Unlock") {
                        Task { await unlockIfNeeded() }
                    }
                    .buttonStyle(AppTheme.buttons.primary)
                }
            }
        }
        .tint(AppTheme.colors.accent)
        .sheet(isPresented: $showPermissions) {
            PermissionsView(permissionsManager: permissionsManager)
        }
        .onAppear {
            showPermissions = permissionsManager.shouldShowPermissionsSheet
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase != .active {
                authManager.lock()
                KeyManager.shared.clearMasterKeyFromMemory()
            } else {
                if didOnboard {
                    Task { await unlockIfNeeded() }
                }
            }
        }
        .onChange(of: didOnboard) { _, newValue in
            if newValue && scenePhase == .active {
                Task { await unlockIfNeeded() }
            }
        }
    }

    private var shouldHideContent: Bool {
        scenePhase != .active || !authManager.isAuthenticated
    }

    private func unlockIfNeeded() async {
        guard !isUnlocking else { return }
        isUnlocking = true
        defer { isUnlocking = false }
        let success = await authManager.authenticateIfNeeded(useBiometrics: faceIdEnabled)
        guard success else { return }
        await vaultStore.prepareIfNeeded()
    }
}

#Preview {
    ContentView(context: PersistenceController.preview.container.viewContext)
}
