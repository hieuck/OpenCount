import SwiftUI

/// Overlay vẽ bounding box lên ảnh
struct DetectionOverlay: View {
    let objects: [DetectedObject]
    let imageSize: CGSize

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ForEach(Array(objects.enumerated()), id: \.element.id) { index, object in
                    let rect = normalizedRectToView(
                        object.boundingBox,
                        in: proxy.size
                    )

                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Constants.color(for: object.label), lineWidth: 2)
                        .frame(width: rect.width, height: rect.height)
                        .position(rect.mid)
                        .overlay(
                            VStack(spacing: 2) {
                                Text(object.label)
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                Text("\(Int(object.confidence * 100))%")
                                    .font(.caption2)
                            }
                            .foregroundColor(.white)
                            .padding(4)
                            .background(.black.opacity(0.7))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            .offset(x: 4, y: -4)
                        )
                }
            }
        }
        .allowsHitTesting(false)
    }

    /// Chuyển đổi rect normalized (0-1) sang coordinate của view
    private func normalizedRectToView(
        _ rect: CGRect,
        in size: CGSize
    ) -> CGRect {
        let scale = min(size.width, size.height) / max(imageSize.width, imageSize.height)
        let width = rect.width * size.width
        let height = rect.height * size.height
        let x = rect.origin.x * size.width
        let y = rect.origin.y * size.height

        return CGRect(x: x, y: y, width: width, height: height)
    }
}
