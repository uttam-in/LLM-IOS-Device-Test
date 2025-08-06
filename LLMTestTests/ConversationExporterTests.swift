//
//  ConversationExporterTests.swift
//  LLMTestTests
//
//  Created by Uttam Kumar Panasala on 8/6/25.
//

import XCTest
import CoreData
@testable import LLMTest

@MainActor
final class ConversationExporterTests: XCTestCase {
    var storageManager: StorageManager!
    var testContainer: NSPersistentContainer!
    var exporter: ConversationExporter!
    
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
        
        // Create exporter instance
        exporter = ConversationExporter()
    }
    
    override func tearDown() async throws {
        exporter = nil
        storageManager = nil
        testContainer = nil
        try await super.tearDown()
    }
    
    // MARK: - JSON Export Tests
    
    func testJSONExportWithEmptyConversation() async throws {
        // Given
        let conversation = storageManager.createConversation(title: "Empty Conversation")
        
        // When
        let jsonData = try exporter.exportConversationToJSON(conversation: conversation)
        
        // Then
        XCTAssertNotNil(jsonData)
        
        // Parse and validate JSON structure
        let jsonDict = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
        XCTAssertNotNil(jsonDict)
        XCTAssertEqual(jsonDict?["title"] as? String, "Empty Conversation")
        XCTAssertEqual(jsonDict?["messageCount"] as? Int, 0)
        
        let messages = jsonDict?["messages"] as? [[String: Any]]
        XCTAssertNotNil(messages)
        XCTAssertEqual(messages?.count, 0)
    }
    
    func testJSONExportWithMultipleMessages() async throws {
        // Given
        let conversation = storageManager.createConversation(title: "Test Conversation")
        let userMessage = storageManager.addMessage(
            to: conversation,
            content: "Hello, how are you?",
            isFromUser: true
        )
        let aiMessage = storageManager.addMessage(
            to: conversation,
            content: "I'm doing well, thank you for asking!",
            isFromUser: false,
            messageType: "ai_response"
        )
        
        // When
        let jsonData = try exporter.exportConversationToJSON(conversation: conversation)
        
        // Then
        XCTAssertNotNil(jsonData)
        
        // Parse and validate JSON structure
        let jsonDict = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
        XCTAssertNotNil(jsonDict)
        XCTAssertEqual(jsonDict?["title"] as? String, "Test Conversation")
        XCTAssertEqual(jsonDict?["messageCount"] as? Int, 2)
        
        let messages = jsonDict?["messages"] as? [[String: Any]]
        XCTAssertNotNil(messages)
        XCTAssertEqual(messages?.count, 2)
        
        // Validate first message (user message)
        let firstMessage = messages?[0]
        XCTAssertEqual(firstMessage?["content"] as? String, "Hello, how are you?")
        XCTAssertEqual(firstMessage?["isFromUser"] as? Bool, true)
        XCTAssertEqual(firstMessage?["messageType"] as? String, "text")
        
        // Validate second message (AI message)
        let secondMessage = messages?[1]
        XCTAssertEqual(secondMessage?["content"] as? String, "I'm doing well, thank you for asking!")
        XCTAssertEqual(secondMessage?["isFromUser"] as? Bool, false)
        XCTAssertEqual(secondMessage?["messageType"] as? String, "ai_response")
    }
    
    func testJSONExportWithSpecialCharacters() async throws {
        // Given
        let conversation = storageManager.createConversation(title: "Special Characters: àáâãäåæçèé")
        let message = storageManager.addMessage(
            to: conversation,
            content: "Unicode content: 🚀🌟🎉",
            isFromUser: true
        )
        
        // When
        let jsonData = try exporter.exportConversationToJSON(conversation: conversation)
        
        // Then
        XCTAssertNotNil(jsonData)
        
        // Parse and validate JSON structure handles special characters
        let jsonDict = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
        XCTAssertNotNil(jsonDict)
        XCTAssertTrue((jsonDict?["title"] as? String)?.contains("àáâãäåæçèé") ?? false)
        let messages = jsonDict?["messages"] as? [[String: Any]]
        let firstMessageContent = messages?[0]["content"] as? String
        XCTAssertTrue(firstMessageContent?.contains("🚀🌟🎉") ?? false)
    }
    
    // MARK: - CSV Export Tests
    
    func testCSVExportWithEmptyConversation() async throws {
        // Given
        let conversation = storageManager.createConversation(title: "Empty Conversation")
        
        // When
        let csvData = try exporter.exportConversationToCSV(conversation: conversation)
        
        // Then
        XCTAssertNotNil(csvData)
        
        // Convert to string and validate structure
        let csvString = String(data: csvData, encoding: .utf8)
        XCTAssertNotNil(csvString)
        
        // Should contain header only
        let lines = csvString?.components(separatedBy: .newlines).filter { !$0.isEmpty }
        XCTAssertEqual(lines?.count, 1)
        XCTAssertEqual(lines?[0], "Timestamp,Role,Content,MessageType")
    }
    
    func testCSVExportWithMultipleMessages() async throws {
        // Given
        let conversation = storageManager.createConversation(title: "Test Conversation")
        let userMessage = storageManager.addMessage(
            to: conversation,
            content: "Hello, how are you?",
            isFromUser: true
        )
        let aiMessage = storageManager.addMessage(
            to: conversation,
            content: "I'm doing well, thank you for asking!",
            isFromUser: false,
            messageType: "ai_response"
        )
        
        // When
        let csvData = try exporter.exportConversationToCSV(conversation: conversation)
        
        // Then
        XCTAssertNotNil(csvData)
        
        // Convert to string and validate structure
        let csvString = String(data: csvData, encoding: .utf8)
        XCTAssertNotNil(csvString)
        
        let lines = csvString?.components(separatedBy: .newlines).filter { !$0.isEmpty }
        XCTAssertEqual(lines?.count, 3) // Header + 2 messages
        XCTAssertEqual(lines?[0], "Timestamp,Role,Content,MessageType")
        
        // Validate content (exact timestamps will vary, so just check structure)
        XCTAssertTrue(lines?[1].contains("User") ?? false)
        XCTAssertTrue(lines?[1].contains("Hello, how are you?") ?? false)
        XCTAssertTrue(lines?[2].contains("AI") ?? false)
        XCTAssertTrue(lines?[2].contains("I'm doing well, thank you for asking!") ?? false)
    }
    
    func testCSVExportWithCommasInContent() async throws {
        // Given
        let conversation = storageManager.createConversation(title: "Test Conversation")
        let message = storageManager.addMessage(
            to: conversation,
            content: "This message has commas, semicolons; and quotes: \"Hello\"",
            isFromUser: true
        )
        
        // When
        let csvData = try exporter.exportConversationToCSV(conversation: conversation)
        
        // Then
        XCTAssertNotNil(csvData)
        
        // Convert to string and validate structure
        let csvString = String(data: csvData, encoding: .utf8)
        XCTAssertNotNil(csvString)
        
        // Check that content with commas is properly quoted
        XCTAssertTrue(csvString!.contains("\"This message has commas, semicolons; and quotes: \"Hello\"\""))
    }
    
    // MARK: - Text Export Tests
    
    func testTextExportWithEmptyConversation() async throws {
        // Given
        let conversation = storageManager.createConversation(title: "Empty Conversation")
        
        // When
        let textData = try exporter.exportConversationToText(conversation: conversation)
        
        // Then
        XCTAssertNotNil(textData)
        
        // Convert to string and validate structure
        let textString = String(data: textData, encoding: .utf8)
        XCTAssertNotNil(textString)
        
        // Should contain conversation title and separator
        XCTAssertTrue(textString!.contains("Empty Conversation"))
        XCTAssertTrue(textString!.contains("===================="))
    }
    
    func testTextExportWithMultipleMessages() async throws {
        // Given
        let conversation = storageManager.createConversation(title: "Test Conversation")
        let userMessage = storageManager.addMessage(
            to: conversation,
            content: "Hello, how are you?",
            isFromUser: true
        )
        let aiMessage = storageManager.addMessage(
            to: conversation,
            content: "I'm doing well, thank you for asking!",
            isFromUser: false,
            messageType: "ai_response"
        )
        
        // When
        let textData = try exporter.exportConversationToText(conversation: conversation)
        
        // Then
        XCTAssertNotNil(textData)
        
        // Convert to string and validate structure
        let textString = String(data: textData, encoding: .utf8)
        XCTAssertNotNil(textString)
        
        // Validate content
        XCTAssertTrue(textString!.contains("Test Conversation"))
        XCTAssertTrue(textString!.contains("[User]: Hello, how are you?"))
        XCTAssertTrue(textString!.contains("[AI]: I'm doing well, thank you for asking!"))
    }
    
    // MARK: - Date Formatting Tests
    
    func testFormattedDate() {
        // Given
        let date = Date()
        
        // When
        let formattedDate = exporter.formatDate(date)
        
        // Then
        XCTAssertNotNil(formattedDate)
        XCTAssertFalse(formattedDate.isEmpty)
        
        // Check that it contains expected date components
        XCTAssertTrue(formattedDate.contains(":")) // Time separator
        XCTAssertEqual(formattedDate.split(separator: ":").count, 3) // Hours, minutes, seconds
    }
    
    // MARK: - Error Handling Tests
    
    func testExportWithNilConversation() {
        // When & Then
        XCTAssertThrowsError(try exporter.exportConversationToJSON(conversation: nil)) { error in
            XCTAssertTrue(error is ConversationExporterError)
            if case ConversationExporterError.invalidConversation = error {
                // Expected error
            } else {
                XCTFail("Unexpected error type: \(error)")
            }
        }
        
        XCTAssertThrowsError(try exporter.exportConversationToCSV(conversation: nil)) { error in
            XCTAssertTrue(error is ConversationExporterError)
            if case ConversationExporterError.invalidConversation = error {
                // Expected error
            } else {
                XCTFail("Unexpected error type: \(error)")
            }
        }
        
        XCTAssertThrowsError(try exporter.exportConversationToText(conversation: nil)) { error in
            XCTAssertTrue(error is ConversationExporterError)
            if case ConversationExporterError.invalidConversation = error {
                // Expected error
            } else {
                XCTFail("Unexpected error type: \(error)")
            }
        }
    }
    
    // MARK: - Performance Tests
    
    func testExportPerformanceWithLargeConversation() async throws {
        // Given - create a large conversation
        let conversation = storageManager.createConversation(title: "Large Conversation")
        
        // Add 100 messages
        for i in 1...100 {
            _ = storageManager.addMessage(
                to: conversation,
                content: "Message \(i) with some content to make it larger",
                isFromUser: i % 2 == 0
            )
        }
        
        // When & Then
        measure {
            do {
                let _ = try exporter.exportConversationToJSON(conversation: conversation)
            } catch {
                XCTFail("Export failed: \(error)")
            }
        }
    }
    
    func testCSVExportPerformanceWithLargeConversation() async throws {
        // Given - create a large conversation
        let conversation = storageManager.createConversation(title: "Large CSV Conversation")
        
        // Add 100 messages
        for i in 1...100 {
            _ = storageManager.addMessage(
                to: conversation,
                content: "Message \(i) with some content to make it larger",
                isFromUser: i % 2 == 0
            )
        }
        
        // When & Then
        measure {
            do {
                let _ = try exporter.exportConversationToCSV(conversation: conversation)
            } catch {
                XCTFail("CSV Export failed: \(error)")
            }
        }
    }
}
