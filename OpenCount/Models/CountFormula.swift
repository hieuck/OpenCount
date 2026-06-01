import Foundation
import SwiftData

// MARK: - CountFormula

/// A user-defined formula that computes a derived value from session tallies.
///
/// Example formulas:
///   "Adults + Juveniles"          → sum of two types
///   "Males / (Males + Females)"   → sex ratio
///   "Trees * 0.5"                 → biomass estimate
///
/// Formulas use object type names as variables. The evaluator substitutes
/// the current tally for each named type before computing the result.
///
/// This feature is unique to OpenCount — neither ZapCount nor CountThings
/// support custom counting formulas.
@Model
final class CountFormula {
    var id: UUID
    var name: String
    var expression: String
    var unit: String
    var sortOrder: Int
    var session: CountSession?

    init(
        id: UUID = UUID(),
        name: String,
        expression: String,
        unit: String = "",
        sortOrder: Int = 0,
        session: CountSession? = nil
    ) {
        self.id = id
        self.name = name
        self.expression = expression
        self.unit = unit
        self.sortOrder = sortOrder
        self.session = session
    }
}

// MARK: - FormulaEvaluator

/// Evaluates a `CountFormula` expression given a tally dictionary.
///
/// Supported operations: +, -, *, /, (, ), numeric literals, type names.
/// Type names are matched case-insensitively and substituted with their tally.
struct FormulaEvaluator {

    /// Evaluates the formula expression and returns the numeric result.
    /// Returns `nil` if the expression is invalid or contains unknown type names.
    static func evaluate(
        formula: CountFormula,
        tally: [String: Int]
    ) -> Double? {
        var expression = formula.expression

        // Substitute type names (longest first to avoid partial matches)
        let sortedNames = tally.keys.sorted { $0.count > $1.count }
        for name in sortedNames {
            let count = tally[name] ?? 0
            // Case-insensitive replacement
            let pattern = NSRegularExpression.escapedPattern(for: name)
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                expression = regex.stringByReplacingMatches(
                    in: expression,
                    range: NSRange(expression.startIndex..., in: expression),
                    withTemplate: "\(count)"
                )
            }
        }

        // Evaluate the resulting arithmetic expression
        return evaluateArithmetic(expression)
    }

    /// Simple recursive-descent arithmetic evaluator.
    /// Supports: +, -, *, /, (, ), unary minus, integer and decimal literals.
    private static func evaluateArithmetic(_ expression: String) -> Double? {
        let cleaned = expression.replacingOccurrences(of: " ", with: "")
        var index = cleaned.startIndex
        return parseExpression(cleaned, index: &index)
    }

    private static func parseExpression(_ s: String, index: inout String.Index) -> Double? {
        var result = parseTerm(s, index: &index)
        while index < s.endIndex {
            let op = s[index]
            if op == "+" || op == "-" {
                s.formIndex(after: &index)
                guard let rhs = parseTerm(s, index: &index) else { return nil }
                if op == "+" { result = (result ?? 0) + rhs }
                else         { result = (result ?? 0) - rhs }
            } else {
                break
            }
        }
        return result
    }

    private static func parseTerm(_ s: String, index: inout String.Index) -> Double? {
        var result = parseFactor(s, index: &index)
        while index < s.endIndex {
            let op = s[index]
            if op == "*" || op == "/" {
                s.formIndex(after: &index)
                guard let rhs = parseFactor(s, index: &index) else { return nil }
                if op == "*" { result = (result ?? 0) * rhs }
                else {
                    guard rhs != 0 else { return nil }
                    result = (result ?? 0) / rhs
                }
            } else {
                break
            }
        }
        return result
    }

    private static func parseFactor(_ s: String, index: inout String.Index) -> Double? {
        guard index < s.endIndex else { return nil }

        // Parenthesised sub-expression
        if s[index] == "(" {
            s.formIndex(after: &index)
            let result = parseExpression(s, index: &index)
            if index < s.endIndex && s[index] == ")" {
                s.formIndex(after: &index)
            }
            return result
        }

        // Unary minus
        if s[index] == "-" {
            s.formIndex(after: &index)
            return parseFactor(s, index: &index).map { -$0 }
        }

        // Numeric literal
        var numStr = ""
        while index < s.endIndex && (s[index].isNumber || s[index] == ".") {
            numStr.append(s[index])
            s.formIndex(after: &index)
        }
        return Double(numStr)
    }
}
