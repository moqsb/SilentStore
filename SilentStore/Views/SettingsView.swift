import SwiftUI

struct SettingsView: View {
    @ObservedObject var vaultStore: VaultStore
    @AppStorage("aiEnabled") private var aiEnabled = false
    @AppStorage("faceIdEnabled") private var faceIdEnabled = true
    @AppStorage("reminderEnabled") private var reminderEnabled = false
    @AppStorage("reminderWeekday") private var reminderWeekday = 2
    @AppStorage("reminderHour") private var reminderHour = 19
    @AppStorage("reminderMinute") private var reminderMinute = 0
    @State private var showRecovery = false
    @State private var showRecoveryInput = false
    @State private var recoveryKey = ""

    var body: some View {
        NavigationStack {
            List {
                Section("Security") {
                    Toggle("Use Face ID / Touch ID", isOn: $faceIdEnabled)
                    Toggle("Enable Local AI", isOn: $aiEnabled)
                    Button("Create Recovery Key") {
                        showRecovery = true
                    }
                    Button("Recover with Key") {
                        showRecoveryInput = true
                    }
                }

                Section("Reminders") {
                    Toggle("Weekly Reminder", isOn: $reminderEnabled)
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

                Section("Storage") {
                    NavigationLink("Storage Dashboard") {
                        StorageDashboard(vaultStore: vaultStore)
                    }
                    NavigationLink("Privacy Policy") {
                        PrivacyView()
                    }
                }
            }
            .navigationTitle("Settings")
            .scrollContentBackground(.hidden)
            .background(AppTheme.gradients.background.ignoresSafeArea())
        }
        .sheet(isPresented: $showRecovery) {
            RecoveryModal()
        }
        .sheet(isPresented: $showRecoveryInput) {
            RecoveryInputModal(recoveryKey: $recoveryKey)
        }
    }
}

private struct RecoveryModal: View {
    @State private var recoveryKey = ""
    @State private var isLoading = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("Recovery Key")
                    .font(AppTheme.fonts.title)
                Text("Save this key in a safe place. It will only be shown once.")
                    .font(AppTheme.fonts.caption)
                    .foregroundStyle(AppTheme.colors.secondaryText)
                    .multilineTextAlignment(.center)
                if isLoading {
                    ProgressView()
                } else {
                    Text(recoveryKey.isEmpty ? "Tap generate to create a key." : recoveryKey)
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(AppTheme.colors.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .padding(.horizontal)
                }
                HStack {
                    Button("Generate") {
                        Task { await generate() }
                    }
                    .buttonStyle(AppTheme.buttons.primary)
                    if !recoveryKey.isEmpty {
                        ShareLink(item: recoveryKey) {
                            Text("Share")
                        }
                        .buttonStyle(AppTheme.buttons.secondary)
                    }
                }
                Spacer()
            }
            .padding(.top, 24)
            .navigationTitle("Recovery Key")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func generate() async {
        isLoading = true
        do {
            recoveryKey = try await KeyManager.shared.createRecoveryKey()
        } catch {
            recoveryKey = "Failed to generate key."
        }
        isLoading = false
    }
}

private struct RecoveryInputModal: View {
    @Binding var recoveryKey: String
    @Environment(\.dismiss) private var dismiss
    @State private var isRecovering = false
    @State private var statusMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("Enter Recovery Key")
                    .font(AppTheme.fonts.title)
                TextField("Base64 key", text: $recoveryKey)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)
                if let statusMessage {
                    Text(statusMessage)
                        .font(AppTheme.fonts.caption)
                        .foregroundStyle(AppTheme.colors.secondaryText)
                }
                Button("Recover") {
                    Task { await recover() }
                }
                .buttonStyle(AppTheme.buttons.primary)
                .disabled(isRecovering || recoveryKey.isEmpty)
                Spacer()
            }
            .padding(.top, 24)
            .navigationTitle("Recovery")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func recover() async {
        isRecovering = true
        do {
            try await KeyManager.shared.recoverMasterKey(from: recoveryKey)
            statusMessage = "Recovery successful."
        } catch {
            statusMessage = "Recovery failed. Check the key."
        }
        isRecovering = false
    }
}
