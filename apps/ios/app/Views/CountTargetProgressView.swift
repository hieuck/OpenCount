import SwiftUI

// MARK: - CountTargetProgressView

/// A circular progress ring displayed around an ObjectType's tally badge
/// when a count target has been set.
///
/// - Fills as count approaches target
/// - Turns green at 100%, red if exceeded
/// - Triggers confetti animation on first completion
///
/// Requirement 53 (Req 42)
struct CountTargetProgressView: View {

    let count: Int
    let target: Int
    let color: Color

    private var progress: Double {
        guard target > 0 else { return 0 }
        return min(Double(count) / Double(target), 1.0)
    }

    private var isComplete: Bool { count >= target }
    private var isExceeded: Bool { count > target }

    private var ringColor: Color {
        if isExceeded { return .red }
        if isComplete { return .green }
        return color
    }

    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(color.opacity(0.2), lineWidth: 3)

            // Progress ring
            Circle()
                .trim(from: 0, to: progress)
                .stroke(ringColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.3), value: progress)
        }
        .accessibilityLabel(
            "Progress: \(count) of \(target) \(isComplete ? "(complete)" : isExceeded ? "(exceeded)" : "")"
        )
    }
}

// MARK: - ConfettiView

/// A lightweight confetti burst animation using CAEmitterLayer.
/// Triggered when a count target is first reached.
///
/// Requirement 53 (Req 42)
struct ConfettiView: UIViewRepresentable {

    let isActive: Bool

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        if isActive {
            startConfetti(in: uiView)
        }
    }

    private func startConfetti(in view: UIView) {
        let emitter = CAEmitterLayer()
        emitter.emitterPosition = CGPoint(x: view.bounds.midX, y: -10)
        emitter.emitterShape = .line
        emitter.emitterSize = CGSize(width: view.bounds.width, height: 1)

        let colors: [UIColor] = [.systemRed, .systemBlue, .systemGreen, .systemYellow, .systemPurple, .systemOrange]
        let cells = colors.map { color -> CAEmitterCell in
            let cell = CAEmitterCell()
            cell.birthRate = 8
            cell.lifetime = 3.0
            cell.velocity = 200
            cell.velocityRange = 80
            cell.emissionLongitude = .pi
            cell.emissionRange = .pi / 4
            cell.spin = 3
            cell.spinRange = 6
            cell.scaleRange = 0.5
            cell.scaleSpeed = -0.1
            cell.color = color.cgColor
            cell.contents = makeConfettiImage()
            return cell
        }

        emitter.emitterCells = cells
        view.layer.addSublayer(emitter)

        // Stop emitting after 0.5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            emitter.birthRate = 0
        }
        // Remove layer after animation completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            emitter.removeFromSuperlayer()
        }
    }

    private func makeConfettiImage() -> CGImage? {
        let size = CGSize(width: 8, height: 8)
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        UIColor.white.setFill()
        UIBezierPath(rect: CGRect(origin: .zero, size: size)).fill()
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image?.cgImage
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        ZStack {
            CountTargetProgressView(count: 7, target: 10, color: .blue)
                .frame(width: 50, height: 50)
            Text("7")
                .font(.headline)
        }

        ZStack {
            CountTargetProgressView(count: 10, target: 10, color: .blue)
                .frame(width: 50, height: 50)
            Text("10")
                .font(.headline)
        }

        ZStack {
            CountTargetProgressView(count: 12, target: 10, color: .blue)
                .frame(width: 50, height: 50)
            Text("12")
                .font(.headline)
        }
    }
    .padding()
}
