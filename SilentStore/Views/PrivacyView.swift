import SwiftUI

struct PrivacyView: View {
    private var policyText: String {
        if let url = Bundle.main.url(forResource: "PRIVACY", withExtension: "txt"),
           let text = try? String(contentsOf: url) {
            return text
        }
        return "SilentStore keeps your files encrypted on-device. No data is uploaded or shared."
    }

    var body: some View {
        ScrollView {
            Text(policyText)
                .font(AppTheme.fonts.body)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("Privacy Policy")
        .background(AppTheme.gradients.background.ignoresSafeArea())
    }
}
