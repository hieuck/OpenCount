package com.opencount.shared

import kotlin.test.Test
import kotlin.test.*

class CounterKMPTests {
    data class Marker(val x: Double, val y: Double, val label: String = "object", val score: Float = 0f)

    class Counter {
        private val _markers = mutableListOf<Marker>()
        val markers: List<Marker> get() = _markers.toList()
        var count: Int = 0; private set

        fun add(x: Double, y: Double, label: String = "object"): Boolean {
            if (x < 0 || x > 1 || y < 0 || y > 1) return false
            _markers.add(Marker(x, y, label))
            count = _markers.size
            return true
        }

        fun remove(index: Int): Boolean {
            if (index < 0 || index >= _markers.size) return false
            _markers.removeAt(index)
            count = _markers.size
            return true
        }

        fun undo(): Boolean = remove(_markers.size - 1)

        fun clear() { _markers.clear(); count = 0 }

        fun nearest(x: Double, y: Double, threshold: Double = 0.05): Int {
            var idx = -1; var min = threshold
            _markers.forEachIndexed { i, m ->
                val d = kotlin.math.sqrt((m.x - x) * (m.x - x) + (m.y - y) * (m.y - y))
                if (d < min) { min = d; idx = i }
            }
            return idx
        }

        fun groupByLabel(): Map<String, Int> {
            val groups = mutableMapOf<String, Int>()
            _markers.forEach { groups[it.label] = (groups[it.label] ?: 0) + 1 }
            return groups
        }
    }

    @Test fun startsEmpty() { val c = Counter(); assertEquals(0, c.count); assertTrue(c.markers.isEmpty()) }

    @Test fun addsMarker() { val c = Counter(); assertTrue(c.add(0.5, 0.5, "car")); assertEquals(1, c.count); assertEquals("car", c.markers[0].label) }

    @Test fun rejectsOutOfRange() { val c = Counter(); assertFalse(c.add(-0.1, 0.5)); assertFalse(c.add(1.5, 0.5)); assertFalse(c.add(0.5, -0.1)); assertFalse(c.add(0.5, 1.5)); assertEquals(0, c.count) }

    @Test fun removesByIndex() { val c = Counter(); c.add(0.1, 0.1, "a"); c.add(0.2, 0.2, "b"); assertTrue(c.remove(0)); assertEquals(1, c.count); assertEquals("b", c.markers[0].label) }

    @Test fun removeFromEmpty() { val c = Counter(); assertFalse(c.remove(0)); assertFalse(c.undo()) }

    @Test fun clearsAll() { val c = Counter(); c.add(0.1, 0.1); c.add(0.2, 0.2); c.clear(); assertEquals(0, c.count); assertTrue(c.markers.isEmpty()) }

    @Test fun findsNearest() { val c = Counter(); c.add(0.1, 0.1); c.add(0.5, 0.5); c.add(0.9, 0.9); assertEquals(1, c.nearest(0.51, 0.51)); assertEquals(2, c.nearest(0.89, 0.89)) }

    @Test fun groupsByLabel() { val c = Counter(); c.add(0.1, 0.1, "car"); c.add(0.2, 0.2, "car"); c.add(0.3, 0.3, "person"); val g = c.groupByLabel(); assertEquals(2, g["car"]); assertEquals(1, g["person"]) }

    @Test fun rapidAddRemove() { val c = Counter(); repeat(100) { c.add(it / 100.0, it / 100.0) }; assertEquals(100, c.count); repeat(50) { c.undo() }; assertEquals(50, c.count) }

    @Test fun boundaryCoordinates() { val c = Counter(); assertTrue(c.add(0.0, 0.0)); assertTrue(c.add(1.0, 1.0)); assertEquals(2, c.count) }
}
