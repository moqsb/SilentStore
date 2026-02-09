import SwiftUI

struct TermsOfUseView: View {
    private var termsText: String {
        if let url = Bundle.main.url(forResource: "TERMS", withExtension: "txt"),
           let text = try? String(contentsOf: url, encoding: .utf8) {
            return text
        }
        return NSLocalizedString("Terms of use apply. Use the app responsibly and keep your passcode safe.", comment: "")
    }

    var body: some View {
        ScrollView {
            Text(termsText)
                .font(AppTheme.fonts.body)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle(NSLocalizedString("Terms of Use", comment: ""))
        .background(AppTheme.gradients.background.ignoresSafeArea())
    }
}
