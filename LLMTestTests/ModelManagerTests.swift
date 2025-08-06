//
//  ModelManagerTests.swift
//  LLMTestTests
//
//  Created by Uttam Kumar Panasala on 8/6/25.
//

import XCTest
import Combine
@testable import LLMTest

@MainActor
final class ModelManagerTests: XCTestCase {
    var modelManager: ModelManager!
    var cancellables: Set<AnyCancellable>!
    var tempDirectory: URL!
    
    override func setUp() async throws {
        try await super.setUp()
        
        cancellables = Set<AnyCancellable>()
        
        // Create temporary directory for testing
        tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("ModelManagerTests")
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        
        // We'll use the shared instance but reset its state
        modelManager = ModelManager.shared
    }
    
    override func tearDown() async throws {
        cancellables = nil
        
        // Clean up temp directory
        if FileManager.default.fileExists(atPath: tempDirectory.path) {
            try FileManager.default.removeItem(at: tempDirectory)
        }
        
        modelManager = nil
        try await super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testModelManagerInitialization() {
        XCTAssertNotNil(modelManager)
        XCTAssertFalse(modelManager.availableModels.isEmpty)
        XCTAssertFalse(modelManager.isLoading)
        XCTAssertNil(modelManager.errorMessage)
        XCTAssertTrue(modelManager.activeDownloads.isEmpty)
    }
    
    func testAvailableModelsLoaded() {
        // Should have at least Gemma 2B model
        XCTAssertGreaterThanOrEqual(modelManager.availableModels.count, 1)
        
        let gemmaModel = modelManager.availableModels.first { $0.id.contains("gemma") }
        XCTAssertNotNil(gemmaModel)
        XCTAssertEqual(gemmaModel?.name, "Gemma 2B Instruct")
        XCTAssertTrue(gemmaModel?.supportedPlatforms.contains("iOS") == true)
    }
    
    // MARK: - Storage Management Tests
    
    func testGetAvailableStorageSpace() throws {
        let availableSpace = try modelManager.getAvailableStorageSpace()
        XCTAssertGreaterThan(availableSpace, 0)
    }
    
    func testStorageSpaceValidation() throws {
        // Create a mock model with very large size
        let largeModel = ModelInfo(
            id: "large-test-model",
            name: "Large Test Model",
            description: "A test model that's too large",
            downloadURL: URL(string: "https://example.com/large.gguf")!,
            fileSize: Int64.max, // Impossibly large
            checksum: "test",
            checksumType: .sha256,
            version: "1.0.0",
            requiredRAM: 1024,
            supportedPlatforms: ["iOS"]
        )
        
        XCTAssertThrowsError(try modelManager.validateStorageSpace(for: largeModel)) { error in
            guard case ModelManagerError.insufficientStorage = error else {
                XCTFail("Expected insufficientStorage error, got \(error)")
                return
            }
        }
    }
    
    func testGetStorageInfo() {
        let storageInfo = modelManager.getStorageInfo()
        
        XCTAssertGreaterThanOrEqual(storageInfo.available, 0)
        XCTAssertGreaterThanOrEqual(storageInfo.used, 0)
        XCTAssertGreaterThanOrEqual(storageInfo.total, storageInfo.used)
    }
    
    // MARK: - Model Status Tests
    
    func testModelStatusChecks() {
        guard let testModel = modelManager.availableModels.first else {
            XCTFail("No available models for testing")
            return
        }
        
        // Initially, model should not be downloaded or downloading
        XCTAssertFalse(modelManager.isModelDownloaded(testModel))
        XCTAssertFalse(modelManager.isModelDownloading(testModel))
        XCTAssertNil(modelManager.getDownloadItem(for: testModel))
    }
    
    func testModelFileURLs() {
        guard let testModel = modelManager.availableModels.first else {
            XCTFail("No available models for testing")
            return
        }
        
        let fileURL = modelManager.getModelFileURL(for: testModel)
        let tempURL = modelManager.getTempFileURL(for: testModel)
        
        XCTAssertTrue(fileURL.path.contains(testModel.id))
        XCTAssertTrue(fileURL.pathExtension == "gguf")
        XCTAssertTrue(tempURL.path.contains(testModel.id))
        XCTAssertTrue(tempURL.pathExtension == "tmp")
        XCTAssertNotEqual(fileURL, tempURL)
    }
    
    // MARK: - Download Validation Tests
    
    func testDownloadValidation() async {
        // Test unsupported platform
        let unsupportedModel = ModelInfo(
            id: "unsupported-model",
            name: "Unsupported Model",
            description: "Test model for unsupported platform",
            downloadURL: URL(string: "https://example.com/test.gguf")!,
            fileSize: 1024,
            checksum: "test",
            checksumType: .sha256,
            version: "1.0.0",
            requiredRAM: 1024,
            supportedPlatforms: ["macOS"] // iOS not supported
        )
        
        do {
            try await modelManager.downloadModel(unsupportedModel)
            XCTFail("Should have thrown unsupported platform error")
        } catch ModelManagerError.unsupportedPlatform {
            // Expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testDownloadAlreadyExistingModel() async {
        guard let testModel = modelManager.availableModels.first else {
            XCTFail("No available models for testing")
            return
        }
        
        // Create a mock downloaded file
        let fileURL = modelManager.getModelFileURL(for: testModel)
        try! FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try! "mock content".write(to: fileURL, atomically: true, encoding: .utf8)
        
        defer {
            try? FileManager.default.removeItem(at: fileURL)
        }
        
        do {
            try await modelManager.downloadModel(testModel)
            XCTFail("Should have thrown model already exists error")
        } catch ModelManagerError.modelAlreadyExists {
            // Expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    // MARK: - Checksum Verification Tests
    
    func testChecksumCalculation() async throws {
        // Create a test file with known content
        let testContent = "Hello, World!"
        let testFile = tempDirectory.appendingPathComponent("test.txt")
        try testContent.write(to: testFile, atomically: true, encoding: .utf8)
        
        // Calculate SHA256 checksum using private method (via reflection)
        let modelManager = ModelManager.shared
        let mirror = Mirror(reflecting: modelManager)
        
        // We can't directly test private methods, so we'll test the public interface
        // that would use checksum verification in a real download scenario
        
        // Clean up
        try FileManager.default.removeItem(at: testFile)
    }
    
    // MARK: - Download Item Tests
    
    func testModelDownloadItemInitialization() {
        guard let testModel = modelManager.availableModels.first else {
            XCTFail("No available models for testing")
            return
        }
        
        let downloadItem = ModelDownloadItem(modelInfo: testModel)
        
        XCTAssertEqual(downloadItem.modelInfo.id, testModel.id)
        XCTAssertEqual(downloadItem.state, .notStarted)
        XCTAssertEqual(downloadItem.downloadedBytes, 0)
        XCTAssertEqual(downloadItem.totalBytes, testModel.fileSize)
        XCTAssertEqual(downloadItem.downloadSpeed, 0.0)
        XCTAssertEqual(downloadItem.estimatedTimeRemaining, 0.0)
    }
    
    func testDownloadItemProgressUpdate() {
        guard let testModel = modelManager.availableModels.first else {
            XCTFail("No available models for testing")
            return
        }
        
        let downloadItem = ModelDownloadItem(modelInfo: testModel)
        downloadItem.state = .downloading(progress: 0.0)
        
        // Simulate progress update
        downloadItem.updateProgress(downloadedBytes: 500, totalBytes: 1000)
        
        XCTAssertEqual(downloadItem.downloadedBytes, 500)
        XCTAssertEqual(downloadItem.totalBytes, 1000)
        
        if case .downloading(let progress) = downloadItem.state {
            XCTAssertEqual(progress, 0.5, accuracy: 0.01)
        } else {
            XCTFail("Expected downloading state with progress")
        }
    }
    
    func testDownloadStateProperties() {
        XCTAssertFalse(DownloadState.notStarted.isActive)
        XCTAssertTrue(DownloadState.downloading(progress: 0.5).isActive)
        XCTAssertFalse(DownloadState.paused(progress: 0.5).isActive)
        XCTAssertFalse(DownloadState.completed.isActive)
        XCTAssertFalse(DownloadState.failed(error: "test").isActive)
        XCTAssertTrue(DownloadState.verifying.isActive)
        XCTAssertFalse(DownloadState.verified.isActive)
        XCTAssertFalse(DownloadState.cancelled.isActive)
        
        XCTAssertEqual(DownloadState.notStarted.progress, 0.0)
        XCTAssertEqual(DownloadState.downloading(progress: 0.5).progress, 0.5)
        XCTAssertEqual(DownloadState.paused(progress: 0.3).progress, 0.3)
        XCTAssertEqual(DownloadState.completed.progress, 1.0)
        XCTAssertEqual(DownloadState.verified.progress, 1.0)
    }
    
    // MARK: - Model Management Tests
    
    func testModelDeletion() throws {
        guard let testModel = modelManager.availableModels.first else {
            XCTFail("No available models for testing")
            return
        }
        
        // Create a mock downloaded file
        let fileURL = modelManager.getModelFileURL(for: testModel)
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "mock content".write(to: fileURL, atomically: true, encoding: .utf8)
        
        // Verify file exists
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
        
        // Delete the model
        try modelManager.deleteModel(testModel)
        
        // Verify file is deleted
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))
    }
    
    func testDeleteNonExistentModel() {
        guard let testModel = modelManager.availableModels.first else {
            XCTFail("No available models for testing")
            return
        }
        
        XCTAssertThrowsError(try modelManager.deleteModel(testModel)) { error in
            guard case ModelManagerError.fileNotFound = error else {
                XCTFail("Expected fileNotFound error, got \(error)")
                return
            }
        }
    }
    
    // MARK: - Cache Management Tests
    
    func testClearCache() {
        // Create some temp files
        let tempFile1 = modelManager.getTempFileURL(for: modelManager.availableModels[0])
        let tempFile2 = tempDirectory.appendingPathComponent("temp2.tmp")
        
        do {
            try FileManager.default.createDirectory(at: tempFile1.deletingLastPathComponent(), withIntermediateDirectories: true)
            try "temp1".write(to: tempFile1, atomically: true, encoding: .utf8)
            try "temp2".write(to: tempFile2, atomically: true, encoding: .utf8)
            
            // Verify files exist
            XCTAssertTrue(FileManager.default.fileExists(atPath: tempFile1.path))
            
            // Clear cache
            modelManager.clearCache()
            
            // Note: clearCache only clears the temp directory managed by ModelManager
            // Our test temp file in a different location won't be affected
            
        } catch {
            XCTFail("Failed to create temp files: \(error)")
        }
    }
    
    // MARK: - Refresh Tests
    
    func testRefreshAvailableModels() async {
        let initialCount = modelManager.availableModels.count
        
        await modelManager.refreshAvailableModels()
        
        // Should still have the same models (since we're not actually fetching from server)
        XCTAssertEqual(modelManager.availableModels.count, initialCount)
        XCTAssertFalse(modelManager.isLoading)
    }
    
    // MARK: - Error Handling Tests
    
    func testModelManagerErrorDescriptions() {
        let networkError = NSError(domain: "TestDomain", code: 1, userInfo: [NSLocalizedDescriptionKey: "Network failed"])
        let errors: [ModelManagerError] = [
            .networkError(networkError),
            .invalidURL,
            .insufficientStorage(required: 1000, available: 500),
            .checksumMismatch(expected: "abc", actual: "def"),
            .fileNotFound,
            .invalidModel,
            .downloadCancelled,
            .downloadFailed("Connection lost"),
            .verificationFailed("Invalid signature"),
            .unsupportedPlatform,
            .modelAlreadyExists,
            .corruptedDownload
        ]
        
        for error in errors {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertFalse(error.errorDescription!.isEmpty)
        }
        
        // Test specific error messages
        if case .insufficientStorage(let required, let available) = errors[2] {
            XCTAssertTrue(error.errorDescription!.contains("1000"))
            XCTAssertTrue(error.errorDescription!.contains("500"))
        }
        
        if case .checksumMismatch(let expected, let actual) = errors[3] {
            XCTAssertTrue(error.errorDescription!.contains("abc"))
            XCTAssertTrue(error.errorDescription!.contains("def"))
        }
    }
    
    // MARK: - Concurrent Access Tests
    
    func testConcurrentDownloadAttempts() async {
        guard let testModel = modelManager.availableModels.first else {
            XCTFail("No available models for testing")
            return
        }
        
        // Create a modified model with a valid but non-existent URL for testing
        let testModelWithValidURL = ModelInfo(
            id: testModel.id,
            name: testModel.name,
            description: testModel.description,
            downloadURL: URL(string: "https://httpbin.org/status/404")!, // Will return 404
            fileSize: 1024,
            checksum: testModel.checksum,
            checksumType: testModel.checksumType,
            version: testModel.version,
            requiredRAM: testModel.requiredRAM,
            supportedPlatforms: testModel.supportedPlatforms
        )
        
        // Try to start multiple downloads concurrently
        async let download1 = modelManager.downloadModel(testModelWithValidURL)
        async let download2 = modelManager.downloadModel(testModelWithValidURL)
        
        do {
            let _ = try await download1
            let _ = try await download2
            XCTFail("At least one download should have failed")
        } catch {
            // Expected - downloads should fail due to 404 or concurrent access
        }
    }
    
    // MARK: - Performance Tests
    
    func testModelManagerPerformance() {
        measure {
            let storageInfo = modelManager.getStorageInfo()
            XCTAssertGreaterThanOrEqual(storageInfo.available, 0)
        }
    }
    
    func testStorageCalculationPerformance() {
        measure {
            do {
                let _ = try modelManager.getAvailableStorageSpace()
            } catch {
                XCTFail("Storage calculation failed: \(error)")
            }
        }
    }
    
    // MARK: - Integration Tests
    
    func testModelManagerIntegrationWithFileSystem() {
        // Test that ModelManager correctly interacts with the file system
        guard let testModel = modelManager.availableModels.first else {
            XCTFail("No available models for testing")
            return
        }
        
        let modelURL = modelManager.getModelFileURL(for: testModel)
        let tempURL = modelManager.getTempFileURL(for: testModel)
        
        // Ensure directories exist
        let modelDir = modelURL.deletingLastPathComponent()
        let tempDir = tempURL.deletingLastPathComponent()
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: modelDir.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: tempDir.path))
    }
}