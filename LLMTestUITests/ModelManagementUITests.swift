//
//  ModelManagementUITests.swift
//  LLMTestUITests
//
//  Created by Uttam Kumar Panasala on 8/6/25.
//

import XCTest

final class ModelManagementUITests: XCTestCase {
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        
        // Reset UserDefaults for consistent testing
        app.launchArguments.append("--reset-user-defaults")
        app.launch()
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    // MARK: - First-Time Setup Tests
    
    func testFirstTimeSetupWelcomeScreen() throws {
        // Test that first-time setup appears on fresh install
        XCTAssertTrue(app.staticTexts["Welcome to LLM Chat!"].exists)
        XCTAssertTrue(app.staticTexts["To get started, we need to download the Gemma 2B language model."].exists)
        
        // Verify feature highlights are present
        XCTAssertTrue(app.staticTexts["100% Private - All processing happens on your device"].exists)
        XCTAssertTrue(app.staticTexts["Works offline - No internet required after download"].exists)
        XCTAssertTrue(app.staticTexts["Fast responses - Optimized for mobile devices"].exists)
        
        // Verify action buttons
        XCTAssertTrue(app.buttons["Download Model"].exists)
        XCTAssertTrue(app.buttons["Skip for now"].exists)
    }
    
    func testFirstTimeSetupDownloadFlow() throws {
        // Start download process
        let downloadButton = app.buttons["Download Model"]
        XCTAssertTrue(downloadButton.exists)
        downloadButton.tap()
        
        // Verify download screen appears
        XCTAssertTrue(app.staticTexts["Downloading Gemma 2B Model"].exists)
        XCTAssertTrue(app.staticTexts["Please wait while we download the AI model."].exists)
        
        // Verify progress elements exist
        XCTAssertTrue(app.progressIndicators.firstMatch.exists)
        XCTAssertTrue(app.buttons["Cancel Download"].exists)
        
        // Test cancel functionality
        app.buttons["Cancel Download"].tap()
        
        // Should return to welcome screen
        XCTAssertTrue(app.staticTexts["Welcome to LLM Chat!"].exists)
    }
    
    func testFirstTimeSetupSkipFlow() throws {
        // Test skip functionality
        let skipButton = app.buttons["Skip for now"]
        XCTAssertTrue(skipButton.exists)
        skipButton.tap()
        
        // Verify confirmation dialog
        XCTAssertTrue(app.alerts["Skip Model Download"].exists)
        XCTAssertTrue(app.staticTexts["You can download the model later from Settings"].exists)
        
        // Test cancel skip
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.staticTexts["Welcome to LLM Chat!"].exists)
        
        // Test confirm skip
        skipButton.tap()
        app.buttons["Skip"].tap()
        
        // Should navigate to main app (ConversationListView)
        // Note: This test assumes ConversationListView has identifiable elements
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == true"),
            object: app.navigationBars.firstMatch
        )
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testFirstTimeSetupCompletionFlow() throws {
        // This test would require mocking the download completion
        // In a real implementation, you might use launch arguments to simulate completion
        app.launchArguments.append("--simulate-download-completion")
        app.terminate()
        app.launch()
        
        // Verify completion screen
        XCTAssertTrue(app.staticTexts["Setup Complete!"].exists)
        XCTAssertTrue(app.staticTexts["The Gemma 2B model has been successfully downloaded"].exists)
        XCTAssertTrue(app.buttons["Get Started"].exists)
        
        // Test completion
        app.buttons["Get Started"].tap()
        
        // Should navigate to main app
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == true"),
            object: app.navigationBars.firstMatch
        )
        wait(for: [expectation], timeout: 5.0)
    }
    
    // MARK: - Model Management UI Tests
    
    func testModelDownloadViewNavigation() throws {
        // Skip first-time setup to access model management
        skipFirstTimeSetup()
        
        // Navigate to model management (assuming it's accessible from settings or main menu)
        // This would depend on your app's navigation structure
        navigateToModelManagement()
        
        // Verify model management screen elements
        XCTAssertTrue(app.navigationBars["Model Manager"].exists)
        XCTAssertTrue(app.staticTexts["Storage"].exists)
        XCTAssertTrue(app.staticTexts["Available Models"].exists)
    }
    
    func testStorageInfoDisplay() throws {
        skipFirstTimeSetup()
        navigateToModelManagement()
        
        // Verify storage info section
        let storageSection = app.staticTexts["Storage"]
        XCTAssertTrue(storageSection.exists)
        
        // Tap to view storage details
        storageSection.tap()
        
        // Verify storage detail view
        XCTAssertTrue(app.navigationBars["Storage Details"].exists)
        XCTAssertTrue(app.staticTexts["Storage Overview"].exists)
        XCTAssertTrue(app.staticTexts["Used by Models"].exists)
        XCTAssertTrue(app.staticTexts["Available Space"].exists)
        XCTAssertTrue(app.staticTexts["Total Space"].exists)
        
        // Close storage details
        app.buttons["Done"].tap()
    }
    
    func testModelDownloadWorkflow() throws {
        skipFirstTimeSetup()
        navigateToModelManagement()
        
        // Find an available model to download
        let availableModelsSection = app.staticTexts["Available Models"]
        XCTAssertTrue(availableModelsSection.exists)
        
        // Look for download button (this would depend on your model list implementation)
        let downloadButton = app.buttons["Download"].firstMatch
        if downloadButton.exists {
            downloadButton.tap()
            
            // Verify download confirmation dialog
            XCTAssertTrue(app.alerts["Download Model"].exists)
            
            // Confirm download
            app.buttons["Download"].tap()
            
            // Verify download appears in active downloads
            XCTAssertTrue(app.staticTexts["Active Downloads"].exists)
        }
    }
    
    func testModelDeletionWorkflow() throws {
        // This test assumes a model is already downloaded
        skipFirstTimeSetup()
        simulateModelDownloaded()
        navigateToModelManagement()
        
        // Find downloaded models section
        let downloadedModelsSection = app.staticTexts["Downloaded Models"]
        XCTAssertTrue(downloadedModelsSection.exists)
        
        // Find model actions button
        let actionsButton = app.buttons.matching(identifier: "ellipsis.circle").firstMatch
        if actionsButton.exists {
            actionsButton.tap()
            
            // Verify model actions dialog
            XCTAssertTrue(app.alerts["Model Actions"].exists)
            XCTAssertTrue(app.buttons["Delete"].exists)
            XCTAssertTrue(app.buttons["Reinstall"].exists)
            
            // Test delete action
            app.buttons["Delete"].tap()
            
            // Verify delete confirmation
            XCTAssertTrue(app.alerts["Delete Model"].exists)
            
            // Cancel deletion
            app.buttons["Cancel"].tap()
        }
    }
    
    func testModelReinstallationWorkflow() throws {
        skipFirstTimeSetup()
        simulateModelDownloaded()
        navigateToModelManagement()
        
        // Find downloaded models section
        let downloadedModelsSection = app.staticTexts["Downloaded Models"]
        XCTAssertTrue(downloadedModelsSection.exists)
        
        // Find model actions button
        let actionsButton = app.buttons.matching(identifier: "ellipsis.circle").firstMatch
        if actionsButton.exists {
            actionsButton.tap()
            
            // Test reinstall action
            app.buttons["Reinstall"].tap()
            
            // Verify reinstall confirmation
            XCTAssertTrue(app.alerts["Reinstall Model"].exists)
            XCTAssertTrue(app.staticTexts.containing("This will delete and re-download").firstMatch.exists)
            
            // Cancel reinstallation
            app.buttons["Cancel"].tap()
        }
    }
    
    func testErrorHandlingUI() throws {
        skipFirstTimeSetup()
        navigateToModelManagement()
        
        // This test would require simulating an error condition
        // You might use launch arguments to trigger specific error states
        app.launchArguments.append("--simulate-download-error")
        app.terminate()
        app.launch()
        
        navigateToModelManagement()
        
        // Attempt to download a model to trigger error
        let downloadButton = app.buttons["Download"].firstMatch
        if downloadButton.exists {
            downloadButton.tap()
            app.buttons["Download"].tap() // Confirm download
            
            // Wait for error alert
            let errorAlert = app.alerts["Error"]
            let expectation = XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "exists == true"),
                object: errorAlert
            )
            wait(for: [expectation], timeout: 10.0)
            
            // Verify error handling options
            XCTAssertTrue(app.buttons["Retry"].exists)
            XCTAssertTrue(app.buttons["OK"].exists)
            
            // Test retry functionality
            app.buttons["Retry"].tap()
        }
    }
    
    func testRefreshFunctionality() throws {
        skipFirstTimeSetup()
        navigateToModelManagement()
        
        // Test pull-to-refresh
        let modelList = app.tables.firstMatch
        if modelList.exists {
            // Perform pull-to-refresh gesture
            let start = modelList.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2))
            let end = modelList.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8))
            start.press(forDuration: 0.1, thenDragTo: end)
            
            // Verify refresh indicator appears
            XCTAssertTrue(app.activityIndicators.firstMatch.exists)
        }
    }
    
    func testClearCacheFunctionality() throws {
        skipFirstTimeSetup()
        navigateToModelManagement()
        
        // Find clear cache button in toolbar
        let clearCacheButton = app.buttons["Clear Cache"]
        if clearCacheButton.exists {
            clearCacheButton.tap()
            
            // Verify cache clearing (this might show a confirmation or just execute)
            // The exact behavior would depend on your implementation
        }
    }
    
    // MARK: - Performance Tests
    
    func testModelListPerformance() throws {
        skipFirstTimeSetup()
        
        measure {
            navigateToModelManagement()
            
            // Measure time to load and display model list
            let modelList = app.tables.firstMatch
            XCTAssertTrue(modelList.waitForExistence(timeout: 5.0))
        }
    }
    
    func testStorageCalculationPerformance() throws {
        skipFirstTimeSetup()
        navigateToModelManagement()
        
        measure {
            // Tap storage info to trigger calculation
            app.staticTexts["Storage"].tap()
            
            // Wait for storage details to load
            XCTAssertTrue(app.navigationBars["Storage Details"].waitForExistence(timeout: 3.0))
            
            // Close storage details
            app.buttons["Done"].tap()
        }
    }
    
    // MARK: - Accessibility Tests
    
    func testAccessibilityLabels() throws {
        skipFirstTimeSetup()
        navigateToModelManagement()
        
        // Verify important elements have accessibility labels
        XCTAssertNotNil(app.buttons["Download"].firstMatch.label)
        XCTAssertNotNil(app.staticTexts["Storage"].label)
        
        // Test VoiceOver navigation
        // This would require more detailed accessibility testing
    }
    
    // MARK: - Helper Methods
    
    private func skipFirstTimeSetup() {
        if app.staticTexts["Welcome to LLM Chat!"].exists {
            app.buttons["Skip for now"].tap()
            app.buttons["Skip"].tap()
        }
    }
    
    private func navigateToModelManagement() {
        // This method would depend on your app's navigation structure
        // For example, if model management is in settings:
        if app.tabBars.buttons["Settings"].exists {
            app.tabBars.buttons["Settings"].tap()
            app.buttons["Model Management"].tap()
        } else if app.navigationBars.buttons["Settings"].exists {
            app.navigationBars.buttons["Settings"].tap()
            app.buttons["Model Management"].tap()
        }
        // Add other navigation paths as needed
    }
    
    private func simulateModelDownloaded() {
        // This would use launch arguments to simulate having a downloaded model
        app.launchArguments.append("--simulate-model-downloaded")
        app.terminate()
        app.launch()
    }
}

// MARK: - Model Management Integration Tests

final class ModelManagementIntegrationTests: XCTestCase {
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }
    
    func testFirstTimeSetupToMainAppFlow() throws {
        // Test complete flow from first-time setup to main app
        XCTAssertTrue(app.staticTexts["Welcome to LLM Chat!"].exists)
        
        // Skip setup
        app.buttons["Skip for now"].tap()
        app.buttons["Skip"].tap()
        
        // Verify transition to main app
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == true"),
            object: app.navigationBars.firstMatch
        )
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testModelDownloadToUsageFlow() throws {
        // This would test the complete flow from downloading a model to using it
        // Implementation would depend on how models are used in your chat interface
    }
    
    func testErrorRecoveryFlow() throws {
        // Test recovery from various error states
        // This would require simulating different error conditions
    }
}
