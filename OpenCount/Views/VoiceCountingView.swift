import SwiftUI
import Speech

// MARK: - VoiceCountingView

/// Hands-free counting via voice commands.
///
/// Displays a large microphone button, recognized command feedback,
/// and a live tally for the selected object type.
///
/// Voice commands:
///   "count" / "add" / "mark"  → increment
///   "undo" / "remove"         → undo
///   "next" / "switch"         → cycle type
///   "stop" / "done"           → close
///
/// This feature is unique to OpenCount — ZapCount and CountThings
/// do not support voice-driven counting.
struct VoiceCountingView: View {

    let session: CountSession
    @ObservedObject var viewModel: CountingViewModel
    @Environment(\.dismiss) private var dismiss

    @StateObject private var voiceService = VoiceCountingService()
    @State private var currentTypeIndex: Int = 0
    @State private var pulseAnimation: Bool = false

    private var objectTypes: [ObjectType] {
        session.objectTypes.sorted { $0.sortOrder < $1.sortOrder }
    }

    private var currentType: ObjectType? {
        guard !objectTypes.isEmpty else { return nil }
        return objectTypes[currentTypeIndex % objectTypes.count]
    }

    private var currentCount: Int {
        guard let type = currentType else { return 0 }
        return viewModel.markers.filter { $0.objectType.id == type.id }.count
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [
                        (currentType.flatMap { Color(hex: $0.colorHex) } ?? .accentColor).opacity(0.15),
                        Color(.systemBackground)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 32) {
                    // Availability warning
                    if !voiceService.isAvailable {
                        unavailableWarning
                    }

                    // Type selector
                    if objectTypes.count > 1 {
                        typeSelectorStrip
                    }

                    Spacer()

                    // Count display
                    countDisplay

                    // Microphone button
                    microphoneButton

                    // Command feedback
                    commandFeedback

                    Spacer()

                    // Voice command guide
                    commandGuide
                }
                .padding()
            }
            .navigationTitle("Voice Counting")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        voiceService.stopListening()
                        dismiss()
                    }
                }
            }
            .onAppear {
                setupVoiceCallbacks()
            }
            .onDisappear {
                voiceService.stopListening()
            }
        }
    }

    // MARK: - Unavailable warning

    private var unavailableWarning: some View {
        HStack(spacing: 8) {
            Image(systemName: "mic.slash.fill")
                .foregroundStyle(.orange)
            Text("Speech recognition not authorized. Enable in Settings → Privacy → Speech Recognition.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.orange.opacity(0.1))
        )
    }

    // MARK: - Type selector

    private var typeSelectorStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(objectTypes.indices, id: \.self) { index in
                    let type = objectTypes[index]
                    let isSelected = index == currentTypeIndex % objectTypes.count
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            currentTypeIndex = index
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: type.iconName)
                                .font(.caption.weight(.semibold))
                            Text(type.name)
                                .font(.caption.weight(isSelected ? .bold : .regular))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(
                            Capsule()
                                .fill(isSelected
                                      ? (Color(hex: type.colorHex) ?? .accentColor).opacity(0.2)
                                      : Color(.secondarySystemBackground))
                        )
                        .overlay(
                            Capsule()
                                .stroke(isSelected
                                        ? (Color(hex: type.colorHex) ?? .accentColor)
                                        : Color.clear,
                                        lineWidth: 1.5)
                        )
                        .foregroundStyle(isSelected ? .primary : .secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 4)
        }
    }

    // MARK: - Count display

    private var countDisplay: some View {
        VStack(spacing: 8) {
            if let type = currentType {
                HStack(spacing: 8) {
                    Image(systemName: type.iconName)
                        .font(.title3)
                        .foregroundStyle(Color(hex: type.colorHex) ?? .accentColor)
                    Text(type.name)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
            }

            Text("\(currentCount)")
                .font(.system(size: 96, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(currentType.flatMap { Color(hex: $0.colorHex) } ?? .accentColor)
                .contentTransition(.numericText())
                .animation(.spring(response: 0.3), value: currentCount)
                .accessibilityLabel("Count: \(currentCount)")
        }
    }

    // MARK: - Microphone button

    private var microphoneButton: some View {
        Button {
            if voiceService.isListening {
                voiceService.stopListening()
            } else {
                voiceService.startListening()
            }
        } label: {
            ZStack {
                // Pulse ring when listening
                if voiceService.isListening {
                    Circle()
                        .stroke(
                            (currentType.flatMap { Color(hex: $0.colorHex) } ?? .accentColor)
                                .opacity(0.3),
                            lineWidth: 3
                        )
                        .frame(width: 140, height: 140)
                        .scaleEffect(pulseAnimation ? 1.3 : 1.0)
                        .opacity(pulseAnimation ? 0 : 1)
                        .animation(
                            .easeOut(duration: 1.0).repeatForever(autoreverses: false),
                            value: pulseAnimation
                        )
                }

                Circle()
                    .fill(
                        voiceService.isListening
                            ? (currentType.flatMap { Color(hex: $0.colorHex) } ?? .accentColor)
                            : Color(.secondarySystemBackground)
                    )
                    .frame(width: 110, height: 110)
                    .shadow(
                        color: voiceService.isListening
                            ? (currentType.flatMap { Color(hex: $0.colorHex) } ?? .accentColor).opacity(0.4)
                            : Color.black.opacity(0.1),
                        radius: voiceService.isListening ? 20 : 8,
                        x: 0, y: 4
                    )

                Image(systemName: voiceService.isListening ? "mic.fill" : "mic")
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundStyle(voiceService.isListening ? .white : .secondary)
            }
        }
        .buttonStyle(.plain)
        .disabled(!voiceService.isAvailable)
        .accessibilityLabel(voiceService.isListening ? "Stop voice counting" : "Start voice counting")
        .accessibilityHint(voiceService.isListening
            ? "Tap to stop listening for voice commands."
            : "Tap to start listening. Say 'count' to add, 'undo' to remove, 'next' to switch type.")
        .onChange(of: voiceService.isListening) { _, listening in
            pulseAnimation = listening
        }
    }

    // MARK: - Command feedback

    private var commandFeedback: some View {
        Group {
            if voiceService.isListening {
                HStack(spacing: 8) {
                    // Animated waveform dots
                    ForEach(0..<5, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(currentType.flatMap { Color(hex: $0.colorHex) } ?? .accentColor)
                            .frame(width: 4, height: CGFloat.random(in: 8...24))
                            .animation(
                                .easeInOut(duration: 0.4)
                                    .repeatForever()
                                    .delay(Double(i) * 0.1),
                                value: voiceService.isListening
                            )
                    }

                    if !voiceService.lastRecognizedCommand.isEmpty {
                        Text(voiceService.lastRecognizedCommand)
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .transition(.scale.combined(with: .opacity))
                    } else {
                        Text("Listening…")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .animation(.spring(response: 0.3), value: voiceService.lastRecognizedCommand)
            } else {
                Text("Tap the microphone to start")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(height: 40)
    }

    // MARK: - Command guide

    private var commandGuide: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Voice Commands")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                commandChip(icon: "plus.circle.fill", color: .green,
                            command: "\"count\" / \"add\"", action: "Increment")
                commandChip(icon: "arrow.uturn.backward.circle.fill", color: .orange,
                            command: "\"undo\" / \"remove\"", action: "Undo")
                commandChip(icon: "arrow.right.circle.fill", color: .blue,
                            command: "\"next\" / \"switch\"", action: "Next type")
                commandChip(icon: "stop.circle.fill", color: .red,
                            command: "\"stop\" / \"done\"", action: "Finish")
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private func commandChip(icon: String, color: Color, command: String, action: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.title3)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(command)
                    .font(.caption.weight(.medium))
                Text(action)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Say \(command) to \(action)")
    }

    // MARK: - Setup

    private func setupVoiceCallbacks() {
        voiceService.onCount = {
            guard let type = self.currentType else { return }
            self.viewModel.selectedObjectType = type
            self.viewModel.placeMarker(at: CGPoint(x: 0.5, y: 0.5))
        }

        voiceService.onUndo = {
            self.viewModel.undo()
        }

        voiceService.onNextType = {
            withAnimation(.spring(response: 0.3)) {
                self.currentTypeIndex = (self.currentTypeIndex + 1) % max(1, self.objectTypes.count)
            }
        }

        voiceService.onStop = {
            self.voiceService.stopListening()
            self.dismiss()
        }
    }
}

// MARK: - Preview

#Preview {
    let session = CountSession(name: "Bird Survey")
    let type1 = ObjectType(name: "Eagle", colorHex: "#E74C3C", iconName: "bird.fill", sortOrder: 0, session: session)
    let type2 = ObjectType(name: "Hawk", colorHex: "#3498DB", iconName: "bird", sortOrder: 1, session: session)
    session.objectTypes = [type1, type2]
    return VoiceCountingView(
        session: session,
        viewModel: CountingViewModel(session: session)
    )
}
