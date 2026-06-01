import SwiftUI
import Combine

// MARK: - CoachMarkKey

/// Identifies each feature that has an associated coach mark.
///
/// Requirements: 29.2, 29.6
enum CoachMarkKey: String, CaseIterable, Codable {
    case aiCounting
    case liveCamera
    case arCounting
    case batchProcessing
    case regionDrawing
    case exportSheet
    case heatmap
    case collaboration
}

// MARK: - OnboardingCoordinator

/// Manages the first-run onboarding gate and per-feature coach mark state.
///
/// - `hasSeenOnboarding` is persisted via `@AppStorage` and gates the full-screen
///   onboarding flow shown in `ContentView`.
/// - `seenCoachMarks` is a `Set<CoachMarkKey>` serialised as JSON in `AppStorage`.
///   Once a key is inserted the corresponding coach mark is never shown again,
///   unless the user resets via `resetOnboarding()`.
///
/// Requirements: 29.1–29.7
final class OnboardingCoordinator: ObservableObject {

    // MARK: - Onboarding gate (Req 29.1, 29.3)

    /// `false` on first launch; set to `true` after the user completes or skips
    /// the onboarding flow.  Resetting to `false` re-triggers the flow.
    @AppStorage("hasSeenOnboarding") var hasSeenOnboarding: Bool = false

    // MARK: - Coach mark persistence (Req 29.2, 29.6, 29.7)

    /// Raw JSON data backing `seenCoachMarks`.  Stored in `UserDefaults` so it
    /// survives app restarts without requiring SwiftData.
    @AppStorage("seenCoachMarks") private var seenCoachMarksData: Data = Data()

    /// The set of coach mark keys the user has already dismissed.
    var seenCoachMarks: Set<CoachMarkKey> {
        get {
            guard !seenCoachMarksData.isEmpty,
                  let decoded = try? JSONDecoder().decode(Set<CoachMarkKey>.self,
                                                          from: seenCoachMarksData)
            else { return [] }
            return decoded
        }
        set {
            if let encoded = try? JSONEncoder().encode(newValue) {
                seenCoachMarksData = encoded
            }
            objectWillChange.send()
        }
    }

    // MARK: - Public API

    /// Marks the onboarding flow as complete.
    func markOnboardingComplete() {
        hasSeenOnboarding = true
    }

    /// Returns `true` when the coach mark for `key` should be displayed.
    ///
    /// A coach mark is shown only once: after the user dismisses it the key is
    /// added to `seenCoachMarks` and this method returns `false` thereafter.
    func shouldShowCoachMark(for key: CoachMarkKey) -> Bool {
        !seenCoachMarks.contains(key)
    }

    /// Records that the user has seen and dismissed the coach mark for `key`.
    func dismissCoachMark(_ key: CoachMarkKey) {
        var updated = seenCoachMarks
        updated.insert(key)
        seenCoachMarks = updated
    }

    /// Resets both the onboarding gate and all coach marks so the full tutorial
    /// plays again from the beginning.  Called from Settings → "Replay Tutorial".
    ///
    /// Requirements: 29.3
    func resetOnboarding() {
        hasSeenOnboarding = false
        seenCoachMarks = []
    }
}
