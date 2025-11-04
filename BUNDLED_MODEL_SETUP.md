# Adding Bundled Whisper Base Model

This guide explains how to bundle the Whisper base model with your app so it's immediately available without downloading.

## Prerequisites

1. Download the Whisper base model from HuggingFace or OpenAI
2. The model should be in the WhisperKit format (directory structure with required files)

## Model Structure

The base model directory (`whisper-base`) should contain:
```
whisper-base/
├── config.json
├── generation_config.json
├── merges.txt
├── model.safetensors (or model files)
├── normalizer.json
├── preprocessor_config.json
├── tokenizer.json
├── vocab.json
└── (other model files)
```

## Adding to Xcode Project

### Step 1: Create BundledModels Directory

1. In Finder, create a folder named `BundledModels` in your project directory
2. Place the `whisper-base` folder inside it:
   ```
   Voice Notes/
   ├── BundledModels/
   │   └── whisper-base/
   │       ├── config.json
   │       ├── ... (other model files)
   ```

### Step 2: Add to Xcode

1. Open your Xcode project
2. In the Project Navigator, right-click on "Voice Notes" target
3. Select "Add Files to 'Voice Notes'..."
4. Navigate to and select the `BundledModels` folder
5. **IMPORTANT**: Check these options:
   - ✅ "Copy items if needed"
   - ✅ "Create folder references" (NOT "Create groups")
   - ✅ Target: "Voice Notes" should be checked

### Step 3: Verify Bundle Configuration

1. Select the `BundledModels` folder in Xcode
2. In File Inspector (right panel), verify:
   - "Target Membership" shows "Voice Notes" is checked
   - "Type" shows "Folder Reference" (blue folder icon)

## How It Works

### Automatic Copy on First Launch

The code in `WhisperModelManager.swift` automatically handles copying:

```swift
private func copyBundledModelsIfNeeded() {
    // Looks for model in app bundle at: BundledModels/whisper-base/
    guard let bundlePath = Bundle.main.path(forResource: "whisper-base", ofType: nil, inDirectory: "BundledModels") else {
        print("ℹ️ No bundled base model found")
        return
    }

    // Copies to app's documents directory on first launch
    // Skips copying if model already exists
}
```

### Default Model

The base model is set as the default:
```swift
@Published var selectedModel: WhisperModelSize = .base
```

## Verification

### Check Console Logs

When the app launches, you should see one of these messages:

**Success (first launch):**
```
✅ WhisperModelManager: Bundled base model copied successfully
   From: /path/to/app.bundle/BundledModels/whisper-base
   To: /path/to/Documents/WhisperModels/whisper-base
```

**Already Exists (subsequent launches):**
```
ℹ️ WhisperModelManager: Base model already exists, skipping copy
```

**Not Found (if bundle missing):**
```
ℹ️ WhisperModelManager: No bundled base model found
```

### Check UI

1. Open the app
2. Go to Settings → Local Transcription
3. The "Base" model should show a green checkmark (✓) indicating it's downloaded
4. User should be able to use local transcription immediately

## App Size Impact

Including the base model will increase your app bundle size by approximately:
- **Base Model**: ~145 MB

This means:
- Larger initial download from App Store (~145 MB more)
- But users get instant offline transcription without additional downloads
- No cellular data usage for model download

## Alternative: Download on Demand

If you prefer not to increase app size, you can skip bundling the model. Users will need to:
1. Enable local transcription in settings
2. Download the base model (one-time, ~145 MB)
3. Wait for download to complete before using offline transcription

## Troubleshooting

### Model Not Found

If you see "No bundled base model found":
1. Verify folder structure: `BundledModels/whisper-base/`
2. Check Xcode: folder should be blue (folder reference)
3. Verify Target Membership is checked
4. Clean build folder (Cmd+Shift+K) and rebuild

### Copy Failed

If you see "Failed to copy bundled model":
1. Check console for detailed error message
2. Verify file permissions on bundled files
3. Ensure app has write access to documents directory

### Wrong Model Format

If transcription fails after bundling:
1. Verify model is in WhisperKit format (not raw Whisper)
2. Check that all required files are present
3. Test with a downloaded model first to verify transcription works

## Notes

- The bundled model is only copied once (first launch)
- If user deletes the model, it won't be automatically restored
- Updates to bundled model require app update
- Consider using `.gitignore` to exclude large model files from git
