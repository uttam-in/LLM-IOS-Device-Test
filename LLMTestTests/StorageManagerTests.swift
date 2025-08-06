//
//  StorageManagerTests.swift
//  LLMTestTests
//
//  Created by Uttam Kumar Panasala on 8/6/25.
//

import XCTest
import CoreData
@testable import LLMTest

@MainActor
final class StorageManagerTests: XCTestCase {
    var storageManager: StorageManager!
    var testContainer: NSPersistentContainer!
    
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
    }
    
    override func tearDown() async throws {
        storageManager = nil
        testContainer = nil
        try await super.tearDown()
    }
    
    // MARK: - Conversation Tests
    
    func testCreateConversation() async throws {
        // Given
        let title = "Test Conversation"
        
        // When
        let conversation = storageManager.createConversation(title: title)
        
        // Then
        XCTAssertNotNil(conversation.id)
        XCTAssertEqual(conversation.title, title)
        XCTAssertNotNil(conversation.createdAt)
        XCTAssertNotNil(conversation.updatedAt)
        XCTAssertEqual(conversation.messageCount, 0)
        XCTAssertFalse(conversation.isArchived)
    }
    
    func testCreateConversationWithDefaultTitle() async throws {
        // When
        let conversation = storageManager.createConversation()
        
        // Then
        XCTAssertEqual(conversation.title, "New Conversation")
    }
    
    func testUpdateConversationTitle() async throws {
        // Given
        let conversation = storageManager.createConversation(title: "Original Title")
        let newTitle = "Updated Title"
        
        // When
        storageManager.updateConversation(conversation, title: newTitle)
        
        // Then
        XCTAssertEqual(conversation.title, newTitle)
    }
    
    func testToggleArchiveConversation() async throws {
        // Given
        let conversation = storageManager.createConversation()
        XCTAssertFalse(conversation.isArchived)
        
        // When
        storageManager.toggleArchiveConversation(conversation)
        
        // Then
        XCTAssertTrue(conversation.isArchived)
        
        // When - toggle again
        storageManager.toggleArchiveConversation(conversation)
        
        // Then
        XCTAssertFalse(conversation.isArchived)
    }
    
    func testDeleteConversation() async throws {
        // Given
        let conversation = storageManager.createConversation()
        let conversationId = conversation.id!
        
        // When
        storageManager.deleteConversation(conversation)
        
        // Then
        let retrievedConversation = storageManager.getConversation(by: conversationId)
        XCTAssertNil(retrievedConversation)
    }
    
    func testGetConversationById() async throws {
        // Given
        let conversation = storageManager.createConversation(title: "Test Conversation")
        let conversationId = conversation.id!
        
        // When
        let retrievedConversation = storageManager.getConversation(by: conversationId)
        
        // Then
        XCTAssertNotNil(retrievedConversation)
        XCTAssertEqual(retrievedConversation?.title, "Test Conversation")
        XCTAssertEqual(retrievedConversation?.id, conversationId)
    }
    
    func testLoadConversations() async throws {
        // Given
        let conversation1 = storageManager.createConversation(title: "Conversation 1")
        let conversation2 = storageManager.createConversation(title: "Conversation 2")
        
        // When
        storageManager.loadConversations()
        
        // Then
        XCTAssertEqual(storageManager.conversations.count, 2)
        XCTAssertTrue(storageManager.conversations.contains(conversation1))
        XCTAssertTrue(storageManager.conversations.contains(conversation2))
    }
    
    // MARK: - Message Tests
    
    func testAddMessageToConversation() async throws {
        // Given
        let conversation = storageManager.createConversation()
        let messageContent = "Hello, this is a test message"
        
        // When
        let message = storageManager.addMessage(
            to: conversation,
            content: messageContent,
            isFromUser: true
        )
        
        // Then
        XCTAssertNotNil(message.id)
        XCTAssertEqual(message.content, messageContent)
        XCTAssertTrue(message.isFromUser)
        XCTAssertNotNil(message.timestamp)
        XCTAssertEqual(message.messageType, "text")
        XCTAssertEqual(message.conversation, conversation)
        XCTAssertEqual(conversation.messageCount, 1)
    }
    
    func testAddMessageWithMetadata() async throws {
        // Given
        let conversation = storageManager.createConversation()
        let messageContent = "Test message"
        let metadata = "{\"tokens\": 10, \"model\": \"gemma-2b\"}"
        
        // When
        let message = storageManager.addMessage(
            to: conversation,
            content: messageContent,
            isFromUser: false,
            messageType: "ai_response",
            metadata: metadata
        )
        
        // Then
        XCTAssertEqual(message.messageType, "ai_response")
        XCTAssertEqual(message.metadata, metadata)
        XCTAssertFalse(message.isFromUser)
    }
    
    func testAutoGenerateConversationTitle() async throws {
        // Given
        let conversation = storageManager.createConversation() // Default title "New Conversation"
        let userMessage = "What is the weather like today?"
        
        // When
        _ = storageManager.addMessage(
            to: conversation,
            content: userMessage,
            isFromUser: true
        )
        
        // Then
        XCTAssertEqual(conversation.title, userMessage)
    }
    
    func testAutoGenerateConversationTitleTruncation() async throws {
        // Given
        let conversation = storageManager.createConversation()
        let longMessage = String(repeating: "This is a very long message. ", count: 10) // > 50 chars
        
        // When
        _ = storageManager.addMessage(
            to: conversation,
            content: longMessage,
            isFromUser: true
        )
        
        // Then
        XCTAssertTrue(conversation.title!.hasSuffix("..."))
        XCTAssertLessThanOrEqual(conversation.title!.count, 53) // 50 + "..."
    }
    
    func testGetMessagesForConversation() async throws {
        // Given
        let conversation = storageManager.createConversation()
        let message1 = storageManager.addMessage(to: conversation, content: "First message", isFromUser: true)
        let message2 = storageManager.addMessage(to: conversation, content: "Second message", isFromUser: false)
        
        // When
        let messages = storageManager.getMessages(for: conversation)
        
        // Then
        XCTAssertEqual(messages.count, 2)
        XCTAssertEqual(messages[0], message1) // Should be sorted by timestamp
        XCTAssertEqual(messages[1], message2)
    }
    
    func testUpdateMessage() async throws {
        // Given
        let conversation = storageManager.createConversation()
        let message = storageManager.addMessage(to: conversation, content: "Original content", isFromUser: true)
        let newContent = "Updated content"
        
        // When
        storageManager.updateMessage(message, content: newContent)
        
        // Then
        XCTAssertEqual(message.content, newContent)
    }
    
    func testDeleteMessage() async throws {
        // Given
        let conversation = storageManager.createConversation()
        let message = storageManager.addMessage(to: conversation, content: "Test message", isFromUser: true)
        XCTAssertEqual(conversation.messageCount, 1)
        
        // When
        storageManager.deleteMessage(message)
        
        // Then
        XCTAssertEqual(conversation.messageCount, 0)
        let messages = storageManager.getMessages(for: conversation)
        XCTAssertEqual(messages.count, 0)
    }
    
    func testDeleteAllMessagesInConversation() async throws {
        // Given
        let conversation = storageManager.createConversation()
        _ = storageManager.addMessage(to: conversation, content: "Message 1", isFromUser: true)
        _ = storageManager.addMessage(to: conversation, content: "Message 2", isFromUser: false)
        _ = storageManager.addMessage(to: conversation, content: "Message 3", isFromUser: true)
        XCTAssertEqual(conversation.messageCount, 3)
        
        // When
        storageManager.deleteAllMessages(in: conversation)
        
        // Then
        XCTAssertEqual(conversation.messageCount, 0)
        let messages = storageManager.getMessages(for: conversation)
        XCTAssertEqual(messages.count, 0)
    }
    
    // MARK: - Search and Filtering Tests
    
    func testSearchMessages() async throws {
        // Given
        let conversation1 = storageManager.createConversation()
        let conversation2 = storageManager.createConversation()
        
        _ = storageManager.addMessage(to: conversation1, content: "Hello world", isFromUser: true)
        _ = storageManager.addMessage(to: conversation1, content: "How are you?", isFromUser: false)
        _ = storageManager.addMessage(to: conversation2, content: "Hello there", isFromUser: true)
        _ = storageManager.addMessage(to: conversation2, content: "Goodbye", isFromUser: false)
        
        // When
        let searchResults = storageManager.searchMessages(query: "hello")
        
        // Then
        XCTAssertEqual(searchResults.count, 2)
        XCTAssertTrue(searchResults.allSatisfy { $0.content?.lowercased().contains("hello") ?? false })
    }
    
    func testGetRecentConversations() async throws {
        // Given
        let conversation1 = storageManager.createConversation(title: "Old Conversation")
        let conversation2 = storageManager.createConversation(title: "Recent Conversation")
        let conversation3 = storageManager.createConversation(title: "Archived Conversation")
        
        // Archive one conversation
        storageManager.toggleArchiveConversation(conversation3)
        
        // When
        let recentConversations = storageManager.getRecentConversations(limit: 5)
        
        // Then
        XCTAssertEqual(recentConversations.count, 2) // Should exclude archived
        XCTAssertTrue(recentConversations.contains(conversation1))
        XCTAssertTrue(recentConversations.contains(conversation2))
        XCTAssertFalse(recentConversations.contains(conversation3))
    }
    
    // MARK: - Statistics Tests
    
    func testGetTotalConversationsCount() async throws {
        // Given
        _ = storageManager.createConversation()
        _ = storageManager.createConversation()
        _ = storageManager.createConversation()
        
        // When
        let count = storageManager.getTotalConversationsCount()
        
        // Then
        XCTAssertEqual(count, 3)
    }
    
    func testGetTotalMessagesCount() async throws {
        // Given
        let conversation1 = storageManager.createConversation()
        let conversation2 = storageManager.createConversation()
        
        _ = storageManager.addMessage(to: conversation1, content: "Message 1", isFromUser: true)
        _ = storageManager.addMessage(to: conversation1, content: "Message 2", isFromUser: false)
        _ = storageManager.addMessage(to: conversation2, content: "Message 3", isFromUser: true)
        
        // When
        let count = storageManager.getTotalMessagesCount()
        
        // Then
        XCTAssertEqual(count, 3)
    }
    
    // MARK: - Data Management Tests
    
    func testClearAllData() async throws {
        // Given
        let conversation = storageManager.createConversation()
        _ = storageManager.addMessage(to: conversation, content: "Test message", isFromUser: true)
        
        XCTAssertEqual(storageManager.getTotalConversationsCount(), 1)
        XCTAssertEqual(storageManager.getTotalMessagesCount(), 1)
        
        // When
        storageManager.clearAllData()
        
        // Then
        XCTAssertEqual(storageManager.getTotalConversationsCount(), 0)
        XCTAssertEqual(storageManager.getTotalMessagesCount(), 0)
        XCTAssertEqual(storageManager.conversations.count, 0)
    }
    
    func testExportConversationData() async throws {
        // Given
        let conversation = storageManager.createConversation(title: "Test Export")
        let message1 = storageManager.addMessage(to: conversation, content: "User message", isFromUser: true)
        let message2 = storageManager.addMessage(to: conversation, content: "AI response", isFromUser: false, messageType: "ai_response")
        
        // When
        let exportData = storageManager.exportConversationData(conversation: conversation)
        
        // Then
        XCTAssertEqual(exportData["title"] as? String, "Test Export")
        XCTAssertEqual(exportData["messageCount"] as? Int32, 2)
        
        let messages = exportData["messages"] as? [[String: Any]]
        XCTAssertEqual(messages?.count, 2)
        
        let firstMessage = messages?[0]
        XCTAssertEqual(firstMessage?["content"] as? String, "User message")
        XCTAssertEqual(firstMessage?["isFromUser"] as? Bool, true)
        
        let secondMessage = messages?[1]
        XCTAssertEqual(secondMessage?["content"] as? String, "AI response")
        XCTAssertEqual(secondMessage?["isFromUser"] as? Bool, false)
        XCTAssertEqual(secondMessage?["messageType"] as? String, "ai_response")
    }
    
    // MARK: - Error Handling Tests
    
    func testErrorHandling() async throws {
        // Test that error handling methods work
        let testError = NSError(domain: "TestDomain", code: 123, userInfo: [NSLocalizedDescriptionKey: "Test error"])
        
        // When
        storageManager.handleError(testError, context: "Test Context")
        
        // Then
        XCTAssertNotNil(storageManager.errorMessage)
        XCTAssertTrue(storageManager.errorMessage!.contains("Test Context"))
        XCTAssertTrue(storageManager.errorMessage!.contains("Test error"))
        
        // When - clear error
        storageManager.clearError()
        
        // Then
        XCTAssertNil(storageManager.errorMessage)
    }
    
    // MARK: - Performance Tests
    
    func testPerformanceCreateManyConversations() async throws {
        measure {
            for i in 0..<100 {
                _ = storageManager.createConversation(title: "Conversation \(i)")
            }
        }
    }
    
    func testPerformanceCreateManyMessages() async throws {
        let conversation = storageManager.createConversation()
        
        measure {
            for i in 0..<100 {
                _ = storageManager.addMessage(
                    to: conversation,
                    content: "Message \(i)",
                    isFromUser: i % 2 == 0
                )
            }
        }
    }
}