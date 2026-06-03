import UIKit

// MARK: - HapticFeedbackManager

/// Centralised haptic feedback manager with lazy-initialized generators.
/// Thread-safe singleton for use from the main thread.
@MainActor
final class HapticFeedbackManager {

    static let shared = HapticFeedbackManager()
    private init() { prepare() }

    // MARK: - Generators

    private let lightImpact   = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpact  = UIImpactFeedbackGenerator(style: .medium)
    private let heavyImpact   = UIImpactFeedbackGenerator(style: .heavy)
    private let selection     = UISelectionFeedbackGenerator()
    private let notification  = UINotificationFeedbackGenerator()

    private func prepare() {
        lightImpact.prepare()
        mediumImpact.prepare()
        selection.prepare()
        notification.prepare()
    }

    // MARK: - Public API

    func impactLight()         { lightImpact.impactOccurred() }
    func impactMedium()        { mediumImpact.impactOccurred() }
    func impactHeavy()         { heavyImpact.impactOccurred() }
    func selectionChanged()    { selection.selectionChanged() }
    func notificationSuccess() { notification.notificationOccurred(.success) }
    func notificationWarning() { notification.notificationOccurred(.warning) }
    func notificationError()   { notification.notificationOccurred(.error) }
}
