import SwiftUI

// MARK: - SessionSearchSuggestionsView

/// Shows smart search suggestions when the search bar is active.
/// Suggests object type names from existing sessions.
///
/// Unique to OpenCount — helps users quickly find sessions by object type.
struct SessionSearchSuggestionsView: View {

    let sessions: [CountSession]
    let onSelect: (String) -> Void

    private var objectTypeNames: [String] {
        Array(Set(sessions.flatMap { $0.objectTypes.map(\.name) }))
            .sorted()
            .prefix(8)
            .map { $0 }
    }

    private var recentSessionNames: [String] {
        sessions
            .sorted { $0.modifiedAt > $1.modifiedAt }
            .prefix(3)
            .map(\.name)
    }

    var body: some View {
        List {
            if !recentSessionNames.isEmpty {
                Section("Recent Sessions") {
                    ForEach(recentSessionNames, id: \.self) { name in
                        Button {
                            onSelect(name)
                        } label: {
                            Label(name, systemImage: "clock")
                                .foregroundStyle(.primary)
                        }
                        .accessibilityLabel("Search for \(name)")
                    }
                }
            }

            if !objectTypeNames.isEmpty {
                Section("Object Types") {
                    ForEach(objectTypeNames, id: \.self) { name in
                        Button {
                            onSelect(name)
                        } label: {
                            Label(name, systemImage: "tag")
                                .foregroundStyle(.primary)
                        }
                        .accessibilityLabel("Search for \(name)")
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}
