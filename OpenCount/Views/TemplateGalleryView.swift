import SwiftUI
import SwiftData

// MARK: - TemplateGalleryView

/// Displays the community Template Marketplace backed by the CloudKit public database.
///
/// Features:
/// - Search bar for text filtering (Req 26.3)
/// - Horizontal category filter chips (Req 26.3)
/// - Template list with star ratings and download counts (Req 26.4, 26.6)
/// - Template preview sheet showing Object_Type colors and icons (Req 26.4)
/// - Install button that adds Object_Types to the current session (Req 26.3)
/// - Publish flow for sharing own templates (Req 26.1)
/// - Report flow with reason picker (Req 26.5)
/// - Offline banner and cached template fallback (Req 33.6)
///
/// Requirements: 26.1–26.6, 33.4, 33.6
struct TemplateGalleryView: View {

    // MARK: - Environment

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var networkMonitor: NetworkMonitor

    // MARK: - Dependencies

    /// The session into which templates will be installed.
    let targetSession: CountSession?

    // MARK: - Service

    @StateObject private var service = TemplateMarketplaceService()

    // MARK: - Search & filter state

    @State private var searchQuery: String = ""
    @State private var selectedCategory: TemplateCategory? = nil

    // MARK: - Sheet state

    @State private var selectedTemplate: MarketplaceTemplate? = nil
    @State private var isShowingPreview: Bool = false
    @State private var isShowingPublish: Bool = false
    @State private var templateToReport: MarketplaceTemplate? = nil
    @State private var isShowingReport: Bool = false

    // MARK: - Offline alert state

    @State private var isShowingOfflineAlert: Bool = false

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                categoryFilterBar
                Divider()
                templateListContent
            }
            .navigationTitle("Template Gallery")
            .navigationBarTitleDisplayMode(.large)
            .searchable(
                text: $searchQuery,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search templates"
            )
            .toolbar { toolbarContent }
            .safeAreaInset(edge: .top) {
                OfflineBanner()
                    .environmentObject(networkMonitor)
            }
            .sheet(isPresented: $isShowingPreview) {
                if let template = selectedTemplate {
                    TemplatePreviewSheet(
                        template: template,
                        targetSession: targetSession,
                        service: service,
                        onInstall: { dismiss() }
                    )
                    .environmentObject(networkMonitor)
                }
            }
            .sheet(isPresented: $isShowingPublish) {
                PublishTemplateSheet(
                    targetSession: targetSession,
                    service: service
                )
                .environmentObject(networkMonitor)
            }
            .sheet(isPresented: $isShowingReport) {
                if let template = templateToReport {
                    ReportTemplateSheet(template: template, service: service)
                }
            }
            .offlineFeatureAlert(isPresented: $isShowingOfflineAlert, featureName: "Template Marketplace")
        }
        .task {
            await service.fetchTemplates(query: nil, category: selectedCategory)
        }
        .onChange(of: searchQuery) { _, newValue in
            Task { await service.fetchTemplates(query: newValue, category: selectedCategory) }
        }
        .onChange(of: selectedCategory) { _, newValue in
            Task { await service.fetchTemplates(query: searchQuery.isEmpty ? nil : searchQuery, category: newValue) }
        }
    }

    // MARK: - Category filter chips

    private var categoryFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                // "All" chip
                CategoryChip(
                    title: "All",
                    systemImage: "square.grid.2x2",
                    isSelected: selectedCategory == nil
                ) {
                    selectedCategory = nil
                }

                ForEach(TemplateCategory.allCases) { category in
                    CategoryChip(
                        title: category.rawValue,
                        systemImage: category.systemImage,
                        isSelected: selectedCategory == category
                    ) {
                        selectedCategory = selectedCategory == category ? nil : category
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(Color(.systemGroupedBackground))
        .accessibilityLabel("Category filter")
    }

    // MARK: - Template list

    @ViewBuilder
    private var templateListContent: some View {
        if service.isLoading && service.templates.isEmpty {
            ProgressView("Loading templates…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityLabel("Loading templates")
        } else if service.templates.isEmpty {
            emptyStateView
        } else {
            templateList
        }
    }

    private var templateList: some View {
        List {
            // Offline cached banner
            if !networkMonitor.isConnected && !service.templates.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "clock.arrow.circlepath")
                        .foregroundStyle(.orange)
                        .accessibilityHidden(true)
                    Text("Showing cached templates — connect to see latest")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .listRowBackground(Color.orange.opacity(0.08))
                .accessibilityLabel("Showing cached templates. Connect to the internet to see the latest templates.")
            }

            ForEach(service.templates) { template in
                TemplateRowView(template: template) {
                    selectedTemplate = template
                    isShowingPreview = true
                } onReport: {
                    templateToReport = template
                    isShowingReport = true
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable {
            guard networkMonitor.isConnected else {
                isShowingOfflineAlert = true
                return
            }
            await service.fetchTemplates(
                query: searchQuery.isEmpty ? nil : searchQuery,
                category: selectedCategory
            )
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "square.stack.3d.up.slash")
                .font(.system(size: 52))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text("No Templates Found")
                .font(.title2.weight(.semibold))
            Text(networkMonitor.isConnected
                 ? "Try a different search or category."
                 : "Connect to the internet to browse templates.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button("Close") { dismiss() }
                .accessibilityLabel("Close template gallery")
        }
        ToolbarItem(placement: .primaryAction) {
            Button {
                if networkMonitor.isConnected {
                    isShowingPublish = true
                } else {
                    isShowingOfflineAlert = true
                }
            } label: {
                Label("Publish", systemImage: "square.and.arrow.up")
            }
            .accessibilityLabel("Publish a template")
            .accessibilityHint("Share your Object Types as a community template.")
        }
    }
}

// MARK: - CategoryChip

/// A tappable pill-shaped chip for the category filter bar.
private struct CategoryChip: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: systemImage)
                    .font(.caption.weight(.semibold))
                    .accessibilityHidden(true)
                Text(title)
                    .font(.subheadline.weight(.medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(isSelected ? Color.accentColor : Color(.secondarySystemGroupedBackground))
            )
            .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title) category filter")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .accessibilityHint(isSelected ? "Currently selected. Tap to deselect." : "Tap to filter by \(title).")
    }
}

// MARK: - TemplateRowView

/// A single row in the template list showing name, author, rating, and download count.
private struct TemplateRowView: View {
    let template: MarketplaceTemplate
    let onTap: () -> Void
    let onReport: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                // Name + category badge
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(template.name)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text("by \(template.authorName)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    CategoryBadge(category: template.category)
                }

                // Description
                if !template.templateDescription.isEmpty {
                    Text(template.templateDescription)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                // Object type color swatches preview
                HStack(spacing: 4) {
                    ForEach(template.objectTypes.prefix(8)) { typeData in
                        Circle()
                            .fill(Color(hex: typeData.colorHex) ?? .gray)
                            .frame(width: 14, height: 14)
                            .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 1))
                    }
                    if template.objectTypes.count > 8 {
                        Text("+\(template.objectTypes.count - 8)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .accessibilityLabel("\(template.objectTypes.count) object types")

                // Rating + download count
                HStack(spacing: 12) {
                    StarRatingView(rating: template.averageRating, ratingCount: template.ratingCount)
                    Spacer()
                    Label("\(template.downloadCount)", systemImage: "arrow.down.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("\(template.downloadCount) downloads")
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(template.name) template by \(template.authorName). \(template.objectTypes.count) object types. \(formattedRating) stars. \(template.downloadCount) downloads.")
        .accessibilityHint("Tap to preview and install this template.")
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive, action: onReport) {
                Label("Report", systemImage: "flag")
            }
            .accessibilityLabel("Report \(template.name)")
        }
        .contextMenu {
            Button(role: .destructive, action: onReport) {
                Label("Report Template", systemImage: "flag")
            }
        }
    }

    private var formattedRating: String {
        String(format: "%.1f", template.averageRating)
    }
}

// MARK: - CategoryBadge

private struct CategoryBadge: View {
    let category: TemplateCategory

    var body: some View {
        Label(category.rawValue, systemImage: category.systemImage)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(Color.accentColor.opacity(0.12)))
            .foregroundStyle(Color.accentColor)
            .accessibilityLabel("Category: \(category.rawValue)")
    }
}

// MARK: - StarRatingView

/// Displays a row of filled/half/empty stars with an optional rating count.
struct StarRatingView: View {
    let rating: Double
    let ratingCount: Int

    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { star in
                Image(systemName: starImageName(for: star))
                    .font(.caption)
                    .foregroundStyle(rating >= Double(star) - 0.25 ? Color.yellow : Color(.systemFill))
                    .accessibilityHidden(true)
            }
            if ratingCount > 0 {
                Text("(\(ratingCount))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(ratingCount > 0
            ? String(format: "%.1f stars from %d ratings", rating, ratingCount)
            : "No ratings yet")
    }

    private func starImageName(for star: Int) -> String {
        let value = rating - Double(star - 1)
        if value >= 0.75 { return "star.fill" }
        if value >= 0.25 { return "star.leadinghalf.filled" }
        return "star"
    }
}

// MARK: - TemplatePreviewSheet

/// Full preview of a template showing all Object_Type colors and icons before install.
/// Requirements: 26.3, 26.4, 26.5
struct TemplatePreviewSheet: View {

    let template: MarketplaceTemplate
    let targetSession: CountSession?
    let service: TemplateMarketplaceService
    let onInstall: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var networkMonitor: NetworkMonitor

    @State private var userRating: Int = 0
    @State private var isInstalling: Bool = false
    @State private var isRating: Bool = false
    @State private var installError: String? = nil
    @State private var isShowingOfflineAlert: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    headerSection
                    Divider()
                    objectTypesSection
                    Divider()
                    ratingSection
                }
                .padding()
            }
            .navigationTitle(template.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .accessibilityLabel("Cancel preview")
                }
                ToolbarItem(placement: .primaryAction) {
                    installButton
                }
            }
            .alert("Install Error", isPresented: Binding(
                get: { installError != nil },
                set: { if !$0 { installError = nil } }
            )) {
                Button("OK", role: .cancel) { installError = nil }
            } message: {
                Text(installError ?? "")
            }
            .offlineFeatureAlert(isPresented: $isShowingOfflineAlert, featureName: "Rating")
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                CategoryBadge(category: template.category)
                Spacer()
                StarRatingView(rating: template.averageRating, ratingCount: template.ratingCount)
            }
            Text("by \(template.authorName)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if !template.templateDescription.isEmpty {
                Text(template.templateDescription)
                    .font(.body)
            }
            Label("\(template.downloadCount) downloads", systemImage: "arrow.down.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityLabel("\(template.downloadCount) downloads")
        }
    }

    // MARK: - Object types preview

    private var objectTypesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Object Types (\(template.objectTypes.count))")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 140), spacing: 12)],
                spacing: 12
            ) {
                ForEach(template.objectTypes) { typeData in
                    ObjectTypePreviewCard(typeData: typeData)
                }
            }
        }
    }

    // MARK: - Rating section

    private var ratingSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Rate This Template")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)

            HStack(spacing: 8) {
                ForEach(1...5, id: \.self) { star in
                    Button {
                        submitRating(star)
                    } label: {
                        Image(systemName: star <= userRating ? "star.fill" : "star")
                            .font(.title2)
                            .foregroundStyle(star <= userRating ? Color.yellow : Color(.systemFill))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(star) star\(star == 1 ? "" : "s")")
                    .accessibilityAddTraits(star == userRating ? [.isSelected] : [])
                    .accessibilityHint("Tap to rate this template \(star) star\(star == 1 ? "" : "s").")
                }
                if isRating {
                    ProgressView()
                        .padding(.leading, 4)
                }
            }
        }
    }

    // MARK: - Install button

    private var installButton: some View {
        Group {
            if isInstalling {
                ProgressView()
            } else {
                Button {
                    guard let session = targetSession else { return }
                    Task { await install(into: session) }
                } label: {
                    Label("Install", systemImage: "plus.circle.fill")
                }
                .disabled(targetSession == nil)
                .accessibilityLabel("Install template")
                .accessibilityHint(targetSession == nil
                    ? "No session selected."
                    : "Adds this template's Object Types to the current session.")
            }
        }
    }

    // MARK: - Actions

    private func install(into session: CountSession) async {
        isInstalling = true
        do {
            try await service.installTemplate(template, into: session, context: modelContext)
            dismiss()
            onInstall()
        } catch {
            installError = error.localizedDescription
        }
        isInstalling = false
    }

    private func submitRating(_ stars: Int) {
        guard networkMonitor.isConnected else {
            isShowingOfflineAlert = true
            return
        }
        userRating = stars
        isRating = true
        Task {
            do {
                try await service.rateTemplate(template, rating: stars)
            } catch {
                // Non-critical; rating failure is silent
            }
            isRating = false
        }
    }
}

// MARK: - ObjectTypePreviewCard

/// A card showing a single Object_Type's color swatch and icon before install.
private struct ObjectTypePreviewCard: View {
    let typeData: MarketplaceObjectTypeData

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color(hex: typeData.colorHex) ?? .gray)
                    .frame(width: 36, height: 36)
                Image(systemName: typeData.iconName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .accessibilityHidden(true)
            }
            Text(typeData.name)
                .font(.subheadline)
                .lineLimit(2)
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(typeData.name) object type")
    }
}

// MARK: - PublishTemplateSheet

/// Allows the user to publish their Object_Types as a new marketplace template.
/// Requirements: 26.1
struct PublishTemplateSheet: View {

    let targetSession: CountSession?
    let service: TemplateMarketplaceService

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var networkMonitor: NetworkMonitor

    @State private var templateName: String = ""
    @State private var templateDescription: String = ""
    @State private var selectedCategory: TemplateCategory = .other
    @State private var authorName: String = ""
    @State private var isPublishing: Bool = false
    @State private var publishError: String? = nil
    @State private var isShowingOfflineAlert: Bool = false

    private var canPublish: Bool {
        !templateName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !authorName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !(targetSession?.objectTypes.isEmpty ?? true)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Template Details") {
                    TextField("Template Name", text: $templateName)
                        .accessibilityLabel("Template name")
                        .accessibilityHint("Required. Enter a name for your template.")

                    TextField("Description (optional)", text: $templateDescription, axis: .vertical)
                        .lineLimit(3...6)
                        .accessibilityLabel("Template description")
                        .accessibilityHint("Optional. Describe what this template is used for.")

                    TextField("Your Name", text: $authorName)
                        .accessibilityLabel("Author name")
                        .accessibilityHint("Required. Enter your display name.")

                    Picker("Category", selection: $selectedCategory) {
                        ForEach(TemplateCategory.allCases) { category in
                            Label(category.rawValue, systemImage: category.systemImage)
                                .tag(category)
                        }
                    }
                    .accessibilityLabel("Template category")
                }

                if let session = targetSession, !session.objectTypes.isEmpty {
                    Section("Object Types to Publish (\(session.objectTypes.count))") {
                        ForEach(session.objectTypes.sorted(by: { $0.sortOrder < $1.sortOrder })) { objectType in
                            HStack(spacing: 10) {
                                ZStack {
                                    Circle()
                                        .fill(Color(hex: objectType.colorHex) ?? .gray)
                                        .frame(width: 28, height: 28)
                                    Image(systemName: objectType.iconName)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(.white)
                                        .accessibilityHidden(true)
                                }
                                Text(objectType.name)
                                    .font(.subheadline)
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel(objectType.name)
                        }
                    }
                } else {
                    Section {
                        Text("No Object Types in the current session. Add Object Types before publishing.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                if let error = publishError {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.subheadline)
                    }
                }
            }
            .navigationTitle("Publish Template")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .accessibilityLabel("Cancel publishing")
                }
                ToolbarItem(placement: .primaryAction) {
                    if isPublishing {
                        ProgressView()
                    } else {
                        Button("Publish") {
                            if networkMonitor.isConnected {
                                Task { await publish() }
                            } else {
                                isShowingOfflineAlert = true
                            }
                        }
                        .disabled(!canPublish)
                        .fontWeight(.semibold)
                        .accessibilityLabel("Publish template")
                        .accessibilityHint(canPublish
                            ? "Publishes your Object Types to the community marketplace."
                            : "Fill in all required fields to enable publishing.")
                    }
                }
            }
            .offlineFeatureAlert(isPresented: $isShowingOfflineAlert, featureName: "Publish Template")
        }
    }

    private func publish() async {
        guard let session = targetSession else { return }
        isPublishing = true
        publishError = nil
        do {
            try await service.publishTemplate(
                name: templateName.trimmingCharacters(in: .whitespacesAndNewlines),
                description: templateDescription.trimmingCharacters(in: .whitespacesAndNewlines),
                category: selectedCategory,
                objectTypes: session.objectTypes,
                authorName: authorName.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            dismiss()
        } catch {
            publishError = error.localizedDescription
        }
        isPublishing = false
    }
}

// MARK: - ReportTemplateSheet

/// Presents a reason picker and submits a report to CloudKit.
/// Requirements: 26.5
struct ReportTemplateSheet: View {

    let template: MarketplaceTemplate
    let service: TemplateMarketplaceService

    @Environment(\.dismiss) private var dismiss

    @State private var selectedReason: ReportReason = .inappropriate
    @State private var isSubmitting: Bool = false
    @State private var reportError: String? = nil
    @State private var didSubmit: Bool = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Why are you reporting this template?") {
                    ForEach(ReportReason.allCases) { reason in
                        Button {
                            selectedReason = reason
                        } label: {
                            HStack {
                                Text(reason.rawValue)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if selectedReason == reason {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.accentColor)
                                        .accessibilityHidden(true)
                                }
                            }
                        }
                        .accessibilityLabel(reason.rawValue)
                        .accessibilityAddTraits(selectedReason == reason ? [.isSelected] : [])
                    }
                }

                if let error = reportError {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.subheadline)
                    }
                }

                if didSubmit {
                    Section {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .accessibilityHidden(true)
                            Text("Report submitted. Thank you.")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Report Template")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .accessibilityLabel("Cancel report")
                }
                ToolbarItem(placement: .primaryAction) {
                    if isSubmitting {
                        ProgressView()
                    } else if didSubmit {
                        Button("Done") { dismiss() }
                            .accessibilityLabel("Done")
                    } else {
                        Button("Submit") {
                            Task { await submitReport() }
                        }
                        .fontWeight(.semibold)
                        .accessibilityLabel("Submit report")
                        .accessibilityHint("Reports this template for \(selectedReason.rawValue).")
                    }
                }
            }
        }
    }

    private func submitReport() async {
        isSubmitting = true
        reportError = nil
        do {
            try await service.reportTemplate(template, reason: selectedReason)
            didSubmit = true
        } catch {
            reportError = error.localizedDescription
        }
        isSubmitting = false
    }
}

// Color(hex:) is defined in Models/ColorExtensions.swift

// MARK: - Preview

#Preview("Template Gallery") {
    TemplateGalleryView(targetSession: nil)
        .environmentObject(NetworkMonitor())
        .modelContainer(
            for: [CountSession.self, ObjectType.self, CountMarker.self,
                  CountRegion.self, SessionImage.self, VideoFrameCount.self],
            inMemory: true
        )
}
