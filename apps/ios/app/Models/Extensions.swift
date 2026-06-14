import Foundation
import CoreGraphics

// MARK: - Comparable + clamped

extension Comparable {
    /// Clamps the value to the given closed range.
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

// MARK: - Notification.Name constants

extension Notification.Name {
    /// Posted when the device is shaken (used for shake-to-undo).
    static let deviceDidShake = Notification.Name("DeviceDidShakeNotification")
    /// Posted by the AI panel's "Find Missed Objects" button.
    static let findMissedObjectsRequested = Notification.Name("com.opencount.findMissedObjectsRequested")
    /// Posted by the AI panel's "Run AI Detection" button.
    static let runAIDetectionRequested = Notification.Name("com.opencount.runAIDetectionRequested")
}
