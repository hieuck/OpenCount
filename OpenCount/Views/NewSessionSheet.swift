import SwiftUI

/// The image source the user wants to use when creating a new session.
enum ImageSource: String, CaseIterable, Identifiable {
    case photos = "Photos Library"
    case camera = "Camera"
    case files  = "Files"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .photos: return "photo.on.rectangle"
        case .camera: return "camera"
        case .files:  return "folder"
        }
    }
}

/// Sheet presented when the user taps the "+" button in `SessionListView`.
/// Collects a required name, optional description, and an image source selection.
/// Requirement 1.1: Create button is disabled when name is empty.
struct NewSessionSheet: View {

    @Environment(\.dismiss) private var dismiss

    // MARK: - Form state

    @State private var name: String = ""
    @State private var description: String = ""
    @State private var selectedSource: ImageSource = .photos

    // MARK: - Callbacks

    /// Called with the entered name, description, and chosen source when the user taps Create.
    let onCreate: (String, String?, ImageSource) -> Void

    // MARK: - Computed

    private var isCreateEnabled: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                // MARK: Session details
                Section("Session Details") {
                    TextField("Name (required)", text: $name)
                        .font(.body)
                        .accessibilityLabel("Session name")
                        .accessibilityHint("Required. Enter a name for this counting session.")

                    TextField("Description (optional)", text: $description, axis: .vertical)
                        .font(.body)
                        .lineLimit(3...6)
                        .accessibilityLabel("Session description")
                        .accessibilityHint("Optional. Describe what you are counting.")
                }

                // MARK: Image source picker
                Section("Image Source") {
                    ForEach(ImageSource.allCases) { source in
                        Button {
                            selectedSource = source
                        } label: {
                            HStack {
                                Label(source.rawValue, systemImage: source.systemImage)
                                    .font(.body)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if selectedSource == source {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.tint)
                                        .accessibilityHidden(true)
                                }
                            }
                        }
                        .accessibilityLabel(source.rawValue)
                        .accessibilityAddTraits(selectedSource == source ? .isSelected : [])
                    }
                }
            }
            .navigationTitle("New Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .accessibilityLabel("Cancel creating new session")
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        let trimmedDesc = description.trimmingCharacters(in: .whitespacesAndNewlines)
                        onCreate(
                            trimmedName,
                            trimmedDesc.isEmpty ? nil : trimmedDesc,
                            selectedSource
                        )
                        dismiss()
                    }
                    .disabled(!isCreateEnabled)
                    .accessibilityLabel("Create session")
                    .accessibilityHint(isCreateEnabled ? "Creates the new session." : "Enter a name to enable.")
                }
            }
        }
    }
}

#Preview {
    NewSessionSheet { name, description, source in
        print("Create: \(name), \(description ?? ""), \(source.rawValue)")
    }
}
