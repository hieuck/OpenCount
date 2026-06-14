import WidgetKit
import SwiftUI

// MARK: - WatchWidgetBundle
// Registers the OpenCount Watch complications with WidgetKit.
// NOTE: This bundle is included in the OpenCountWatch app target.
// The @main entry point is in WatchApp.swift.
// Requirement 22.6

struct WatchWidgetBundle: WidgetBundle {
    var body: some Widget {
        OpenCountComplication()
    }
}
