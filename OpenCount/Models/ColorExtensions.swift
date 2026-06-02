import SwiftUI
import UIKit

// MARK: - Shared Color Extensions
// Centralised hex-color helpers used throughout the app.
// Having a single definition avoids duplicate-symbol compile errors.

extension Color {
    /// Initialises a `Color` from a CSS-style hex string (e.g. `"#FF5733"` or `"FF5733"`).
    init?(hex: String) {
        var str = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if str.hasPrefix("#") { str.removeFirst() }
        guard str.count == 6, let value = UInt64(str, radix: 16) else { return nil }
        let r = Double((value >> 16) & 0xFF) / 255
        let g = Double((value >> 8) & 0xFF) / 255
        let b = Double(value & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }

    /// Returns a CSS-style hex string for the color, or `nil` if conversion fails.
    var hexString: String? {
        guard let components = UIColor(self).cgColor.components, components.count >= 3 else {
            return nil
        }
        let r = Int(components[0] * 255)
        let g = Int(components[1] * 255)
        let b = Int(components[2] * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }

    /// Converts a SwiftUI Color to a hex string (#RRGGBB).
    func toHex() -> String? { hexString }
}

// MARK: - UIColor hex support

extension UIColor {
    /// Initialises a `UIColor` from a CSS-style hex string (e.g. `"#FF5733"` or `"FF5733"`).
    convenience init?(hex: String) {
        var str = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if str.hasPrefix("#") { str.removeFirst() }
        guard str.count == 6, let value = UInt64(str, radix: 16) else { return nil }
        let r = CGFloat((value >> 16) & 0xFF) / 255
        let g = CGFloat((value >> 8) & 0xFF) / 255
        let b = CGFloat(value & 0xFF) / 255
        self.init(red: r, green: g, blue: b, alpha: 1.0)
    }

    /// Returns a CSS-style hex string for the color (e.g. `"#FF5733"`).
    var hexString: String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }
}
