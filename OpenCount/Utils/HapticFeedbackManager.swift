import UIKit

// MARK: - HapticFeedbackManager

/// Centralized haptic feedback manager for consistent tactile feedback across the app.
/// Provides convenience methods for three feedback types:
/// - Impact: Physical feedback for marker placement, UI interactions
/// - Notification: Alerts for success, warning, error states
/// - Selection: Subtle feedback for UI element selection
final class HapticFeedbackManager {

    static let shared = HapticFeedbackManager()

    private init() {}

    // MARK: - Impact Feedback

    /// Light impact feedback (e.g., selection, light taps)
    func impactLight() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }

    /// Medium impact feedback (e.g., marker placement, button press)
    func impactMedium() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }

    /// Heavy impact feedback (e.g., deletion, significant action)
    func impactHeavy() {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
    }

    /// Rigid impact (e.g., strong confirmation)
    func impactRigid() {
        if #available(iOS 13, *) {
            let generator = UIImpactFeedbackGenerator(style: .rigid)
            generator.impactOccurred()
        }
    }

    // MARK: - Notification Feedback

    /// Success notification (positive action completion)
    func notificationSuccess() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    /// Warning notification (alert or caution)
    func notificationWarning() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)
    }

    /// Error notification (failed action or error state)
    func notificationError() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
    }

    // MARK: - Selection Feedback

    /// Selection feedback (UI element selection, segmented control changes)
    func selectionChanged() {
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }

    // MARK: - Composite Feedback Patterns

    /// Success sequence: medium impact + success notification
    func successSequence() {
        impactMedium()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            self.notificationSuccess()
        }
    }

    /// Error sequence: heavy impact + error notification
    func errorSequence() {
        impactHeavy()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            self.notificationError()
        }
    }

    /// Warning sequence: medium impact + warning notification
    func warningSequence() {
        impactMedium()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            self.notificationWarning()
        }
    }

    /// Double tap pattern: two rapid light impacts
    func doubleTap() {
        impactLight()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.impactLight()
        }
    }
}
