import SwiftUI

// MARK: - PrivateTemplateLibraryView

/// Shows the user's private saved templates and allows applying them to new sessions.
/// Templates are stored locally in Documents/templates.json and can be applied with one tap.
///
/// Requirement 54 (Req 43): private template library for one-tap session creation.
struct PrivateTemplateLibraryView: View {

    @Environment(\.dismiss) private var dismiss

    /// Called when the user selects a template to apply.
    let onSelectTemplate: (SessionTemplate) -> Void

    @State private var templates: [SessionTemplate] = []
    @State private var templateToDelete: SessionTemplate?
    @State private var isShowingDeleteConfirmation: Bool = false

    private let service = TemplateLibraryService()

    var body: some View {
        NavigationStack {
            Group {
                if templates.isEmpty {
                    emptyState
                } else {
                    templateList
                }
            }
            .navigationTitle("My Templates")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .accessibilityLabel("Cancel template selection")
                }
            }
            .alert(
                "Delete Template",
                isPresented: $isShowingDeleteConfirmation,
                presenting: templateToDelete
            ) { template in
                Button("Delete", role: .destructive) {
                    service.deleteTemplate(template)
                    templates = service.loadAll().filter { $0.isPrivate }
                }
                .accessibilityLabel("Confirm delete template \(template.name)")
                Button("Cancel", role: .cancel) {}
                    .accessibilityLabel("Cancel delete")
            } message: { template in
                Text("Delete '\(template.name)'? This cannot be undone.")
            }
        }
        .onAppear {
            templates = service.loadAll().filter { $0.isPrivate }
        }
    }

    // MARK: - Template list

    private var templateList: some View {
        List {
            ForEach(templates) { template in
                Button {
                    onSelectTemplate(template)
                    dismiss()
                } label: {
                    templateRow(template)
                }
                .accessibilityLabel("Apply template: \(template.name)")
                .accessibilityHint("Tap to create a new session using this template's object types.")
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        templateToDelete = template
                        isShowingDeleteConfirmation = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Template row

    private func templateRow(_ template: SessionTemplate) -> some View {
        let objectTypes = service.previewObjectTypes(for: template)
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(template.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    if let desc = template.templateDescription, !desc.isEmpty {
                        Text(desc)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                Spacer()
                // Version badge
                Text("v\(template.version)")
                    .font(.caption2.bold())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.accentColor.opacity(0.15)))
                    .foregroundStyle(.accentColor)
            }

            // Object type color swatches preview
            if !objectTypes.isEmpty {
                HStack(spacing: 4) {
                    ForEach(objectTypes.prefix(8), id: \.name) { typeData in
                        Circle()
                            .fill(Color(hex: typeData.colorHex) ?? .accentColor)
                            .frame(width: 10, height: 10)
                            .accessibilityHidden(true)
                    }
                    if objectTypes.count > 8 {
                        Text("+\(objectTypes.count - 8)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("\(objectTypes.count) type\(objectTypes.count == 1 ? "" : "s")")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Text(template.createdAt.formatted(date: .abbreviated, time: .omitted))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "square.stack.3d.up.slash")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text("No Templates Yet")
                .font(.title3.weight(.semibold))
            Text("Save a session's object types as a template to reuse them here.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No templates yet. Save a session's object types as a template to reuse them.")
    }
}

// MARK: - SaveAsTemplateSheet

/// A sheet for saving the current session's object types as a private template.
/// Requirement 54 (Req 43)
struct SaveAsTemplateSheet: View {

    let session: CountSession

    @Environment(\.dismiss) private var dismiss

    @State private var templateName: String = ""
    @State private var templateDescription: String = ""
    @State private var isSaving: Bool = false
    @State private var saveError: String?
    @State private var isShowingError: Bool = false

    private let service = TemplateLibraryService()

    private var isSaveEnabled: Bool {
        !templateName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Template Details") {
                    TextField("Template Name (required)", text: $templateName)
                        .accessibilityLabel("Template name")
                        .accessibilityHint("Required. Enter a name for this template.")

                    TextField("Description (optional)", text: $templateDescription, axis: .vertical)
                        .lineLimit(3...5)
                        .accessibilityLabel("Template description")
                }

                Section("Object Types to Save") {
                    ForEach(session.objectTypes.sorted { $0.sortOrder < $1.sortOrder }) { ot in
                        HStack(spacing: 10) {
                            Circle()
                                .fill(Color(hex: ot.colorHex) ?? .accentColor)
                                .frame(width: 12, height: 12)
                                .accessibilityHidden(true)
                            Image(systemName: ot.iconName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .accessibilityHidden(true)
                            Text(ot.name)
                                .font(.body)
                            if let target = ot.targetCount {
                                Spacer()
                                Text("Target: \(target)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .accessibilityLabel("\(ot.name)\(ot.targetCount.map { ", target \($0)" } ?? "")")
                    }
                }
            }
            .navigationTitle("Save as Template")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .accessibilityLabel("Cancel saving template")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveTemplate()
                    }
                    .disabled(!isSaveEnabled || isSaving)
                    .accessibilityLabel("Save template")
                    .accessibilityHint(isSaveEnabled ? "Saves the template." : "Enter a name to enable.")
                }
            }
            .alert("Save Failed", isPresented: $isShowingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(saveError ?? "Unknown error")
            }
        }
    }

    private func saveTemplate() {
        isSaving = true
        let name = templateName.trimmingCharacters(in: .whitespacesAndNewlines)
        let desc = templateDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            try service.saveAsTemplate(
                name: name,
                description: desc.isEmpty ? nil : desc,
                from: session
            )
            dismiss()
        } catch {
            saveError = error.localizedDescription
            isShowingError = true
            isSaving = false
        }
    }
}

// Color(hex:) is defined in Models/ColorExtensions.swift

// MARK: - Preview

#Preview("Private Template Library") {
    PrivateTemplateLibraryView { template in
        #if DEBUG
        print("Selected: \(template.name)")
        #endif
    }
}
