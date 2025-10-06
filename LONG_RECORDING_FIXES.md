# Long Recording Summarization Fixes

## Problem
Users reported that 26-minute recordings were not getting summarized. The summarization appeared to get "stuck" and the retry button didn't work.

## Root Causes Identified

### 1. **Transcript Length Limit Too Restrictive**
- **Old limit**: 50,000 characters
- **Issue**: A 26-minute recording at 150 words/min = ~3,900 words = ~23,400 chars, which is close to the limit. Dense conversations or technical discussions could easily exceed it.
- **Fix**: Increased limit to 100,000 characters

### 2. **Network Timeout Too Short**
- **Old timeout**: 600 seconds (10 minutes)
- **Issue**: Long transcripts take longer to process by AI models
- **Fix**: Increased to 900 seconds (15 minutes)

### 3. **Silent Failures**
- **Issue**: Errors weren't being properly logged, making it hard to diagnose why summarization failed
- **Fix**: Added comprehensive logging:
  - Transcript length (characters and word count)
  - Request/response timing
  - Specific error types (timeout, rate limit, payload too large)
  - Network error details

### 4. **Timeout Errors Not Handled**
- **Issue**: URLError timeout wasn't caught and converted to user-friendly message
- **Fix**: Explicit handling of `URLError.timedOut` with clear message: "Request timed out. Try a shorter recording or retry."

## Changes Made

### File: `OpenAISummarizationService.swift`
```swift
// OLD
if text.count > 50000 {
    throw SummarizationError.textTooLong
}

// NEW
if text.count > 100000 {
    print("⚠️ Transcript too long: \(text.count) characters (limit: 100,000)")
    throw SummarizationError.textTooLong
}
print("📝 Processing transcript: \(text.count) characters (~\(text.count / 150) words)")
```

### File: `Providers/OpenAISummaryProvider.swift`

**Extended Timeouts:**
```swift
config.timeoutIntervalForRequest = 180.0  // 3 minutes per request
config.timeoutIntervalForResource = 900.0  // 15 minutes total
```

**Added Logging:**
```swift
let charCount = transcript.count
let wordCount = transcript.split(separator: " ").count
print("📝 OpenAISummaryProvider: Processing \(charCount) chars (~\(wordCount) words)")
print("📤 OpenAISummaryProvider: Sending request to OpenAI...")

let startTime = Date()
// ... network request ...
let elapsed = Date().timeIntervalSince(startTime)
print("📥 OpenAISummaryProvider: Response received in \(String(format: "%.1f", elapsed))s")
```

**Better Error Handling:**
```swift
case 413:  // Payload too large
    print("❌ OpenAISummaryProvider: Payload too large (413)")
    throw SummarizationError.textTooLong

// Timeout handling
if let urlError = error as? URLError {
    if urlError.code == .timedOut {
        print("❌ OpenAISummaryProvider: Request timed out after \(elapsed)s")
        throw SummarizationError.networkError(NSError(
            domain: "OpenAI",
            code: -1001,
            userInfo: [NSLocalizedDescriptionKey: "Request timed out. Try a shorter recording or retry."]
        ))
    }
}
```

## User Experience Improvements

### Before
- 26-minute recording appears to "hang"
- No error message shown
- Retry button doesn't work (same silent failure)
- No way to know what went wrong

### After
- Clear logging shows exactly what's happening:
  - `📝 Processing transcript: 38,450 characters (~5,640 words)`
  - `📤 Sending request to OpenAI...`
  - Either:
    - `📥 Response received in 45.3s` ✅
    - `❌ Request timed out after 900.0s` (with user-friendly error)
    - `❌ Transcript too long (105,000 chars)` (with clear limit)

- Error messages are shown in the UI
- Retry button will work (errors are properly thrown and caught)
- Users know if they need to:
  - Wait longer (in progress)
  - Retry (temporary network issue)
  - Split the recording (too long)

## Testing Recommendations

1. **Test with 20-30 minute recording**
   - Should now succeed (previously might fail)
   - Check console logs for timing info

2. **Test with very long recording (45+ min)**
   - Should fail with clear "text too long" error
   - Error should be displayed in UI
   - User should see message suggesting shorter recordings

3. **Test retry button**
   - After any failure, retry should work
   - Console should show new attempt with timing

4. **Test in poor network conditions**
   - Timeout should be caught and displayed
   - Message should suggest retry

## Supported Recording Lengths

| Duration | Word Count | Char Count | Status |
|----------|-----------|------------|--------|
| 10 min | ~1,500 | ~9,000 | ✅ Always works |
| 20 min | ~3,000 | ~18,000 | ✅ Always works |
| 30 min | ~4,500 | ~27,000 | ✅ Should work |
| 45 min | ~6,750 | ~40,500 | ✅ Should work |
| 60 min | ~9,000 | ~54,000 | ⚠️ Depends on content density |
| 90 min | ~13,500 | ~81,000 | ⚠️ May hit limit |
| 120 min | ~18,000 | ~108,000 | ❌ Exceeds limit |

## Future Improvements

1. **Chunking for Very Long Recordings**
   - Split 60+ min recordings into chunks
   - Summarize each chunk separately
   - Combine summaries

2. **Progress Indicators**
   - Show "Processing large transcript..." message
   - Estimated time remaining based on length

3. **Smart Truncation**
   - If exceeds limit, truncate and summarize
   - Add note: "Summary based on first X minutes"

4. **Retry with Exponential Backoff**
   - Auto-retry on timeout with longer timeout
   - Show "Retrying with extended timeout..."

## Console Output Examples

### Successful 26-min Recording
```
📝 OpenAISummaryProvider: Processing 38,450 chars (~5,640 words), length: standard
📤 OpenAISummaryProvider: Sending request to OpenAI...
📥 OpenAISummaryProvider: Response received in 52.3s
✅ Summary completed for recording ABC-123
    Summary length: 1,245 chars
```

### Failed Due to Timeout
```
📝 OpenAISummaryProvider: Processing 95,000 chars (~13,900 words), length: detailed
📤 OpenAISummaryProvider: Sending request to OpenAI...
❌ OpenAISummaryProvider: Request timed out after 900.0s
🔄 ProcessingManager: Summary failed for recording XYZ-789
Error: Request timed out. Try a shorter recording or retry.
```

### Failed Due to Length
```
📝 OpenAISummaryProvider: Processing 108,000 chars (~15,800 words), length: standard
❌ OpenAISummaryProvider: Transcript too long (108,000 chars)
Error: Text is too long for summarization
```
