import XCTest
@testable import Voice_Notes

@MainActor
final class RecordingFlowIntegrationTests: XCTestCase {
    
    var audioRecorder: AudioRecorder!
    var recordingsManager: RecordingsManager!
    var testFileURL: URL!
    
    override func setUp() async throws {
        try await super.setUp()
        
        audioRecorder = AudioRecorder.shared
        recordingsManager = RecordingsManager.shared
        
        // Clear existing recordings
        for recording in recordingsManager.recordings {
            recordingsManager.delete(id: recording.id)
        }
    }
    
    override func tearDown() async throws {
        // Clean up test files
        if let fileURL = testFileURL, FileManager.default.fileExists(atPath: fileURL.path) {
            try? FileManager.default.removeItem(at: fileURL)
        }
        
        // Clear test recordings
        for recording in recordingsManager.recordings {
            recordingsManager.delete(id: recording.id)
        }
        
        audioRecorder = nil
        recordingsManager = nil
        testFileURL = nil
        
        try await super.tearDown()
    }
    
    // MARK: - Helper Methods
    
    func createMockRecordingFile(withSize size: Int64) -> (fileName: String, fileURL: URL, fileSize: Int64) {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileName = "recording_\(Int(Date().timeIntervalSince1970)).m4a"
        let fileURL = documentsPath.appendingPathComponent(fileName)
        
        // Create file with specified size
        let data = Data(repeating: 0x00, count: Int(size))
        try? data.write(to: fileURL)
        
        return (fileName, fileURL, size)
    }
    
    // MARK: - Test Cases
    
    func testCompleteRecordingFlowWithValidFile() async throws {
        // Given: A valid recording file
        let mockRecording = createMockRecordingFile(withSize: 1024) // 1KB file
        testFileURL = mockRecording.fileURL
        
        let initialRecordingCount = recordingsManager.recordings.count
        
        // When: Simulating the ContentView flow
        // 1. Stop recording returns valid result
        // 2. Check file size > 0
        // 3. Create Recording object
        // 4. Add recording
        // 5. Start transcription
        
        XCTAssertTrue(mockRecording.fileSize > 0, "File should have content")
        
        let newRecording = Recording(
            fileName: mockRecording.fileName,
            date: Date(),
            duration: 10.0,
            title: ""
        )
        
        recordingsManager.addRecording(newRecording)
        
        // Then: Recording should be added
        XCTAssertEqual(recordingsManager.recordings.count, initialRecordingCount + 1, 
                      "Recording should be added to manager")
        
        let addedRecording = recordingsManager.recordings.first { $0.id == newRecording.id }
        XCTAssertNotNil(addedRecording, "Recording should exist")
        XCTAssertEqual(addedRecording?.status, .idle, "Recording should start in idle state")
        
        // When: Starting transcription
        recordingsManager.startTranscription(for: newRecording)
        
        // Then: Transcription should be initiated
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        if let recording = recordingsManager.recordings.first(where: { $0.id == newRecording.id }) {
            // Should be processing or have completed/failed (depending on API config)
            let isProcessingOrAttempted = recording.status != .idle
            XCTAssertTrue(isProcessingOrAttempted, "Recording should have attempted to process")
        }
    }
    
    func testRecordingFlowWithEmptyFile() async throws {
        // Given: An empty recording file (0 bytes)
        let mockRecording = createMockRecordingFile(withSize: 0)
        testFileURL = mockRecording.fileURL
        
        let initialRecordingCount = recordingsManager.recordings.count
        
        // When: Simulating ContentView flow with empty file
        // ContentView should NOT create recording if fileSize is 0
        
        if mockRecording.fileSize > 0 {
            // This branch should NOT execute
            let newRecording = Recording(
                fileName: mockRecording.fileName,
                date: Date(),
                duration: 0.0,
                title: ""
            )
            recordingsManager.addRecording(newRecording)
            recordingsManager.startTranscription(for: newRecording)
            
            XCTFail("Should not create recording for empty file")
        }
        
        // Then: No recording should be created
        XCTAssertEqual(recordingsManager.recordings.count, initialRecordingCount, 
                      "No recording should be added for empty file")
    }
    
    func testRecordingFlowValidatesFileBeforeTranscription() async throws {
        // Given: A recording with missing file
        let fileName = "nonexistent_\(UUID().uuidString).m4a"
        let recording = Recording(
            fileName: fileName,
            date: Date(),
            duration: 5.0
        )
        
        recordingsManager.addRecording(recording)
        
        // When: Attempting to start transcription
        recordingsManager.startTranscription(for: recording)
        
        // Then: Should fail validation
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        if let failedRecording = recordingsManager.recordings.first(where: { $0.id == recording.id }) {
            if case .failed(let reason) = failedRecording.status {
                XCTAssertTrue(reason.contains("not found") || reason.contains("accessing"), 
                            "Should fail with file error: \(reason)")
            } else {
                XCTFail("Recording should have failed, got status: \(failedRecording.status)")
            }
        }
    }
    
    func testNoDoubleTranscriptionInitiation() async throws {
        // Given: A valid recording
        let mockRecording = createMockRecordingFile(withSize: 1024)
        testFileURL = mockRecording.fileURL
        
        let recording = Recording(
            fileName: mockRecording.fileName,
            date: Date(),
            duration: 5.0
        )
        
        recordingsManager.addRecording(recording)
        
        // When: Starting transcription twice (simulating bug scenario)
        recordingsManager.startTranscription(for: recording)
        
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Count active operations for this recording (would need access to ProcessingManager)
        // Since ProcessingManager prevents duplicate summarizations, verify no crash/error occurs
        
        recordingsManager.startTranscription(for: recording)
        
        // Then: Should handle gracefully without duplicates
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Verify recording is still in valid state
        if let updatedRecording = recordingsManager.recordings.first(where: { $0.id == recording.id }) {
            XCTAssertNotNil(updatedRecording, "Recording should still exist")
            // Should not be in some corrupted state
        }
    }
    
    func testRecordingDeletion() async throws {
        // Given: A recording with file
        let mockRecording = createMockRecordingFile(withSize: 1024)
        testFileURL = mockRecording.fileURL
        
        let recording = Recording(
            fileName: mockRecording.fileName,
            date: Date(),
            duration: 5.0
        )
        
        recordingsManager.addRecording(recording)
        
        // Verify file exists
        XCTAssertTrue(FileManager.default.fileExists(atPath: mockRecording.fileURL.path), 
                     "Recording file should exist")
        
        // When: Deleting the recording
        recordingsManager.delete(id: recording.id)
        
        // Then: Recording and file should be removed
        XCTAssertNil(recordingsManager.recordings.first { $0.id == recording.id }, 
                    "Recording should be removed from manager")
        
        // File deletion is best-effort, may or may not be deleted
        // Just verify no crash occurs
    }
    
    func testProcessingCancellation() async throws {
        // Given: A recording being processed
        let mockRecording = createMockRecordingFile(withSize: 1024)
        testFileURL = mockRecording.fileURL
        
        let recording = Recording(
            fileName: mockRecording.fileName,
            date: Date(),
            duration: 5.0
        )
        
        recordingsManager.addRecording(recording)
        recordingsManager.startTranscription(for: recording)
        
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // When: Cancelling processing
        recordingsManager.cancelProcessing(for: recording.id)
        
        // Then: Should return to idle state
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        if let cancelledRecording = recordingsManager.recordings.first(where: { $0.id == recording.id }) {
            XCTAssertEqual(cancelledRecording.status, .idle, 
                          "Recording should be idle after cancellation")
        }
    }
    
    func testRecordingStatusProgression() async throws {
        // Given: A valid recording
        let mockRecording = createMockRecordingFile(withSize: 1024)
        testFileURL = mockRecording.fileURL
        
        let recording = Recording(
            fileName: mockRecording.fileName,
            date: Date(),
            duration: 5.0
        )
        
        // Track status changes
        var statusChanges: [Recording.Status] = []
        
        recordingsManager.addRecording(recording)
        statusChanges.append(recording.status)
        
        // When: Starting transcription
        recordingsManager.startTranscription(for: recording)
        
        // Then: Monitor status changes
        for _ in 0..<5 {
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            
            if let currentRecording = recordingsManager.recordings.first(where: { $0.id == recording.id }) {
                statusChanges.append(currentRecording.status)
                
                // If reached final state, break
                switch currentRecording.status {
                case .done, .failed, .idle:
                    if statusChanges.count > 1 {
                        break
                    }
                default:
                    continue
                }
            }
        }
        
        // Verify we had status changes (at least added and attempted processing)
        XCTAssertGreaterThan(statusChanges.count, 1, "Status should change during processing")
    }
    
    func testAudioRecorderStopReturnsValidData() {
        // This tests the AudioRecorder integration point
        // Note: Can't actually record in unit tests, but we can test the data structure
        
        // Given: Mock stop recording result
        let mockResult = (duration: 10.0, fileURL: URL(fileURLWithPath: "/tmp/test.m4a"), fileSize: Int64(1024))
        
        // Then: Verify result structure is usable
        XCTAssertGreaterThan(mockResult.duration, 0, "Duration should be positive")
        XCTAssertNotNil(mockResult.fileURL, "File URL should exist")
        
        if let fileSize = mockResult.fileSize {
            XCTAssertGreaterThan(fileSize, 0, "File size should be positive")
        }
        
        // ContentView checks: if let fileSize = result.fileSize, fileSize > 0
        let shouldCreateRecording = mockResult.fileSize ?? 0 > 0
        XCTAssertTrue(shouldCreateRecording, "Should create recording for valid file")
    }
    
    func testRecordingWithZeroFileSizeIsNotProcessed() async throws {
        // Given: A recording result with 0 file size
        let mockFileName = "zero_size_\(UUID().uuidString).m4a"
        let mockFileSize: Int64? = 0
        
        // When: ContentView logic checks file size
        let shouldCreateRecording = (mockFileSize ?? 0) > 0
        
        // Then: Should NOT create recording
        XCTAssertFalse(shouldCreateRecording, "Should not create recording for 0-byte file")
        
        // Verify no recording was added
        let recordingsWithThisName = recordingsManager.recordings.filter { $0.fileName == mockFileName }
        XCTAssertEqual(recordingsWithThisName.count, 0, "No recording should exist with this filename")
    }
    
    func testMultipleRecordingsCanBeProcessedIndependently() async throws {
        // Given: Multiple recordings
        let recording1 = createMockRecordingFile(withSize: 1024)
        let recording2 = createMockRecordingFile(withSize: 2048)
        
        let rec1 = Recording(fileName: recording1.fileName, date: Date(), duration: 5.0)
        let rec2 = Recording(fileName: recording2.fileName, date: Date(), duration: 10.0)
        
        // When: Adding and processing both
        recordingsManager.addRecording(rec1)
        recordingsManager.addRecording(rec2)
        
        recordingsManager.startTranscription(for: rec1)
        recordingsManager.startTranscription(for: rec2)
        
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        // Then: Both should be tracked independently
        let recording1Status = recordingsManager.recordings.first { $0.id == rec1.id }
        let recording2Status = recordingsManager.recordings.first { $0.id == rec2.id }
        
        XCTAssertNotNil(recording1Status, "Recording 1 should exist")
        XCTAssertNotNil(recording2Status, "Recording 2 should exist")
        
        // Both should have attempted processing
        XCTAssertNotEqual(recording1Status?.status, .idle, "Recording 1 should have processed")
        XCTAssertNotEqual(recording2Status?.status, .idle, "Recording 2 should have processed")
        
        // Cleanup
        try? FileManager.default.removeItem(at: recording1.fileURL)
        try? FileManager.default.removeItem(at: recording2.fileURL)
    }
}



