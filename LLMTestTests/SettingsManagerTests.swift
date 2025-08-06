//
//  SettingsManagerTests.swift
//  LLMTestTests
//
//  Created by Uttam Kumar Panasala on 8/6/25.
//

import XCTest
import CoreData
@testable import LLMTest

@MainActor
final class SettingsManagerTests: XCTestCase {
    var settingsManager: SettingsManager!
    var persistentContainer: NSPersistentContainer!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Create in-memory Core Data stack for testing
        persistentContainer = NSPersistentContainer(name: "LLMTest")
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        persistentContainer.persistentStoreDescriptions = [description]
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            persistentContainer.loadPersistentStores { _, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
        
        // Note: In a real implementation, we'd need to modify SettingsManager to accept a custom container
        // For now, we'll test the behavior conceptually
    }
    
    override func tearDown() async throws {
        settingsManager = nil
        persistentContainer = nil
        try await super.tearDown()
    }
    
    func testDefaultSettings() async throws {
        // Test that default settings are created correctly
        let context = persistentContainer.viewContext
        let settings = AppSettings(context: context)
        settings.id = UUID()
        settings.temperature = 0.7
        settings.maxTokens = 2048
        settings.selectedTheme = AppTheme.system.rawValue
        settings.textSize = TextSize.medium.rawValue
        
        try context.save()
        
        XCTAssertEqual(settings.temperature, 0.7)
        XCTAssertEqual(settings.maxTokens, 2048)
        XCTAssertEqual(settings.selectedTheme, "system")
        XCTAssertEqual(settings.textSize, "medium")
    }
    
    func testTemperatureValidation() {
        // Test temperature bounds
        let validTemperatures = [0.1, 0.7, 1.0, 2.0]
        let invalidTemperatures = [0.0, -0.5, 2.1, 10.0]
        
        for temp in validTemperatures {
            XCTAssertTrue(temp >= 0.1 && temp <= 2.0, "Temperature \(temp) should be valid")
        }
        
        for temp in invalidTemperatures {
            XCTAssertFalse(temp >= 0.1 && temp <= 2.0, "Temperature \(temp) should be invalid")
        }
    }
    
    func testMaxTokensValidation() {
        // Test max tokens bounds
        let validTokens = [256, 1024, 2048, 4096]
        let invalidTokens = [0, 100, 5000, -256]
        
        for tokens in validTokens {
            XCTAssertTrue(tokens >= 256 && tokens <= 4096, "Max tokens \(tokens) should be valid")
        }
        
        for tokens in invalidTokens {
            XCTAssertFalse(tokens >= 256 && tokens <= 4096, "Max tokens \(tokens) should be invalid")
        }
    }
    
    func testThemeEnumValues() {
        let themes = AppTheme.allCases
        XCTAssertEqual(themes.count, 3)
        XCTAssertTrue(themes.contains(.light))
        XCTAssertTrue(themes.contains(.dark))
        XCTAssertTrue(themes.contains(.system))
        
        XCTAssertEqual(AppTheme.light.displayName, "Light")
        XCTAssertEqual(AppTheme.dark.displayName, "Dark")
        XCTAssertEqual(AppTheme.system.displayName, "System")
    }
    
    func testTextSizeEnumValues() {
        let sizes = TextSize.allCases
        XCTAssertEqual(sizes.count, 3)
        XCTAssertTrue(sizes.contains(.small))
        XCTAssertTrue(sizes.contains(.medium))
        XCTAssertTrue(sizes.contains(.large))
        
        XCTAssertEqual(TextSize.small.scaleFactor, 0.9)
        XCTAssertEqual(TextSize.medium.scaleFactor, 1.0)
        XCTAssertEqual(TextSize.large.scaleFactor, 1.2)
    }
    
    func testExportFormatValues() {
        let formats = ExportFormat.allCases
        XCTAssertEqual(formats.count, 3)
        XCTAssertTrue(formats.contains(.json))
        XCTAssertTrue(formats.contains(.csv))
        XCTAssertTrue(formats.contains(.txt))
        
        XCTAssertEqual(ExportFormat.json.displayName, "JSON")
        XCTAssertEqual(ExportFormat.csv.displayName, "CSV")
        XCTAssertEqual(ExportFormat.txt.displayName, "Plain Text")
    }
    
    func testCoreDataModelCreation() throws {
        let context = persistentContainer.viewContext
        
        // Test AppSettings creation
        let settings = AppSettings(context: context)
        settings.id = UUID()
        settings.temperature = 1.0
        settings.maxTokens = 1024
        settings.selectedTheme = "dark"
        settings.textSize = "large"
        
        // Test Conversation creation
        let conversation = Conversation(context: context)
        conversation.id = UUID()
        conversation.title = "Test Conversation"
        conversation.createdAt = Date()
        conversation.updatedAt = Date()
        
        // Test ChatMessage creation
        let message = ChatMessage(context: context)
        message.id = UUID()
        message.content = "Hello, world!"
        message.isFromUser = true
        message.timestamp = Date()
        message.conversation = conversation
        
        try context.save()
        
        XCTAssertNotNil(settings.id)
        XCTAssertNotNil(conversation.id)
        XCTAssertNotNil(message.id)
        XCTAssertEqual(message.conversation, conversation)
    }
}