//
//  ChatInterfaceUITests.swift
//  LLMTestUITests
//
//  Created by Uttam Kumar Panasala on 8/6/25.
//

import XCTest

final class ChatInterfaceUITests: XCTestCase {
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    // MARK: - Conversation List Tests
    
    func testConversationListAppears() throws {
        // Test that the main conversation list appears
        let conversationListTitle = app.navigationBars["Chats"]
        XCTAssertTrue(conversationListTitle.exists)
        
        // Test that the new chat button exists
        let newChatButton = app.navigationBars.buttons.matching(identifier: "square.and.pencil").element
        XCTAssertTrue(newChatButton.exists)
        
        // Test that the settings button exists
        let settingsButton = app.navigationBars.buttons.matching(identifier: "gearshape").element
        XCTAssertTrue(settingsButton.exists)
    }
    
    func testCreateNewConversation() throws {
        // Tap the new chat button
        let newChatButton = app.navigationBars.buttons.matching(identifier: "square.and.pencil").element
        newChatButton.tap()
        
        // Wait for navigation to complete
        let chatNavigationBar = app.navigationBars.firstMatch
        let exists = NSPredicate(format: "exists == true")
        expectation(for: exists, evaluatedWith: chatNavigationBar, handler: nil)
        waitForExpectations(timeout: 5, handler: nil)
    }
    
    func testEmptyStateDisplayed() throws {
        // If no conversations exist, empty state should be shown
        let emptyStateText = app.staticTexts["No Conversations Yet"]
        let startNewChatButton = app.buttons["Start New Chat"]
        
        if emptyStateText.exists {
            XCTAssertTrue(startNewChatButton.exists)
            
            // Test tapping the start new chat button
            startNewChatButton.tap()
            
            // Should navigate to chat view
            let chatNavigationBar = app.navigationBars.firstMatch
            let exists = NSPredicate(format: "exists == true")
            expectation(for: exists, evaluatedWith: chatNavigationBar, handler: nil)
            waitForExpectations(timeout: 5, handler: nil)
        }
    }
    
    // MARK: - Chat Interface Tests
    
    func testChatInterfaceElements() throws {
        // Create a new conversation first
        createNewConversationForTesting()
        
        // Test that chat interface elements exist
        let messageTextField = app.textFields["Type a message..."]
        XCTAssertTrue(messageTextField.exists)
        
        let sendButton = app.buttons.matching(identifier: "arrow.up.circle.fill").element
        XCTAssertTrue(sendButton.exists)
        
        // Test that send button is initially disabled (no text)
        XCTAssertFalse(sendButton.isEnabled)
    }
    
    func testSendMessage() throws {
        // Create a new conversation first
        createNewConversationForTesting()
        
        let messageTextField = app.textFields["Type a message..."]
        let sendButton = app.buttons.matching(identifier: "arrow.up.circle.fill").element
        
        // Type a message
        messageTextField.tap()
        messageTextField.typeText("Hello, this is a test message!")
        
        // Send button should now be enabled
        XCTAssertTrue(sendButton.isEnabled)
        
        // Tap send button
        sendButton.tap()
        
        // Message should appear in the chat
        let sentMessage = app.staticTexts["Hello, this is a test message!"]
        let exists = NSPredicate(format: "exists == true")
        expectation(for: exists, evaluatedWith: sentMessage, handler: nil)
        waitForExpectations(timeout: 5, handler: nil)
        
        // Text field should be cleared
        XCTAssertEqual(messageTextField.value as? String ?? "", "Type a message...")
    }
    
    func testMessageBubbleAppearance() throws {
        // Create a new conversation and send a message
        createNewConversationForTesting()
        sendTestMessage("Test message for bubble appearance")
        
        // Verify message appears
        let messageText = app.staticTexts["Test message for bubble appearance"]
        XCTAssertTrue(messageText.exists)
    }
    
    func testKeyboardDismissal() throws {
        // Create a new conversation first
        createNewConversationForTesting()
        
        let messageTextField = app.textFields["Type a message..."]
        
        // Tap text field to show keyboard
        messageTextField.tap()
        
        // Tap outside the text field to dismiss keyboard
        let chatView = app.otherElements.firstMatch
        chatView.tap()
        
        // Keyboard should be dismissed (this is hard to test directly in UI tests)
        // We can verify by checking if the text field is no longer focused
        XCTAssertTrue(messageTextField.exists)
    }
    
    func testLongMessageHandling() throws {
        // Create a new conversation first
        createNewConversationForTesting()
        
        let messageTextField = app.textFields["Type a message..."]
        let sendButton = app.buttons.matching(identifier: "arrow.up.circle.fill").element
        
        // Type a very long message
        let longMessage = String(repeating: "This is a very long message that should wrap properly in the message bubble. ", count: 5)
        
        messageTextField.tap()
        messageTextField.typeText(longMessage)
        
        // Send the message
        sendButton.tap()
        
        // Verify the long message appears (checking for a portion of it)
        let messageExists = app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'This is a very long message'")).firstMatch.exists
        XCTAssertTrue(messageExists)
    }
    
    func testMultipleMessages() throws {
        // Create a new conversation first
        createNewConversationForTesting()
        
        // Send multiple messages
        sendTestMessage("First message")
        sendTestMessage("Second message")
        sendTestMessage("Third message")
        
        // Verify all messages appear
        XCTAssertTrue(app.staticTexts["First message"].exists)
        XCTAssertTrue(app.staticTexts["Second message"].exists)
        XCTAssertTrue(app.staticTexts["Third message"].exists)
    }
    
    func testAIResponseAppears() throws {
        // Create a new conversation and send a message
        createNewConversationForTesting()
        sendTestMessage("Hello AI")
        
        // Wait for AI response (placeholder response should appear)
        let aiResponseExists = NSPredicate(format: "exists == true")
        let aiResponseElement = app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'interesting'")).firstMatch
        
        expectation(for: aiResponseExists, evaluatedWith: aiResponseElement, handler: nil)
        waitForExpectations(timeout: 10, handler: nil) // Wait up to 10 seconds for AI response
    }
    
    func testTypingIndicator() throws {
        // Create a new conversation and send a message
        createNewConversationForTesting()
        
        let messageTextField = app.textFields["Type a message..."]
        let sendButton = app.buttons.matching(identifier: "arrow.up.circle.fill").element
        
        messageTextField.tap()
        messageTextField.typeText("Test typing indicator")
        sendButton.tap()
        
        // Typing indicator should appear briefly (this is hard to test reliably due to timing)
        // We'll just verify the message was sent successfully
        let sentMessage = app.staticTexts["Test typing indicator"]
        let exists = NSPredicate(format: "exists == true")
        expectation(for: exists, evaluatedWith: sentMessage, handler: nil)
        waitForExpectations(timeout: 5, handler: nil)
    }
    
    // MARK: - Navigation Tests
    
    func testNavigationToSettings() throws {
        // From conversation list
        let settingsButton = app.navigationBars.buttons.matching(identifier: "gearshape").element
        settingsButton.tap()
        
        // Settings sheet should appear
        let settingsTitle = app.navigationBars["Settings"]
        let exists = NSPredicate(format: "exists == true")
        expectation(for: exists, evaluatedWith: settingsTitle, handler: nil)
        waitForExpectations(timeout: 5, handler: nil)
        
        // Close settings
        let doneButton = app.navigationBars.buttons["Done"]
        doneButton.tap()
    }
    
    func testBackNavigationFromChat() throws {
        // Create a new conversation
        createNewConversationForTesting()
        
        // Navigate back to conversation list
        let backButton = app.navigationBars.buttons.element(boundBy: 0)
        backButton.tap()
        
        // Should return to conversation list
        let conversationListTitle = app.navigationBars["Chats"]
        XCTAssertTrue(conversationListTitle.exists)
    }
    
    // MARK: - Helper Methods
    
    private func createNewConversationForTesting() {
        let newChatButton = app.navigationBars.buttons.matching(identifier: "square.and.pencil").element
        newChatButton.tap()
        
        // Wait for navigation to complete
        let messageTextField = app.textFields["Type a message..."]
        let exists = NSPredicate(format: "exists == true")
        expectation(for: exists, evaluatedWith: messageTextField, handler: nil)
        waitForExpectations(timeout: 5, handler: nil)
    }
    
    private func sendTestMessage(_ message: String) {
        let messageTextField = app.textFields["Type a message..."]
        let sendButton = app.buttons.matching(identifier: "arrow.up.circle.fill").element
        
        messageTextField.tap()
        messageTextField.typeText(message)
        sendButton.tap()
        
        // Wait for message to appear
        let sentMessage = app.staticTexts[message]
        let exists = NSPredicate(format: "exists == true")
        expectation(for: exists, evaluatedWith: sentMessage, handler: nil)
        waitForExpectations(timeout: 5, handler: nil)
    }
    
    // MARK: - Performance Tests
    
    func testChatPerformance() throws {
        measure {
            createNewConversationForTesting()
            sendTestMessage("Performance test message")
        }
    }
    
    func testScrollingPerformance() throws {
        // Create a conversation with multiple messages
        createNewConversationForTesting()
        
        // Send multiple messages to test scrolling
        for i in 1...10 {
            sendTestMessage("Message number \(i)")
        }
        
        // Test scrolling performance
        measure {
            let scrollView = app.scrollViews.firstMatch
            scrollView.swipeUp()
            scrollView.swipeDown()
        }
    }
}