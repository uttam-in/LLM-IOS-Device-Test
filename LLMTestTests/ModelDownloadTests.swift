//
//  ModelDownloadTests.swift
//  LLMTestTests
//
//  Created by Uttam Kumar Panasala on 8/6/25.
//

import XCTest
import Combine
@testable import LLMTest

@MainActor
final class ModelDownloadTests: XCTestCase {
    var mockModelInfo: ModelInfo!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() async throws {
        try await super.setUp()
        
        cancellables = Set<AnyCancellable>()
        
        // Create a mock model for testing
        mockModelInfo = ModelInfo(
            id: "test-model-123",
            name: "Test Model",
            description: "A test model for unit testing",
            downloadURL: URL(string: "https://httpbin.org/bytes/1024")!, // Returns 1KB of data
            fileSize: 1024,
            checksum: "test-checksum-123",
            checksumType: .sha256,
            version: "1.0.0",
            requiredRAM: 512 * 1024 * 1024, // 512MB
            supportedPlatforms: ["iOS", "macOS"]
        )
    }
    
    override func tearDown() async throws {
        cancellables = nil
        mockModelInfo = nil
        try await super.tearDown()
    }
    
    // MARK: - ModelInfo Tests
    
    func testModelInfoInitialization() {
        XCTAssertEqual(mockModelInfo.id, "test-model-123")
        XCTAssertEqual(mockModelInfo.name, "Test Model")
        XCTAssertEqual(mockModelInfo.fileSize, 1024)
        XCTAssertEqual(mockModelInfo.checksumType, .sha256)
        XCTAssertTrue(mockModelInfo.supportedPlatforms.contains("iOS"))
    }
    
    // MARK: - ChecksumType Tests
    
    func testChecksumTypeValues() {
        XCTAssertEqual(ChecksumType.sha256.rawValue, "sha256")
        XCTAssertEqual(ChecksumType.md5.rawValue, "md5")
        
        let allCases = ChecksumType.allCases
        XCTAssertEqual(allCases.count, 2)
        XCTAssertTrue(allCases.contains(.sha256))
        XCTAssertTrue(allCases.contains(.md5))
    }
    
    // MARK: - DownloadState Tests
    
    func testDownloadStateEquality() {
        XCTAssertEqual(DownloadState.notStarted, DownloadState.notStarted)
        XCTAssertEqual(DownloadState.downloading(progress: 0.5), DownloadState.downloading(progress: 0.5))
        XCTAssertEqual(DownloadState.completed, DownloadState.completed)
        XCTAssertEqual(DownloadState.cancelled, DownloadState.cancelled)
        
        XCTAssertNotEqual(DownloadState.downloading(progress: 0.5), DownloadState.downloading(progress: 0.6))
        XCTAssertNotEqual(DownloadState.notStarted, DownloadState.completed)
    }
    
    func testDownloadStateIsActive() {
        XCTAssertFalse(DownloadState.notStarted.isActive)
        XCTAssertTrue(DownloadState.downloading(progress: 0.5).isActive)
        XCTAssertFalse(DownloadState.paused(progress: 0.5).isActive)
        XCTAssertFalse(DownloadState.completed.isActive)
        XCTAssertFalse(DownloadState.failed(error: "test").isActive)
        XCTAssertTrue(DownloadState.verifying.isActive)
        XCTAssertFalse(DownloadState.verified.isActive)
        XCTAssertFalse(DownloadState.cancelled.isActive)
    }
    
    func testDownloadStateProgress() {
        XCTAssertEqual(DownloadState.notStarted.progress, 0.0)
        XCTAssertEqual(DownloadState.downloading(progress: 0.3).progress, 0.3)
        XCTAssertEqual(DownloadState.paused(progress: 0.7).progress, 0.7)
        XCTAssertEqual(DownloadState.completed.progress, 1.0)
        XCTAssertEqual(DownloadState.verified.progress, 1.0)
        XCTAssertEqual(DownloadState.failed(error: "test").progress, 0.0)
        XCTAssertEqual(DownloadState.cancelled.progress, 0.0)
    }
    
    // MARK: - ModelDownloadItem Tests
    
    func testModelDownloadItemInitialization() {
        let downloadItem = ModelDownloadItem(modelInfo: mockModelInfo)
        
        XCTAssertNotNil(downloadItem.id)
        XCTAssertEqual(downloadItem.modelInfo.id, mockModelInfo.id)
        XCTAssertEqual(downloadItem.state, .notStarted)
        XCTAssertEqual(downloadItem.downloadedBytes, 0)
        XCTAssertEqual(downloadItem.totalBytes, mockModelInfo.fileSize)
        XCTAssertEqual(downloadItem.downloadSpeed, 0.0)
        XCTAssertEqual(downloadItem.estimatedTimeRemaining, 0.0)
    }
    
    func testModelDownloadItemProgressTracking() {
        let downloadItem = ModelDownloadItem(modelInfo: mockModelInfo)
        
        // Set to downloading state
        downloadItem.state = .downloading(progress: 0.0)
        
        // Simulate progress updates
        downloadItem.updateProgress(downloadedBytes: 256, totalBytes: 1024)
        
        XCTAssertEqual(downloadItem.downloadedBytes, 256)
        XCTAssertEqual(downloadItem.totalBytes, 1024)
        
        if case .downloading(let progress) = downloadItem.state {
            XCTAssertEqual(progress, 0.25, accuracy: 0.01)
        } else {
            XCTFail("Expected downloading state")
        }
        
        // Simulate another update to test speed calculation
        Thread.sleep(forTimeInterval: 0.1) // Small delay
        downloadItem.updateProgress(downloadedBytes: 512, totalBytes: 1024)
        
        XCTAssertEqual(downloadItem.downloadedBytes, 512)
        XCTAssertGreaterThan(downloadItem.downloadSpeed, 0)
        XCTAssertGreaterThan(downloadItem.estimatedTimeRemaining, 0)
    }
    
    func testModelDownloadItemStateTransitions() {
        let downloadItem = ModelDownloadItem(modelInfo: mockModelInfo)
        
        // Test state transitions
        downloadItem.state = .downloading(progress: 0.5)
        downloadItem.pause()
        
        if case .paused(let progress) = downloadItem.state {
            XCTAssertEqual(progress, 0.5, accuracy: 0.01)
        } else {
            XCTFail("Expected paused state")
        }
        
        downloadItem.resume()
        
        if case .downloading(let progress) = downloadItem.state {
            XCTAssertEqual(progress, 0.5, accuracy: 0.01)
        } else {
            XCTFail("Expected downloading state")
        }
        
        downloadItem.cancel()
        XCTAssertEqual(downloadItem.state, .cancelled)
    }
    
    // MARK: - Error Handling Tests
    
    func testModelManagerErrorTypes() {
        let testError = NSError(domain: "TestDomain", code: 1, userInfo: nil)
        
        let errors: [ModelManagerError] = [
            .networkError(testError),
            .invalidURL,
            .insufficientStorage(required: 1000, available: 500),
            .checksumMismatch(expected: "abc123", actual: "def456"),
            .fileNotFound,
            .invalidModel,
            .downloadCancelled,
            .downloadFailed("Network timeout"),
            .verificationFailed("Invalid signature"),
            .unsupportedPlatform,
            .modelAlreadyExists,
            .corruptedDownload
        ]
        
        // Test that all errors have descriptions
        for error in errors {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertFalse(error.errorDescription!.isEmpty)
        }
        
        // Test specific error content
        XCTAssertTrue(errors[2].errorDescription!.contains("1000"))
        XCTAssertTrue(errors[2].errorDescription!.contains("500"))
        XCTAssertTrue(errors[3].errorDescription!.contains("abc123"))
        XCTAssertTrue(errors[3].errorDescription!.contains("def456"))
        XCTAssertTrue(errors[7].errorDescription!.contains("Network timeout"))
    }
    
    // MARK: - Download Validation Tests
    
    func testDownloadValidationScenarios() async {
        let modelManager = ModelManager.shared
        
        // Test 1: Unsupported platform
        let unsupportedModel = ModelInfo(
            id: "unsupported-test",
            name: "Unsupported Test",
            description: "Test",
            downloadURL: URL(string: "https://example.com/test.gguf")!,
            fileSize: 1024,
            checksum: "test",
            checksumType: .sha256,
            version: "1.0.0",
            requiredRAM: 1024,
            supportedPlatforms: ["Android"] // Not iOS
        )
        
        do {
            try await modelManager.downloadModel(unsupportedModel)
            XCTFail("Should have failed for unsupported platform")
        } catch ModelManagerError.unsupportedPlatform {
            // Expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
        
        // Test 2: Insufficient storage
        let largeModel = ModelInfo(
            id: "large-test",
            name: "Large Test",
            description: "Test",
            downloadURL: URL(string: "https://example.com/large.gguf")!,
            fileSize: Int64.max, // Too large
            checksum: "test",
            checksumType: .sha256,
            version: "1.0.0",
            requiredRAM: 1024,
            supportedPlatforms: ["iOS"]
        )
        
        do {
            try await modelManager.downloadModel(largeModel)
            XCTFail("Should have failed for insufficient storage")
        } catch ModelManagerError.insufficientStorage {
            // Expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    // MARK: - File Management Tests
    
    func testFileURLGeneration() {
        let modelManager = ModelManager.shared
        
        let modelFileURL = modelManager.getModelFileURL(for: mockModelInfo)
        let tempFileURL = modelManager.getTempFileURL(for: mockModelInfo)
        
        XCTAssertTrue(modelFileURL.path.contains(mockModelInfo.id))
        XCTAssertTrue(modelFileURL.pathExtension == "gguf")
        
        XCTAssertTrue(tempFileURL.path.contains(mockModelInfo.id))
        XCTAssertTrue(tempFileURL.pathExtension == "tmp")
        
        XCTAssertNotEqual(modelFileURL, tempFileURL)
    }
    
    // MARK: - Storage Space Tests
    
    func testStorageSpaceCalculations() {
        let modelManager = ModelManager.shared
        
        do {
            let availableSpace = try modelManager.getAvailableStorageSpace()
            XCTAssertGreaterThan(availableSpace, 0)
            
            // Test storage validation with reasonable model
            try modelManager.validateStorageSpace(for: mockModelInfo)
            
        } catch {
            XCTFail("Storage space operations failed: \(error)")
        }
    }
    
    // MARK: - Concurrent Operations Tests
    
    func testConcurrentDownloadManagement() async {
        let modelManager = ModelManager.shared
        
        // Create multiple mock models
        let models = (1...3).map { index in
            ModelInfo(
                id: "concurrent-test-\(index)",
                name: "Concurrent Test \(index)",
                description: "Test model \(index)",
                downloadURL: URL(string: "https://httpbin.org/status/404")!, // Will fail
                fileSize: 1024,
                checksum: "test\(index)",
                checksumType: .sha256,
                version: "1.0.0",
                requiredRAM: 1024,
                supportedPlatforms: ["iOS"]
            )
        }
        
        // Try to download all models concurrently
        await withTaskGroup(of: Void.self) { group in
            for model in models {
                group.addTask {
                    do {
                        try await modelManager.downloadModel(model)
                    } catch {
                        // Expected to fail due to 404
                    }
                }
            }
        }
        
        // All downloads should have been attempted
        // (They will fail due to 404, but that's expected for this test)
    }
    
    // MARK: - Performance Tests
    
    func testDownloadItemPerformance() {
        let downloadItem = ModelDownloadItem(modelInfo: mockModelInfo)
        downloadItem.state = .downloading(progress: 0.0)
        
        measure {
            for i in 1...1000 {
                downloadItem.updateProgress(downloadedBytes: Int64(i), totalBytes: 1000)
            }
        }
    }
    
    func testModelInfoComparison() {
        let model1 = mockModelInfo!
        let model2 = ModelInfo(
            id: mockModelInfo.id,
            name: mockModelInfo.name,
            description: mockModelInfo.description,
            downloadURL: mockModelInfo.downloadURL,
            fileSize: mockModelInfo.fileSize,
            checksum: mockModelInfo.checksum,
            checksumType: mockModelInfo.checksumType,
            version: mockModelInfo.version,
            requiredRAM: mockModelInfo.requiredRAM,
            supportedPlatforms: mockModelInfo.supportedPlatforms
        )
        
        measure {
            for _ in 1...1000 {
                let _ = model1.id == model2.id
                let _ = model1.fileSize == model2.fileSize
                let _ = model1.checksum == model2.checksum
            }
        }
    }
    
    // MARK: - Edge Cases Tests
    
    func testDownloadItemWithZeroProgress() {
        let downloadItem = ModelDownloadItem(modelInfo: mockModelInfo)
        downloadItem.state = .downloading(progress: 0.0)
        
        downloadItem.updateProgress(downloadedBytes: 0, totalBytes: 0)
        
        XCTAssertEqual(downloadItem.downloadedBytes, 0)
        XCTAssertEqual(downloadItem.totalBytes, 0)
        
        if case .downloading(let progress) = downloadItem.state {
            XCTAssertEqual(progress, 0.0)
        } else {
            XCTFail("Expected downloading state")
        }
    }
    
    func testDownloadItemWithNegativeBytes() {
        let downloadItem = ModelDownloadItem(modelInfo: mockModelInfo)
        downloadItem.state = .downloading(progress: 0.0)
        
        // This shouldn't happen in real scenarios, but test defensive programming
        downloadItem.updateProgress(downloadedBytes: -100, totalBytes: 1000)
        
        XCTAssertEqual(downloadItem.downloadedBytes, -100)
        XCTAssertEqual(downloadItem.totalBytes, 1000)
    }
    
    func testModelInfoWithEmptyValues() {
        let emptyModel = ModelInfo(
            id: "",
            name: "",
            description: "",
            downloadURL: URL(string: "https://example.com")!,
            fileSize: 0,
            checksum: "",
            checksumType: .sha256,
            version: "",
            requiredRAM: 0,
            supportedPlatforms: []
        )
        
        XCTAssertEqual(emptyModel.id, "")
        XCTAssertEqual(emptyModel.fileSize, 0)
        XCTAssertTrue(emptyModel.supportedPlatforms.isEmpty)
    }
    
    // MARK: - State Machine Tests
    
    func testDownloadStateTransitions() {
        var state = DownloadState.notStarted
        
        // Valid transitions
        state = .downloading(progress: 0.0)
        XCTAssertTrue(state.isActive)
        
        state = .paused(progress: 0.5)
        XCTAssertFalse(state.isActive)
        XCTAssertEqual(state.progress, 0.5)
        
        state = .downloading(progress: 0.5)
        XCTAssertTrue(state.isActive)
        
        state = .verifying
        XCTAssertTrue(state.isActive)
        
        state = .completed
        XCTAssertFalse(state.isActive)
        XCTAssertEqual(state.progress, 1.0)
        
        // Test error states
        state = .failed(error: "Network error")
        XCTAssertFalse(state.isActive)
        XCTAssertEqual(state.progress, 0.0)
        
        state = .cancelled
        XCTAssertFalse(state.isActive)
        XCTAssertEqual(state.progress, 0.0)
    }
}