import XCTest
@testable import Voice_Notes

@MainActor
final class RecordingProcessingTests: XCTestCase {
    
    var recordingsManager: RecordingsManager!
    var testRecording: Recording!
    var testFileURL: URL!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Use shared instance since it's a singleton
        recordingsManager = RecordingsManager.shared
        
        // Clear any existing recordings for clean test state
        for recording in recordingsManager.recordings {
            recordingsManager.delete(id: recording.id)
        }
        
        // Create a test audio file
        testFileURL = createTestAudioFile()
        
        testRecording = Recording(
            fileName: testFileURL.lastPathComponent,
            date: Date(),
            duration: 10.0,
            title: "Test Recording"
        )
    }
    
    override func tearDown() async throws {
        // Clean up test files
        if FileManager.default.fileExists(atPath: testFileURL.path) {
            try? FileManager.default.removeItem(at: testFileURL)
        }
        
        // Clear test recordings
        for recording in recordingsManager.recordings {
            recordingsManager.delete(id: recording.id)
        }
        
        recordingsManager = nil
        testRecording = nil
        testFileURL = nil
        
        try await super.tearDown()
    }
    
    // MARK: - Helper Methods
    
    func createTestAudioFile() -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileName = "test_recording_\(UUID().uuidString).m4a"
        let fileURL = documentsPath.appendingPathComponent(fileName)
        
        // Create a small valid m4a file (just enough to pass validation)
        let testData = Data([
            0x00, 0x00, 0x00, 0x20, 0x66, 0x74, 0x79, 0x70, // ftyp header
            0x4D, 0x34, 0x41, 0x20, 0x00, 0x00, 0x02, 0x00,
            0x69, 0x73, 0x6F, 0x6D, 0x69, 0x73, 0x6F, 0x32,
            0x6D, 0x70, 0x34, 0x31, 0x00, 0x00, 0x00, 0x08,
        ])
        
        try? testData.write(to: fileURL)
        return fileURL
    }
    
    func waitForRecordingStatus(recordingId: UUID, status: Recording.Status, timeout: TimeInterval = 5.0) async throws -> Bool {
        let startTime = Date()
        
        while Date().timeIntervalSince(startTime) < timeout {
            if let recording = recordingsManager.recordings.first(where: { $0.id == recordingId }) {
                switch (recording.status, status) {
                case (.idle, .idle),
                     (.done, .done):
                    return true
                case (.transcribing, .transcribing),
                     (.summarizing, .summarizing):
                    return true
                case (.failed, .failed):
                    return true
                default:
                    break
                }
            }
            
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }
        
        return false
    }
    
    // MARK: - Test Cases
    
    func testAddRecordingDoesNotAutoStartTranscription() async throws {
        // Given: A test recording
        let initialCount = recordingsManager.recordings.count
        
        // When: Adding a recording
        recordingsManager.addRecording(testRecording)
        
        // Then: Recording should be added but not processing
        XCTAssertEqual(recordingsManager.recordings.count, initialCount + 1, "Recording should be added")
        
        let addedRecording = recordingsManager.recordings.first { $0.id == testRecording.id }
        XCTAssertNotNil(addedRecording, "Recording should exist in manager")
        XCTAssertEqual(addedRecording?.status, .idle, "Recording should start in idle state, not auto-transcribing")
        
        // Wait a bit to ensure no auto-transcription starts
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        if let recording = recordingsManager.recordings.first(where: { $0.id == testRecording.id }) {
            XCTAssertEqual(recording.status, .idle, "Recording should still be idle after delay")
        }
    }
    
    func testStartTranscriptionValidatesFileExists() async throws {
        // Given: A recording with non-existent file
        let invalidRecording = Recording(
            fileName: "nonexistent_file.m4a",
            date: Date(),
            duration: 5.0
        )
        
        recordingsManager.addRecording(invalidRecording)
        
        // When: Starting transcription
        recordingsManager.startTranscription(for: invalidRecording)
        
        // Then: Should fail with appropriate error
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        if let recording = recordingsManager.recordings.first(where: { $0.id == invalidRecording.id }) {
            if case .failed(let reason) = recording.status {
                XCTAssertTrue(reason.contains("not found") || reason.contains("Error accessing"), 
                            "Should fail with file not found error, got: \(reason)")
            } else {
                XCTFail("Recording should have failed status, got: \(recording.status)")
            }
        }
    }
    
    func testStartTranscriptionValidatesFileNotEmpty() async throws {
        // Given: An empty file
        let emptyFileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("empty_\(UUID().uuidString).m4a")
        try Data().write(to: emptyFileURL) // Write empty data
        
        let emptyRecording = Recording(
            fileName: emptyFileURL.lastPathComponent,
            date: Date(),
            duration: 5.0
        )
        
        recordingsManager.addRecording(emptyRecording)
        
        // When: Starting transcription
        recordingsManager.startTranscription(for: emptyRecording)
        
        // Then: Should fail with empty file error
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        if let recording = recordingsManager.recordings.first(where: { $0.id == emptyRecording.id }) {
            if case .failed(let reason) = recording.status {
                XCTAssertTrue(reason.contains("empty"), "Should fail with empty file error, got: \(reason)")
            } else {
                XCTFail("Recording should have failed status, got: \(recording.status)")
            }
        }
        
        // Cleanup
        try? FileManager.default.removeItem(at: emptyFileURL)
    }
    
    func testRecordingStatusUpdates() async throws {
        // Given: A recording added to manager
        recordingsManager.addRecording(testRecording)
        
        // When: Starting transcription (mock - won't actually call API in tests)
        recordingsManager.startTranscription(for: testRecording)
        
        // Then: Status should change to transcribing
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        if let recording = recordingsManager.recordings.first(where: { $0.id == testRecording.id }) {
            // Should be either transcribing or failed (if API key not configured in test env)
            let isTranscribingOrFailed = recording.status.isProcessing || 
                                        (recording.status != .idle && recording.status != .done)
            XCTAssertTrue(isTranscribingOrFailed, "Recording should be processing or have attempted to process")
        }
    }
    
    func testDeleteRecordingRemovesFromList() async throws {
        // Given: A recording in the manager
        recordingsManager.addRecording(testRecording)
        let initialCount = recordingsManager.recordings.count
        
        // When: Deleting the recording
        recordingsManager.delete(id: testRecording.id)
        
        // Then: Recording should be removed
        XCTAssertEqual(recordingsManager.recordings.count, initialCount - 1, "Recording count should decrease")
        XCTAssertNil(recordingsManager.recordings.first { $0.id == testRecording.id }, "Recording should be deleted")
    }
    
    func testUpdateRecordingModifiesProperties() async throws {
        // Given: A recording in the manager
        recordingsManager.addRecording(testRecording)
        
        let newTranscript = "Test transcript text"
        let newTitle = "Updated Title"
        
        // When: Updating recording properties
        recordingsManager.updateRecording(
            testRecording.id,
            transcript: newTranscript,
            title: newTitle
        )
        
        // Then: Recording should be updated
        if let updatedRecording = recordingsManager.recordings.first(where: { $0.id == testRecording.id }) {
            XCTAssertEqual(updatedRecording.transcript, newTranscript, "Transcript should be updated")
            XCTAssertEqual(updatedRecording.title, newTitle, "Title should be updated")
        } else {
            XCTFail("Recording should exist after update")
        }
    }
    
    func testCancelProcessingStopsOperation() async throws {
        // Given: A recording that's being processed
        recordingsManager.addRecording(testRecording)
        recordingsManager.startTranscription(for: testRecording)
        
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // When: Cancelling processing
        recordingsManager.cancelProcessing(for: testRecording.id)
        
        // Then: Recording should return to idle state
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        if let recording = recordingsManager.recordings.first(where: { $0.id == testRecording.id }) {
            XCTAssertEqual(recording.status, .idle, "Recording should be idle after cancellation")
        }
    }
    
    func testRetryTranscriptionRestartsProcessing() async throws {
        // Given: A recording that failed
        let failedRecording = Recording(
            fileName: testFileURL.lastPathComponent,
            date: Date(),
            duration: 5.0,
            status: .failed(reason: "Test failure")
        )
        
        recordingsManager.addRecording(failedRecording)
        
        // When: Retrying transcription
        recordingsManager.retryTranscription(for: failedRecording)
        
        // Then: Should attempt to transcribe again
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        if let recording = recordingsManager.recordings.first(where: { $0.id == failedRecording.id }) {
            // Should no longer be in failed state (either processing or different error)
            if case .failed(let reason) = recording.status {
                // If it fails again, it should be a different/fresh error
                XCTAssertNotEqual(reason, "Test failure", "Should have attempted new transcription")
            }
        }
    }
    
    func testRecordingPersistence() async throws {
        // Given: A recording added to manager
        recordingsManager.addRecording(testRecording)
        
        // Force save
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // When: Creating a new manager instance and loading
        // Note: Since RecordingsManager is a singleton, we can't easily test this
        // But we can verify the data is saved to UserDefaults
        
        let userDefaults = UserDefaults.standard
        let recordingsData = userDefaults.data(forKey: "SavedRecordings")
        
        // Then: Data should be persisted
        XCTAssertNotNil(recordingsData, "Recordings should be saved to UserDefaults")
        
        if let data = recordingsData {
            let decodedRecordings = try? JSONDecoder().decode([Recording].self, from: data)
            XCTAssertNotNil(decodedRecordings, "Recordings should be decodable")
            XCTAssertTrue(decodedRecordings?.contains(where: { $0.id == testRecording.id }) ?? false,
                         "Test recording should be in saved data")
        }
    }
    
    func testTagManagement() async throws {
        // Given: A recording
        recordingsManager.addRecording(testRecording)
        
        // When: Adding tags
        recordingsManager.addTagToRecording(recordingId: testRecording.id, tag: "test")
        recordingsManager.addTagToRecording(recordingId: testRecording.id, tag: "important")
        
        // Then: Tags should be added
        if let recording = recordingsManager.recordings.first(where: { $0.id == testRecording.id }) {
            XCTAssertTrue(recording.tags.contains("test"), "Should contain 'test' tag")
            XCTAssertTrue(recording.tags.contains("important"), "Should contain 'important' tag")
            XCTAssertEqual(recording.tags.count, 2, "Should have 2 tags")
        }
        
        // When: Removing a tag
        recordingsManager.removeTagFromRecording(recordingId: testRecording.id, tag: "test")
        
        // Then: Tag should be removed
        if let recording = recordingsManager.recordings.first(where: { $0.id == testRecording.id }) {
            XCTAssertFalse(recording.tags.contains("test"), "Should not contain 'test' tag")
            XCTAssertTrue(recording.tags.contains("important"), "Should still contain 'important' tag")
            XCTAssertEqual(recording.tags.count, 1, "Should have 1 tag")
        }
    }
}



