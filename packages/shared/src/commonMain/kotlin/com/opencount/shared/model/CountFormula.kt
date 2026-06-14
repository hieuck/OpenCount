package com.opencount.shared.model

import kotlinx.serialization.Serializable

@Serializable
data class CountFormula(
    val id: String,
    val name: String,
    val expression: String,
    val unit: String = "",
    val sortOrder: Int = 0,
)

object FormulaEvaluator {
    fun evaluate(formula: CountFormula, tally: Map<String, Int>): Double? {
        var expression = formula.expression
        val sortedNames = tally.keys.sortedByDescending { it.length }
        for (name in sortedNames) {
            val count = tally[name] ?: 0
            expression = expression.replace(name, count.toString(), ignoreCase = true)
        }
        return evaluateArithmetic(expression)
    }

    private fun evaluateArithmetic(expression: String): Double? {
        val cleaned = expression.replace(" ", "")
        val tokens = tokenize(cleaned) ?: return null
        return parseExpression(tokens)
    }

    private fun tokenize(s: String): List<String>? {
        val tokens = mutableListOf<String>()
        var i = 0
        while (i < s.length) {
            val c = s[i]
            when {
                c.isDigit() || c == '.' -> {
                    val start = i
                    while (i < s.length && (s[i].isDigit() || s[i] == '.')) i++
                    tokens.add(s.substring(start, i))
                }
                c in "+-*/()" -> {
                    tokens.add(c.toString())
                    i++
                }
                else -> return null
            }
        }
        return tokens
    }

    private var pos = 0
    private lateinit var tokens: List<String>

    private fun parseExpression(tokens: List<String>): Double? {
        this.tokens = tokens; pos = 0
        return parseExpr()
    }

    private fun parseExpr(): Double? {
        var result = parseTerm() ?: return null
        while (pos < tokens.size && (tokens[pos] == "+" || tokens[pos] == "-")) {
            val op = tokens[pos++]
            val rhs = parseTerm() ?: return null
            result = if (op == "+") result + rhs else result - rhs
        }
        return result
    }

    private fun parseTerm(): Double? {
        var result = parseFactor() ?: return null
        while (pos < tokens.size && (tokens[pos] == "*" || tokens[pos] == "/")) {
            val op = tokens[pos++]
            val rhs = parseFactor() ?: return null
            result = if (op == "*") result * rhs else if (rhs != 0.0) result / rhs else return null
        }
        return result
    }

    private fun parseFactor(): Double? {
        if (pos >= tokens.size) return null
        return when (val token = tokens[pos++]) {
            "(" -> {
                val result = parseExpr()
                if (pos < tokens.size && tokens[pos] == ")") pos++ else return null
                result
            }
            "-" -> parseFactor()?.let { -it }
            else -> token.toDoubleOrNull()
        }
    }
}
