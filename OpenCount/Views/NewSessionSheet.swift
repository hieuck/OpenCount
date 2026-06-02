import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

/// The image source the user wants to use when creating a new session.
enum ImageSource: String, CaseIterable, Identifiable {
    case photos = "Photos Library"
    case camera = "Camera"
    case files  = "Files"
    case none   = "No Image (manual counting)"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .photos: return "photo.on.rectangle"
        case .camera: return "camera"
        case .files:  return "folder"
        case .none:   return "hand.tap"
        }
    }
}

/// Sheet presented when the user taps the "+" button in `SessionListView`.
/// Collects a required name, optional description, image source, and object types.
/// Requirement 1.1: Create button is disabled when name is empty.
struct NewSessionSheet: View {

    @Environment(\.dismiss) private var dismiss

    // MARK: - Form state

    @State private var name: String = ""
    @State private var description: String = ""
    @State private var selectedSource: ImageSource = .photos

    // MARK: - Image picker state

    @State private var photoPickerItems: [PhotosPickerItem] = []
    @State private var selectedImages: [UIImage] = []
    @State private var isCameraPresented: Bool = false
    @State private var isFileImporterPresented: Bool = false

    // MARK: - Object type quick-add

    @State private var objectTypeNames: [String] = [""]

    // MARK: - Smart suggestions

    @State private var suggestions: [SmartSuggestionsService.ObjectTypeSuggestion] = []
    private let suggestionsService = SmartSuggestionsService()

    // MARK: - Callbacks

    /// Called with the entered name, description, chosen source, pre-selected images, and object type names.
    let onCreate: (String, String?, ImageSource, [UIImage], [String]) -> Void

    // MARK: - Computed

    private var isCreateEnabled: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var currentTypeNames: Set<String> {
        Set(objectTypeNames.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty })
    }

    private var filteredSuggestions: [SmartSuggestionsService.ObjectTypeSuggestion] {
        suggestions.filter { !currentTypeNames.contains($0.name) }.prefix(6).map { $0 }
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

                // MARK: Object types quick-add
                Section {
                    ForEach(objectTypeNames.indices, id: \.self) { index in
                        HStack {
                            TextField("Object type (e.g. Bird, Car)", text: $objectTypeNames[index])
                                .font(.body)
                            if objectTypeNames.count > 1 {
                                Button {
                                    objectTypeNames.remove(at: index)
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundStyle(.red)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    Button {
                        objectTypeNames.append("")
                    } label: {
                        Label("Add Object Type", systemImage: "plus.circle")
                    }
                } header: {
                    Text("Object Types")
                } footer: {
                    Text("Define what you'll be counting. You can add more later.")
                }

                // MARK: Smart suggestions
                if !filteredSuggestions.isEmpty {
                    Section {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(filteredSuggestions) { suggestion in
                                    Button {
                                        addSuggestion(suggestion)
                                    } label: {
                                        HStack(spacing: 6) {
                                            Circle()
                                                .fill(Color(hex: suggestion.colorHex) ?? .accentColor)
                                                .frame(width: 10, height: 10)
                                                .accessibilityHidden(true)
                                            Image(systemName: suggestion.iconName)
                                                .font(.caption)
                                                .accessibilityHidden(true)
                                            Text(suggestion.name)
                                                .font(.caption.weight(.medium))
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(
                                            Capsule()
                                                .fill(Color(.secondarySystemBackground))
                                        )
                                        .overlay(
                                            Capsule()
                                                .stroke(Color(.separator), lineWidth: 0.5)
                                        )
                                        .foregroundStyle(.primary)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("Add \(suggestion.name) (used \(suggestion.usageCount) times)")
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    } header: {
                        Label("Suggestions from past sessions", systemImage: "sparkles")
                            .font(.caption)
                            .textCase(nil)
                    }
                }

                // MARK: Image source picker
                Section("Image Source") {
                    ForEach(ImageSource.allCases) { source in
                        Button {
                            selectedSource = source
                            // Trigger picker immediately on selection
                            switch source {
                            case .camera:
                                isCameraPresented = true
                            case .files:
                                isFileImporterPresented = true
                            default:
                                break
                            }
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

                // MARK: Photos picker (inline when Photos selected)
                if selectedSource == .photos {
                    Section {
                        PhotosPicker(
                            selection: $photoPickerItems,
                            maxSelectionCount: 20,
                            matching: .images
                        ) {
                            Label(
                                selectedImages.isEmpty
                                    ? "Choose Images"
                                    : "\(selectedImages.count) image\(selectedImages.count == 1 ? "" : "s") selected",
                                systemImage: "photo.on.rectangle.angled"
                            )
                        }
                        .onChange(of: photoPickerItems) { _, items in
                            Task {
                                var images: [UIImage] = []
                                for item in items {
                                    if let data = try? await item.loadTransferable(type: Data.self),
                                       let img = UIImage(data: data) {
                                        images.append(img)
                                    }
                                }
                                selectedImages = images
                            }
                        }

                        // Thumbnail strip
                        if !selectedImages.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(selectedImages.indices, id: \.self) { i in
                                        Image(uiImage: selectedImages[i])
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 60, height: 60)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                            .overlay(
                                                Button {
                                                    selectedImages.remove(at: i)
                                                    if i < photoPickerItems.count {
                                                        photoPickerItems.remove(at: i)
                                                    }
                                                } label: {
                                                    Image(systemName: "xmark.circle.fill")
                                                        .foregroundStyle(.white)
                                                        .background(Color.black.opacity(0.5), in: Circle())
                                                }
                                                .padding(4),
                                                alignment: .topTrailing
                                            )
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    } header: {
                        Text("Selected Images")
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
                        let validTypes = objectTypeNames
                            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                            .filter { !$0.isEmpty }
                        onCreate(
                            trimmedName,
                            trimmedDesc.isEmpty ? nil : trimmedDesc,
                            selectedSource,
                            selectedImages,
                            validTypes
                        )
                        dismiss()
                    }
                    .disabled(!isCreateEnabled)
                    .accessibilityLabel("Create session")
                    .accessibilityHint(isCreateEnabled ? "Creates the new session." : "Enter a name to enable.")
                }
            }
            // Camera picker
            .fullScreenCover(isPresented: $isCameraPresented) {
                CameraPickerView { image in
                    selectedImages.append(image)
                }
                .ignoresSafeArea()
            }
            // File importer
            .fileImporter(
                isPresented: $isFileImporterPresented,
                allowedContentTypes: [.image, .jpeg, .png, .heic, .tiff],
                allowsMultipleSelection: true
            ) { result in
                switch result {
                case .success(let urls):
                    for url in urls {
                        let accessing = url.startAccessingSecurityScopedResource()
                        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
                        if let data = try? Data(contentsOf: url),
                           let img = UIImage(data: data) {
                            selectedImages.append(img)
                        }
                    }
                case .failure:
                    break
                }
            }
        }
        .onAppear {
            loadSuggestions()
        }
    }

    // MARK: - Smart suggestions

    private func loadSuggestions() {
        Task {
            let sessions = (try? await StorageService.shared.fetchAllSessions()) ?? []
            await MainActor.run {
                suggestions = suggestionsService.suggestions(from: sessions, limit: 10)
            }
        }
    }

    private func addSuggestion(_ suggestion: SmartSuggestionsService.ObjectTypeSuggestion) {
        // Replace the last empty field or append a new one
        if let emptyIndex = objectTypeNames.lastIndex(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
            objectTypeNames[emptyIndex] = suggestion.name
        } else {
            objectTypeNames.append(suggestion.name)
        }
    }
}

#Preview {
    NewSessionSheet { name, description, source, images, types in
        #if DEBUG
        print("Create: \(name), \(description ?? ""), \(source.rawValue), \(images.count) images, types: \(types)")
        #endif
    }
}
