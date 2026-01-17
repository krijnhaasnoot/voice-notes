#!/bin/bash

# Download WhisperKit model for bundling with the app
# This script downloads the optimized CoreML model from HuggingFace
# Usage: ./download_whisper_model.sh [tiny|base|small]

set -e

# Allow model selection via argument, default to base (balanced speed and quality)
MODEL_SIZE="${1:-base}"
MODEL_NAME="openai_whisper-${MODEL_SIZE}"
OUTPUT_DIR="../BundledModels"

# Model info
case $MODEL_SIZE in
    tiny)
        MODEL_INFO="~75MB, ~10x real-time speed, basic quality"
        ;;
    base)
        MODEL_INFO="~145MB, ~5x real-time speed, good quality (recommended)"
        ;;
    small)
        MODEL_INFO="~466MB, ~2x real-time speed, excellent quality"
        ;;
    *)
        echo "❌ Unknown model size: $MODEL_SIZE"
        echo "Usage: $0 [tiny|base|small]"
        exit 1
        ;;
esac

echo "🎙️ Downloading WhisperKit ${MODEL_SIZE} model..."
echo "   $MODEL_INFO"
echo ""

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Check if huggingface-cli is available
if command -v huggingface-cli &> /dev/null; then
    echo "📥 Using huggingface-cli to download model..."
    huggingface-cli download argmaxinc/whisperkit-coreml "$MODEL_NAME" --local-dir "$OUTPUT_DIR" --local-dir-use-symlinks False
else
    echo "📥 Downloading model files manually..."
    
    BASE_URL="https://huggingface.co/argmaxinc/whisperkit-coreml/resolve/main/$MODEL_NAME"
    MODEL_DIR="$OUTPUT_DIR/$MODEL_NAME"
    
    mkdir -p "$MODEL_DIR"
    
    # Download config files
    echo "   Downloading config.json..."
    curl -L -o "$MODEL_DIR/config.json" "$BASE_URL/config.json" 2>/dev/null || true
    
    echo "   Downloading generation_config.json..."
    curl -L -o "$MODEL_DIR/generation_config.json" "$BASE_URL/generation_config.json" 2>/dev/null || true
    
    echo ""
    echo "⚠️  For complete model download, install huggingface-cli:"
    echo "   pip install huggingface_hub"
    echo ""
    echo "   Then run:"
    echo "   huggingface-cli download argmaxinc/whisperkit-coreml $MODEL_NAME --local-dir $OUTPUT_DIR"
fi

echo ""
echo "✅ Model downloaded to: $OUTPUT_DIR/$MODEL_NAME"
echo ""
echo "📋 Next steps:"
echo "   1. Open Xcode"
echo "   2. Drag the 'BundledModels' folder into your project"
echo "   3. Make sure 'Copy items if needed' is checked"
echo "   4. Select 'Create folder references' (blue folder icon)"
echo "   5. Build and run!"
echo ""
echo "💡 To download a different model size:"
echo "   ./download_whisper_model.sh tiny   # Fastest, basic quality"
echo "   ./download_whisper_model.sh base   # Balanced (default)"
echo "   ./download_whisper_model.sh small  # Best quality"
echo ""
