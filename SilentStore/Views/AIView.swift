import SwiftUI

struct AIView: View {
    @ObservedObject var vaultStore: VaultStore
    @State private var messages: [AIMessage] = []
    @State private var inputText = ""
    @State private var isProcessing = false
    @State private var aiInsights: AIInsights?
    @State private var isLoadingInsights = false
    @AppStorage("aiEnabled") private var aiEnabled = false
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // AI Insights Summary
                if let insights = aiInsights {
                    insightsSection(insights: insights)
                }
                
                // Chat Section
                chatSection
            }
            .padding(.top, 8)
        }
        .background(AppTheme.gradients.background.ignoresSafeArea())
        .navigationTitle("AI Assistant")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    Task {
                        await loadInsights()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .onAppear {
            if aiEnabled {
                Task {
                    await loadInsights()
                    if messages.isEmpty {
                        addWelcomeMessage()
                    }
                }
            } else {
                addAIDisabledMessage()
            }
        }
    }
    
    // MARK: - Insights Section
    
    private func insightsSection(insights: AIInsights) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppTheme.gradients.accent)
                
                Text(NSLocalizedString("Your Vault Insights", comment: ""))
                    .font(AppTheme.fonts.subtitle)
                    .foregroundStyle(AppTheme.colors.primaryText)
            }
            .padding(.horizontal, 16)
            
            VStack(spacing: 12) {
                // Most Opened Files
                if !insights.mostOpenedFiles.isEmpty {
                    InsightCard(
                        icon: "star.fill",
                        title: NSLocalizedString("Most Opened Files", comment: ""),
                        description: String(format: NSLocalizedString("%d files you open frequently", comment: ""), insights.mostOpenedFiles.count),
                        items: insights.mostOpenedFiles,
                        vaultStore: vaultStore
                    )
                }
                if let recentFile = insights.lastOpenedFile {
                    InsightCard(
                        icon: "clock.fill",
                        title: NSLocalizedString("Last Opened", comment: ""),
                        description: recentFile.originalName,
                        items: [recentFile],
                        vaultStore: vaultStore
                    )
                }
                
                // Storage Recommendations
                if !insights.cleanupRecommendations.isEmpty {
                    CleanupRecommendationsCard(
                        recommendations: insights.cleanupRecommendations,
                        vaultStore: vaultStore
                    )
                }
            }
            .padding(.horizontal, 16)
        }
    }
    
    // MARK: - Chat Section
    
    private var chatSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "message.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppTheme.gradients.accent)
                
                Text(NSLocalizedString("Chat with AI", comment: ""))
                    .font(AppTheme.fonts.subtitle)
                    .foregroundStyle(AppTheme.colors.primaryText)
            }
            .padding(.horizontal, 16)
            
            if !aiEnabled {
                VStack(spacing: 12) {
                    Image(systemName: "sparkles.square.filled.on.square")
                        .font(.system(size: 48))
                        .foregroundStyle(AppTheme.colors.secondaryText.opacity(0.5))
                    
                    Text(NSLocalizedString("Enable AI in Settings", comment: ""))
                        .font(AppTheme.fonts.body)
                        .foregroundStyle(AppTheme.colors.primaryText)
                    
                    Text(NSLocalizedString("Turn on Local AI to chat and get insights", comment: ""))
                        .font(AppTheme.fonts.caption)
                        .foregroundStyle(AppTheme.colors.secondaryText)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                // Messages
                ScrollViewReader { proxy in
                    VStack(spacing: 12) {
                        ForEach(messages) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                        }
                        
                        if isProcessing {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text(NSLocalizedString("AI is thinking...", comment: ""))
                                    .font(AppTheme.fonts.caption)
                                    .foregroundStyle(AppTheme.colors.secondaryText)
                            }
                            .padding()
                            .id("processing")
                        }
                    }
                    .padding(.horizontal, 16)
                    .onChange(of: messages.count) { _, _ in
                        if let lastMessage = messages.last {
                            withAnimation {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                    .onChange(of: isProcessing) { _, newValue in
                        if newValue {
                            withAnimation {
                                proxy.scrollTo("processing", anchor: .bottom)
                            }
                        }
                    }
                }
                
                quickActionChips
                
                HStack(spacing: 12) {
                    TextField(NSLocalizedString("Ask AI about your files...", comment: ""), text: $inputText, axis: .vertical)
                        .textFieldStyle(.plain)
                        .focused($isTextFieldFocused)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(AppTheme.colors.cardBackground)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(isTextFieldFocused ? AppTheme.colors.accent : AppTheme.colors.cardBorder, lineWidth: isTextFieldFocused ? 2 : 1.5)
                                )
                        )
                        .lineLimit(1...5)
                        .onSubmit {
                            sendMessage()
                        }
                    
                    Button {
                        sendMessage()
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(inputText.isEmpty ? AppTheme.colors.secondaryText.opacity(0.3) : AppTheme.colors.accent)
                    }
                    .disabled(inputText.isEmpty || isProcessing)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
        }
        .onTapGesture {
            // Hide keyboard when tapping outside
            isTextFieldFocused = false
        }
    }
    
    private var quickActionChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                QuickChip(title: NSLocalizedString("Storage", comment: "")) { sendPredefined(NSLocalizedString("How much space am I using?", comment: "")) }
                QuickChip(title: NSLocalizedString("Duplicates", comment: "")) { sendPredefined(NSLocalizedString("Show duplicate files", comment: "")) }
                QuickChip(title: NSLocalizedString("Large files", comment: "")) { sendPredefined(NSLocalizedString("What are my largest files?", comment: "")) }
                QuickChip(title: NSLocalizedString("Recent", comment: "")) { sendPredefined(NSLocalizedString("Last opened files", comment: "")) }
                QuickChip(title: NSLocalizedString("Most used", comment: "")) { sendPredefined(NSLocalizedString("Most opened files", comment: "")) }
            }
            .padding(.horizontal, 16)
        }
        .padding(.bottom, 12)
    }
    
    private func sendPredefined(_ text: String) {
        guard !text.isEmpty, !isProcessing else { return }
        inputText = text
        sendMessage()
    }
    
    private func addWelcomeMessage() {
        let welcomeText = NSLocalizedString("Hi! I’m your vault assistant. Ask in English or Arabic:\n• \"How much space?\" / \"كم مساحتي؟\"\n• \"Find photos\" / \"ابحث عن صور\"\n• \"Duplicate files\" / \"ملفات مكررة\"\n• \"Rename X to Y\"\n\nTap a chip below or type your question.", comment: "")
        messages.append(AIMessage(content: welcomeText, isUser: false))
    }
    
    private func addAIDisabledMessage() {
        let message = NSLocalizedString("AI is currently disabled. Enable it in Settings to chat and get insights about your files.", comment: "")
        messages.append(AIMessage(content: message, isUser: false))
    }
    
    private func sendMessage() {
        guard !inputText.isEmpty, !isProcessing else { return }
        
        // Hide keyboard
        isTextFieldFocused = false
        
        let userMessage = inputText
        inputText = ""
        isProcessing = true
        
        // Add user message
        messages.append(AIMessage(content: userMessage, isUser: true))
        
        // Process AI response
        Task {
            let response = await processAIQuery(userMessage)
            await MainActor.run {
                messages.append(AIMessage(content: response, isUser: false))
                isProcessing = false
            }
        }
    }
    
    private func processAIQuery(_ query: String) async -> String {
        // Use advanced AI Chat Manager for intelligent responses
        return await AIChatManager.shared.processQuery(query, vaultStore: vaultStore)
    }
    
    private func loadInsights() async {
        guard aiEnabled else { return }
        isLoadingInsights = true
        defer { isLoadingInsights = false }
        
        let mostOpened = vaultStore.items
            .sorted { item1, item2 in
                let count1 = UserDefaults.standard.integer(forKey: "openCount_\(item1.id.uuidString)")
                let count2 = UserDefaults.standard.integer(forKey: "openCount_\(item2.id.uuidString)")
                return count1 > count2
            }
            .prefix(5)
            .map { $0 }
        
        let lastOpened = vaultStore.recentOpenedItems().first
        
        let duplicates = vaultStore.findExactDuplicates()
        let largeFiles = vaultStore.items.filter { $0.size > 50_000_000 }.sorted { $0.size > $1.size }.prefix(5)
        
        var cleanupRecommendations: [CleanupRecommendation] = []
        
        if !duplicates.isEmpty {
            let totalSize = duplicates.flatMap { $0 }.dropFirst().reduce(0) { $0 + $1.size }
            cleanupRecommendations.append(.duplicates(count: duplicates.count, estimatedSavings: totalSize))
        }
        
        if !largeFiles.isEmpty {
            let totalSize = largeFiles.reduce(0) { $0 + $1.size }
            cleanupRecommendations.append(.largeFiles(count: largeFiles.count, totalSize: totalSize))
        }
        
        await MainActor.run {
            aiInsights = AIInsights(
                mostOpenedFiles: Array(mostOpened),
                lastOpenedFile: lastOpened,
                cleanupRecommendations: cleanupRecommendations
            )
        }
    }
}

// MARK: - Models

struct AIMessage: Identifiable {
    let id = UUID()
    let content: String
    let isUser: Bool
    let timestamp = Date()
}

struct AIInsights {
    let mostOpenedFiles: [VaultItem]
    let lastOpenedFile: VaultItem?
    let cleanupRecommendations: [CleanupRecommendation]
}

enum CleanupRecommendation: Identifiable {
    case duplicates(count: Int, estimatedSavings: Int64)
    case largeFiles(count: Int, totalSize: Int64)
    
    var id: String {
        switch self {
        case .duplicates: return "duplicates"
        case .largeFiles: return "largeFiles"
        }
    }
    
    var title: String {
        switch self {
        case .duplicates(let count, _):
            return String(format: NSLocalizedString("%d Duplicate Groups", comment: ""), count)
        case .largeFiles(let count, _):
            return String(format: NSLocalizedString("%d Large Files", comment: ""), count)
        }
    }
    
    var description: String {
        switch self {
        case .duplicates(_, let savings):
            return String(format: NSLocalizedString("Save %@ by removing duplicates", comment: ""), ByteCountFormatter.string(fromByteCount: savings, countStyle: .file))
        case .largeFiles(_, let totalSize):
            return String(format: NSLocalizedString("Total size: %@", comment: ""), ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file))
        }
    }
}

// MARK: - Components

private struct QuickChip: View {
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            HapticFeedback.play(.light)
            action()
        }) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppTheme.colors.accent)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(AppTheme.colors.accent.opacity(0.15))
                )
        }
        .buttonStyle(.plain)
    }
}

private struct MessageBubble: View {
    let message: AIMessage
    
    var body: some View {
        HStack {
            if message.isUser {
                Spacer()
            }
            
            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(message.isUser ? .white : AppTheme.colors.primaryText)
                    .padding(12)
                    .background(
                        Group {
                            if message.isUser {
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(AppTheme.gradients.accent)
                            } else {
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(AppTheme.colors.cardBackground)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                                            .stroke(AppTheme.colors.cardBorder, lineWidth: 1.5)
                                    )
                            }
                        }
                    )
            }
            .frame(maxWidth: UIScreen.main.bounds.width * 0.75, alignment: message.isUser ? .trailing : .leading)
            
            if !message.isUser {
                Spacer()
            }
        }
    }
}

private struct InsightCard: View {
    let icon: String
    let title: String
    let description: String
    let items: [VaultItem]
    @ObservedObject var vaultStore: VaultStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(AppTheme.gradients.accent)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(AppTheme.colors.accent.opacity(0.15))
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppTheme.colors.primaryText)
                    
                    Text(description)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(AppTheme.colors.secondaryText)
                        .lineLimit(2)
                }
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(items.prefix(5)) { item in
                        NavigationLink {
                            FileViewer(item: item)
                                .environmentObject(vaultStore)
                        } label: {
                            VaultThumbnailView(item: item, size: 60)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppTheme.colors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(AppTheme.colors.cardBorder, lineWidth: 1.5)
                )
        )
    }
}

private struct CleanupRecommendationsCard: View {
    let recommendations: [CleanupRecommendation]
    @ObservedObject var vaultStore: VaultStore
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "sparkles")
                    .font(.system(size: 18))
                    .foregroundStyle(AppTheme.gradients.accent)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(AppTheme.colors.accent.opacity(0.15))
                    )
                
                Text(NSLocalizedString("Cleanup Recommendations", comment: ""))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppTheme.colors.primaryText)
            }
            
            VStack(spacing: 10) {
                ForEach(recommendations) { recommendation in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(recommendation.title)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(AppTheme.colors.primaryText)
                            
                            Text(recommendation.description)
                                .font(.system(size: 12, weight: .regular))
                                .foregroundStyle(AppTheme.colors.secondaryText)
                        }
                        
                        Spacer()
                        
                        NavigationLink {
                            StorageDashboard(vaultStore: vaultStore)
                        } label: {
                            Text(NSLocalizedString("View", comment: ""))
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(AppTheme.colors.accent)
                        }
                    }
                    .padding(.vertical, 4)
                    
                    if recommendation.id != recommendations.last?.id {
                        Divider()
                            .background(AppTheme.colors.cardBorder)
                    }
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppTheme.colors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    AppTheme.colors.accent.opacity(0.3),
                                    AppTheme.colors.accent.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
        )
    }
}
