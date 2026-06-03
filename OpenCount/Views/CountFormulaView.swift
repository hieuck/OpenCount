import SwiftUI

// MARK: - CountFormulaView

/// Displays and manages custom counting formulas for a session.
///
/// Users can define formulas like "Adults + Juveniles" or "Males / (Males + Females)"
/// that compute derived values from the current tallies in real time.
///
/// This feature is unique to OpenCount — neither ZapCount nor CountThings
/// support custom counting formulas.
struct CountFormulaView: View {

    let session: CountSession
    @ObservedObject var viewModel: CountingViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var formulas: [CountFormula] = []
    @State private var isAddingFormula: Bool = false
    @State private var formulaToEdit: CountFormula? = nil

    // MARK: - Computed tally

    private var tallyByName: [String: Int] {
        var result: [String: Int] = [:]
        for type in session.objectTypes {
            let count = viewModel.markers.filter { $0.objectType.id == type.id }.count
            result[type.name] = count
        }
        return result
    }

    var body: some View {
        NavigationStack {
            Group {
                if formulas.isEmpty {
                    emptyState
                } else {
                    formulaList
                }
            }
            .navigationTitle("Count Formulas")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isAddingFormula = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add formula")
                }
            }
            .sheet(isPresented: $isAddingFormula) {
                FormulaEditorSheet(session: session) { formula in
                    formulas.append(formula)
                    session.formulas.append(formula)
                    Task { try? await StorageService.shared.save(session) }
                }
            }
            .sheet(item: $formulaToEdit) { formula in
                FormulaEditorSheet(session: session, existingFormula: formula) { updated in
                    if let index = formulas.firstIndex(where: { $0.id == updated.id }) {
                        formulas[index] = updated
                    }
                    Task { try? await StorageService.shared.save(session) }
                }
            }
        }
        .onAppear {
            loadFormulas()
        }
    }

    // MARK: - Formula list

    private var formulaList: some View {
        List {
            Section {
                ForEach(formulas.sorted { $0.sortOrder < $1.sortOrder }) { formula in
                    FormulaRow(
                        formula: formula,
                        result: FormulaEvaluator.evaluate(formula: formula, tally: tallyByName)
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        formulaToEdit = formula
                    }
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        let formula = formulas[index]
                        session.formulas.removeAll { $0.id == formula.id }
                        formulas.remove(at: index)
                    }
                    Task { try? await StorageService.shared.save(session) }
                }
            } header: {
                Text("Formulas update in real time as you count.")
                    .font(.caption)
                    .textCase(nil)
            }

            Section("Available Variables") {
                ForEach(session.objectTypes.sorted { $0.sortOrder < $1.sortOrder }) { type in
                    HStack(spacing: 10) {
                        Circle()
                            .fill(Color(hex: type.colorHex) ?? .accentColor)
                            .frame(width: 10, height: 10)
                            .accessibilityHidden(true)
                        Text(type.name)
                            .font(.subheadline)
                        Spacer()
                        Text("\(tallyByName[type.name] ?? 0)")
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(type.name): \(tallyByName[type.name] ?? 0)")
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "function")
                .font(.system(size: 52))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text("No Formulas")
                .font(.title2.weight(.semibold))
            Text("Create formulas to compute derived values from your counts.\n\nExample: \"Adults + Juveniles\" or \"Males / (Males + Females)\"")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button {
                isAddingFormula = true
            } label: {
                Label("Add Formula", systemImage: "plus.circle.fill")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityLabel("Add your first formula")
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Load

    private func loadFormulas() {
        formulas = session.formulas.sorted { $0.sortOrder < $1.sortOrder }
    }
}

// MARK: - FormulaRow

private struct FormulaRow: View {
    let formula: CountFormula
    let result: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(formula.name)
                    .font(.headline)
                Spacer()
                if let result {
                    Text(formattedResult(result))
                        .font(.title3.monospacedDigit().weight(.bold))
                        .foregroundStyle(.accentColor)
                } else {
                    Text("—")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 4) {
                Text(formula.expression)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                if !formula.unit.isEmpty {
                    Text("[\(formula.unit)]")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(formula.name): \(result.map { formattedResult($0) } ?? "invalid expression")\(formula.unit.isEmpty ? "" : " \(formula.unit)")")
    }

    private func formattedResult(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", value)
        }
        return String(format: "%.3f", value)
    }
}

// MARK: - FormulaEditorSheet

struct FormulaEditorSheet: View {

    let session: CountSession
    var existingFormula: CountFormula? = nil
    let onSave: (CountFormula) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var expression: String = ""
    @State private var unit: String = ""
    @State private var previewResult: Double? = nil
    @State private var expressionError: Bool = false

    private var tallyByName: [String: Int] {
        var result: [String: Int] = [:]
        for type in session.objectTypes {
            result[type.name] = 0 // Preview with zero counts
        }
        return result
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !expression.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Formula Details") {
                    TextField("Name (e.g. Sex Ratio)", text: $name)
                        .accessibilityLabel("Formula name")

                    VStack(alignment: .leading, spacing: 6) {
                        TextField("Expression (e.g. Males / (Males + Females))", text: $expression, axis: .vertical)
                            .lineLimit(2...4)
                            .font(.system(.body, design: .monospaced))
                            .onChange(of: expression) { _ in
                                validateExpression()
                            }
                            .accessibilityLabel("Formula expression")

                        if expressionError {
                            Label("Invalid expression", systemImage: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundStyle(.red)
                        } else if let result = previewResult {
                            Label("Preview (with zero counts): \(formattedResult(result))", systemImage: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.green)
                        }
                    }

                    TextField("Unit (optional, e.g. %)", text: $unit)
                        .accessibilityLabel("Unit label")
                }

                Section("Available Variables") {
                    ForEach(session.objectTypes.sorted { $0.sortOrder < $1.sortOrder }) { type in
                        Button {
                            insertVariable(type.name)
                        } label: {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(Color(hex: type.colorHex) ?? .accentColor)
                                    .frame(width: 10, height: 10)
                                    .accessibilityHidden(true)
                                Text(type.name)
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: "plus.circle")
                                    .foregroundStyle(.accentColor)
                                    .font(.caption)
                            }
                        }
                        .accessibilityLabel("Insert \(type.name) variable")
                        .accessibilityHint("Tap to insert \(type.name) into the expression.")
                    }
                }

                Section("Examples") {
                    exampleRow("Sum", "Adults + Juveniles")
                    exampleRow("Ratio", "Males / (Males + Females)")
                    exampleRow("Percentage", "(Infected / Total) * 100", unit: "%")
                    exampleRow("Weighted", "Large * 3 + Small * 1")
                }
            }
            .navigationTitle(existingFormula == nil ? "New Formula" : "Edit Formula")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!canSave)
                        .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            if let formula = existingFormula {
                name = formula.name
                expression = formula.expression
                unit = formula.unit
                validateExpression()
            }
        }
    }

    private func exampleRow(_ label: String, _ expr: String, unit: String = "") -> some View {
        Button {
            expression = expr
            if !unit.isEmpty { self.unit = unit }
            validateExpression()
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                Text(expr)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityLabel("Use \(label) example: \(expr)")
    }

    private func insertVariable(_ name: String) {
        if expression.isEmpty {
            expression = name
        } else {
            expression += " + \(name)"
        }
        validateExpression()
    }

    private func validateExpression() {
        let testFormula = CountFormula(name: "test", expression: expression)
        let result = FormulaEvaluator.evaluate(formula: testFormula, tally: tallyByName)
        previewResult = result
        expressionError = result == nil && !expression.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func save() {
        let formula: CountFormula
        if let existing = existingFormula {
            existing.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
            existing.expression = expression.trimmingCharacters(in: .whitespacesAndNewlines)
            existing.unit = unit.trimmingCharacters(in: .whitespacesAndNewlines)
            formula = existing
        } else {
            formula = CountFormula(
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                expression: expression.trimmingCharacters(in: .whitespacesAndNewlines),
                unit: unit.trimmingCharacters(in: .whitespacesAndNewlines),
                sortOrder: 0,
                session: session
            )
        }
        onSave(formula)
        dismiss()
    }

    private func formattedResult(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", value)
        }
        return String(format: "%.3f", value)
    }
}
