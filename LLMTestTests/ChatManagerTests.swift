//
//  ChatManagerTests.swift
//  LLMTestTests
//
//  Created by Uttam Kumar Panasala on 8/6/25.
//

import XCTest
import CoreData
import Combine
@testable import LLMTest

@MainActor
final class ChatManagerTests: XCTestCase {
    var chatManager: ChatManager!
    var storageManager: StorageManager!
    var testContainer: NSPersistentContainer!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Create in-memory Core Data stack for testing
        testContainer = NSPersistentContainer(name: "LLMTest")
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        testContainer.persistentStoreDescriptions = [description]
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            testContainer.loadPersistentStores { _, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
        
        // Create a test storage manager with our test container
        storageManager = StorageManager.shared
        storageManager.persistentContainer = testContainer
        
        // Create chat manager instance
        chatManager = ChatManager.shared
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() async throws {
        cancellables = nil
        chatManager = nil
        storageManager = nil
        testContainer = nil
        try await super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testChatManagerInitialization() {
        XCTAssertNotNil(chatManager)
        XCTAssertFalse(chatManager.isProcessing)
        XCTAssertNil(chatManager.errorMessage)
        XCTAssertFalse(chatManager.isModelLoaded)
        XCTAssertNil(chatManager.activeConversation)
    }
    
    // MARK: - Message Validation Tests
    
    func testValidMessageValidation() {
        // Valid messages
        XCTAssertTrue(chatManager.isValidMessage("Hello"))
        XCTAssertTrue(chatManager.isValidMessage("This is a valid message"))
        XCTAssertTrue(chatManager.isValidMessage("Message with numbers 123"))
        XCTAssertTrue(chatManager.isValidMessage("Message with special chars: !@#$%"))
        
        // Test message at maximum length (4000 characters)
        let maxLengthMessage = String(repeating: "a", count: 4000)
        XCTAssertTrue(chatManager.isValidMessage(maxLengthMessage))
    }
    
    func testInvalidMessageValidation() {
        // Invalid messages
        XCTAssertFalse(chatManager.isValidMessage(""))
        XCTAssertFalse(chatManager.isValidMessage("   "))
        XCTAssertFalse(chatManager.isValidMessage("\n\t"))
        
        // Test message over maximum length (4001 characters)
        let overMaxLengthMessage = String(repeating: "a", count: 4001)
        XCTAssertFalse(chatManager.isValidMessage(overMaxLengthMessage))
    }
    
    func testMessageValidationWithWhitespace() {
        // Messages with leading/trailing whitespace should be considered valid
        // (they will be trimmed during processing)
        XCTAssertTrue(chatManager.isValidMessage("  Hello  "))
        XCTAssertTrue(chatManager.isValidMessage("\nHello\n"))
        XCTAssertTrue(chatManager.isValidMessage("\tHello\t"))
    }
    
    // MARK: - Message Retrieval Tests
    
    func testGetMessagesForConversation() {
        // Given
        let conversation = storageManager.createConversation(title: "Test Conversation")
        let message1 = storageManager.addMessage(to: conversation, content: "First message", isFromUser: true)
        let message2 = storageManager.addMessage(to: conversation, content: "Second message", isFromUser: false)
        
        // When
        let messages = chatManager.getMessages(for: conversation)
        
        // Then
        XCTAssertEqual(messages.count, 2)
        XCTAssertEqual(messages[0].content, "First message")
        XCTAssertEqual(messages[1].content, "Second message")
        XCTAssertTrue(messages[0].isFromUser)
        XCTAssertFalse(messages[1].isFromUser)
    }
    
    func testGetMessagesForEmptyConversation() {
        // Given
        let conversation = storageManager.createConversation(title: "Empty Conversation")
        
        // When
        let messages = chatManager.getMessages(for: conversation)
        
        // Then
        XCTAssertEqual(messages.count, 0)
    }
    
    // MARK: - Send Message Tests
    
    func testSendValidMessage() async {
        // Given
        let conversation = storageManager.createConversation(title: "Test Conversation")
        let messageContent = "Hello, this is a test message"
        
        // When
        await chatManager.sendMessage(messageContent, to: conversation)
        
        // Then
        let messages = chatManager.getMessages(for: conversation)
        XCTAssertEqual(messages.count, 1)
        XCTAssertEqual(messages[0].content, messageContent)
        XCTAssertTrue(messages[0].isFromUser)
        XCTAssertEqual(messages[0].messageType, "text")
    }
    
    func testSendEmptyMessage() async {
        // Given
        let conversation = storageManager.createConversation(title: "Test Conversation")
        
        // When
        await chatManager.sendMessage("", to: conversation)
        
        // Then
        let messages = chatManager.getMessages(for: conversation)
        XCTAssertEqual(messages.count, 0) // Empty message should not be added
    }
    
    func testSendWhitespaceOnlyMessage() async {
        // Given
        let conversation = storageManager.createConversation(title: "Test Conversation")
        
        // When
        await chatManager.sendMessage("   \n\t   ", to: conversation)
        
        // Then
        let messages = chatManager.getMessages(for: conversation)
        XCTAssertEqual(messages.count, 0) // Whitespace-only message should not be added
    }
    
    func testSendMessageTrimsWhitespace() async {
        // Given
        let conversation = storageManager.createConversation(title: "Test Conversation")
        let messageContent = "  Hello, world!  "
        
        // When
        await chatManager.sendMessage(messageContent, to: conversation)
        
        // Then
        let messages = chatManager.getMessages(for: conversation)
        XCTAssertEqual(messages.count, 1)
        XCTAssertEqual(messages[0].content, "Hello, world!") // Should be trimmed
    }
    
    // MARK: - Processing State Tests
    
    func testProcessingStateChanges() async {
        // Given
        let conversation = storageManager.createConversation(title: "Test Conversation")
        let expectation = XCTestExpectation(description: "Processing state changed")
        
        var processingStates: [Bool] = []
        
        chatManager.$isProcessing
            .sink { isProcessing in
                processingStates.append(isProcessing)
                if processingStates.count >= 2 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // When
        await chatManager.sendMessage("Test message", to: conversation)
        
        // Then
        await fulfillment(of: [expectation], timeout: 5.0)
        
        // Should start as false, then potentially change during processing
        XCTAssertFalse(processingStates[0]) // Initial state
        XCTAssertFalse(chatManager.isProcessing) // Should end as false
    }
    
    // MARK: - Error Handling Tests
    
    func testErrorMessagePublishing() {
        let expectation = XCTestExpectation(description: "Error message published")
        
        chatManager.$errorMessage
            .dropFirst() // Skip initial nil
            .sink { errorMessage in
                if errorMessage != nil {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // Simulate an error by trying to generate AI response without a loaded model
        // This should trigger an error state
        let conversation = storageManager.createConversation(title: "Test Conversation")
        
        Task {
            await chatManager.sendMessage("Test message", to: conversation)
        }
        
        wait(for: [expectation], timeout: 5.0)
        
        // Error message should be set when model is not loaded
        XCTAssertNotNil(chatManager.errorMessage)
    }
    
    // MARK: - Active Conversation Tests
    
    func testActiveConversationManagement() {
        // Given
        let conversation1 = storageManager.createConversation(title: "Conversation 1")
        let conversation2 = storageManager.createConversation(title: "Conversation 2")
        
        // Initially no active conversation
        XCTAssertNil(chatManager.activeConversation)
        
        // When
        chatManager.activeConversation = conversation1
        
        // Then
        XCTAssertEqual(chatManager.activeConversation?.id, conversation1.id)
        
        // When
        chatManager.activeConversation = conversation2
        
        // Then
        XCTAssertEqual(chatManager.activeConversation?.id, conversation2.id)
        
        // When
        chatManager.activeConversation = nil
        
        // Then
        XCTAssertNil(chatManager.activeConversation)
    }
    
    // MARK: - Model Loading State Tests
    
    func testModelLoadedState() {
        // Initially model should not be loaded
        XCTAssertFalse(chatManager.isModelLoaded)
        
        // Note: In a real test, we would need to mock the LlamaWrapper
        // to test model loading functionality properly
    }
    
    // MARK: - Message Type Tests
    
    func testUserMessageType() async {
        // Given
        let conversation = storageManager.createConversation(title: "Test Conversation")
        
        // When
        await chatManager.sendMessage("User message", to: conversation)
        
        // Then
        let messages = chatManager.getMessages(for: conversation)
        XCTAssertEqual(messages.count, 1)
        XCTAssertEqual(messages[0].messageType, "text")
        XCTAssertTrue(messages[0].isFromUser)
    }
    
    // MARK: - Conversation Update Tests
    
    func testConversationUpdatedAfterMessage() async {
        // Given
        let conversation = storageManager.createConversation(title: "Test Conversation")
        let originalUpdateTime = conversation.updatedAt
        
        // Wait a moment to ensure timestamp difference
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // When
        await chatManager.sendMessage("Test message", to: conversation)
        
        // Then
        XCTAssertNotNil(conversation.updatedAt)
        if let originalTime = originalUpdateTime, let newTime = conversation.updatedAt {
            XCTAssertGreaterThan(newTime, originalTime)
        }
        XCTAssertEqual(conversation.messageCount, 1)
    }
    
    // MARK: - Concurrent Operations Tests
    
    func testConcurrentMessageSending() async {
        // Given
        let conversation = storageManager.createConversation(title: "Concurrent Test")
        
        // When - send multiple messages concurrently
        await withTaskGroup(of: Void.self) { group in
            for i in 1...5 {
                group.addTask {
                    await self.chatManager.sendMessage("Message \(i)", to: conversation)
                }
            }
        }
        
        // Then
        let messages = chatManager.getMessages(for: conversation)
        XCTAssertEqual(messages.count, 5)
        XCTAssertEqual(conversation.messageCount, 5)
    }
    
    // MARK: - Performance Tests
    
    func testMessageValidationPerformance() {
        let testMessage = "This is a test message for performance testing"
        
        measure {
            for _ in 1...1000 {
                _ = chatManager.isValidMessage(testMessage)
            }
        }
    }
    
    func testGetMessagesPerformance() async {
        // Given - create a conversation with many messages
        let conversation = storageManager.createConversation(title: "Performance Test")
        
        for i in 1...100 {
            _ = storageManager.addMessage(
                to: conversation,
                content: "Message \(i)",
                isFromUser: i % 2 == 0
            )
        }
        
        // When & Then
        measure {
            let _ = chatManager.getMessages(for: conversation)
        }
    }
    
    // MARK: - Edge Cases Tests
    
    func testSendMessageWithSpecialCharacters() async {
        // Given
        let conversation = storageManager.createConversation(title: "Special Chars Test")
        let specialMessage = "Message with émojis 🚀🌟 and spëcial chars: àáâãäåæçèé"
        
        // When
        await chatManager.sendMessage(specialMessage, to: conversation)
        
        // Then
        let messages = chatManager.getMessages(for: conversation)
        XCTAssertEqual(messages.count, 1)
        XCTAssertEqual(messages[0].content, specialMessage)
    }
    
    func testSendMessageWithNewlines() async {
        // Given
        let conversation = storageManager.createConversation(title: "Newlines Test")
        let multilineMessage = "Line 1\nLine 2\nLine 3"
        
        // When
        await chatManager.sendMessage(multilineMessage, to: conversation)
        
        // Then
        let messages = chatManager.getMessages(for: conversation)
        XCTAssertEqual(messages.count, 1)
        XCTAssertEqual(messages[0].content, multilineMessage)
    }
    
    func testSendVeryLongValidMessage() async {
        // Given
        let conversation = storageManager.createConversation(title: "Long Message Test")
        let longMessage = String(repeating: "A", count: 3999) // Just under the 4000 limit
        
        // When
        await chatManager.sendMessage(longMessage, to: conversation)
        
        // Then
        let messages = chatManager.getMessages(for: conversation)
        XCTAssertEqual(messages.count, 1)
        XCTAssertEqual(messages[0].content, longMessage)
    }
}
