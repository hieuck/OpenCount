import SwiftUI
import UIKit

// MARK: - PanoramaCanvasView

/// A SwiftUI view that renders large images (up to 16384×16384) smoothly using
/// a `CATiledLayer`-backed `UIView` inside a `UIScrollView`.
///
/// Features:
/// - Tiled rendering via `CATiledLayer` — only visible tiles are drawn, keeping
///   memory usage low even for very large images.
/// - Pinch-to-zoom and pan via `UIScrollView`.
/// - `CountMarker` dots rendered on top of the tiled image layer.
///
/// Requirements: 25.1, 25.3
struct PanoramaCanvasView: UIViewRepresentable {

    // MARK: - Properties

    /// The full-resolution image to display.
    let image: UIImage
    /// Markers to render on top of the image.
    let markers: [CountMarker]
    /// Dot radius for markers in points (screen space).
    var markerRadius: CGFloat = 8

    // MARK: - UIViewRepresentable

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.minimumZoomScale = 0.1
        scrollView.maximumZoomScale = 10.0
        scrollView.showsHorizontalScrollIndicator = true
        scrollView.showsVerticalScrollIndicator = true
        scrollView.bouncesZoom = true

        // The tiled image view is the scroll view's content.
        let tiledView = TiledImageView(image: image)
        tiledView.frame = CGRect(origin: .zero, size: image.size)
        scrollView.addSubview(tiledView)
        scrollView.contentSize = image.size

        // Marker overlay sits on top of the tiled view, same size.
        let markerView = MarkerOverlayView(
            image: image,
            markers: markers,
            markerRadius: markerRadius
        )
        markerView.frame = CGRect(origin: .zero, size: image.size)
        markerView.isUserInteractionEnabled = false
        scrollView.addSubview(markerView)

        context.coordinator.tiledView = tiledView
        context.coordinator.markerView = markerView
        context.coordinator.scrollView = scrollView

        // Fit the image in the scroll view on first layout.
        DispatchQueue.main.async {
            context.coordinator.zoomToFit()
        }

        return scrollView
    }

    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        // Update markers when the binding changes.
        context.coordinator.markerView?.update(markers: markers, markerRadius: markerRadius)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, UIScrollViewDelegate {
        weak var scrollView: UIScrollView?
        weak var tiledView: TiledImageView?
        weak var markerView: MarkerOverlayView?

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            // Both tiledView and markerView are children of scrollView.
            // We zoom the tiledView; markerView is kept in sync via layoutSubviews.
            return tiledView
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            // Keep the marker overlay frame in sync with the tiled view.
            if let tv = tiledView {
                markerView?.frame = tv.frame
            }
            centerContent(in: scrollView)
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            if let tv = tiledView {
                markerView?.frame = tv.frame
            }
        }

        /// Centers the content view when it is smaller than the scroll view bounds.
        func centerContent(in scrollView: UIScrollView) {
            guard let tv = tiledView else { return }
            let boundsSize = scrollView.bounds.size
            var frameToCenter = tv.frame

            if frameToCenter.size.width < boundsSize.width {
                frameToCenter.origin.x = (boundsSize.width - frameToCenter.size.width) / 2
            } else {
                frameToCenter.origin.x = 0
            }

            if frameToCenter.size.height < boundsSize.height {
                frameToCenter.origin.y = (boundsSize.height - frameToCenter.size.height) / 2
            } else {
                frameToCenter.origin.y = 0
            }

            tv.frame = frameToCenter
            markerView?.frame = frameToCenter
        }

        /// Scales the scroll view so the full image fits within its bounds.
        func zoomToFit() {
            guard let scrollView = scrollView, let tv = tiledView else { return }
            let boundsSize = scrollView.bounds.size
            guard boundsSize.width > 0, boundsSize.height > 0 else { return }
            let imageSize = tv.imageSize
            let scaleX = boundsSize.width / imageSize.width
            let scaleY = boundsSize.height / imageSize.height
            let minScale = min(scaleX, scaleY)
            scrollView.minimumZoomScale = max(0.01, minScale * 0.5)
            scrollView.setZoomScale(minScale, animated: false)
            centerContent(in: scrollView)
        }
    }
}

// MARK: - TiledImageView

/// A `UIView` backed by `CATiledLayer` that draws a large image tile-by-tile.
/// Only the tiles currently visible on screen are rendered, keeping memory usage low.
///
/// Requirements: 25.3
final class TiledImageView: UIView {

    let image: UIImage
    var imageSize: CGSize { image.size }

    init(image: UIImage) {
        self.image = image
        super.init(frame: CGRect(origin: .zero, size: image.size))
        backgroundColor = .systemBackground
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // Use CATiledLayer as the backing layer.
    override class var layerClass: AnyClass {
        CATiledLayer.self
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard let tiledLayer = layer as? CATiledLayer else { return }
        // Tile size: 256×256 points is a good balance between draw calls and memory.
        tiledLayer.tileSize = CGSize(width: 256, height: 256)
        // levelsOfDetail: how many zoom levels CATiledLayer pre-renders.
        tiledLayer.levelsOfDetail = 4
        tiledLayer.levelsOfDetailBias = 2
    }

    override func draw(_ rect: CGRect) {
        guard let cgImage = image.cgImage,
              let context = UIGraphicsGetCurrentContext() else { return }

        // CATiledLayer calls draw(_:) for each tile rect in the layer's coordinate space.
        // We clip to the tile rect and draw the portion of the image that falls within it.
        context.saveGState()
        context.clip(to: rect)

        // UIKit coordinate system has origin at top-left; CGContext at bottom-left.
        // Flip the context so the image draws right-side up.
        context.translateBy(x: 0, y: bounds.height)
        context.scaleBy(x: 1, y: -1)

        // The rect in the flipped coordinate system.
        let flippedRect = CGRect(
            x: rect.origin.x,
            y: bounds.height - rect.origin.y - rect.height,
            width: rect.width,
            height: rect.height
        )

        context.draw(cgImage, in: CGRect(origin: .zero, size: bounds.size))
        _ = flippedRect // used implicitly via the full-bounds draw above

        context.restoreGState()
    }
}

// MARK: - MarkerOverlayView

/// A transparent `UIView` that draws `CountMarker` dots on top of the tiled image.
/// Coordinates are converted from normalized image space to the view's point space.
///
/// Requirements: 25.3
final class MarkerOverlayView: UIView {

    private var markers: [CountMarker]
    private var imageSize: CGSize
    private var markerRadius: CGFloat

    init(image: UIImage, markers: [CountMarker], markerRadius: CGFloat) {
        self.markers = markers
        self.imageSize = image.size
        self.markerRadius = markerRadius
        super.init(frame: CGRect(origin: .zero, size: image.size))
        backgroundColor = .clear
        isOpaque = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(markers: [CountMarker], markerRadius: CGFloat) {
        self.markers = markers
        self.markerRadius = markerRadius
        setNeedsDisplay()
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }

        for marker in markers {
            let x = CGFloat(marker.normalizedX) * bounds.width
            let y = CGFloat(marker.normalizedY) * bounds.height
            let dotRect = CGRect(
                x: x - markerRadius,
                y: y - markerRadius,
                width: markerRadius * 2,
                height: markerRadius * 2
            )

            let color = UIColor(hex: marker.objectType.colorHex) ?? .systemRed

            if marker.isAIDerived {
                // AI-derived: outlined circle.
                context.setStrokeColor(color.cgColor)
                context.setLineWidth(max(1.5, markerRadius * 0.2))
                context.strokeEllipse(in: dotRect)
            } else {
                // Manual: filled circle with a white border for visibility.
                context.setFillColor(color.cgColor)
                context.fillEllipse(in: dotRect)
                context.setStrokeColor(UIColor.white.withAlphaComponent(0.8).cgColor)
                context.setLineWidth(max(1, markerRadius * 0.15))
                context.strokeEllipse(in: dotRect)
            }
        }
    }
}
