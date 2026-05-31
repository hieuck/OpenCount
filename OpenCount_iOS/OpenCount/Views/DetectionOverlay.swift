import SwiftUI

/// Overlay vẽ bounding box lên ảnh
struct DetectionOverlay: View {
    let objects: [DetectedObject]
    let imageSize: CGSize

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ForEach(objects) { object in
                    let rect = normalizedRectToView(
                        object.boundingBox,
                        in: proxy.size
                    )

                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Constants.color(for: object.label), lineWidth: 2)
                        .frame(width: rect.width, height: rect.height)
                        .position(rect.mid)
                        .overlay(
                            Label(
                                "\(object.label)\n\(Int(object.confidence * 100))%",
                                systemImage: "checkmark.circle.fill"
                            )
                            .labelStyle(LabelStyleOverlay())
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

/// Style cho label trên bounding box
private struct LabelStyleOverlay: LabelStyle {
    func makeLabel(configuration: Configuration) -> some View {
        configuration.icon
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(.white)
            .padding(4)
            .background(.black.opacity(0.7))
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}
