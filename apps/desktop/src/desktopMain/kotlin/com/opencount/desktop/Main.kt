package com.opencount.desktop

import androidx.compose.foundation.*
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.painter.BitmapPainter
import androidx.compose.ui.graphics.toComposeImageBitmap
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.*
import java.io.File
import javax.imageio.ImageIO
import javax.swing.JFileChooser
import javax.swing.filechooser.FileNameExtensionFilter

fun main() = application {
    Window(
        onCloseRequest = ::exitApplication,
        title = "OpenCount",
        state = rememberWindowState(width = 1000.dp, height = 700.dp),
    ) {
        MaterialTheme {
            OpenCountApp()
        }
    }
}

data class Marker(val nx: Float, val ny: Float) // normalized 0..1

@Composable
fun OpenCountApp() {
    var imageBitmap by remember { mutableStateOf<androidx.compose.ui.graphics.ImageBitmap?>(null) }
    var markers by remember { mutableStateOf(listOf<Marker>()) }
    var objectName by remember { mutableStateOf("cars") }
    var imageFile by remember { mutableStateOf<File?>(null) }

    Surface(modifier = Modifier.fillMaxSize()) {
        Column {
            // Top bar
            Surface(shadowElevation = 4.dp) {
                Row(
                    modifier = Modifier.fillMaxWidth().padding(12.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Button(onClick = {
                        val chooser = JFileChooser()
                        chooser.dialogTitle = "Open Image"
                        chooser.fileFilter = FileNameExtensionFilter("Images", "jpg", "jpeg", "png", "bmp", "gif")
                        if (chooser.showOpenDialog(null) == JFileChooser.APPROVE_OPTION) {
                            val file = chooser.selectedFile
                            imageFile = file
                            val bufImg = ImageIO.read(file)
                            if (bufImg != null) {
                                imageBitmap = bufImg.toComposeImageBitmap()
                                markers = emptyList()
                            }
                        }
                    }) { Text("Open Image") }

                    Spacer(Modifier.width(12.dp))

                    OutlinedTextField(
                        value = objectName,
                        onValueChange = { objectName = it },
                        label = { Text("Object to count") },
                        singleLine = true,
                        modifier = Modifier.width(150.dp),
                    )

                    Spacer(Modifier.width(12.dp))

                    Button(onClick = {
                        // Mock AI detection: place markers in a grid
                        if (imageBitmap != null) {
                            markers = (1..6).map { i ->
                                Marker(i / 7f, 0.3f + (i % 3) * 0.2f)
                            } + (1..4).map { i ->
                                Marker(0.1f + i * 0.2f, 0.7f)
                            }
                        }
                    }) { Text("AI Detect") }

                    Spacer(Modifier.weight(1f))

                    Text(
                        "${markers.size} ${objectName}",
                        style = MaterialTheme.typography.titleLarge,
                    )

                    Spacer(Modifier.width(12.dp))

                    if (markers.isNotEmpty()) {
                        OutlinedButton(onClick = {
                            val file = File(System.getProperty("user.home"), "Desktop/count_${objectName}.txt")
                            file.writeText("$objectName: ${markers.size}")
                        }) { Text("Export") }
                    }
                }
            }

            // Image canvas
            Box(
                modifier = Modifier.fillMaxSize().background(Color(0xFF2D2D2D)),
                contentAlignment = Alignment.Center,
            ) {
                if (imageBitmap != null) {
                    val bitmap = imageBitmap
                    if (bitmap != null) {
                        Canvas(
                            modifier = Modifier.fillMaxSize().pointerInput(Unit) {
                                detectTapGestures { offset ->
                                    // Convert screen tap to image-normalized coordinates
                                    val scale = minOf(size.width.toFloat() / bitmap.width,
                                        size.height.toFloat() / bitmap.height)
                                    val w = bitmap.width * scale
                                    val h = bitmap.height * scale
                                    val ox = (size.width - w) / 2f
                                    val oy = (size.height - h) / 2f
                                    val nx = (offset.x - ox) / w
                                    val ny = (offset.y - oy) / h
                                    if (nx in 0f..1f && ny in 0f..1f) {
                                        markers = markers + Marker(nx, ny)
                                    }
                                }
                            }
                        ) {
                            val scale = minOf(size.width / bitmap.width, size.height / bitmap.height)
                            val w = bitmap.width * scale
                            val h = bitmap.height * scale
                            val ox = (size.width - w) / 2f
                            val oy = (size.height - h) / 2f

                            drawImage(bitmap,
                                dstOffset = androidx.compose.ui.unit.IntOffset(ox.toInt(), oy.toInt()),
                                dstSize = androidx.compose.ui.unit.IntSize(w.toInt(), h.toInt()))

                            markers.forEach { m ->
                                val sx = ox + m.nx * w
                                val sy = oy + m.ny * h
                                drawCircle(Color.Red, radius = 8f, center = Offset(sx, sy))
                                drawCircle(Color.White, radius = 8f, center = Offset(sx, sy), style = Stroke(width = 2f))
                            }
                        }
                    } else {
                        Box(modifier = Modifier.fillMaxSize().background(Color(0xFF2D2D2D)),
                            contentAlignment = Alignment.Center) {
                            Text("Open an image to start counting",
                                color = Color.White.copy(alpha = 0.5f),
                                style = MaterialTheme.typography.titleLarge)
                        }
                    }

                    // Instructions overlay
                    if (markers.isEmpty()) {
                        Text("Tap on image to place markers",
                            color = Color.White.copy(alpha = 0.6f),
                            style = MaterialTheme.typography.titleMedium,
                            modifier = Modifier.align(Alignment.TopCenter).padding(8.dp))
                    }

                    // Count badge
                    if (markers.isNotEmpty()) {
                        Surface(
                            modifier = Modifier.align(Alignment.TopEnd).padding(16.dp),
                            shape = CircleShape,
                            color = Color(0xFF1A73E8),
                        ) {
                            Text(
                                "${markers.size}",
                                modifier = Modifier.padding(horizontal = 20.dp, vertical = 12.dp),
                                color = Color.White,
                                style = MaterialTheme.typography.headlineMedium,
                            )
                        }
                    }
                } else {
                    Text("Open an image to start counting",
                        color = Color.White.copy(alpha = 0.5f),
                        style = MaterialTheme.typography.titleLarge)
                }
            }

            // Bottom bar
            if (markers.isNotEmpty()) {
                Surface(shadowElevation = 4.dp) {
                    Row(
                        modifier = Modifier.fillMaxWidth().padding(8.dp),
                        horizontalArrangement = Arrangement.SpaceEvenly,
                    ) {
                        TextButton(onClick = {
                            if (markers.isNotEmpty()) markers = markers.dropLast(1)
                        }) { Text("Undo") }
                        TextButton(onClick = { markers = emptyList() }) { Text("Clear") }
                        Text("${markers.size} $objectName",
                            style = MaterialTheme.typography.titleMedium,
                            modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp))
                    }
                }
            }
        }
    }
}
