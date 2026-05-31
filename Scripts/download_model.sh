#!/bin/bash
# Script tải YOLOv3 Core ML model về project
# Sử dụng: cd Scripts && ./download_model.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
MODEL_DIR="$PROJECT_DIR/OpenCount_iOS/OpenCount/Resources"

echo "🤖 OpenCount - Tải YOLOv3 Core ML Model"
echo "========================================="

mkdir -p "$MODEL_DIR"

echo "📥 Đang tải model..."
curl -fSL -o "$MODEL_DIR/YOLOv3.mlmodel" \
  "https://docs-assets.developer.apple.com/coreml/models/Image/ObjectDetection/YOLOv3.mlmodel"

echo "✅ Tải xong!"
echo "📍 Model: $MODEL_DIR/YOLOv3.mlmodel"
echo ""
echo "📝 Bước tiếp theo:"
echo "1. Mở OpenCount.xcodeproj trong Xcode"
echo "2. Build & Run (Cmd+R)"
