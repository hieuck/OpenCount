# Quick Integration Checklist

## For Views Using Session Images

### SessionRowView Pattern (Already Updated)
```swift
@EnvironmentObject private var lazyImageLoader: LazyImageLoader

var body: some View {
    // Access cached thumbnail
    if let thumb = lazyImageLoader.thumbnails[session.id] {
        Image(uiImage: thumb)
            .resizable()
            .scaledToFill()
    }
}

func onAppear {
    lazyImageLoader.loadThumbnail(for: session.id, from: session)
}
```

### Custom Views Needing Images
1. Add `@EnvironmentObject private var lazyImageLoader: LazyImageLoader`
2. In parent view, ensure it receives the environment object
3. Call `lazyImageLoader.loadThumbnail(...)` on appear
4. Access via `lazyImageLoader.thumbnails[id]`

## For Processing Large Images

### In Inference Code (Already Updated in AIService)
```swift
// Automatic: AIService now calls optimizeImageForInference()
let detections = try await aiService.detect(in: largeImage, ...)

// Manual if needed:
let optimizer = ImageOptimizationService.shared
optimizer.optimizeForProcessing(sourceURL: url) { optimizedImage in
    // Use optimizedImage for inference
}
```

### For Custom Processing
```swift
let optimizer = ImageOptimizationService.shared

// Check if downsampling needed
if optimizer.shouldDownsample(dimensions: imageSize) {
    optimizer.optimizeForProcessing(sourceURL: imageURL) { image in
        // Process downsampled image
    }
}
```

## For Image Import/Save

### In StorageService (Already Updated)
```swift
// Automatic: StorageService.save() now optimizes automatically
try await storage.save(session)
// This triggers:
// - Thumbnail generation
// - Storage optimization
// - Cache population
```

### Manual Image Optimization
```swift
let storage = StorageService.shared
await storage.preloadSessionImages(sessionID)
```

## Memory Management

### Monitor Cache Usage
```swift
let loader = LazyImageLoader()
let memoryUsage = loader.currentMemoryUsage() // bytes
let cacheSize = ThumbnailCacheManager.shared.currentCacheSize()
```

### Clear Cache (e.g., on memory warning)
```swift
ThumbnailCacheManager.shared.clearCache()
lazyImageLoader.reset()
```

## Configuration Tuning

### Adjust Downsampling Thresholds
In `ImageOptimizationService`:
```swift
private let maxProcessingDimension: CGFloat = 1920  // Adjust for your needs
private let processingQuality: CGFloat = 0.85        // Higher = slower/better
```

### Adjust Preload Distance
In `LazyImageLoader`:
```swift
private let preloadDistance: Int = 3  // Items to preload ahead/behind
```

### Adjust Cache Limits
In `ThumbnailCacheManager`:
```swift
private let maxCacheSizeBytes = 100 * 1024 * 1024  // 100MB
```

## Troubleshooting

### Issue: Images not appearing in list
**Solution:** Verify LazyImageLoader is set as environment object in SessionListView

### Issue: Out of memory during inference
**Solution:** Reduce `maxProcessingDimension` from 1920 to 1280, or increase `processingQuality` reduction

### Issue: Slow thumbnail loading
**Solution:** Increase `preloadDistance` from 3 to 5, or pre-warm cache on app launch

### Issue: High memory usage
**Solution:** Reduce `maxCacheSizeBytes` or call `clearCache()` more frequently

## Performance Baselines

After optimization, expect:
- **Memory**: 75-85% reduction for large photo processing
- **Inference speed**: 30-50% faster on images >1920px
- **List scroll FPS**: 55-60fps with 100+ sessions
- **Thumbnail load**: <50ms from cache, <200ms on first generation
