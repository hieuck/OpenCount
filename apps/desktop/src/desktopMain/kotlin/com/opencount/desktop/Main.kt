package com.opencount.desktop

import androidx.compose.foundation.*
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.ExperimentalComposeUiApi
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.toComposeImageBitmap
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.*
import kotlinx.coroutines.*
import java.awt.datatransfer.DataFlavor
import java.awt.dnd.*
import java.awt.image.BufferedImage
import java.io.File
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter
import javax.imageio.ImageIO
import javax.swing.JFileChooser
import javax.swing.filechooser.FileNameExtensionFilter

private val IO = Dispatchers.Default

/** List of image file extensions */
private val IMAGE_EXTS = setOf("jpg", "jpeg", "png", "bmp", "gif", "webp")

/** Open file chooser dialog */
private fun openFileDialog(): File? {
    val chooser = JFileChooser()
    chooser.dialogTitle = "Open Image"
    chooser.fileFilter = FileNameExtensionFilter("Images", *IMAGE_EXTS.toTypedArray())
    return if (chooser.showOpenDialog(null) == JFileChooser.APPROVE_OPTION) chooser.selectedFile else null
}

fun main() = application {
    var droppedFile by remember { mutableStateOf<File?>(null) }

    Window(
        onCloseRequest = ::exitApplication,
        title = "OpenCount",
        state = rememberWindowState(width = 1100.dp, height = 750.dp),
    ) {
        // Drag & drop: accept image files from OS
        DisposableEffect(Unit) {
            val dt = DropTarget()
            dt.addDropTargetListener(object : DropTargetAdapter() {
                override fun drop(e: DropTargetDropEvent) {
                    e.acceptDrop(DnDConstants.ACTION_COPY)
                    try {
                        @Suppress("UNCHECKED_CAST")
                        val files = e.transferable.getTransferData(DataFlavor.javaFileListFlavor) as List<File>
                        val imgFile = files.firstOrNull { it.extension.lowercase() in IMAGE_EXTS }
                        if (imgFile != null) droppedFile = imgFile
                    } catch (_: Exception) {}
                    e.dropComplete(true)
                }
                override fun dragEnter(e: DropTargetDragEvent) { e.acceptDrag(DnDConstants.ACTION_COPY) }
            })
            window.dropTarget = dt
            onDispose { window.dropTarget = null }
        }

        MaterialTheme {
            OpenCountApp(droppedFile = droppedFile, onDroppedHandled = { droppedFile = null })
        }
    }
}

/** Load image in background, return immediately */
private suspend fun loadImageAsync(file: File): androidx.compose.ui.graphics.ImageBitmap? = withContext(IO) {
    try {
        val img = ImageIO.read(file)
        img?.toComposeImageBitmap()
    } catch (_: Exception) { null }
}

data class Marker(val nx: Float, val ny: Float)
data class CountRecord(val name: String, val count: Int, val time: String)

@Composable
fun OpenCountApp(droppedFile: File? = null, onDroppedHandled: () -> Unit = {}) {
    var imageBitmap by remember { mutableStateOf<androidx.compose.ui.graphics.ImageBitmap?>(null) }
    var markers by remember { mutableStateOf(listOf<Marker>()) }
    var objectName by remember { mutableStateOf("Object") }
    var history by remember { mutableStateOf(listOf<CountRecord>()) }
    var showHistory by remember { mutableStateOf(false) }
    var isProcessing by remember { mutableStateOf(false) }
    var isLoading by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()

    // Handle dropped file
    LaunchedEffect(droppedFile) {
        if (droppedFile != null) {
            isLoading = true
            val bitmap = loadImageAsync(droppedFile)
            if (bitmap != null) { imageBitmap = bitmap; markers = emptyList() }
            isLoading = false
            onDroppedHandled()
        }
    }

    // Drag & drop support
    LaunchedEffect(Unit) {
        // Find the AWT window from Compose's local window info
        // and add a DropTarget listener
    }

    Surface(modifier = Modifier.fillMaxSize()) {
        Column {
            // Top bar
            Surface(shadowElevation = 2.dp) {
                Row(modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp),
                    verticalAlignment = Alignment.CenterVertically) {

                    Text("OpenCount", fontWeight = FontWeight.Bold, fontSize = 18.sp)

                    if (imageBitmap != null) {
                        Spacer(Modifier.width(16.dp))
                        Text("|", color = Color.Gray)
                        Spacer(Modifier.width(16.dp))

                        OutlinedTextField(
                            value = objectName,
                            onValueChange = { objectName = it },
                            label = { Text("Object") },
                            singleLine = true,
                            modifier = Modifier.width(140.dp),
                            textStyle = LocalTextStyle.current.copy(fontSize = 14.sp)
                        )
                    }

                    Spacer(Modifier.weight(1f))

                    if (imageBitmap != null) {
                        Text("${markers.size}", fontSize = 28.sp, fontWeight = FontWeight.Bold, color = Color(0xFF1A73E8))
                        Spacer(Modifier.width(4.dp))
                        Text(objectName, fontSize = 14.sp, color = Color.Gray)
                        Spacer(Modifier.width(16.dp))
                    }

                    if (history.isNotEmpty()) {
                        TextButton(onClick = { showHistory = !showHistory }) {
                            Text("📊 ${history.size}")
                        }
                    }
                }
            }

            if (showHistory && history.isNotEmpty()) {
                Surface(shadowElevation = 2.dp, color = Color(0xFFF8F9FA)) {
                    Column(modifier = Modifier.fillMaxWidth().padding(8.dp)) {
                        Text("History", fontWeight = FontWeight.Bold, fontSize = 12.sp, modifier = Modifier.padding(8.dp))
                        history.reversed().forEach { record ->
                            Text("${record.time}: ${record.count} × ${record.name}", fontSize = 11.sp, modifier = Modifier.padding(horizontal = 8.dp, vertical = 2.dp))
                        }
                    }
                }
            }

            // Main content
            Box(modifier = Modifier.weight(1f).fillMaxWidth().background(Color(0xFF2D2D2D)),
                contentAlignment = Alignment.Center) {

                if (imageBitmap != null) {
                    val bitmap = imageBitmap!!
                    Canvas(modifier = Modifier.fillMaxSize().pointerInput(Unit) {
                        detectTapGestures { offset ->
                            val sc = minOf(size.width.toFloat() / bitmap.width, size.height.toFloat() / bitmap.height)
                            val iw = bitmap.width * sc; val ih = bitmap.height * sc
                            val ox = (size.width - iw) / 2f; val oy = (size.height - ih) / 2f
                            val nx = (offset.x - ox) / iw; val ny = (offset.y - oy) / ih
                            if (nx in 0f..1f && ny in 0f..1f) { markers = markers + Marker(nx, ny) }
                        }
                    }) {
                        val sc = minOf(size.width / bitmap.width, size.height / bitmap.height)
                        val iw = bitmap.width * sc; val ih = bitmap.height * sc
                        val ox = (size.width - iw) / 2f; val oy = (size.height - ih) / 2f
                        drawImage(bitmap, dstOffset = androidx.compose.ui.unit.IntOffset(ox.toInt(), oy.toInt()),
                            dstSize = androidx.compose.ui.unit.IntSize(iw.toInt(), ih.toInt()))
                        markers.forEachIndexed { i, m ->
                            val sx = ox + m.nx * iw; val sy = oy + m.ny * ih
                            drawCircle(Color.Red, radius = 10f, center = Offset(sx, sy))
                            drawCircle(Color.White, radius = 10f, center = Offset(sx, sy), style = Stroke(2f))
                            drawCircle(Color.Red, radius = 4f, center = Offset(sx, sy))
                        }
                    }

                    // Overlays
                    if (markers.isEmpty()) {
                        Text("Tap on image to place markers", color = Color.White.copy(alpha = 0.6f),
                            fontSize = 16.sp, modifier = Modifier.align(Alignment.TopCenter).padding(12.dp))
                    }
                    if (markers.isNotEmpty()) {
                        Surface(shape = CircleShape, color = Color(0xFF1A73E8),
                            modifier = Modifier.align(Alignment.TopEnd).padding(16.dp)) {
                            Text("${markers.size}", color = Color.White, fontWeight = FontWeight.Bold, fontSize = 20.sp,
                                modifier = Modifier.padding(horizontal = 20.dp, vertical = 10.dp))
                        }
                    }
                    if (isProcessing) {
                        Card(modifier = Modifier.align(Alignment.Center)) {
                            Text("AI Processing...", modifier = Modifier.padding(16.dp))
                        }
                    }
                } else {
                    // Welcome screen (like ZapCount)
                    Column(horizontalAlignment = Alignment.CenterHorizontally,
                        modifier = Modifier.padding(32.dp)) {
                        Text("📷", fontSize = 64.sp)
                        Spacer(Modifier.height(16.dp))
                        Text("OpenCount", fontSize = 32.sp, fontWeight = FontWeight.Bold, color = Color.White)
                        Text("AI Object Counter", fontSize = 14.sp, color = Color.White.copy(alpha = 0.5f))
                        Spacer(Modifier.height(32.dp))
                        Button(onClick = {
                            val chooser = JFileChooser()
                            chooser.dialogTitle = "Open Image"
                            chooser.fileFilter = FileNameExtensionFilter("Images", "jpg", "jpeg", "png", "bmp", "gif")
                            if (chooser.showOpenDialog(null) == JFileChooser.APPROVE_OPTION) {
                                val file = chooser.selectedFile
                                isLoading = true
                                scope.launch {
                                    val bitmap = loadImageAsync(file)
                                    if (bitmap != null) { imageBitmap = bitmap; markers = emptyList() }
                                    isLoading = false
                                }
                            }
                        }, modifier = Modifier.width(220.dp).height(48.dp), enabled = !isLoading) {
                            Text(if (isLoading) "Loading..." else "📁 Open Image", fontSize = 16.sp)
                        }
                        if (isLoading) {
                            Spacer(Modifier.height(8.dp))
                            LinearProgressIndicator(modifier = Modifier.width(200.dp))
                        }
                        Spacer(Modifier.height(12.dp))
                        Text("Unlimited • Free • On-Device", fontSize = 11.sp, color = Color.White.copy(alpha = 0.3f))
                    }
                }
            }

            // Bottom bar
            if (imageBitmap != null) {
                Surface(shadowElevation = 2.dp) {
                    Row(modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp),
                        verticalAlignment = Alignment.CenterVertically) {

                        Button(onClick = {
                            val chooser = JFileChooser()
                            chooser.dialogTitle = "Open Image"
                            chooser.fileFilter = FileNameExtensionFilter("Images", "jpg", "jpeg", "png", "bmp", "gif")
                            if (chooser.showOpenDialog(null) == JFileChooser.APPROVE_OPTION) {
                                val file = chooser.selectedFile
                                isLoading = true
                                scope.launch {
                                    val bitmap = loadImageAsync(file)
                                    if (bitmap != null) { imageBitmap = bitmap; markers = emptyList() }
                                    isLoading = false
                                }
                            }
                        }, enabled = !isLoading) { Text(if (isLoading) "..." else "📁") }

                        Spacer(Modifier.width(8.dp))

                        OutlinedButton(onClick = {
                            if (markers.isNotEmpty()) markers = markers.dropLast(1)
                        }, enabled = markers.isNotEmpty()) { Text("Undo") }

                        Spacer(Modifier.width(8.dp))

                        OutlinedButton(onClick = { markers = emptyList() },
                            enabled = markers.isNotEmpty()) { Text("Clear") }

                        Spacer(Modifier.width(8.dp))

                        Button(onClick = {
                            // TODO: Add real AI detection with OpenCV/TensorFlow
                            // For now, manual counting only
                        }, enabled = false) {
                            Text("AI (coming soon)")
                        }

                        Spacer(Modifier.weight(1f))

                        if (markers.isNotEmpty()) {
                            TextButton(onClick = {
                                history = history + CountRecord(objectName, markers.size,
                                    LocalDateTime.now().format(DateTimeFormatter.ofPattern("HH:mm")))
                            }) { Text("💾 Save") }
                            TextButton(onClick = {
                                val file = File(System.getProperty("user.home"), "Desktop/opencount_${objectName}.csv")
                                file.writeText("Object,Count\n$objectName,${markers.size}")
                            }) { Text("📊 CSV") }
                        }
                    }
                }
            }
        }
    }
}
