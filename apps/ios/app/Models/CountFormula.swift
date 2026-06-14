import Foundation

// MARK: - CountFormula

final class CountFormula: ObservableObject, Identifiable, Codable {
    var id: UUID
    var name: String
    var expression: String
    var unit: String
    var sortOrder: Int
    weak var session: CountSession?

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

    enum CodingKeys: String, CodingKey {
        case id, name, expression, unit, sortOrder
    }

    required init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id         = try c.decode(UUID.self,   forKey: .id)
        name       = try c.decode(String.self, forKey: .name)
        expression = try c.decode(String.self, forKey: .expression)
        unit       = try c.decode(String.self, forKey: .unit)
        sortOrder  = try c.decode(Int.self,    forKey: .sortOrder)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id,        forKey: .id)
        try c.encode(name,      forKey: .name)
        try c.encode(expression, forKey: .expression)
        try c.encode(unit,      forKey: .unit)
        try c.encode(sortOrder, forKey: .sortOrder)
    }
}

// MARK: - FormulaEvaluator

struct FormulaEvaluator {
    static func evaluate(formula: CountFormula, tally: [String: Int]) -> Double? {
        var expression = formula.expression
        let sortedNames = tally.keys.sorted { $0.count > $1.count }
        for name in sortedNames {
            let count = tally[name] ?? 0
            let pattern = NSRegularExpression.escapedPattern(for: name)
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                expression = regex.stringByReplacingMatches(
                    in: expression,
                    range: NSRange(expression.startIndex..., in: expression),
                    withTemplate: "\(count)"
                )
            }
        }
        return evaluateArithmetic(expression)
    }

    private static func evaluateArithmetic(_ expression: String) -> Double? {
        let cleaned = expression.replacingOccurrences(of: " ", with: "")
        var index = cleaned.startIndex
        return parseExpression(cleaned, index: &index)
    }

    private static func parseExpression(_ s: String, index: inout String.Index) -> Double? {
        var result = parseTerm(s, index: &index)
        while index < s.endIndex {
            let op = s[index]
            guard op == "+" || op == "-" else { break }
            s.formIndex(after: &index)
            guard let rhs = parseTerm(s, index: &index) else { return nil }
            result = op == "+" ? (result ?? 0) + rhs : (result ?? 0) - rhs
        }
        return result
    }

    private static func parseTerm(_ s: String, index: inout String.Index) -> Double? {
        var result = parseFactor(s, index: &index)
        while index < s.endIndex {
            let op = s[index]
            guard op == "*" || op == "/" else { break }
            s.formIndex(after: &index)
            guard let rhs = parseFactor(s, index: &index) else { return nil }
            if op == "*" { result = (result ?? 0) * rhs }
            else { guard rhs != 0 else { return nil }; result = (result ?? 0) / rhs }
        }
        return result
    }

    private static func parseFactor(_ s: String, index: inout String.Index) -> Double? {
        guard index < s.endIndex else { return nil }
        if s[index] == "(" {
            s.formIndex(after: &index)
            let result = parseExpression(s, index: &index)
            if index < s.endIndex && s[index] == ")" { s.formIndex(after: &index) }
            return result
        }
        if s[index] == "-" {
            s.formIndex(after: &index)
            return parseFactor(s, index: &index).map { -$0 }
        }
        var numStr = ""
        while index < s.endIndex && (s[index].isNumber || s[index] == ".") {
            numStr.append(s[index]); s.formIndex(after: &index)
        }
        return Double(numStr)
    }
}
