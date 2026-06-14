import SwiftUI
import UniformTypeIdentifiers

// MARK: - CustomModelView

/// Settings sub-screen for managing imported CoreML models.
/// Shows active model info, allows importing new models, and switching between models.
///
/// Requirements: 20.1–20.7
struct CustomModelView: View {

    @StateObject private var modelService = CustomModelService()
    @State private var isImporting: Bool = false
    @State private var importError: String?
    @State private var isShowingImportError: Bool = false
    @State private var isShowingDeleteConfirmation: Bool = false
    @State private var modelToDelete: ModelMetadata?
    @State private var activationError: String?
    @State private var isShowingActivationError: Bool = false

    var body: some View {
        List {
            // Active model section
            activeModelSection

            // Built-in model section
            builtInModelSection

            // Imported models section
            importedModelsSection

            // Import button section
            importSection
        }
        .navigationTitle("AI Models")
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [
                UTType(filenameExtension: "mlpackage") ?? .data,
                UTType(filenameExtension: "mlmodel") ?? .data,
                UTType(filenameExtension: "mlmodelc") ?? .data
            ],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result: result)
        }
        .alert("Import Failed", isPresented: $isShowingImportError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importError ?? "Unknown error")
        }
        .alert("Activation Failed", isPresented: $isShowingActivationError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(activationError ?? "Unknown error")
        }
        .alert("Delete Model", isPresented: $isShowingDeleteConfirmation, presenting: modelToDelete) { model in
            Button("Delete", role: .destructive) {
                try? modelService.deleteModel(model)
            }
            Button("Cancel", role: .cancel) {}
        } message: { model in
            Text("Delete '\(model.name)'? This cannot be undone.")
        }
    }

    // MARK: - Active model section

    @ViewBuilder
    private var activeModelSection: some View {
        Section {
            activeModelRowContent
        } header: {
            Text("Active Model")
        }
    }

    @ViewBuilder
    private var activeModelRowContent: some View {
        if let active = modelService.activeModelMetadata {
            modelRow(active, isActive: true)
        } else {
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text("YOLOv8n (Built-in)")
                        .font(.body)
                    Text("80 classes · 640×640")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
            .accessibilityLabel("Active model: YOLOv8n built-in, 80 classes")
        }
    }

    // MARK: - Built-in model section

    private var builtInModelSection: some View {
        Section {
            Button {
                // Switch back to built-in model
                modelService.activeModelMetadata = nil
                UserDefaults.standard.removeObject(forKey: "activeModelID")
            } label: {
                HStack {
                    Image(systemName: "brain.head.profile")
                        .foregroundStyle(.secondary)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("YOLOv8n (Built-in)")
                            .font(.body)
                            .foregroundStyle(.primary)
                        Text("80 classes · 640×640 · Bundled")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if modelService.activeModelMetadata == nil {
                        Image(systemName: "checkmark")
                            .foregroundStyle(Color.accentColor)
                    }
                }
            }
            .accessibilityLabel("Use built-in YOLOv8n model")
            .accessibilityAddTraits(modelService.activeModelMetadata == nil ? .isSelected : [])
        } header: {
            Text("Built-in Model")
        }
    }

    // MARK: - Imported models section

    @ViewBuilder
    private var importedModelsSection: some View {
        if !modelService.importedModels.isEmpty {
            Section {
                ForEach(modelService.importedModels) { model in
                    modelRow(model, isActive: modelService.activeModelMetadata?.id == model.id)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                modelToDelete = model
                                isShowingDeleteConfirmation = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            } header: {
                Text("Imported Models (\(modelService.importedModels.count))")
            }
        }
    }

    // MARK: - Import section

    private var importSection: some View {
        Section {
            Button {
                isImporting = true
            } label: {
                Label("Import Model (.mlpackage / .mlmodel)", systemImage: "square.and.arrow.down")
            }
            .accessibilityLabel("Import a CoreML model from Files")
            .accessibilityHint("Imports a .mlpackage or .mlmodel file and validates it for use with OpenCount.")
        } footer: {
            Text("Imported models must output VNRecognizedObjectObservation results. Supports up to 1,000 output classes.")
        }
    }    // MARK: - Model row

    private func modelRow(_ model: ModelMetadata, isActive: Bool) -> some View {
        Button {
            activateModel(model)
        } label: {
            HStack {
                Image(systemName: "cpu")
                    .foregroundStyle(.secondary)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.name)
                        .font(.body)
                        .foregroundStyle(.primary)
                    Text("\(model.classCount) classes · \(Int(model.inputSize.width))×\(Int(model.inputSize.height))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Imported \(model.importedAt.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                Spacer()
                if isActive {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }
        }
        .accessibilityLabel("\(model.name), \(model.classCount) classes\(isActive ? ", currently active" : "")")
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }

    // MARK: - Actions

    private func handleImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            Task {
                do {
                    _ = try await modelService.importModel(from: url)
                } catch {
                    await MainActor.run {
                        importError = error.localizedDescription
                        isShowingImportError = true
                    }
                }
            }
        case .failure(let error):
            importError = error.localizedDescription
            isShowingImportError = true
        }
    }

    private func activateModel(_ model: ModelMetadata) {
        do {
            _ = try modelService.activateModel(model)
        } catch {
            activationError = error.localizedDescription
            isShowingActivationError = true
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        CustomModelView()
    }
}
