import XCTest
@testable import Voice_Notes

class StringExtensionTests: XCTestCase {
    
    // MARK: - isLikelyAction Tests
    
    func testActionVerbs() {
        // Test common action verbs
        XCTAssertTrue("call John".isLikelyAction)
        XCTAssertTrue("email the client".isLikelyAction)
        XCTAssertTrue("buy groceries".isLikelyAction)
        XCTAssertTrue("schedule meeting".isLikelyAction)
        XCTAssertTrue("review document".isLikelyAction)
        XCTAssertTrue("book appointment".isLikelyAction)
        XCTAssertTrue("follow up with Sarah".isLikelyAction)
        XCTAssertTrue("check inventory".isLikelyAction)
        XCTAssertTrue("update website".isLikelyAction)
        XCTAssertTrue("create proposal".isLikelyAction)
    }
    
    func testActionPhrases() {
        // Test task patterns
        XCTAssertTrue("need to finish report".isLikelyAction)
        XCTAssertTrue("should call dentist".isLikelyAction)
        XCTAssertTrue("must submit form".isLikelyAction)
        XCTAssertTrue("have to buy milk".isLikelyAction)
        XCTAssertTrue("remember to lock door".isLikelyAction)
        XCTAssertTrue("task: complete onboarding".isLikelyAction)
        XCTAssertTrue("todo: organize desk".isLikelyAction)
        XCTAssertTrue("action: send invoice".isLikelyAction)
    }
    
    func testActionQuestions() {
        // Test action-oriented questions
        XCTAssertTrue("when should I call?".isLikelyAction)
        XCTAssertTrue("how do I reset password?".isLikelyAction)
        XCTAssertTrue("who should I contact?".isLikelyAction)
    }
    
    func testNonActionItems() {
        // Test items that should NOT be considered actions
        XCTAssertFalse("The weather is nice today".isLikelyAction)
        XCTAssertFalse("This is a general observation".isLikelyAction)
        XCTAssertFalse("Meeting went well".isLikelyAction)
        XCTAssertFalse("We discussed the project".isLikelyAction)
        XCTAssertFalse("The report shows good results".isLikelyAction)
        XCTAssertFalse("Traffic was heavy".isLikelyAction)
        XCTAssertFalse("It was an interesting presentation".isLikelyAction)
    }
    
    func testEdgeCases() {
        // Test edge cases
        XCTAssertFalse("".isLikelyAction) // Empty string
        XCTAssertFalse("   ".isLikelyAction) // Whitespace only
        XCTAssertTrue("call".isLikelyAction) // Single verb
        XCTAssertTrue("Call John about the meeting".isLikelyAction) // Capitalized
        XCTAssertTrue("SCHEDULE APPOINTMENT".isLikelyAction) // All caps
    }
    
    func testMultiWordVerbs() {
        // Test multi-word action verbs
        XCTAssertTrue("pick up dry cleaning".isLikelyAction)
        XCTAssertTrue("set up meeting room".isLikelyAction)
        XCTAssertTrue("follow up on proposal".isLikelyAction)
        XCTAssertTrue("reach out to supplier".isLikelyAction)
        XCTAssertTrue("go to pharmacy".isLikelyAction)
    }
    
    func testBusinessActions() {
        // Test business/professional actions
        XCTAssertTrue("submit quarterly report".isLikelyAction)
        XCTAssertTrue("process invoices".isLikelyAction)
        XCTAssertTrue("organize team meeting".isLikelyAction)
        XCTAssertTrue("deliver presentation".isLikelyAction)
        XCTAssertTrue("attend conference".isLikelyAction)
        XCTAssertTrue("participate in training".isLikelyAction)
    }
    
    func testPersonalTasks() {
        // Test personal/household actions
        XCTAssertTrue("clean kitchen".isLikelyAction)
        XCTAssertTrue("paint bedroom".isLikelyAction)
        XCTAssertTrue("fix leaky faucet".isLikelyAction)
        XCTAssertTrue("install new software".isLikelyAction)
        XCTAssertTrue("visit doctor".isLikelyAction)
        XCTAssertTrue("make dinner reservation".isLikelyAction)
    }
}