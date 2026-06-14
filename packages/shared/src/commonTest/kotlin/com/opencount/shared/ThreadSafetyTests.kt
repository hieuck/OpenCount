package com.opencount.shared

import com.opencount.shared.model.CountFormula
import com.opencount.shared.model.FormulaEvaluator
import com.opencount.shared.model.uuid
import kotlin.test.Test
import kotlin.test.*

class ThreadSafetyTests {
    @Test
    fun concurrentUUIDsAreUnique() {
        val ids = (1..1000).map { uuid() }
        assertEquals(ids.size, ids.toSet().size)
    }

    @Test
    fun uuidFormat() {
        val id = uuid()
        assertTrue(id.contains("-"))
        val parts = id.split("-")
        assertEquals(2, parts.size)
        assertTrue(parts[0].all { it.isDigit() })
    }

    @Test
    fun concurrentFormulaEvaluation() {
        val formula = CountFormula(id = "f1", name = "Test", expression = "a + b * c")
        val tally = mapOf("a" to 10, "b" to 20, "c" to 30)
        val results = (1..100).map {
            FormulaEvaluator.evaluate(formula, tally)
        }
        assertTrue(results.all { it == 610.0 })
    }

    @Test
    fun concurrentTokensAreIndependent() {
        val formulae = listOf(
            CountFormula(id = "f1", name = "F1", expression = "1 + 2"),
            CountFormula(id = "f2", name = "F2", expression = "3 * 4"),
            CountFormula(id = "f3", name = "F3", expression = "10 - 5"),
            CountFormula(id = "f4", name = "F4", expression = "20 / 4"),
            CountFormula(id = "f5", name = "F5", expression = "(1 + 2) * 3"),
        )
        val results = formulae.map { FormulaEvaluator.evaluate(it, emptyMap()) }
        assertEquals(listOf(3.0, 12.0, 5.0, 5.0, 9.0), results)
    }

    @Test
    fun repeatedConcurrentUuidCalls() {
        val ids = (1..5000).map { uuid() }
        assertEquals(ids.size, ids.toSet().size)
    }
}
