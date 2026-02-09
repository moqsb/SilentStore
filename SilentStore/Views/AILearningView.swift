import SwiftUI

struct AILearningView: View {
    @State private var preferredHour: Int = 0
    @State private var preferredFileTypes: [String] = []
    @State private var learnedCategories: [String: Int] = [:]
    @State private var searchKeywords: [String: Int] = [:]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Preferred Hour
                if preferredHour > 0 {
                    learningCard(
                        icon: "clock.fill",
                        title: NSLocalizedString("Preferred Usage Time", comment: ""),
                        content: "\(NSLocalizedString("Most active around", comment: "")) \(preferredHour):00"
                    )
                }
                
                // Preferred File Types
                if !preferredFileTypes.isEmpty {
                    learningCard(
                        icon: "doc.fill",
                        title: NSLocalizedString("Preferred File Types", comment: ""),
                        content: preferredFileTypes.prefix(5).joined(separator: ", ")
                    )
                }
                
                // Learned Categories
                if !learnedCategories.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "folder.fill")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(AppTheme.gradients.accent)
                            Text(NSLocalizedString("Learned Categories", comment: ""))
                                .font(AppTheme.fonts.subtitle)
                            Spacer()
                        }
                        
                        ForEach(Array(learnedCategories.sorted { $0.value > $1.value }.prefix(10)), id: \.key) { category, count in
                            HStack {
                                Text(category)
                                    .font(AppTheme.fonts.body)
                                Spacer()
                                Text("\(count) \(NSLocalizedString("files", comment: ""))")
                                    .font(AppTheme.fonts.caption)
                                    .foregroundStyle(AppTheme.colors.secondaryText)
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(AppTheme.colors.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .padding()
                    .background(AppTheme.colors.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(AppTheme.colors.cardBorder, lineWidth: 1.5)
                    )
                }
                
                // Search Keywords
                if !searchKeywords.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(AppTheme.gradients.accent)
                            Text(NSLocalizedString("Search Patterns", comment: ""))
                                .font(AppTheme.fonts.subtitle)
                            Spacer()
                        }
                        
                        ForEach(Array(searchKeywords.sorted { $0.value > $1.value }.prefix(10)), id: \.key) { keyword, count in
                            HStack {
                                Text(keyword)
                                    .font(AppTheme.fonts.body)
                                Spacer()
                                Text("\(count) \(NSLocalizedString("times", comment: ""))")
                                    .font(AppTheme.fonts.caption)
                                    .foregroundStyle(AppTheme.colors.secondaryText)
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(AppTheme.colors.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .padding()
                    .background(AppTheme.colors.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(AppTheme.colors.cardBorder, lineWidth: 1.5)
                    )
                }
                
                if preferredHour == 0 && preferredFileTypes.isEmpty && learnedCategories.isEmpty && searchKeywords.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 48, weight: .light))
                            .foregroundStyle(AppTheme.colors.secondaryText.opacity(0.5))
                        Text(NSLocalizedString("No Learning Data Yet", comment: ""))
                            .font(AppTheme.fonts.subtitle)
                            .foregroundStyle(AppTheme.colors.primaryText)
                        Text(NSLocalizedString("AI will learn from your usage patterns as you use the app", comment: ""))
                            .font(AppTheme.fonts.caption)
                            .foregroundStyle(AppTheme.colors.secondaryText)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
                }
            }
            .padding()
        }
        .background(AppTheme.gradients.background.ignoresSafeArea())
        .navigationTitle(NSLocalizedString("AI Learning", comment: ""))
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            loadLearningData()
        }
    }
    
    private func learningCard(icon: String, title: String, content: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(AppTheme.gradients.accent)
                .frame(width: 40, height: 40)
                .background(
                    Circle()
                        .fill(AppTheme.colors.accent.opacity(0.15))
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(AppTheme.fonts.body)
                    .foregroundStyle(AppTheme.colors.primaryText)
                Text(content)
                    .font(AppTheme.fonts.caption)
                    .foregroundStyle(AppTheme.colors.secondaryText)
            }
            
            Spacer()
        }
        .padding()
        .background(AppTheme.colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(AppTheme.colors.cardBorder, lineWidth: 1.5)
        )
    }
    
    private func loadLearningData() {
        preferredHour = AILearningManager.shared.getPreferredHour()
        preferredFileTypes = AILearningManager.shared.getPreferredFileTypes()
        
        // Load learned categories
        if let categoriesData = UserDefaults.standard.dictionary(forKey: "ai_learned_categories") as? [String: Int] {
            learnedCategories = categoriesData
        }
        
        // Load search keywords
        if let keywordsData = UserDefaults.standard.dictionary(forKey: "ai_search_keywords") as? [String: Int] {
            searchKeywords = keywordsData
        }
    }
}
