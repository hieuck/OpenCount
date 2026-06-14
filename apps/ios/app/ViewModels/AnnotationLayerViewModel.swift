import Foundation
import SwiftUI
import Combine

// MARK: - AnnotationLayerViewModel

/// Manages the advanced annotation tools: text labels, measurement lines, and arrows.
/// Also controls which annotation layers are visible.
///
/// Requirements: 34.1–34.6
@MainActor
final class AnnotationLayerViewModel: ObservableObject {

    // MARK: - Published state

    @Published var textAnnotations: [TextAnnotation] = []
    @Published var measureLines: [MeasureLine] = []
    @Published var arrowAnnotations: [ArrowAnnotation] = []

    /// The set of layer types currently visible.
    /// Requirement 34.5: show or hide each annotation layer independently.
    @Published var visibleLayers: Set<AnnotationLayerType> = Set(AnnotationLayerType.allCases)

    // MARK: - Tool enum

    enum AnnotationLayerTool: Equatable {
        case none
        case textLabel
        case measureLine
        case arrow
    }

    // MARK: - Active drawing state

    /// Start point for in-progress line/arrow drawing (normalized coords).
    @Published var drawingStartPoint: CGPoint?

    /// The currently active annotation tool.
    @Published var activeTool: AnnotationLayerTool = .none

    // MARK: - Layer visibility

    /// Toggles the visibility of the given layer type.
    /// Requirement 34.5: toggling a layer does NOT mutate the underlying data arrays.
    func toggleLayer(_ layer: AnnotationLayerType) {
        if visibleLayers.contains(layer) {
            visibleLayers.remove(layer)
        } else {
            visibleLayers.insert(layer)
        }
    }

    func isVisible(_ layer: AnnotationLayerType) -> Bool {
        visibleLayers.contains(layer)
    }

    // MARK: - Text annotations

    /// Adds a text annotation at the given normalized position.
    /// Requirement 34.1
    func addTextAnnotation(at position: CGPoint, text: String = "Label",
                           fontSize: CGFloat = 16, colorHex: String = "#FFFFFF") {
        let annotation = TextAnnotation(
            normalizedPosition: position,
            text: text,
            fontSize: fontSize,
            colorHex: colorHex
        )
        textAnnotations.append(annotation)
    }

    func updateTextAnnotation(_ annotation: TextAnnotation) {
        if let idx = textAnnotations.firstIndex(where: { $0.id == annotation.id }) {
            textAnnotations[idx] = annotation
        }
    }

    func removeTextAnnotation(id: UUID) {
        textAnnotations.removeAll { $0.id == id }
    }

    // MARK: - Measure lines

    /// Adds a measurement line between two normalized points.
    /// Requirement 34.2
    func addMeasureLine(from start: CGPoint, to end: CGPoint, colorHex: String = "#FFFF00") {
        let line = MeasureLine(startPoint: start, endPoint: end, colorHex: colorHex)
        measureLines.append(line)
    }

    func removeMeasureLine(id: UUID) {
        measureLines.removeAll { $0.id == id }
    }

    // MARK: - Arrow annotations

    /// Adds an arrow annotation from tail to head in normalized coordinates.
    /// Requirement 34.3
    func addArrow(from tail: CGPoint, to head: CGPoint, colorHex: String = "#FF0000") {
        let arrow = ArrowAnnotation(tailPoint: tail, headPoint: head, colorHex: colorHex)
        arrowAnnotations.append(arrow)
    }

    func removeArrow(id: UUID) {
        arrowAnnotations.removeAll { $0.id == id }
    }

    // MARK: - Generic remove

    func removeAnnotation(id: UUID, type: AnnotationLayerType) {
        switch type {
        case .textLabels: removeTextAnnotation(id: id)
        case .measureLines: removeMeasureLine(id: id)
        case .arrows: removeArrow(id: id)
        default: break
        }
    }

    // MARK: - Drawing gesture handlers

    /// Called when the user begins a draw gesture (for line/arrow tools).
    func beginDrawing(at point: CGPoint) {
        drawingStartPoint = point
    }

    /// Called when the user ends a draw gesture.
    func endDrawing(at endPoint: CGPoint) {
        guard let start = drawingStartPoint else { return }
        switch activeTool {
        case .measureLine:
            addMeasureLine(from: start, to: endPoint)
        case .arrow:
            addArrow(from: start, to: endPoint)
        case .textLabel:
            addTextAnnotation(at: endPoint)
        case .none:
            break
        }
        drawingStartPoint = nil
    }

    /// Returns the set of layers that should be included in an export.
    /// Requirement 34.6: allow the user to choose which annotation layers to include.
    func exportLayers(selectedLayers: Set<AnnotationLayerType>) -> AnnotationExportData {
        AnnotationExportData(
            textAnnotations: selectedLayers.contains(.textLabels) ? textAnnotations : [],
            measureLines: selectedLayers.contains(.measureLines) ? measureLines : [],
            arrowAnnotations: selectedLayers.contains(.arrows) ? arrowAnnotations : []
        )
    }
}

// MARK: - AnnotationExportData

/// Bundles annotation data for export rendering.
struct AnnotationExportData {
    let textAnnotations: [TextAnnotation]
    let measureLines: [MeasureLine]
    let arrowAnnotations: [ArrowAnnotation]
}
