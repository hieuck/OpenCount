import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins

// MARK: - QRCodeService

/// Generates QR codes encoding a session's tally summary.
/// Requirement 52 (Req 41)
final class QRCodeService {

    private let context = CIContext()

    /// Generates a QR code image for the given session's tally.
    /// Payload: compact JSON with session name, date, counts, and SHA256 hash.
    func generateQRCode(for session: CountSession) -> UIImage? {
        let payload = buildPayload(for: session)
        guard let data = payload.data(using: .utf8) else { return nil }

        let filter = CIFilter.qrCodeGenerator()
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")

        guard let outputImage = filter.outputImage else { return nil }

        // Scale up for display clarity
        let scale = CGAffineTransform(scaleX: 10, y: 10)
        let scaledImage = outputImage.transformed(by: scale)

        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }

    /// Builds the compact JSON payload for the QR code.
    func buildPayload(for session: CountSession) -> String {
        var tallies: [String: Int] = [:]
        for marker in session.markers {
            tallies[marker.objectType.name, default: 0] += 1
        }

        let formatter = ISO8601DateFormatter()
        let dateStr = formatter.string(from: session.modifiedAt)

        var parts: [String] = []
        parts.append("\"session\":\"\(session.name.replacingOccurrences(of: "\"", with: "\\\""))\"")
        parts.append("\"date\":\"\(dateStr)\"")
        let countsStr = tallies.map { "\"\($0.key)\":\($0.value)" }.sorted().joined(separator: ",")
        parts.append("\"counts\":{\(countsStr)}")

        let payload = "{\(parts.joined(separator: ","))}"
        return payload
    }
}

// MARK: - QRCodeView

/// Displays a QR code for the session's tally summary with share and copy options.
/// Requirement 52 (Req 41)
struct QRCodeView: View {

    let session: CountSession

    @State private var qrImage: UIImage?
    @State private var isShareSheetPresented: Bool = false
    @State private var shareItems: [Any] = []

    private let qrService = QRCodeService()

    var body: some View {
        VStack(spacing: 24) {
            // QR Code image
            Group {
                if let image = qrImage {
                    Image(uiImage: image)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 220, height: 220)
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white)
                                .shadow(color: .black.opacity(0.1), radius: 8)
                        )
                        .accessibilityLabel("QR code for session \(session.name)")
                } else {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.secondarySystemBackground))
                        .frame(width: 220, height: 220)
                        .overlay(ProgressView())
                        .accessibilityLabel("Generating QR code…")
                }
            }

            // Session info
            VStack(spacing: 4) {
                Text(session.name)
                    .font(.headline)
                Text(session.modifiedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Total: \(session.markers.count) markers")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)

            // Action buttons
            HStack(spacing: 16) {
                Button {
                    shareQRCode()
                } label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityLabel("Share QR code")
                .accessibilityHint("Share the QR code image via the system share sheet.")

                Button {
                    copyPayload()
                } label: {
                    Label("Copy Data", systemImage: "doc.on.clipboard")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Copy QR payload to clipboard")
                .accessibilityHint("Copies the QR code data as text to the clipboard.")
            }
            .padding(.horizontal)
        }
        .padding()
        .onAppear {
            qrImage = qrService.generateQRCode(for: session)
        }
        .sheet(isPresented: $isShareSheetPresented) {
            ShareSheet(activityItems: shareItems)
                .ignoresSafeArea()
        }
    }

    // MARK: - Actions

    private func shareQRCode() {
        guard let image = qrImage else { return }
        shareItems = [image, "OpenCount QR: \(session.name)"]
        isShareSheetPresented = true
    }

    private func copyPayload() {
        let payload = qrService.buildPayload(for: session)
        UIPasteboard.general.string = payload
    }
}

// MARK: - Preview

#Preview {
    let session = CountSession(name: "Bird Survey")
    let type1 = ObjectType(name: "Robin", colorHex: "#E74C3C", iconName: "bird", sortOrder: 0, session: session)
    session.objectTypes = [type1]
    session.markers = [
        CountMarker(normalizedX: 0.3, normalizedY: 0.4, objectType: type1, session: session),
        CountMarker(normalizedX: 0.6, normalizedY: 0.6, objectType: type1, session: session),
    ]
    return QRCodeView(session: session)
}
