import XCTest
@testable import Voice_Notes

@MainActor
final class ProcessingManagerTests: XCTestCase {
    
    var processingManager: ProcessingManager!
    var testRecordingId: UUID!
    var testAudioURL: URL!
    
    override func setUp() async throws {
        try await super.setUp()
        
        processingManager = ProcessingManager()
        testRecordingId = UUID()
        testAudioURL = createTestAudioFile()
    }
    
    override func tearDown() async throws {
        // Clean up test files
        if FileManager.default.fileExists(atPath: testAudioURL.path) {
            try? FileManager.default.removeItem(at: testAudioURL)
        }
        
        processingManager = nil
        testRecordingId = nil
        testAudioURL = nil
        
        try await super.tearDown()
    }
    
    // MARK: - Helper Methods
    
    func createTestAudioFile() -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileName = "test_audio_\(UUID().uuidString).m4a"
        let fileURL = documentsPath.appendingPathComponent(fileName)
        
        // Create a minimal valid m4a file
        let testData = Data([
            0x00, 0x00, 0x00, 0x20, 0x66, 0x74, 0x79, 0x70,
            0x4D, 0x34, 0x41, 0x20, 0x00, 0x00, 0x02, 0x00,
            0x69, 0x73, 0x6F, 0x6D, 0x69, 0x73, 0x6F, 0x32,
            0x6D, 0x70, 0x34, 0x31, 0x00, 0x00, 0x00, 0x08,
        ])
        
        try? testData.write(to: fileURL)
        return fileURL
    }
    
    // MARK: - Test Cases
    
    func testStartTranscriptionCreatesOperation() async throws {
        // When: Starting transcription
        let operation = processingManager.startTranscription(
            for: testRecordingId,
            audioURL: testAudioURL,
            languageHint: nil
        )
        
        // Then: Operation should be created and tracked
        XCTAssertEqual(operation.recordingId, testRecordingId, "Operation should be for correct recording")
        XCTAssertEqual(operation.type, .transcription, "Operation type should be transcription")
        
        // Check operation is in active operations
        XCTAssertNotNil(processingManager.activeOperations[operation.id], "Operation should be tracked")
        
        if case .running(let progress) = operation.status {
            XCTAssertEqual(progress, 0.0, "Initial progress should be 0")
        } else {
            XCTFail("New operation should have running status")
        }
    }
    
    func testStartSummarizationCreatesOperation() async throws {
        // Given: A test transcript
        let transcript = "This is a test transcript for summarization."
        
        // When: Starting summarization
        let operation = processingManager.startSummarization(
            for: testRecordingId,
            transcript: transcript
        )
        
        // Then: Operation should be created and tracked
        XCTAssertEqual(operation.recordingId, testRecordingId, "Operation should be for correct recording")
        XCTAssertEqual(operation.type, .summarization, "Operation type should be summarization")
        XCTAssertNotNil(processingManager.activeOperations[operation.id], "Operation should be tracked")
    }
    
    func testMultipleSummarizationRequestsOnlyCreateOneOperation() async throws {
        // Given: A test transcript
        let transcript = "Test transcript"
        
        // When: Starting summarization twice
        let operation1 = processingManager.startSummarization(for: testRecordingId, transcript: transcript)
        let operation2 = processingManager.startSummarization(for: testRecordingId, transcript: transcript)
        
        // Then: Should return the same operation (no duplicate)
        XCTAssertEqual(operation1.id, operation2.id, "Should return existing operation, not create duplicate")
        
        // Count active summarization operations for this recording
        let summarizationOps = processingManager.activeOperations.values.filter {
            $0.recordingId == testRecordingId && $0.type == .summarization
        }
        
        XCTAssertEqual(summarizationOps.count, 1, "Should only have one summarization operation")
    }
    
    func testCancelOperation() async throws {
        // Given: An active operation
        let operation = processingManager.startTranscription(
            for: testRecordingId,
            audioURL: testAudioURL,
            languageHint: nil
        )
        
        // When: Cancelling the operation
        processingManager.cancelOperation(operation.id)
        
        // Then: Operation should be marked as cancelled
        if let cancelledOp = processingManager.activeOperations[operation.id] {
            if case .cancelled = cancelledOp.status {
                // Success
            } else {
                XCTFail("Operation should have cancelled status, got: \(cancelledOp.status)")
            }
        } else {
            XCTFail("Operation should still exist in active operations")
        }
    }
    
    func testCleanupCompletedOperations() async throws {
        // Given: Multiple operations in different states
        let operation1 = processingManager.startTranscription(for: UUID(), audioURL: testAudioURL, languageHint: nil)
        
        // Manually mark operation as completed (simulating completion)
        var completedOp = operation1
        completedOp.status = .completed(result: .transcript("Test transcript"))
        processingManager.activeOperations[operation1.id] = completedOp
        
        let initialCount = processingManager.activeOperations.count
        
        // When: Cleaning up completed operations
        processingManager.cleanupCompletedOperations()
        
        // Then: Completed operations should be removed
        XCTAssertLessThan(processingManager.activeOperations.count, initialCount, 
                         "Completed operations should be removed")
        XCTAssertNil(processingManager.activeOperations[operation1.id], 
                    "Completed operation should be cleaned up")
    }
    
    func testCleanupFailedOperations() async throws {
        // Given: A failed operation
        let operation = processingManager.startTranscription(for: testRecordingId, audioURL: testAudioURL, languageHint: nil)
        
        // Mark as failed
        var failedOp = operation
        failedOp.status = .failed(error: TranscriptionError.apiKeyMissing)
        processingManager.activeOperations[operation.id] = failedOp
        
        // When: Cleaning up
        processingManager.cleanupCompletedOperations()
        
        // Then: Failed operations should be removed
        XCTAssertNil(processingManager.activeOperations[operation.id], 
                    "Failed operation should be cleaned up")
    }
    
    func testOperationProgressTracking() async throws {
        // Given: An active operation
        let operation = processingManager.startTranscription(
            for: testRecordingId,
            audioURL: testAudioURL,
            languageHint: nil
        )
        
        // Allow operation to start
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Then: Should be able to track operation state
        if let trackedOp = processingManager.activeOperations[operation.id] {
            switch trackedOp.status {
            case .running(let progress):
                XCTAssertGreaterThanOrEqual(progress, 0.0, "Progress should be >= 0")
                XCTAssertLessThanOrEqual(progress, 1.0, "Progress should be <= 1")
            case .failed, .cancelled:
                // These are valid states if API isn't configured in test env
                break
            case .completed:
                // Unexpected in such short time but valid
                break
            }
        }
    }
    
    func testOperationTypeEnumeration() {
        // Test that operation types are correctly defined
        let transcriptionOp = ProcessingOperation(
            id: UUID(),
            recordingId: UUID(),
            type: .transcription,
            status: .running(progress: 0.0)
        )
        
        let summarizationOp = ProcessingOperation(
            id: UUID(),
            recordingId: UUID(),
            type: .summarization,
            status: .running(progress: 0.0)
        )
        
        XCTAssertEqual(transcriptionOp.type, .transcription)
        XCTAssertEqual(summarizationOp.type, .summarization)
        XCTAssertNotEqual(transcriptionOp.type, summarizationOp.type)
    }
    
    func testOperationStatusStates() {
        let runningStatus: ProcessingOperation.OperationStatus = .running(progress: 0.5)
        let completedStatus: ProcessingOperation.OperationStatus = .completed(result: .transcript("Test"))
        let failedStatus: ProcessingOperation.OperationStatus = .failed(error: TranscriptionError.cancelled)
        let cancelledStatus: ProcessingOperation.OperationStatus = .cancelled
        
        // Verify different status types
        if case .running(let progress) = runningStatus {
            XCTAssertEqual(progress, 0.5)
        } else {
            XCTFail("Should be running status")
        }
        
        if case .completed = completedStatus {
            // Success
        } else {
            XCTFail("Should be completed status")
        }
        
        if case .failed = failedStatus {
            // Success
        } else {
            XCTFail("Should be failed status")
        }
        
        if case .cancelled = cancelledStatus {
            // Success
        } else {
            XCTFail("Should be cancelled status")
        }
    }
    
    func testOperationResultTypes() {
        // Test transcript result
        let transcriptResult: ProcessingOperation.OperationResult = .transcript("Sample transcript")
        
        if case .transcript(let text) = transcriptResult {
            XCTAssertEqual(text, "Sample transcript")
        } else {
            XCTFail("Should be transcript result")
        }
        
        // Test summary result
        let summaryResult: ProcessingOperation.OperationResult = .summary(clean: "Clean summary", raw: "Raw summary")
        
        if case .summary(let clean, let raw) = summaryResult {
            XCTAssertEqual(clean, "Clean summary")
            XCTAssertEqual(raw, "Raw summary")
        } else {
            XCTFail("Should be summary result")
        }
    }
    
    func testCancellationTokenInOperation() {
        let operation = ProcessingOperation(
            id: UUID(),
            recordingId: UUID(),
            type: .transcription,
            status: .running(progress: 0.0)
        )
        
        // Verify cancel token exists and is not cancelled by default
        XCTAssertFalse(operation.cancelToken.isCancelled, "New operation should not be cancelled")
    }
    
    func testMultipleOperationsForDifferentRecordings() async throws {
        // Given: Multiple recordings
        let recordingId1 = UUID()
        let recordingId2 = UUID()
        
        // When: Starting operations for both
        let op1 = processingManager.startTranscription(for: recordingId1, audioURL: testAudioURL, languageHint: nil)
        let op2 = processingManager.startTranscription(for: recordingId2, audioURL: testAudioURL, languageHint: nil)
        
        // Then: Both operations should exist independently
        XCTAssertNotEqual(op1.id, op2.id, "Operations should have unique IDs")
        XCTAssertEqual(op1.recordingId, recordingId1, "Operation 1 should track recording 1")
        XCTAssertEqual(op2.recordingId, recordingId2, "Operation 2 should track recording 2")
        
        XCTAssertNotNil(processingManager.activeOperations[op1.id])
        XCTAssertNotNil(processingManager.activeOperations[op2.id])
        XCTAssertGreaterThanOrEqual(processingManager.activeOperations.count, 2, 
                                    "Should have at least 2 active operations")
    }
}



