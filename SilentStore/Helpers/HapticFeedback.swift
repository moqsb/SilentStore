import UIKit

enum HapticFeedback {
    case light
    case medium
    case heavy
    case success
    case warning
    case error
    case selection
    
    // Cached generators for better performance and smoother feedback
    private static var impactLightGenerator: UIImpactFeedbackGenerator?
    private static var impactMediumGenerator: UIImpactFeedbackGenerator?
    private static var impactHeavyGenerator: UIImpactFeedbackGenerator?
    private static var notificationGenerator: UINotificationFeedbackGenerator?
    private static var selectionGenerator: UISelectionFeedbackGenerator?
    
    static func impact(_ style: HapticFeedback) {
        // Prepare generators in advance for smoother feedback
        switch style {
        case .light:
            if impactLightGenerator == nil {
                impactLightGenerator = UIImpactFeedbackGenerator(style: .light)
                impactLightGenerator?.prepare()
            }
            impactLightGenerator?.impactOccurred()
            // Prepare for next use
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                impactLightGenerator?.prepare()
            }
            
        case .medium:
            if impactMediumGenerator == nil {
                impactMediumGenerator = UIImpactFeedbackGenerator(style: .medium)
                impactMediumGenerator?.prepare()
            }
            impactMediumGenerator?.impactOccurred()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                impactMediumGenerator?.prepare()
            }
            
        case .heavy:
            if impactHeavyGenerator == nil {
                impactHeavyGenerator = UIImpactFeedbackGenerator(style: .heavy)
                impactHeavyGenerator?.prepare()
            }
            impactHeavyGenerator?.impactOccurred()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                impactHeavyGenerator?.prepare()
            }
            
        case .success:
            if notificationGenerator == nil {
                notificationGenerator = UINotificationFeedbackGenerator()
                notificationGenerator?.prepare()
            }
            notificationGenerator?.notificationOccurred(.success)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                notificationGenerator?.prepare()
            }
            
        case .warning:
            if notificationGenerator == nil {
                notificationGenerator = UINotificationFeedbackGenerator()
                notificationGenerator?.prepare()
            }
            notificationGenerator?.notificationOccurred(.warning)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                notificationGenerator?.prepare()
            }
            
        case .error:
            if notificationGenerator == nil {
                notificationGenerator = UINotificationFeedbackGenerator()
                notificationGenerator?.prepare()
            }
            notificationGenerator?.notificationOccurred(.error)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                notificationGenerator?.prepare()
            }
            
        case .selection:
            if selectionGenerator == nil {
                selectionGenerator = UISelectionFeedbackGenerator()
                selectionGenerator?.prepare()
            }
            selectionGenerator?.selectionChanged()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                selectionGenerator?.prepare()
            }
        }
    }
    
    static func play(_ style: HapticFeedback) {
        impact(style)
    }
    
    // Prepare all generators on app launch for instant feedback
    static func prepareAll() {
        impactLightGenerator = UIImpactFeedbackGenerator(style: .light)
        impactMediumGenerator = UIImpactFeedbackGenerator(style: .medium)
        impactHeavyGenerator = UIImpactFeedbackGenerator(style: .heavy)
        notificationGenerator = UINotificationFeedbackGenerator()
        selectionGenerator = UISelectionFeedbackGenerator()
        
        impactLightGenerator?.prepare()
        impactMediumGenerator?.prepare()
        impactHeavyGenerator?.prepare()
        notificationGenerator?.prepare()
        selectionGenerator?.prepare()
    }
}
