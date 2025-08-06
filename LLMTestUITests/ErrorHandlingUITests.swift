//
//  ErrorHandlingUITests.swift
//  LLMTestUITests
//
//  Created by Uttam Kumar Panasala on 8/6/25.
//

import XCTest

final class ErrorHandlingUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    // MARK: - Error Alert UI Tests
    
    func testErrorAlertDisplaysCorrectly() throws {
        // Trigger a network error scenario
        app.buttons["Settings"].tap()
        app.buttons["Test Network Error"].tap()
        
        // Verify error alert appears
        let errorAlert = app.otherElements["ErrorAlert"]
        XCTAssertTrue(errorAlert.waitForExistence(timeout: 5.0))
        
        // Verify error title and message
        XCTAssertTrue(app.staticTexts["Connection Problem"].exists)
        XCTAssertTrue(app.staticTexts["No internet connection available. Please check your network settings."].exists)
        
        // Verify error icon
        XCTAssertTrue(app.images["exclamationmark.triangle.fill"].exists)
        
        // Verify technical details disclosure
        let technicalDetails = app.buttons["Technical Details"]
        XCTAssertTrue(technicalDetails.exists)
        
        technicalDetails.tap()
        XCTAssertTrue(app.staticTexts["Error Code: NET_001"].exists)
        XCTAssertTrue(app.staticTexts["Category: Network"].exists)
    }
    
    func testErrorRecoveryActions() throws {
        // Trigger a model error scenario
        app.buttons["Models"].tap()
        app.buttons["Test Model Error"].tap()
        
        let errorAlert = app.otherElements["ErrorAlert"]
        XCTAssertTrue(errorAlert.waitForExistence(timeout: 5.0))
        
        // Verify recovery actions are present
        XCTAssertTrue(app.buttons["Try Again"].exists)
        XCTAssertTrue(app.buttons["Redownload Model"].exists)
        XCTAssertTrue(app.buttons["Dismiss"].exists)
        
        // Test retry action
        app.buttons["Try Again"].tap()
        
        // Verify loading state
        XCTAssertTrue(app.activityIndicators.firstMatch.exists)
        
        // Wait for action to complete
        XCTAssertTrue(app.buttons["Try Again"].waitForExistence(timeout: 10.0))
    }
    
    func testErrorDismissal() throws {
        // Trigger an error
        app.buttons["Settings"].tap()
        app.buttons["Test Storage Error"].tap()
        
        let errorAlert = app.otherElements["ErrorAlert"]
        XCTAssertTrue(errorAlert.waitForExistence(timeout: 5.0))
        
        // Dismiss error
        app.buttons["Dismiss"].tap()
        
        // Verify error is dismissed
        XCTAssertFalse(errorAlert.exists)
    }
    
    func testCriticalErrorHandling() throws {
        // Trigger a critical error
        app.buttons["Settings"].tap()
        app.buttons["Test Critical Error"].tap()
        
        let errorAlert = app.otherElements["ErrorAlert"]
        XCTAssertTrue(errorAlert.waitForExistence(timeout: 5.0))
        
        // Verify critical error styling
        XCTAssertTrue(app.images["exclamationmark.octagon.fill"].exists)
        XCTAssertTrue(app.staticTexts["Critical Error"].exists)
        
        // Verify contact support action
        XCTAssertTrue(app.buttons["Contact Support"].exists)
        
        // Test that tapping background doesn't dismiss critical errors
        let background = app.otherElements["ErrorBackground"]
        background.tap()
        XCTAssertTrue(errorAlert.exists) // Should still be visible
    }
    
    // MARK: - Error Toast UI Tests
    
    func testErrorToastDisplay() throws {
        // Trigger a low severity error
        app.buttons["Chat"].tap()
        app.buttons["Test Low Severity Error"].tap()
        
        // Verify toast appears
        let errorToast = app.otherElements["ErrorToast"]
        XCTAssertTrue(errorToast.waitForExistence(timeout: 3.0))
        
        // Verify toast content
        XCTAssertTrue(app.staticTexts["Notice"].exists)
        XCTAssertTrue(app.images["info.circle.fill"].exists)
        
        // Verify auto-dismissal for low severity
        XCTAssertFalse(errorToast.waitForExistence(timeout: 5.0))
    }
    
    func testErrorToastManualDismissal() throws {
        // Trigger a medium severity error that shows as toast
        app.buttons["Chat"].tap()
        app.buttons["Test Medium Severity Error"].tap()
        
        let errorToast = app.otherElements["ErrorToast"]
        XCTAssertTrue(errorToast.waitForExistence(timeout: 3.0))
        
        // Manually dismiss toast
        app.buttons["DismissToast"].tap()
        XCTAssertFalse(errorToast.exists)
    }
    
    // MARK: - Recovery Progress UI Tests
    
    func testRecoveryProgressDisplay() throws {
        // Trigger a recovery operation
        app.buttons["Settings"].tap()
        app.buttons["Clear Cache"].tap()
        
        // Verify recovery progress appears
        let progressView = app.otherElements["RecoveryProgress"]
        XCTAssertTrue(progressView.waitForExistence(timeout: 3.0))
        
        // Verify progress elements
        XCTAssertTrue(app.progressIndicators.firstMatch.exists)
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'Clearing'")).firstMatch.exists)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label MATCHES '[0-9]+%'")).firstMatch.exists)
        
        // Wait for completion
        XCTAssertFalse(progressView.waitForExistence(timeout: 15.0))
    }
    
    func testModelRedownloadProgress() throws {
        // Trigger model redownload
        app.buttons["Models"].tap()
        app.buttons["Redownload Model"].tap()
        
        let progressView = app.otherElements["RecoveryProgress"]
        XCTAssertTrue(progressView.waitForExistence(timeout: 3.0))
        
        // Verify download-specific messages
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'Downloading'")).firstMatch.waitForExistence(timeout: 5.0))
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'Verifying'")).firstMatch.waitForExistence(timeout: 30.0))
        
        // Wait for completion
        XCTAssertFalse(progressView.waitForExistence(timeout: 60.0))
    }
    
    // MARK: - Error History and Statistics Tests
    
    func testErrorHistoryAccess() throws {
        // Navigate to error history
        app.buttons["Settings"].tap()
        app.buttons["Error History"].tap()
        
        // Verify error history view
        XCTAssertTrue(app.navigationBars["Error History"].exists)
        
        // Trigger some errors to populate history
        app.buttons["Test Multiple Errors"].tap()
        
        // Verify error entries appear
        XCTAssertTrue(app.cells.firstMatch.waitForExistence(timeout: 5.0))
        
        // Test error details
        app.cells.firstMatch.tap()
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'Error Code:'")).firstMatch.exists)
    }
    
    func testErrorStatistics() throws {
        // Navigate to error statistics
        app.buttons["Settings"].tap()
        app.buttons["Error Statistics"].tap()
        
        // Verify statistics view
        XCTAssertTrue(app.navigationBars["Error Statistics"].exists)
        
        // Verify statistics elements
        XCTAssertTrue(app.staticTexts["Total Errors"].exists)
        XCTAssertTrue(app.staticTexts["Errors (24h)"].exists)
        XCTAssertTrue(app.staticTexts["Most Common"].exists)
        
        // Verify charts/graphs if present
        XCTAssertTrue(app.otherElements["ErrorChart"].exists)
    }
    
    // MARK: - Integration Tests
    
    func testErrorHandlingDuringModelDownload() throws {
        // Start model download
        app.buttons["Models"].tap()
        app.buttons["Download Gemma 2B"].tap()
        
        // Simulate network interruption
        app.buttons["Simulate Network Error"].tap()
        
        // Verify error handling
        let errorAlert = app.otherElements["ErrorAlert"]
        XCTAssertTrue(errorAlert.waitForExistence(timeout: 10.0))
        
        // Verify retry option
        XCTAssertTrue(app.buttons["Try Again"].exists)
        
        // Test retry
        app.buttons["Try Again"].tap()
        
        // Verify download resumes
        let progressView = app.otherElements["DownloadProgress"]
        XCTAssertTrue(progressView.waitForExistence(timeout: 5.0))
    }
    
    func testErrorHandlingDuringChat() throws {
        // Navigate to chat
        app.buttons["Chat"].tap()
        
        // Send a message
        let messageField = app.textFields["Type a message..."]
        messageField.tap()
        messageField.typeText("Hello, how are you?")
        app.buttons["Send"].tap()
        
        // Simulate inference error
        app.buttons["Simulate Inference Error"].tap()
        
        // Verify error handling
        let errorAlert = app.otherElements["ErrorAlert"]
        XCTAssertTrue(errorAlert.waitForExistence(timeout: 10.0))
        
        // Verify fallback model option
        XCTAssertTrue(app.buttons["Use Different Model"].exists)
        
        // Test fallback
        app.buttons["Use Different Model"].tap()
        
        // Verify model switch
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'Switched to'")).firstMatch.waitForExistence(timeout: 10.0))
    }
    
    // MARK: - Accessibility Tests
    
    func testErrorAlertAccessibility() throws {
        // Trigger an error
        app.buttons["Settings"].tap()
        app.buttons["Test Accessibility Error"].tap()
        
        let errorAlert = app.otherElements["ErrorAlert"]
        XCTAssertTrue(errorAlert.waitForExistence(timeout: 5.0))
        
        // Verify accessibility labels
        XCTAssertNotNil(errorAlert.label)
        XCTAssertTrue(errorAlert.isAccessibilityElement)
        
        // Verify button accessibility
        let retryButton = app.buttons["Try Again"]
        XCTAssertTrue(retryButton.exists)
        XCTAssertNotNil(retryButton.label)
        XCTAssertTrue(retryButton.isAccessibilityElement)
        
        // Test VoiceOver navigation
        XCTAssertTrue(app.buttons["Dismiss"].isHittable)
    }
    
    func testErrorToastAccessibility() throws {
        // Trigger a toast error
        app.buttons["Chat"].tap()
        app.buttons["Test Toast Error"].tap()
        
        let errorToast = app.otherElements["ErrorToast"]
        XCTAssertTrue(errorToast.waitForExistence(timeout: 3.0))
        
        // Verify accessibility
        XCTAssertTrue(errorToast.isAccessibilityElement)
        XCTAssertNotNil(errorToast.label)
        
        // Verify dismiss button accessibility
        let dismissButton = app.buttons["DismissToast"]
        XCTAssertTrue(dismissButton.exists)
        XCTAssertTrue(dismissButton.isAccessibilityElement)
    }
    
    // MARK: - Performance Tests
    
    func testErrorHandlingPerformance() throws {
        measure {
            // Trigger multiple errors rapidly
            for i in 0..<10 {
                app.buttons["Settings"].tap()
                app.buttons["Test Performance Error"].tap()
                
                let errorAlert = app.otherElements["ErrorAlert"]
                if errorAlert.waitForExistence(timeout: 2.0) {
                    app.buttons["Dismiss"].tap()
                }
                
                app.navigationBars.buttons.firstMatch.tap() // Go back
            }
        }
    }
    
    func testRecoveryPerformance() throws {
        measure {
            // Test recovery operation performance
            app.buttons["Settings"].tap()
            app.buttons["Clear Cache"].tap()
            
            let progressView = app.otherElements["RecoveryProgress"]
            XCTAssertTrue(progressView.waitForExistence(timeout: 3.0))
            
            // Wait for completion
            XCTAssertFalse(progressView.waitForExistence(timeout: 10.0))
        }
    }
    
    // MARK: - Edge Cases
    
    func testMultipleSimultaneousErrors() throws {
        // Trigger multiple errors at once
        app.buttons["Settings"].tap()
        app.buttons["Test Multiple Errors"].tap()
        
        // Should only show one error at a time
        let errorAlerts = app.otherElements.matching(identifier: "ErrorAlert")
        XCTAssertEqual(errorAlerts.count, 1)
        
        // Dismiss and verify next error appears
        app.buttons["Dismiss"].tap()
        
        // Check if another error appears
        let nextError = app.otherElements["ErrorAlert"]
        if nextError.waitForExistence(timeout: 3.0) {
            XCTAssertTrue(nextError.exists)
        }
    }
    
    func testErrorDuringRecovery() throws {
        // Start a recovery operation
        app.buttons["Settings"].tap()
        app.buttons["Clear Cache"].tap()
        
        let progressView = app.otherElements["RecoveryProgress"]
        XCTAssertTrue(progressView.waitForExistence(timeout: 3.0))
        
        // Trigger another error during recovery
        app.buttons["Test Error During Recovery"].tap()
        
        // Verify error is queued or handled appropriately
        let errorAlert = app.otherElements["ErrorAlert"]
        XCTAssertTrue(errorAlert.waitForExistence(timeout: 5.0))
    }
    
    func testErrorAfterAppBackground() throws {
        // Trigger an error
        app.buttons["Settings"].tap()
        app.buttons["Test Background Error"].tap()
        
        let errorAlert = app.otherElements["ErrorAlert"]
        XCTAssertTrue(errorAlert.waitForExistence(timeout: 5.0))
        
        // Background the app
        XCUIDevice.shared.press(.home)
        
        // Reopen the app
        app.activate()
        
        // Verify error state is maintained
        XCTAssertTrue(errorAlert.exists)
    }
}
