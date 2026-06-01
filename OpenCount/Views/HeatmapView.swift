import SwiftUI
import UIKit

// MARK: - HeatmapView

/// Renders a density heatmap of count markers overlaid on the canvas.
///
/// Uses a Gaussian kernel to accumulate marker density into a grid,
/// then renders it as a colour-mapped overlay (blue → green → yellow → red).
///
/// Requirement: HeatmapMarkerPreservationTests — heatmap layer type.
struct HeatmapView: View {

    let markers: [CountMarker]
    let canvasSize: CGSize
    /// Opacity of the heatmap overlay (0.0–1.0).
    var opacity: Double = 0.65

    var body: some View {
        Canvas { context, size in
            guard !markers.isEmpty else { return }
            let heatmapImage = generateHeatmap(size: size)
            if let image = heatmapImage {
                context.draw(Image(uiImage: image), in: CGRect(origin: .zero, size: size))
            }
        }
        .opacity(opacity)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    // MARK: - Heatmap generation

    private func generateHeatmap(size: CGSize) -> UIImage? {
        let gridW = Int(size.width)
        let gridH = Int(size.height)
        guard gridW > 0, gridH > 0 else { return nil }

        // Accumulate density into a float grid
        var grid = [Float](repeating: 0, count: gridW * gridH)
        let sigma: Float = Float(min(gridW, gridH)) * 0.05  // 5% of canvas dimension

        for marker in markers {
            let cx = Float(marker.normalizedX) * Float(gridW)
            let cy = Float(marker.normalizedY) * Float(gridH)

            // Bounding box for the Gaussian kernel (3σ radius)
            let radius = Int(sigma * 3)
            let minX = max(0, Int(cx) - radius)
            let maxX = min(gridW - 1, Int(cx) + radius)
            let minY = max(0, Int(cy) - radius)
            let maxY = min(gridH - 1, Int(cy) + radius)

            for y in minY...maxY {
                for x in minX...maxX {
                    let dx = Float(x) - cx
                    let dy = Float(y) - cy
                    let value = exp(-(dx*dx + dy*dy) / (2 * sigma * sigma))
                    grid[y * gridW + x] += value
                }
            }
        }

        // Normalise to [0, 1]
        let maxVal = grid.max() ?? 1
        if maxVal > 0 {
            for i in 0..<grid.count {
                grid[i] /= maxVal
            }
        }

        // Map to RGBA using a heat colour ramp
        var pixels = [UInt8](repeating: 0, count: gridW * gridH * 4)
        for i in 0..<(gridW * gridH) {
            let t = grid[i]
            guard t > 0.01 else { continue }  // Skip near-zero cells (transparent)
            let (r, g, b) = heatColour(t: t)
            let alpha = UInt8(min(255, Int(t * 220) + 35))
            pixels[i * 4 + 0] = r
            pixels[i * 4 + 1] = g
            pixels[i * 4 + 2] = b
            pixels[i * 4 + 3] = alpha
        }

        // Create CGImage from pixel buffer
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let provider = CGDataProvider(data: NSData(bytes: pixels, length: pixels.count)) else {
            return nil
        }
        guard let cgImage = CGImage(
            width: gridW,
            height: gridH,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: gridW * 4,
            space: colorSpace,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: true,
            intent: .defaultIntent
        ) else { return nil }

        return UIImage(cgImage: cgImage)
    }

    /// Maps a normalised value t ∈ [0,1] to an RGB heat colour.
    /// Colour ramp: blue (cold) → cyan → green → yellow → red (hot).
    private func heatColour(t: Float) -> (UInt8, UInt8, UInt8) {
        let r: Float
        let g: Float
        let b: Float

        switch t {
        case 0..<0.25:
            let s = t / 0.25
            r = 0; g = s; b = 1
        case 0.25..<0.5:
            let s = (t - 0.25) / 0.25
            r = 0; g = 1; b = 1 - s
        case 0.5..<0.75:
            let s = (t - 0.5) / 0.25
            r = s; g = 1; b = 0
        default:
            let s = (t - 0.75) / 0.25
            r = 1; g = 1 - s; b = 0
        }

        return (
            UInt8(min(255, Int(r * 255))),
            UInt8(min(255, Int(g * 255))),
            UInt8(min(255, Int(b * 255)))
        )
    }
}

// MARK: - Preview

#Preview {
    let markers: [CountMarker] = (0..<50).map { _ in
        let objectType = ObjectType(name: "Bird", colorHex: "#FF5733", iconName: "bird", sortOrder: 0)
        return CountMarker(
            normalizedX: Double.random(in: 0.1...0.9),
            normalizedY: Double.random(in: 0.1...0.9),
            objectType: objectType,
            session: CountSession(name: "Preview")
        )
    }

    ZStack {
        Color.gray.opacity(0.3)
        HeatmapView(markers: markers, canvasSize: CGSize(width: 400, height: 400))
    }
    .frame(width: 400, height: 400)
}
