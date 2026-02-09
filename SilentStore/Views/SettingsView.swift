import SwiftUI

struct SettingsView: View {
    enum PasscodeSheetMode: Identifiable {
        case set
        case change

        var id: String { self == .set ? "set" : "change" }
    }

    @ObservedObject var vaultStore: VaultStore
    @AppStorage("aiEnabled") private var aiEnabled = false
    @AppStorage("faceIdEnabled") private var faceIdEnabled = false
    @AppStorage("reminderEnabled") private var reminderEnabled = false
    @State private var biometricStatus: BiometricStatus = .notDetermined
    @AppStorage("reminderWeekday") private var reminderWeekday = 2
    @AppStorage("reminderHour") private var reminderHour = 19
    @AppStorage("reminderMinute") private var reminderMinute = 0
    @AppStorage("appearanceMode") private var appearanceMode = "system"
    @AppStorage("didOnboard") private var didOnboard = false
    @State private var passcodeMode: PasscodeSheetMode?
    @State private var showWipeConfirm = false
    @State private var hasPasscode = false
    @State private var showTutorial = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Profile Card
                    profileCard
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .padding(.bottom, 24)
                    
                    // Sections
                    VStack(spacing: 0) {
                        settingsSection(NSLocalizedString("Account", comment: "")) {
                            settingsNavRow(icon: "hand.raised.fill", title: NSLocalizedString("Privacy", comment: "")) {
                                PrivacySettingsView()
                            }
                            settingsDivider()
                            settingsNavRow(icon: "lock.shield.fill", title: NSLocalizedString("Security", comment: "")) {
                                SecuritySettingsView(vaultStore: vaultStore, hasPasscode: $hasPasscode, passcodeMode: $passcodeMode, showWipeConfirm: $showWipeConfirm)
                            }
                            settingsDivider()
                            settingsActionRow(icon: "checkmark.shield.fill", title: NSLocalizedString("Two-Step Verification", comment: "")) {
                                passcodeMode = hasPasscode ? .change : .set
                            }
                        }
                        
                        settingsSection(NSLocalizedString("Appearance", comment: "")) {
                            settingsNavRow(icon: "paintbrush.fill", title: NSLocalizedString("Theme", comment: ""), subtitle: themeDisplayName) {
                                ThemeOptionsView(appearanceMode: $appearanceMode)
                            }
                            settingsDivider()
                            settingsNavRow(icon: "photo.fill", title: NSLocalizedString("Wallpaper", comment: "")) {
                                WallpaperPickerView()
                            }
                            settingsDivider()
                            settingsNavRow(icon: "square.and.arrow.down.fill", title: NSLocalizedString("Backup", comment: "")) {
                                BackupSettingsView()
                            }
                            settingsDivider()
                            settingsNavRow(icon: "clock.fill", title: NSLocalizedString("History", comment: "")) {
                                HistoryView()
                            }
                        }
                        
                        settingsSection(NSLocalizedString("Notifications", comment: "")) {
                            settingsToggleRow(icon: "envelope.fill", title: NSLocalizedString("Message Notifications", comment: ""), isOn: $reminderEnabled)
                                .onChange(of: reminderEnabled) { _, isOn in
                                    if isOn {
                                        ReminderManager.shared.scheduleWeeklyReminder(weekday: reminderWeekday, hour: reminderHour, minute: reminderMinute)
                                    } else {
                                        ReminderManager.shared.cancelReminder()
                                    }
                                }
                            settingsDivider()
                            settingsToggleRow(icon: "person.2.fill", title: NSLocalizedString("Group Notifications", comment: ""), isOn: .constant(false))
                            settingsDivider()
                            settingsToggleRow(icon: "bell.fill", title: NSLocalizedString("In-App Sounds", comment: ""), isOn: .constant(true))
                        }
                        
                        settingsSection(NSLocalizedString("Storage and Data", comment: "")) {
                            settingsNavRow(icon: "antenna.radiowaves.left.and.right", title: NSLocalizedString("Network Usage", comment: "")) {
                                NetworkUsageView()
                            }
                            settingsDivider()
                            settingsNavRow(icon: "internaldrive.fill", title: NSLocalizedString("Storage Usage", comment: ""), subtitle: storageSummaryText) {
                                StorageDashboard(vaultStore: vaultStore)
                            }
                            settingsDivider()
                            settingsNavRow(icon: "arrow.down.circle.fill", title: NSLocalizedString("Media Auto-Download", comment: "")) {
                                AutoDownloadView()
                            }
                        }
                        
                        settingsSection(NSLocalizedString("Help", comment: "")) {
                            settingsNavRow(icon: "questionmark.circle.fill", title: NSLocalizedString("FAQ", comment: "")) {
                                FAQView()
                            }
                            settingsDivider()
                            settingsNavRow(icon: "envelope.fill", title: NSLocalizedString("Contact Support", comment: "")) {
                                ContactSupportView()
                            }
                            settingsDivider()
                            settingsNavRow(icon: "doc.text.fill", title: NSLocalizedString("Terms & Privacy Policy", comment: "")) {
                                PrivacyView()
                            }
                        }
                        
                        settingsSection(NSLocalizedString("App Info", comment: "")) {
                            settingsNavRow(icon: "info.circle.fill", title: NSLocalizedString("Version", comment: ""), subtitle: appVersion) {
                                AboutView()
                            }
                            settingsDivider()
                            settingsNavRow(icon: "info.circle.fill", title: NSLocalizedString("About", comment: "")) {
                                AboutView()
                            }
                        }
                    }
                    .padding(.bottom, 32)
                }
            }
            .background(AppTheme.gradients.background.ignoresSafeArea())
            .navigationTitle(NSLocalizedString("Settings", comment: ""))
            .navigationBarTitleDisplayMode(.large)
        }
        .sheet(item: $passcodeMode) { mode in
            PasscodeSheet(mode: mode) {
                hasPasscode = KeyManager.shared.hasPasscode()
            }
        }
        .sheet(isPresented: $showTutorial) {
            TutorialView(isPresented: $showTutorial)
        }
        .alert(NSLocalizedString("Erase all data?", comment: ""), isPresented: $showWipeConfirm) {
            Button(NSLocalizedString("Erase", comment: ""), role: .destructive) {
                vaultStore.wipeAllData()
                didOnboard = false
                hasPasscode = KeyManager.shared.hasPasscode()
            }
            Button(NSLocalizedString("Cancel", comment: ""), role: .cancel) {}
        } message: {
            Text(NSLocalizedString("This will delete all vault files and the app passcode. You will need to set a new passcode.", comment: ""))
        }
        .onAppear {
            hasPasscode = KeyManager.shared.hasPasscode()
            checkBiometricStatus()
        }
    }
    
    // MARK: - Profile Card
    
    private var profileCard: some View {
        NavigationLink {
            ProfileEditView()
        } label: {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(AppTheme.gradients.accent)
                        .frame(width: 56, height: 56)
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(NSLocalizedString("SilentStore", comment: ""))
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(AppTheme.colors.primaryText)
                    Text(NSLocalizedString("Secure Vault", comment: ""))
                        .font(.system(size: 14))
                        .foregroundStyle(AppTheme.colors.secondaryText)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.colors.secondaryText.opacity(0.6))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AppTheme.colors.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(AppTheme.colors.cardBorder, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Section & Rows
    
    private func settingsSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.colors.secondaryText)
                .textCase(nil)
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
            
            VStack(spacing: 0) {
                content()
            }
            .padding(.horizontal, 20)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AppTheme.colors.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(AppTheme.colors.cardBorder, lineWidth: 1)
                    )
            )
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 24)
    }
    
    private func settingsNavRow<Destination: View>(icon: String, title: String, subtitle: String? = nil, @ViewBuilder destination: () -> Destination) -> some View {
        NavigationLink {
            destination()
        } label: {
            settingsRowContent(icon: icon, title: title, subtitle: subtitle)
        }
        .buttonStyle(.plain)
    }
    
    private func settingsActionRow(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            settingsRowContent(icon: icon, title: title, subtitle: nil)
        }
        .buttonStyle(.plain)
    }
    
    private func settingsDivider() -> some View {
        Divider()
            .background(AppTheme.colors.cardBorder)
            .padding(.leading, 44)
    }
    
    private func settingsRowContent(icon: String, title: String, subtitle: String? = nil) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(AppTheme.colors.accent)
                .frame(width: 28, alignment: .center)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(AppTheme.colors.primaryText)
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.colors.secondaryText)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppTheme.colors.secondaryText.opacity(0.5))
        }
        .padding(.vertical, 12)
    }
    
    private func settingsToggleRow(icon: String, title: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(AppTheme.colors.accent)
                .frame(width: 28, alignment: .center)
            
            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(AppTheme.colors.primaryText)
            
            Spacer()
            
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(AppTheme.colors.accent)
        }
        .padding(.vertical, 12)
    }
    
    // MARK: - Computed Properties
    
    private var themeDisplayName: String {
        switch appearanceMode {
        case "system": return NSLocalizedString("System", comment: "")
        case "light": return NSLocalizedString("Light", comment: "")
        case "dark": return NSLocalizedString("Dark", comment: "")
        default: return NSLocalizedString("System", comment: "")
        }
    }
    
    private var storageSummaryText: String {
        let total = vaultStore.totalAppStorageBytes()
        return ByteCountFormatter.string(fromByteCount: total, countStyle: .file)
    }
    
    private var appVersion: String {
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
           let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            return "\(version) (\(build))"
        }
        return "1.0"
    }
    
    // MARK: - Helper Functions
    
    private func checkBiometricStatus() {
        biometricStatus = BiometricManager.shared.checkAvailability()
    }
    
    private func requestBiometricPermission() async {
        let status = BiometricManager.shared.checkAvailability()
        
        if status == .available {
            let granted = await BiometricManager.shared.requestPermission()
            UserDefaults.standard.set(true, forKey: "hasRequestedBiometricPermission")
            await MainActor.run {
                if granted {
                    faceIdEnabled = true
                    biometricStatus = .available
                } else {
                    faceIdEnabled = false
                    biometricStatus = BiometricManager.shared.checkAvailability()
                }
            }
        } else {
            await MainActor.run {
                faceIdEnabled = false
                biometricStatus = status
            }
        }
    }
}

// MARK: - Supporting Views

private struct ProfileEditView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack {
                Text("Profile Edit")
                    .font(.title2)
                Text("Coming soon")
                    .foregroundStyle(.secondary)
            }
            .navigationTitle(NSLocalizedString("Edit Profile", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

private struct PrivacySettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("aiEnabled") private var aiEnabled = false
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Toggle(NSLocalizedString("AI Features", comment: ""), isOn: $aiEnabled)
                        .onChange(of: aiEnabled) { _, enabled in
                            AIManager.shared.enabled = enabled
                        }
                    
                    if aiEnabled {
                        NavigationLink {
                            AILearningView()
                        } label: {
                            HStack {
                                Text(NSLocalizedString("AI Learning", comment: ""))
                                Spacer()
                            }
                        }
                    }
                }
                
                Section {
                    NavigationLink {
                        PrivacyView()
                    } label: {
                        Text(NSLocalizedString("Privacy Policy", comment: ""))
                    }
                }
            }
            .navigationTitle(NSLocalizedString("Privacy", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct SecuritySettingsView: View {
    @ObservedObject var vaultStore: VaultStore
    @Binding var hasPasscode: Bool
    @Binding var passcodeMode: SettingsView.PasscodeSheetMode?
    @Binding var showWipeConfirm: Bool
    @AppStorage("faceIdEnabled") private var faceIdEnabled = false
    @State private var biometricStatus: BiometricStatus = .notDetermined
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Toggle(NSLocalizedString("Face ID / Touch ID", comment: ""), isOn: $faceIdEnabled)
                        .onChange(of: faceIdEnabled) { _, newValue in
                            if newValue {
                                Task {
                                    await requestBiometricPermission()
                                }
                            }
                        }
                    
                    Button {
                        passcodeMode = hasPasscode ? .change : .set
                    } label: {
                        HStack {
                            Text(hasPasscode ? NSLocalizedString("Change Passcode", comment: "") : NSLocalizedString("Set Passcode", comment: ""))
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(AppTheme.colors.secondaryText.opacity(0.5))
                        }
                    }
                }
                
                Section {
                    Button(role: .destructive) {
                        showWipeConfirm = true
                    } label: {
                        Text(NSLocalizedString("Erase All Data", comment: ""))
                    }
                }
            }
            .navigationTitle(NSLocalizedString("Security", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                biometricStatus = BiometricManager.shared.checkAvailability()
            }
        }
    }
    
    private func requestBiometricPermission() async {
        let status = BiometricManager.shared.checkAvailability()
        
        if status == .available {
            let granted = await BiometricManager.shared.requestPermission()
            UserDefaults.standard.set(true, forKey: "hasRequestedBiometricPermission")
            await MainActor.run {
                if granted {
                    faceIdEnabled = true
                    biometricStatus = .available
                } else {
                    faceIdEnabled = false
                    biometricStatus = BiometricManager.shared.checkAvailability()
                }
            }
        } else {
            await MainActor.run {
                faceIdEnabled = false
                biometricStatus = status
            }
        }
    }
}

private struct ThemeOptionsView: View {
    @Binding var appearanceMode: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker(NSLocalizedString("Theme", comment: ""), selection: $appearanceMode) {
                        Text(NSLocalizedString("System", comment: "")).tag("system")
                        Text(NSLocalizedString("Light", comment: "")).tag("light")
                        Text(NSLocalizedString("Dark", comment: "")).tag("dark")
                    }
                }
            }
            .navigationTitle(NSLocalizedString("Theme", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

private struct WallpaperPickerView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack {
                Text("Wallpaper")
                    .font(.title2)
                Text("Coming soon")
                    .foregroundStyle(.secondary)
            }
            .navigationTitle(NSLocalizedString("Wallpaper", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

private struct BackupSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack {
                Text("Backup")
                    .font(.title2)
                Text("Coming soon")
                    .foregroundStyle(.secondary)
            }
            .navigationTitle(NSLocalizedString("Backup", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

private struct HistoryView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack {
                Text("History")
                    .font(.title2)
                Text("Coming soon")
                    .foregroundStyle(.secondary)
            }
            .navigationTitle(NSLocalizedString("History", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

private struct NetworkUsageView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack {
                Text("Network Usage")
                    .font(.title2)
                Text("Coming soon")
                    .foregroundStyle(.secondary)
            }
            .navigationTitle(NSLocalizedString("Network Usage", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

private struct AutoDownloadView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack {
                Text("Auto-Download")
                    .font(.title2)
                Text("Coming soon")
                    .foregroundStyle(.secondary)
            }
            .navigationTitle(NSLocalizedString("Media Auto-Download", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

private struct FAQView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack {
                Text("FAQ")
                    .font(.title2)
                Text("Coming soon")
                    .foregroundStyle(.secondary)
            }
            .navigationTitle(NSLocalizedString("FAQ", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

private struct ContactSupportView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack {
                Text("Contact Support")
                    .font(.title2)
                Text("Coming soon")
                    .foregroundStyle(.secondary)
            }
            .navigationTitle(NSLocalizedString("Contact Support", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

private struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Text(NSLocalizedString("Version", comment: ""))
                        Spacer()
                        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
                           let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
                            Text("\(version) (\(build))")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                Section {
                    Text(NSLocalizedString("SilentStore is a secure vault for your photos, videos, and documents. All files are encrypted on-device and protected by biometric authentication.", comment: ""))
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(NSLocalizedString("About", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Passcode Sheet (kept from original)

private struct PasscodeSheet: View {
    enum Step {
        case current
        case new
        case confirm
    }
    
    let mode: SettingsView.PasscodeSheetMode
    let onSaved: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var step: Step
    @State private var currentPasscode = ""
    @State private var newPasscode = ""
    @State private var confirmPasscode = ""
    @State private var statusMessage: String?
    @State private var isSaving = false
    
    init(mode: SettingsView.PasscodeSheetMode, onSaved: @escaping () -> Void) {
        self.mode = mode
        self.onSaved = onSaved
        _step = State(initialValue: mode == .set ? .new : .current)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text(stepTitle)
                    .font(AppTheme.fonts.title)
                Text(stepSubtitle)
                    .font(AppTheme.fonts.caption)
                    .foregroundStyle(AppTheme.colors.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                
                if step == .current {
                    PasscodeEntryView(passcode: $currentPasscode, length: 6) {
                        if currentPasscode.count == 6 {
                            step = .new
                        }
                    }
                } else if step == .new {
                    PasscodeEntryView(passcode: $newPasscode, length: 6) {
                        if newPasscode.count == 6 {
                            step = .confirm
                        }
                    }
                } else {
                    PasscodeEntryView(passcode: $confirmPasscode, length: 6) {
                        Task { await save() }
                    }
                }
                
                if let statusMessage {
                    Text(statusMessage)
                        .font(AppTheme.fonts.caption)
                        .foregroundStyle(statusMessage.contains("Failed") || statusMessage.contains("don't") || statusMessage.contains("incorrect") ? .red : AppTheme.colors.secondaryText)
                        .padding(.top, 8)
                }
                
                Spacer()
            }
            .padding(.top, 40)
            .navigationTitle(mode == .set ? NSLocalizedString("Set Passcode", comment: "") : NSLocalizedString("Change Passcode", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("Done", comment: "")) { dismiss() }
                }
            }
        }
    }
    
    private var stepTitle: String {
        switch step {
        case .current:
            return NSLocalizedString("Current Passcode", comment: "")
        case .new:
            return NSLocalizedString("New Passcode", comment: "")
        case .confirm:
            return NSLocalizedString("Confirm Passcode", comment: "")
        }
    }
    
    private var stepSubtitle: String {
        switch step {
        case .current:
            return NSLocalizedString("Enter your current passcode", comment: "")
        case .new:
            return NSLocalizedString("Enter a new 6-digit passcode", comment: "")
        case .confirm:
            return NSLocalizedString("Confirm your new passcode", comment: "")
        }
    }

    private func save() async {
        guard newPasscode.count == 6 && confirmPasscode.count == 6 else { return }
        guard newPasscode == confirmPasscode else {
            HapticFeedback.play(.error)
            statusMessage = NSLocalizedString("Passcodes don't match. Try again.", comment: "")
            newPasscode = ""
            confirmPasscode = ""
            step = .new
            return
        }
        isSaving = true
        statusMessage = nil
        do {
            if mode == .set {
                try await KeyManager.shared.setPasscode(newPasscode)
            } else {
                guard currentPasscode.count == 6 else {
                    HapticFeedback.play(.error)
                    statusMessage = NSLocalizedString("Incorrect current passcode.", comment: "")
                    currentPasscode = ""
                    step = .current
                    isSaving = false
                    return
                }
                try await KeyManager.shared.changePasscode(current: currentPasscode, new: newPasscode)
            }
            HapticFeedback.play(.success)
            statusMessage = NSLocalizedString("Passcode saved.", comment: "")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                onSaved()
                dismiss()
            }
        } catch {
            HapticFeedback.play(.error)
            statusMessage = NSLocalizedString("Failed to save passcode.", comment: "")
            if mode == .change {
                currentPasscode = ""
                newPasscode = ""
                confirmPasscode = ""
                step = .current
            } else {
                newPasscode = ""
                confirmPasscode = ""
                step = .new
            }
        }
        isSaving = false
    }
}
