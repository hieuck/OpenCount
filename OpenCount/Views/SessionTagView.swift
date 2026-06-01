import SwiftUI
import SwiftData

// MARK: - SessionTagManagerView

/// Manages tags for a counting session.
/// Users can create, assign, and remove tags to organize sessions.
///
/// This feature surpasses ZapCount and CountThings which offer no session organization.
struct SessionTagManagerView: View {

    let session: CountSession
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \SessionTag.createdAt, order: .reverse)
    private var allTags: [SessionTag]

    @State private var isAddingTag: Bool = false
    @State private var newTagName: String = ""
    @State private var newTagColorHex: String = "#3498DB"
    @State private var newTagEmoji: String = "🏷️"

    // Session tags stored as a JSON-encoded array of UUIDs in session description
    // (lightweight approach without adding a new relationship)
    @State private var assignedTagIDs: Set<UUID> = []

    var body: some View {
        NavigationStack {
            List {
                if !allTags.isEmpty {
                    Section("Assign Tags") {
                        ForEach(allTags) { tag in
                            TagRow(
                                tag: tag,
                                isAssigned: assignedTagIDs.contains(tag.id)
                            ) {
                                toggleTag(tag)
                            }
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                let tag = allTags[index]
                                assignedTagIDs.remove(tag.id)
                                modelContext.delete(tag)
                            }
                            try? modelContext.save()
                            saveAssignedTags()
                        }
                    }
                }

                Section("Create New Tag") {
                    TextField("Tag name", text: $newTagName)
                        .accessibilityLabel("New tag name")

                    HStack {
                        Text("Color")
                        Spacer()
                        ColorPicker("", selection: Binding(
                            get: { Color(hex: newTagColorHex) ?? .blue },
                            set: { newTagColorHex = $0.hexString ?? "#3498DB" }
                        ), supportsOpacity: false)
                        .labelsHidden()
                    }

                    HStack {
                        Text("Emoji")
                        Spacer()
                        TextField("🏷️", text: $newTagEmoji)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 50)
                    }

                    Button {
                        createTag()
                    } label: {
                        Label("Create Tag", systemImage: "plus.circle.fill")
                    }
                    .disabled(newTagName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityLabel("Create new tag")
                }

                if !SessionTag.predefinedTags.isEmpty {
                    Section("Quick Add") {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(SessionTag.predefinedTags, id: \.name) { preset in
                                    Button {
                                        let tag = SessionTag(
                                            name: preset.name,
                                            colorHex: preset.colorHex,
                                            emoji: preset.emoji
                                        )
                                        modelContext.insert(tag)
                                        try? modelContext.save()
                                        assignedTagIDs.insert(tag.id)
                                        saveAssignedTags()
                                    } label: {
                                        HStack(spacing: 4) {
                                            Text(preset.emoji)
                                            Text(preset.name)
                                                .font(.caption.weight(.medium))
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(
                                            Capsule()
                                                .fill(Color(hex: preset.colorHex)?.opacity(0.15) ?? Color.blue.opacity(0.15))
                                        )
                                        .overlay(
                                            Capsule()
                                                .stroke(Color(hex: preset.colorHex) ?? .blue, lineWidth: 1)
                                        )
                                        .foregroundStyle(Color(hex: preset.colorHex) ?? .blue)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("Add \(preset.name) tag")
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Tags")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .onAppear {
            loadAssignedTags()
        }
    }

    // MARK: - Actions

    private func toggleTag(_ tag: SessionTag) {
        if assignedTagIDs.contains(tag.id) {
            assignedTagIDs.remove(tag.id)
        } else {
            assignedTagIDs.insert(tag.id)
        }
        saveAssignedTags()
    }

    private func createTag() {
        let name = newTagName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }

        let tag = SessionTag(
            name: name,
            colorHex: newTagColorHex,
            emoji: newTagEmoji.isEmpty ? "🏷️" : String(newTagEmoji.prefix(2))
        )
        modelContext.insert(tag)
        try? modelContext.save()

        assignedTagIDs.insert(tag.id)
        saveAssignedTags()

        newTagName = ""
        newTagEmoji = "🏷️"
    }

    // MARK: - Persistence (stored in UserDefaults keyed by session ID)

    private func loadAssignedTags() {
        let key = "session_tags_\(session.id.uuidString)"
        if let data = UserDefaults.standard.data(forKey: key),
           let ids = try? JSONDecoder().decode([UUID].self, from: data) {
            assignedTagIDs = Set(ids)
        }
    }

    private func saveAssignedTags() {
        let key = "session_tags_\(session.id.uuidString)"
        if let data = try? JSONEncoder().encode(Array(assignedTagIDs)) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}

// MARK: - TagRow

private struct TagRow: View {
    let tag: SessionTag
    let isAssigned: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                Text(tag.emoji)
                    .font(.title3)
                    .accessibilityHidden(true)

                Text(tag.name)
                    .font(.subheadline)
                    .foregroundStyle(.primary)

                Spacer()

                if isAssigned {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.accentColor)
                        .accessibilityHidden(true)
                } else {
                    Image(systemName: "circle")
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(tag.emoji) \(tag.name)")
        .accessibilityAddTraits(isAssigned ? [.isSelected] : [])
        .accessibilityHint("Tap to \(isAssigned ? "remove" : "assign") this tag.")
    }
}

// MARK: - TagChipsView

/// A compact horizontal strip of tag chips for display in session rows.
struct TagChipsView: View {
    let sessionID: UUID

    @Query(sort: \SessionTag.createdAt)
    private var allTags: [SessionTag]

    private var assignedTags: [SessionTag] {
        let key = "session_tags_\(sessionID.uuidString)"
        guard let data = UserDefaults.standard.data(forKey: key),
              let ids = try? JSONDecoder().decode([UUID].self, from: data) else {
            return []
        }
        let idSet = Set(ids)
        return allTags.filter { idSet.contains($0.id) }
    }

    var body: some View {
        if !assignedTags.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(assignedTags) { tag in
                        HStack(spacing: 3) {
                            Text(tag.emoji)
                                .font(.caption2)
                            Text(tag.name)
                                .font(.caption2.weight(.medium))
                        }
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(Color(hex: tag.colorHex)?.opacity(0.15) ?? Color.blue.opacity(0.15))
                        )
                        .overlay(
                            Capsule()
                                .stroke(Color(hex: tag.colorHex) ?? .blue, lineWidth: 0.5)
                        )
                        .foregroundStyle(Color(hex: tag.colorHex) ?? .blue)
                        .accessibilityLabel(tag.name)
                    }
                }
            }
        }
    }
}
