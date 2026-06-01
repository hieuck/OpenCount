import SwiftUI

// MARK: - AnnotationLayerView

/// Renders all advanced annotation layers (text labels, measure lines, arrows)
/// on top of the image canvas.
///
/// Requirements: 34.1–34.4
struct AnnotationLayerView: View {

    @ObservedObject var viewModel: AnnotationLayerViewModel
    let canvasSize: CGSize

    var body: some View {
        ZStack {
            // Measure lines layer
            if viewModel.isVisible(.measureLines) {
                ForEach(viewModel.measureLines) { line in
                    MeasureLineView(line: line, canvasSize: canvasSize)
                        .onLongPressGesture {
                            viewModel.removeMeasureLine(id: line.id)
                        }
                }
            }

            // Arrow annotations layer
            if viewModel.isVisible(.arrows) {
                ForEach(viewModel.arrowAnnotations) { arrow in
                    ArrowAnnotationView(arrow: arrow, canvasSize: canvasSize)
                        .onLongPressGesture {
                            viewModel.removeArrow(id: arrow.id)
                        }
                }
            }

            // Text labels layer
            if viewModel.isVisible(.textLabels) {
                ForEach(viewModel.textAnnotations) { annotation in
                    TextAnnotationView(
                        annotation: annotation,
                        canvasSize: canvasSize,
                        onUpdate: { viewModel.updateTextAnnotation($0) },
                        onDelete: { viewModel.removeTextAnnotation(id: annotation.id) }
                    )
                }
            }
        }
        .allowsHitTesting(true)
    }
}

// MARK: - MeasureLineView

/// Renders a measurement line with a length label at the midpoint.
/// Requirement 34.2
struct MeasureLineView: View {

    let line: MeasureLine
    let canvasSize: CGSize

    private var startPt: CGPoint {
        CGPoint(x: line.startPoint.x * canvasSize.width,
                y: line.startPoint.y * canvasSize.height)
    }

    private var endPt: CGPoint {
        CGPoint(x: line.endPoint.x * canvasSize.width,
                y: line.endPoint.y * canvasSize.height)
    }

    private var midPt: CGPoint {
        CGPoint(x: (startPt.x + endPt.x) / 2,
                y: (startPt.y + endPt.y) / 2)
    }

    private var lineColor: Color {
        Color(hex: line.colorHex) ?? .yellow
    }

    var body: some View {
        ZStack {
            // Line with end caps
            Canvas { context, _ in
                var path = Path()
                path.move(to: startPt)
                path.addLine(to: endPt)
                context.stroke(path, with: .color(lineColor), lineWidth: 2)

                context.fill(
                    Path(ellipseIn: CGRect(x: startPt.x - 4, y: startPt.y - 4, width: 8, height: 8)),
                    with: .color(lineColor)
                )
                context.fill(
                    Path(ellipseIn: CGRect(x: endPt.x - 4, y: endPt.y - 4, width: 8, height: 8)),
                    with: .color(lineColor)
                )
            }
            .frame(width: canvasSize.width, height: canvasSize.height)
            .allowsHitTesting(false)

            // Length label at midpoint — "X.XXX u" per Requirement 34.2
            Text(String(format: "%.3f u", line.normalizedLength))
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Capsule().fill(lineColor.opacity(0.85)))
                .position(midPt)
        }
        .accessibilityLabel(
            "Measurement line, length \(String(format: "%.3f", line.normalizedLength)) units. Long press to delete."
        )
    }
}

// MARK: - ArrowAnnotationView

/// Renders an arrow annotation with a filled arrowhead at the head point.
/// Requirement 34.3
struct ArrowAnnotationView: View {

    let arrow: ArrowAnnotation
    let canvasSize: CGSize

    private var tailPt: CGPoint {
        CGPoint(x: arrow.tailPoint.x * canvasSize.width,
                y: arrow.tailPoint.y * canvasSize.height)
    }

    private var headPt: CGPoint {
        CGPoint(x: arrow.headPoint.x * canvasSize.width,
                y: arrow.headPoint.y * canvasSize.height)
    }

    private var arrowColor: Color {
        Color(hex: arrow.colorHex) ?? .red
    }

    var body: some View {
        Canvas { context, _ in
            let dx = headPt.x - tailPt.x
            let dy = headPt.y - tailPt.y
            let length = sqrt(dx * dx + dy * dy)
            guard length > 0 else { return }

            let ux = dx / length
            let uy = dy / length

            // Shaft — stops short of the head so the arrowhead tip is clean
            var shaft = Path()
            shaft.move(to: tailPt)
            shaft.addLine(to: CGPoint(x: headPt.x - ux * 12, y: headPt.y - uy * 12))
            context.stroke(shaft, with: .color(arrowColor), lineWidth: 2.5)

            // Filled arrowhead triangle
            let perpX = -uy * 6
            let perpY = ux * 6
            var head = Path()
            head.move(to: headPt)
            head.addLine(to: CGPoint(x: headPt.x - ux * 14 + perpX,
                                     y: headPt.y - uy * 14 + perpY))
            head.addLine(to: CGPoint(x: headPt.x - ux * 14 - perpX,
                                     y: headPt.y - uy * 14 - perpY))
            head.closeSubpath()
            context.fill(head, with: .color(arrowColor))
        }
        .frame(width: canvasSize.width, height: canvasSize.height)
        .accessibilityLabel("Arrow annotation. Long press to delete.")
    }
}

// MARK: - TextAnnotationView

/// Renders a draggable, tappable text label on the canvas.
/// Tap once to select and reveal the inline editor with font size and color pickers.
/// Requirement 34.1
struct TextAnnotationView: View {

    let annotation: TextAnnotation
    let canvasSize: CGSize
    let onUpdate: (TextAnnotation) -> Void
    let onDelete: () -> Void

    @State private var isEditing: Bool = false
    @State private var editText: String = ""
    @State private var editFontSize: CGFloat = 16
    @State private var editColor: Color = .white
    @State private var dragOffset: CGSize = .zero

    // Available font sizes for the picker
    private let fontSizes: [CGFloat] = [12, 14, 16, 18, 20, 24, 28, 32, 36]

    private var position: CGPoint {
        CGPoint(
            x: annotation.normalizedPosition.x * canvasSize.width + dragOffset.width,
            y: annotation.normalizedPosition.y * canvasSize.height + dragOffset.height
        )
    }

    private var labelColor: Color {
        Color(hex: annotation.colorHex) ?? .white
    }

    var body: some View {
        Group {
            if isEditing {
                inlineEditor
            } else {
                labelView
            }
        }
        .position(position)
        .gesture(dragGesture)
    }

    // MARK: - Label (non-editing)

    private var labelView: some View {
        Text(annotation.text)
            .font(.system(size: annotation.fontSize, weight: .semibold))
            .foregroundStyle(labelColor)
            .padding(4)
            .background(RoundedRectangle(cornerRadius: 4).fill(Color.black.opacity(0.4)))
            .shadow(radius: 2)
            .onTapGesture {
                editText = annotation.text
                editFontSize = annotation.fontSize
                editColor = Color(hex: annotation.colorHex) ?? .white
                isEditing = true
            }
            .contextMenu {
                Button(role: .destructive) { onDelete() } label: {
                    Label("Delete Label", systemImage: "trash")
                }
            }
            .accessibilityLabel("Text label: \(annotation.text). Tap to edit. Long press for options.")
    }

    // MARK: - Inline editor

    private var inlineEditor: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Text field
            TextField("Label", text: $editText)
                .font(.system(size: editFontSize, weight: .semibold))
                .foregroundStyle(editColor)
                .padding(4)
                .background(RoundedRectangle(cornerRadius: 4).fill(Color.black.opacity(0.5)))
                .frame(minWidth: 120)
                .submitLabel(.done)
                .onSubmit { commitEdit() }

            // Font size picker
            HStack(spacing: 4) {
                Image(systemName: "textformat.size")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                Picker("Size", selection: $editFontSize) {
                    ForEach(fontSizes, id: \.self) { size in
                        Text("\(Int(size))").tag(size)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .accessibilityLabel("Font size")
            }

            // Color picker
            HStack(spacing: 4) {
                Image(systemName: "paintpalette")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                ColorPicker("Color", selection: $editColor, supportsOpacity: false)
                    .labelsHidden()
                    .accessibilityLabel("Label color")
            }

            // Done / Cancel buttons
            HStack(spacing: 8) {
                Button("Done") { commitEdit() }
                    .font(.caption.bold())
                    .buttonStyle(.borderedProminent)
                    .controlSize(.mini)
                    .accessibilityLabel("Confirm label edit")

                Button("Cancel") { isEditing = false }
                    .font(.caption)
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                    .accessibilityLabel("Cancel label edit")
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.ultraThinMaterial)
                .shadow(radius: 4)
        )
    }

    // MARK: - Helpers

    private func commitEdit() {
        var updated = annotation
        updated.text = editText.isEmpty ? annotation.text : editText
        updated.fontSize = editFontSize
        updated.colorHex = editColor.toHex() ?? annotation.colorHex
        onUpdate(updated)
        isEditing = false
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                dragOffset = value.translation
            }
            .onEnded { value in
                var updated = annotation
                let newX = (annotation.normalizedPosition.x * canvasSize.width + value.translation.width) / canvasSize.width
                let newY = (annotation.normalizedPosition.y * canvasSize.height + value.translation.height) / canvasSize.height
                updated.normalizedPosition = CGPoint(
                    x: max(0, min(1, newX)),
                    y: max(0, min(1, newY))
                )
                onUpdate(updated)
                dragOffset = .zero
            }
    }
}

// MARK: - LayerPanelView

/// A slide-in panel listing all annotation layer types with eye-icon toggles,
/// item counts, and an active tool selector.
/// Requirement 34.5
struct LayerPanelView: View {

    @ObservedObject var viewModel: AnnotationLayerViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                // MARK: Annotation Layers section
                Section("Annotation Layers") {
                    ForEach(AnnotationLayerType.allCases) { layer in
                        HStack(spacing: 12) {
                            Image(systemName: layer.systemImage)
                                .foregroundStyle(.secondary)
                                .frame(width: 24)
                                .accessibilityHidden(true)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(layer.rawValue)
                                    .font(.body)
                                Text(itemCountLabel(for: layer))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Button {
                                viewModel.toggleLayer(layer)
                            } label: {
                                Image(systemName: viewModel.isVisible(layer) ? "eye.fill" : "eye.slash")
                                    .foregroundStyle(viewModel.isVisible(layer) ? .accentColor : .secondary)
                                    .imageScale(.medium)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(
                                viewModel.isVisible(layer)
                                    ? "Hide \(layer.rawValue) layer"
                                    : "Show \(layer.rawValue) layer"
                            )
                        }
                        .padding(.vertical, 2)
                    }
                }

                // MARK: Active Tool section
                Section("Active Tool") {
                    toolRow(tool: .none, name: "None", icon: "hand.tap")
                    toolRow(tool: .textLabel, name: "Text Label", icon: "textformat")
                    toolRow(tool: .measureLine, name: "Measure Line", icon: "ruler")
                    toolRow(tool: .arrow, name: "Arrow", icon: "arrow.up.right")
                }
            }
            .navigationTitle("Layers & Tools")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityLabel("Close layer panel")
                }
            }
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func toolRow(
        tool: AnnotationLayerViewModel.AnnotationLayerTool,
        name: String,
        icon: String
    ) -> some View {
        Button {
            viewModel.activeTool = tool
        } label: {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(.secondary)
                    .frame(width: 24)
                    .accessibilityHidden(true)
                Text(name)
                    .foregroundStyle(.primary)
                Spacer()
                if viewModel.activeTool == tool {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.accentColor)
                        .accessibilityHidden(true)
                }
            }
        }
        .accessibilityLabel("Select \(name) tool")
        .accessibilityAddTraits(viewModel.activeTool == tool ? .isSelected : [])
    }

    /// Returns a human-readable count string for the given layer type.
    private func itemCountLabel(for layer: AnnotationLayerType) -> String {
        switch layer {
        case .textLabels:
            let n = viewModel.textAnnotations.count
            return n == 1 ? "1 label" : "\(n) labels"
        case .measureLines:
            let n = viewModel.measureLines.count
            return n == 1 ? "1 line" : "\(n) lines"
        case .arrows:
            let n = viewModel.arrowAnnotations.count
            return n == 1 ? "1 arrow" : "\(n) arrows"
        default:
            // Markers, regions, AI detections, heatmap are managed elsewhere
            return "Managed externally"
        }
    }
}

// Color(hex:) and toHex() are defined in Models/ColorExtensions.swift
