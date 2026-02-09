import SwiftUI

struct SettingsView: View {
    enum PasscodeSheetMode: Identifiable {
        case set
        case change

        var id: String { self == .set ? "set" : "change" }
    }

    @ObservedObject var vaultStore: VaultStore
    @AppStorage("aiEnabled") private var aiEnabled = false
    @AppStorage("faceIdEnabled") private var faceIdEnabled = true
    @AppStorage("reminderEnabled") private var reminderEnabled = false
    @AppStorage("reminderWeekday") private var reminderWeekday = 2
    @AppStorage("reminderHour") private var reminderHour = 19
    @AppStorage("reminderMinute") private var reminderMinute = 0
    @AppStorage("appearanceMode") private var appearanceMode = "system"
    @AppStorage("didOnboard") private var didOnboard = false
    @State private var passcodeMode: PasscodeSheetMode?
    @State private var showWipeConfirm = false
    @State private var hasPasscode = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    settingsSection("Security") {
                        settingsToggleRow(
                            icon: "faceid",
                            title: "Use Face ID / Touch ID",
                            subtitle: "Unlock with biometrics",
                            isOn: $faceIdEnabled
                        )
                        settingsActionRow(
                            icon: "number.square",
                            title: hasPasscode ? "Change Passcode" : "Set Passcode",
                            subtitle: "Recover access if biometrics fail"
                        ) {
                            passcodeMode = hasPasscode ? .change : .set
                        }
                    }

                    settingsSection("Privacy") {
                        settingsToggleRow(
                            icon: "sparkles",
                            title: "Enable Local AI",
                            subtitle: "Organize images on device",
                            isOn: $aiEnabled
                        )
                        settingsNavigationRow(
                            icon: "hand.raised.fill",
                            title: "Privacy Policy",
                            subtitle: "Learn how data is handled"
                        ) {
                            PrivacyView()
                        }
                    }

                    settingsSection("Appearance") {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 12) {
                                settingsIcon("paintbrush.fill")
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("App Theme")
                                        .font(AppTheme.fonts.body)
                                    Text("System, Light, or Dark")
                                        .font(AppTheme.fonts.caption)
                                        .foregroundStyle(AppTheme.colors.secondaryText)
                                }
                                Spacer()
                            }
                            Picker("Theme", selection: $appearanceMode) {
                                Text("System").tag("system")
                                Text("Light").tag("light")
                                Text("Dark").tag("dark")
                            }
                            .pickerStyle(.segmented)
                        }
                    }

                    settingsSection("Notifications") {
                        settingsToggleRow(
                            icon: "bell.badge.fill",
                            title: "Weekly Reminder",
                            subtitle: "Keep your vault updated",
                            isOn: $reminderEnabled
                        )
                        .onChange(of: reminderEnabled) { _, isOn in
                            if isOn {
                                ReminderManager.shared.scheduleWeeklyReminder(
                                    weekday: reminderWeekday,
                                    hour: reminderHour,
                                    minute: reminderMinute
                                )
                            } else {
                                ReminderManager.shared.cancelReminder()
                            }
                        }
                        DatePicker(
                            "Reminder Time",
                            selection: Binding(
                                get: {
                                    DateComponents(calendar: .current, hour: reminderHour, minute: reminderMinute).date ?? Date()
                                },
                                set: { date in
                                    let components = Calendar.current.dateComponents([.hour, .minute], from: date)
                                    reminderHour = components.hour ?? 19
                                    reminderMinute = components.minute ?? 0
                                    if reminderEnabled {
                                        ReminderManager.shared.scheduleWeeklyReminder(
                                            weekday: reminderWeekday,
                                            hour: reminderHour,
                                            minute: reminderMinute
                                        )
                                    }
                                }
                            ),
                            displayedComponents: .hourAndMinute
                        )
                        Picker("Weekday", selection: $reminderWeekday) {
                            Text("Sunday").tag(1)
                            Text("Monday").tag(2)
                            Text("Tuesday").tag(3)
                            Text("Wednesday").tag(4)
                            Text("Thursday").tag(5)
                            Text("Friday").tag(6)
                            Text("Saturday").tag(7)
                        }
                    }

                    settingsSection("Storage") {
                        storageSummary
                        settingsNavigationRow(
                            icon: "chart.pie.fill",
                            title: "View More",
                            subtitle: "Full storage dashboard"
                        ) {
                            StorageDashboard(vaultStore: vaultStore)
                        }
                    }

                    settingsSection("Data") {
                        settingsDestructiveRow(
                            icon: "trash.fill",
                            title: "Erase All Data",
                            subtitle: "Removes files and passcode"
                        ) {
                            showWipeConfirm = true
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .navigationTitle("Settings")
            .background(AppTheme.gradients.background.ignoresSafeArea())
        }
        .sheet(item: $passcodeMode) { mode in
            PasscodeSheet(mode: mode) {
                hasPasscode = KeyManager.shared.hasPasscode()
            }
        }
        .alert("Erase all data?", isPresented: $showWipeConfirm) {
            Button("Erase", role: .destructive) {
                vaultStore.wipeAllData()
                didOnboard = false
                hasPasscode = KeyManager.shared.hasPasscode()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will delete all vault files and the app passcode. You will need to set a new passcode.")
        }
        .onAppear {
            hasPasscode = KeyManager.shared.hasPasscode()
        }
    }

    private var storageSummary: some View {
        let storage = vaultStore.deviceStorage()
        let total = vaultStore.totalAppStorageBytes()
        let count = vaultStore.items.count
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                settingsIcon("lock.shield.fill")
                VStack(alignment: .leading, spacing: 4) {
                    Text("Vault Storage")
                        .font(AppTheme.fonts.body)
                    Text("\(count) files • \(ByteCountFormatter.string(fromByteCount: total, countStyle: .file))")
                        .font(AppTheme.fonts.caption)
                        .foregroundStyle(AppTheme.colors.secondaryText)
                }
                Spacer()
            }
            ProgressView(value: progress(total: storage.total, used: total))
                .tint(AppTheme.colors.accent)
            Text(storageText(storage))
                .font(AppTheme.fonts.caption)
                .foregroundStyle(AppTheme.colors.secondaryText)
        }
    }

    private func progress(total: Int64, used: Int64) -> Double {
        guard total > 0 else { return 0 }
        return Double(used) / Double(total)
    }

    private func storageText(_ storage: (total: Int64, available: Int64)) -> String {
        let totalText = ByteCountFormatter.string(fromByteCount: storage.total, countStyle: .file)
        let freeText = ByteCountFormatter.string(fromByteCount: storage.available, countStyle: .file)
        return "\(freeText) free of \(totalText)"
    }

    private func settingsSection(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(AppTheme.fonts.caption)
                .foregroundStyle(AppTheme.colors.secondaryText)
                .padding(.horizontal, 8)
            VStack(spacing: 0) {
                content()
            }
            .padding(12)
            .background(AppTheme.colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(AppTheme.colors.cardBorder, lineWidth: 1)
            )
        }
    }

    private func settingsIcon(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(AppTheme.colors.accent)
            .frame(width: 28, height: 28)
            .background(AppTheme.colors.surface.opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func settingsToggleRow(icon: String, title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            settingsIcon(icon)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(AppTheme.fonts.body)
                Text(subtitle)
                    .font(AppTheme.fonts.caption)
                    .foregroundStyle(AppTheme.colors.secondaryText)
            }
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
        }
        .padding(.vertical, 8)
    }

    private func settingsActionRow(icon: String, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button {
            HapticFeedback.play(.light)
            action()
        } label: {
            HStack(spacing: 12) {
                settingsIcon(icon)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(AppTheme.fonts.body)
                        .foregroundStyle(AppTheme.colors.primaryText)
                    Text(subtitle)
                        .font(AppTheme.fonts.caption)
                        .foregroundStyle(AppTheme.colors.secondaryText)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(AppTheme.colors.secondaryText)
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(InteractiveButtonStyle(hapticStyle: .light))
    }

    private func settingsNavigationRow<Destination: View>(
        icon: String,
        title: String,
        subtitle: String,
        destination: @escaping () -> Destination
    ) -> some View {
        NavigationLink(destination: destination()) {
            HStack(spacing: 12) {
                settingsIcon(icon)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(AppTheme.fonts.body)
                    Text(subtitle)
                        .font(AppTheme.fonts.caption)
                        .foregroundStyle(AppTheme.colors.secondaryText)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(AppTheme.colors.secondaryText)
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }

    private func settingsDestructiveRow(icon: String, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button {
            HapticFeedback.play(.warning)
            action()
        } label: {
            HStack(spacing: 12) {
                settingsIcon(icon)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(AppTheme.fonts.body)
                        .foregroundStyle(.red)
                    Text(subtitle)
                        .font(AppTheme.fonts.caption)
                        .foregroundStyle(AppTheme.colors.secondaryText)
                }
                Spacer()
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(InteractiveButtonStyle(hapticStyle: .warning))
    }
}

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
        _step = State(initialValue: mode == .change ? .current : .new)
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
