import WidgetKit
import SwiftUI

// MARK: - OpenCountWidgetBundle
// Requirement 23.3

/// The widget bundle entry point for the OpenCountWidget extension target.
/// Register all widget types here.
@main
struct OpenCountWidgetBundle: WidgetBundle {
    var body: some Widget {
        OpenCountWidget()
    }
}
