import SwiftUI

// MARK: - GridOverlayView

/// A configurable grid drawn over the image canvas to assist systematic manual counting.
///
/// - Renders an N×N grid of cells over the canvas area.
/// - Each cell displays its sequential 1-based index.
/// - Tapping a cell toggles its "completed" state and highlights it with a
///   semi-transparent fill.
/// - Line color and opacity are configurable via the ViewModel.
///
/// Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 4.6
struct GridOverlayView: View {

    // MARK: - Inputs

    /// The number of columns (and rows) in the grid. Clamped to 2–20.
    let density: Int

    /// The set of cell indices (0-based, row-major) that have been marked as completed.
    let completedCells: Set<Int>

    /// The color used for grid lines and the completed-cell highlight.
    let lineColor: Color

    /// The opacity of the grid lines (0.0–1.0).
    let lineOpacity: Double

    /// Called when the user taps a cell. Passes the 0-based cell index.
    let onCellTapped: (Int) -> Void

    // MARK: - Private constants

    /// Opacity of the semi-transparent highlight fill for completed cells.
    private let completedFillOpacity: Double = 0.35

    /// Font size for the cell index label, scaled relative to cell size.
    private let indexFontSizeRatio: CGFloat = 0.25

    // MARK: - Body

    var body: some View {
        GeometryReader { geometry in
            let columns = max(2, min(density, 20))
            let rows = columns
            let cellWidth = geometry.size.width / CGFloat(columns)
            let cellHeight = geometry.size.height / CGFloat(rows)

            ZStack(alignment: .topLeading) {
                // Completed-cell highlight fills (drawn below lines)
                completedFillLayer(
                    columns: columns,
                    rows: rows,
                    cellWidth: cellWidth,
                    cellHeight: cellHeight
                )

                // Grid lines
                gridLinesLayer(
                    size: geometry.size,
                    columns: columns,
                    rows: rows,
                    cellWidth: cellWidth,
                    cellHeight: cellHeight
                )

                // Cell index labels
                cellIndexLayer(
                    columns: columns,
                    rows: rows,
                    cellWidth: cellWidth,
                    cellHeight: cellHeight
                )

                // Invisible tap targets covering each cell
                tapTargetLayer(
                    columns: columns,
                    rows: rows,
                    cellWidth: cellWidth,
                    cellHeight: cellHeight
                )
            }
        }
        .allowsHitTesting(true)
        .accessibilityLabel("Grid overlay")
        .accessibilityHint("Tap a cell to mark it as counted.")
    }

    // MARK: - Sub-layers

    /// Renders semi-transparent fill rectangles for completed cells.
    @ViewBuilder
    private func completedFillLayer(
        columns: Int,
        rows: Int,
        cellWidth: CGFloat,
        cellHeight: CGFloat
    ) -> some View {
        ForEach(0 ..< rows * columns, id: \.self) { index in
            if completedCells.contains(index) {
                let col = index % columns
                let row = index / columns
                Rectangle()
                    .fill(lineColor.opacity(completedFillOpacity))
                    .frame(width: cellWidth, height: cellHeight)
                    .offset(
                        x: CGFloat(col) * cellWidth,
                        y: CGFloat(row) * cellHeight
                    )
            }
        }
    }

    /// Renders the grid lines using a Canvas for performance.
    @ViewBuilder
    private func gridLinesLayer(
        size: CGSize,
        columns: Int,
        rows: Int,
        cellWidth: CGFloat,
        cellHeight: CGFloat
    ) -> some View {
        Canvas { context, _ in
            var path = Path()

            // Vertical lines
            for col in 0 ... columns {
                let x = CGFloat(col) * cellWidth
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
            }

            // Horizontal lines
            for row in 0 ... rows {
                let y = CGFloat(row) * cellHeight
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
            }

            context.stroke(
                path,
                with: .color(lineColor.opacity(lineOpacity)),
                lineWidth: 1.0
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
    }

    /// Renders the sequential 1-based cell index label in each cell.
    @ViewBuilder
    private func cellIndexLayer(
        columns: Int,
        rows: Int,
        cellWidth: CGFloat,
        cellHeight: CGFloat
    ) -> some View {
        ForEach(0 ..< rows * columns, id: \.self) { index in
            let col = index % columns
            let row = index / columns
            let fontSize = max(8, min(cellWidth, cellHeight) * indexFontSizeRatio)
            let isCompleted = completedCells.contains(index)

            Text("\(index + 1)")
                .font(.system(size: fontSize, weight: .semibold, design: .rounded))
                .foregroundStyle(
                    isCompleted
                        ? lineColor.opacity(0.9)
                        : lineColor.opacity(lineOpacity * 0.8)
                )
                .frame(width: cellWidth, height: cellHeight, alignment: .topLeading)
                .padding(EdgeInsets(top: 3, leading: 4, bottom: 0, trailing: 0))
                .offset(
                    x: CGFloat(col) * cellWidth,
                    y: CGFloat(row) * cellHeight
                )
                .allowsHitTesting(false)
        }
    }

    /// Invisible tap-target buttons covering each cell.
    @ViewBuilder
    private func tapTargetLayer(
        columns: Int,
        rows: Int,
        cellWidth: CGFloat,
        cellHeight: CGFloat
    ) -> some View {
        ForEach(0 ..< rows * columns, id: \.self) { index in
            let col = index % columns
            let row = index / columns
            let isCompleted = completedCells.contains(index)

            Color.clear
                .frame(width: cellWidth, height: cellHeight)
                .contentShape(Rectangle())
                .offset(
                    x: CGFloat(col) * cellWidth,
                    y: CGFloat(row) * cellHeight
                )
                .onTapGesture {
                    onCellTapped(index)
                }
                .accessibilityLabel(
                    "Cell \(index + 1), \(isCompleted ? "completed" : "not completed")"
                )
                .accessibilityHint(
                    isCompleted
                        ? "Tap to mark this cell as not counted."
                        : "Tap to mark this cell as counted."
                )
                .accessibilityAddTraits(isCompleted ? [.isButton, .isSelected] : .isButton)
        }
    }
}

// MARK: - Preview

#Preview {
    GridOverlayView(
        density: 5,
        completedCells: [0, 2, 6, 12],
        lineColor: .blue,
        lineOpacity: 0.7,
        onCellTapped: { _ in }
    )
    .frame(width: 300, height: 300)
    .background(Color(.secondarySystemBackground))
}
