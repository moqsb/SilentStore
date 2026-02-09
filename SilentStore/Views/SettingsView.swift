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
                        }
                        
                        settingsSection(NSLocalizedString("Appearance", comment: "")) {
                            settingsNavRow(icon: "paintbrush.fill", title: NSLocalizedString("Theme", comment: ""), subtitle: themeDisplayName) {
                                ThemeOptionsView(appearanceMode: $appearanceMode)
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
                        }
                        
                        settingsSection(NSLocalizedString("Storage and Data", comment: "")) {
                            settingsNavRow(icon: "internaldrive.fill", title: NSLocalizedString("Storage Usage", comment: ""), subtitle: storageSummaryText) {
                                StorageDashboard(vaultStore: vaultStore)
                            }
                        }
                        
                        settingsSection(NSLocalizedString("Help", comment: "")) {
                            settingsNavRow(icon: "doc.text.fill", title: NSLocalizedString("Terms of Use", comment: "")) {
                                TermsOfUseView()
                            }
                            settingsDivider()
                            settingsNavRow(icon: "hand.raised.fill", title: NSLocalizedString("Privacy Policy", comment: "")) {
                                PrivacyView()
                            }
                        }
                        
                        settingsSection(NSLocalizedString("App Info", comment: "")) {
                            settingsNavRow(icon: "info.circle.fill", title: NSLocalizedString("About", comment: ""), subtitle: appVersion) {
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
        .fullScreenCover(item: $passcodeMode) { mode in
            PasscodeSheet(mode: mode) {
                hasPasscode = KeyManager.shared.hasPasscode()
            }
        }
        .sheet(isPresented: $showTutorial) {
            TutorialView(isPresented: $showTutorial)
        }
        .fullScreenCover(isPresented: $showWipeConfirm) {
            WipeDataConfirmView(
                isPresented: $showWipeConfirm,
                onConfirm: {
                    vaultStore.wipeAllData()
                    didOnboard = false
                    hasPasscode = KeyManager.shared.hasPasscode()
                    showWipeConfirm = false
                }
            )
        }
        .onAppear {
            hasPasscode = KeyManager.shared.hasPasscode()
            checkBiometricStatus()
        }
    }
    
    // MARK: - Profile Card
    
    private var profileCard: some View {
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

// MARK: - Passcode Strength

private enum PasscodeStrength {
    struct RuleResult: Identifiable {
        let id: String
        let passed: Bool
        var label: String { NSLocalizedString(id, comment: "") }
    }
    
    static func check(_ code: String) -> [RuleResult] {
        guard code.count == 6, code.allSatisfy({ $0.isNumber }) else {
            return []
        }
        let digits = code.map { Int(String($0))! }
        return [
            RuleResult(id: "passcode_rule_not_sequential", passed: !isSequential(digits)),
            RuleResult(id: "passcode_rule_not_repeated", passed: !isAllSame(digits)),
            RuleResult(id: "passcode_rule_not_repeating_pair", passed: !isRepeatingPair(digits)),
            RuleResult(id: "passcode_rule_not_common", passed: !isCommonWeak(code))
        ]
    }
    
    private static func isSequential(_ d: [Int]) -> Bool {
        let up = (0..<5).allSatisfy { d[$0] + 1 == d[$0 + 1] }
        let down = (0..<5).allSatisfy { d[$0] - 1 == d[$0 + 1] }
        return up || down
    }
    
    private static func isAllSame(_ d: [Int]) -> Bool {
        d.allSatisfy { $0 == d[0] }
    }
    
    private static func isRepeatingPair(_ d: [Int]) -> Bool {
        if d[0] == d[2] && d[1] == d[3] && d[0] == d[4] && d[1] == d[5] { return true }
        if d[0] == d[1] && d[2] == d[3] && d[4] == d[5] && d[0] == d[2] && d[0] == d[4] { return true }
        if d[0] == d[2] && d[2] == d[4] && d[1] == d[3] && d[3] == d[5] { return true }
        return false
    }
    
    private static func isCommonWeak(_ code: String) -> Bool {
        let weak = ["123456", "654321", "111111", "000000", "123123", "112233", "121212", "012345", "567890", "111222", "123321", "999999"]
        return weak.contains(code)
    }
}

// MARK: - Passcode Sheet (full screen)

private struct PasscodeSheet: View {
    enum Step {
        case warning
        case current
        case new
        case confirm
        case showPasscode
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
        _step = State(initialValue: .warning)
    }

    var body: some View {
        ZStack {
            AppTheme.gradients.background.ignoresSafeArea()
            VStack(spacing: 0) {
                if step != .showPasscode {
                    HStack {
                        Spacer()
                        if step != .warning {
                            Button(NSLocalizedString("Cancel", comment: "")) {
                                HapticFeedback.play(.light)
                                dismiss()
                            }
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(AppTheme.colors.accent)
                            .padding(.trailing, 20)
                            .padding(.top, 16)
                        }
                    }
                    .frame(height: 44)
                }
                
                ScrollView {
                    VStack(spacing: 28) {
                        if step == .warning {
                            warningStepContent
                        } else if step == .current {
                            entryStepContent(title: NSLocalizedString("Current Passcode", comment: ""), subtitle: NSLocalizedString("Enter your current passcode", comment: "")) {
                                PasscodeEntryView(passcode: $currentPasscode, length: 6) {
                                    if currentPasscode.count == 6 { step = .new }
                                }
                            }
                        } else if step == .new {
                            entryStepContent(title: NSLocalizedString("New Passcode", comment: ""), subtitle: NSLocalizedString("Enter a new 6-digit passcode", comment: "")) {
                                VStack(spacing: 20) {
                                    PasscodeEntryView(passcode: $newPasscode, length: 6) {
                                        if newPasscode.count == 6 {
                                            let result = PasscodeStrength.check(newPasscode)
                                            if result.allSatisfy(\.passed) {
                                                step = .confirm
                                            } else {
                                                statusMessage = NSLocalizedString("Make it a bit stronger.", comment: "")
                                                HapticFeedback.play(.warning)
                                            }
                                        }
                                    }
                                    if !newPasscode.isEmpty {
                                        passcodeStrengthRulesView(passcode: newPasscode)
                                    }
                                }
                            }
                        } else if step == .confirm {
                            entryStepContent(title: NSLocalizedString("Confirm Passcode", comment: ""), subtitle: NSLocalizedString("Confirm your new passcode", comment: "")) {
                                PasscodeEntryView(passcode: $confirmPasscode, length: 6) {
                                    Task { await save() }
                                }
                            }
                        } else if step == .showPasscode {
                            showPasscodeStepContent
                        }
                        
                        if let statusMessage, step != .warning, step != .showPasscode {
                            Text(statusMessage)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(statusMessage.contains("Failed") || statusMessage.contains("don't") || statusMessage.contains("incorrect") ? AppTheme.colors.error : AppTheme.colors.secondaryText)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                        }
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                }
            }
        }
    }
    
    private var warningStepContent: some View {
        VStack(spacing: 32) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 56))
                .foregroundStyle(AppTheme.colors.warning)
            Text(NSLocalizedString("Important", comment: ""))
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(AppTheme.colors.primaryText)
            Text(NSLocalizedString("Your passcode cannot be recovered if you forget it. There is no way to reset or retrieve it. Make sure you remember it.", comment: ""))
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(AppTheme.colors.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
            Button {
                HapticFeedback.play(.light)
                step = mode == .set ? .new : .current
            } label: {
                Text(NSLocalizedString("Continue", comment: ""))
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(AppTheme.gradients.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .padding(.horizontal, 28)
            .padding(.top, 12)
        }
        .padding(.top, 40)
    }
    
    private func entryStepContent<Content: View>(title: String, subtitle: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 24) {
            Text(title)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(AppTheme.colors.primaryText)
            Text(subtitle)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(AppTheme.colors.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            content()
        }
        .padding(.top, 24)
    }
    
    @ViewBuilder
    private func passcodeStrengthRulesView(passcode: String) -> some View {
        let hasSix = passcode.count == 6
        let results = hasSix ? PasscodeStrength.check(passcode) : []
        let ruleIds = ["passcode_rule_not_sequential", "passcode_rule_not_repeated", "passcode_rule_not_repeating_pair", "passcode_rule_not_common"]
        VStack(alignment: .leading, spacing: 10) {
            Text(NSLocalizedString("Passcode rules", comment: ""))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.colors.secondaryText)
            ForEach(ruleIds, id: \.self) { id in
                let r = results.first { $0.id == id }
                HStack(spacing: 10) {
                    if hasSix, let r = r {
                        Image(systemName: r.passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(r.passed ? AppTheme.colors.success : AppTheme.colors.error)
                        Text(r.label)
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(r.passed ? AppTheme.colors.secondaryText : AppTheme.colors.error)
                    } else {
                        Image(systemName: "circle.dashed")
                            .font(.system(size: 18))
                            .foregroundStyle(AppTheme.colors.secondaryText.opacity(0.5))
                        Text(NSLocalizedString(id, comment: ""))
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(AppTheme.colors.secondaryText)
                    }
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
    }
    
    private var showPasscodeStepContent: some View {
        VStack(spacing: 28) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(AppTheme.colors.success)
            Text(NSLocalizedString("Passcode changed", comment: ""))
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(AppTheme.colors.primaryText)
            Text(NSLocalizedString("Save it well. You cannot recover it if you forget it.", comment: ""))
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(AppTheme.colors.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
            Text(newPasscode)
                .font(.system(size: 32, weight: .bold, design: .monospaced))
                .foregroundStyle(AppTheme.colors.primaryText)
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .background(AppTheme.colors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(AppTheme.colors.cardBorder, lineWidth: 1)
                )
            Button {
                HapticFeedback.play(.success)
                onSaved()
                dismiss()
            } label: {
                Text(NSLocalizedString("Done", comment: ""))
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(AppTheme.gradients.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .padding(.horizontal, 28)
            .padding(.top, 8)
        }
        .padding(.top, 50)
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
            await MainActor.run {
                step = .showPasscode
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

// MARK: - Wipe Data Full-Screen Confirm (10 second countdown)

private struct WipeDataConfirmView: View {
    @Binding var isPresented: Bool
    let onConfirm: () -> Void
    @State private var countdown = 10
    @State private var countdownTask: Task<Void, Never>?
    
    var body: some View {
        ZStack {
            Color(red: 0.06, green: 0.02, blue: 0.02)
                .ignoresSafeArea()
            VStack(spacing: 32) {
                Image(systemName: "trash.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(AppTheme.colors.error)
                Text(NSLocalizedString("Erase all data?", comment: ""))
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(.white)
                Text(NSLocalizedString("Everything will be lost forever. All your files, passcode, and vault data will be permanently deleted. This cannot be undone.", comment: ""))
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
                Text(NSLocalizedString("There is no way to recover anything after erasing.", comment: ""))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppTheme.colors.error)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
                if countdown > 0 {
                    Text(String(format: NSLocalizedString("You can confirm in %d seconds", comment: ""), countdown))
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(.top, 8)
                }
                Spacer().frame(height: 20)
                Button {
                    onConfirm()
                } label: {
                    Text(NSLocalizedString("Erase everything", comment: ""))
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(countdown > 0 ? Color.gray : AppTheme.colors.error)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .disabled(countdown > 0)
                .padding(.horizontal, 28)
                Button {
                    countdownTask?.cancel()
                    countdownTask = nil
                    isPresented = false
                } label: {
                    Text(NSLocalizedString("Cancel", comment: ""))
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                }
                .padding(.top, 12)
            }
            .padding(.top, 60)
        }
        .onAppear {
            countdown = 10
            countdownTask = Task { @MainActor in
                for _ in 0..<10 {
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    if Task.isCancelled { break }
                    if countdown > 0 { countdown -= 1 }
                }
            }
        }
        .onDisappear {
            countdownTask?.cancel()
        }
    }
}
