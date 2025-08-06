//
//  LlamaWrapperTests.swift
//  LLMTestTests
//
//  Created by Uttam Kumar Panasala on 8/6/25.
//

import XCTest
import Combine
@testable import LLMTest

@MainActor
final class LlamaWrapperTests: XCTestCase {
    var llamaWrapper: LlamaWrapper!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() async throws {
        try await super.setUp()
        llamaWrapper = LlamaWrapper()
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() async throws {
        await llamaWrapper.unloadModel()
        cancellables = nil
        llamaWrapper = nil
        try await super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testWrapperInitialization() {
        XCTAssertNotNil(llamaWrapper)
        XCTAssertFalse(llamaWrapper.isModelLoaded)
        XCTAssertNil(llamaWrapper.currentModelPath)
        XCTAssertFalse(llamaWrapper.isGenerating)
        XCTAssertNil(llamaWrapper.errorMessage)
        
        let config = llamaWrapper.getConfig()
        XCTAssertEqual(config.contextSize, 2048)
        XCTAssertEqual(config.threads, 4)
        XCTAssertFalse(config.gpuEnabled)
        XCTAssertEqual(config.temperature, 0.7, accuracy: 0.01)
        XCTAssertEqual(config.topP, 0.9, accuracy: 0.01)
        XCTAssertEqual(config.maxTokens, 512)
    }
    
    // MARK: - Model Loading Tests
    
    func testModelLoadingSuccess() async throws {
        let tempURL = createMockModelFile()
        defer { try? FileManager.default.removeItem(at: tempURL) }
        
        let expectation = XCTestExpectation(description: "Model loaded")
        
        llamaWrapper.$isModelLoaded
            .dropFirst() // Skip initial false value
            .sink { isLoaded in
                if isLoaded {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        try await llamaWrapper.loadModel(at: tempURL.path, contextSize: 1024)
        
        await fulfillment(of: [expectation], timeout: 5.0)
        
        XCTAssertTrue(llamaWrapper.isModelLoaded)
        XCTAssertEqual(llamaWrapper.currentModelPath, tempURL.path)
        XCTAssertEqual(llamaWrapper.contextSize, 1024)
        XCTAssertGreaterThan(llamaWrapper.vocabularySize, 0)
        XCTAssertGreaterThan(llamaWrapper.embeddingSize, 0)
    }
    
    func testModelLoadingWithInvalidPath() async {
        do {
            try await llamaWrapper.loadModel(at: "/nonexistent/path.gguf")
            XCTFail("Should have thrown an error")
        } catch let error as LlamaWrapperError {
            switch error {
            case .modelNotFound:
                // Expected error
                break
            default:
                XCTFail("Unexpected error type: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
        
        XCTAssertFalse(llamaWrapper.isModelLoaded)
        XCTAssertNil(llamaWrapper.currentModelPath)
    }
    
    func testModelLoadingWithEmptyPath() async {
        do {
            try await llamaWrapper.loadModel(at: "")
            XCTFail("Should have thrown an error")
        } catch let error as LlamaWrapperError {
            switch error {
            case .invalidParameters:
                // Expected error
                break
            default:
                XCTFail("Unexpected error type: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
        
        XCTAssertFalse(llamaWrapper.isModelLoaded)
    }
    
    func testModelUnloading() async throws {
        let tempURL = createMockModelFile()
        defer { try? FileManager.default.removeItem(at: tempURL) }
        
        // Load model first
        try await llamaWrapper.loadModel(at: tempURL.path)
        XCTAssertTrue(llamaWrapper.isModelLoaded)
        
        let expectation = XCTestExpectation(description: "Model unloaded")
        
        llamaWrapper.$isModelLoaded
            .dropFirst() // Skip initial true value
            .sink { isLoaded in
                if !isLoaded {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        await llamaWrapper.unloadModel()
        
        await fulfillment(of: [expectation], timeout: 5.0)
        
        XCTAssertFalse(llamaWrapper.isModelLoaded)
        XCTAssertNil(llamaWrapper.currentModelPath)
        XCTAssertEqual(llamaWrapper.vocabularySize, 0)
        XCTAssertEqual(llamaWrapper.contextSize, 0)
        XCTAssertEqual(llamaWrapper.embeddingSize, 0)
    }
    
    // MARK: - Text Generation Tests
    
    func testTextGenerationWithLoadedModel() async throws {
        let tempURL = createMockModelFile()
        defer { try? FileManager.default.removeItem(at: tempURL) }
        
        try await llamaWrapper.loadModel(at: tempURL.path)
        
        let response = try await llamaWrapper.generateText(
            prompt: "Hello, how are you?",
            maxTokens: 50,
            temperature: 0.7,
            topP: 0.9
        )
        
        XCTAssertFalse(response.isEmpty)
        XCTAssertFalse(llamaWrapper.isGenerating)
    }
    
    func testTextGenerationWithoutLoadedModel() async {
        do {
            _ = try await llamaWrapper.generateText(
                prompt: "Hello",
                maxTokens: 50,
                temperature: 0.7,
                topP: 0.9
            )
            XCTFail("Should have thrown an error")
        } catch let error as LlamaWrapperError {
            switch error {
            case .noModelLoaded:
                // Expected error
                break
            default:
                XCTFail("Unexpected error type: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testTextGenerationWithEmptyPrompt() async throws {
        let tempURL = createMockModelFile()
        defer { try? FileManager.default.removeItem(at: tempURL) }
        
        try await llamaWrapper.loadModel(at: tempURL.path)
        
        do {
            _ = try await llamaWrapper.generateText(
                prompt: "",
                maxTokens: 50,
                temperature: 0.7,
                topP: 0.9
            )
            XCTFail("Should have thrown an error")
        } catch let error as LlamaWrapperError {
            switch error {
            case .invalidParameters:
                // Expected error
                break
            default:
                XCTFail("Unexpected error type: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testTextGenerationConvenienceMethod() async throws {
        let tempURL = createMockModelFile()
        defer { try? FileManager.default.removeItem(at: tempURL) }
        
        try await llamaWrapper.loadModel(at: tempURL.path)
        
        let response = try await llamaWrapper.generateText(prompt: "Test prompt")
        
        XCTAssertFalse(response.isEmpty)
    }
    
    // MARK: - Streaming Text Generation Tests
    
    func testStreamingTextGeneration() async throws {
        let tempURL = createMockModelFile()
        defer { try? FileManager.default.removeItem(at: tempURL) }
        
        try await llamaWrapper.loadModel(at: tempURL.path)
        
        var receivedTokens: [String] = []
        let stream = llamaWrapper.generateTextStream(
            prompt: "Tell me a story",
            maxTokens: 20,
            temperature: 0.7,
            topP: 0.9
        )
        
        do {
            for try await token in stream {
                receivedTokens.append(token)
            }
        } catch {
            XCTFail("Streaming failed: \(error)")
        }
        
        XCTAssertFalse(receivedTokens.isEmpty)
        XCTAssertFalse(llamaWrapper.isGenerating)
        
        let fullText = receivedTokens.joined()
        XCTAssertFalse(fullText.isEmpty)
    }
    
    func testStreamingTextGenerationConvenienceMethod() async throws {
        let tempURL = createMockModelFile()
        defer { try? FileManager.default.removeItem(at: tempURL) }
        
        try await llamaWrapper.loadModel(at: tempURL.path)
        
        var tokenCount = 0
        let stream = llamaWrapper.generateTextStream(prompt: "Test streaming")
        
        do {
            for try await _ in stream {
                tokenCount += 1
            }
        } catch {
            XCTFail("Streaming failed: \(error)")
        }
        
        XCTAssertGreaterThan(tokenCount, 0)
    }
    
    func testStreamingWithoutLoadedModel() async {
        var errorThrown = false
        let stream = llamaWrapper.generateTextStream(prompt: "Test")
        
        do {
            for try await _ in stream {
                XCTFail("Should not receive tokens without a loaded model")
            }
        } catch let error as LlamaWrapperError {
            switch error {
            case .noModelLoaded:
                errorThrown = true
            default:
                XCTFail("Unexpected error type: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
        
        XCTAssertTrue(errorThrown)
    }
    
    // MARK: - Tokenization Tests
    
    func testTokenization() throws {
        let tempURL = createMockModelFile()
        defer { try? FileManager.default.removeItem(at: tempURL) }
        
        try await llamaWrapper.loadModel(at: tempURL.path)
        
        let tokens = try llamaWrapper.tokenize("Hello, world!")
        
        XCTAssertFalse(tokens.isEmpty)
        
        // All tokens should be non-negative integers
        for token in tokens {
            XCTAssertGreaterThanOrEqual(token, 0)
        }
    }
    
    func testDetokenization() throws {
        let tempURL = createMockModelFile()
        defer { try? FileManager.default.removeItem(at: tempURL) }
        
        try await llamaWrapper.loadModel(at: tempURL.path)
        
        let tokenIds = [1, 2, 3, 4, 5]
        let text = try llamaWrapper.detokenize(tokenIds)
        
        XCTAssertFalse(text.isEmpty)
    }
    
    func testTokenizationWithoutModel() {
        XCTAssertThrowsError(try llamaWrapper.tokenize("Hello")) { error in
            guard let wrapperError = error as? LlamaWrapperError else {
                XCTFail("Unexpected error type")
                return
            }
            
            switch wrapperError {
            case .noModelLoaded:
                // Expected
                break
            default:
                XCTFail("Unexpected error: \(wrapperError)")
            }
        }
    }
    
    // MARK: - Configuration Tests
    
    func testThreadConfiguration() {
        llamaWrapper.setThreads(8)
        XCTAssertEqual(llamaWrapper.getConfig().threads, 8)
        
        llamaWrapper.setThreads(1)
        XCTAssertEqual(llamaWrapper.getConfig().threads, 1)
        
        // Test clamping
        llamaWrapper.setThreads(20) // Should be clamped to 16
        XCTAssertEqual(llamaWrapper.getConfig().threads, 16)
        
        llamaWrapper.setThreads(0) // Should be clamped to 1
        XCTAssertEqual(llamaWrapper.getConfig().threads, 1)
    }
    
    func testGPUConfiguration() {
        llamaWrapper.setGPUEnabled(true)
        XCTAssertTrue(llamaWrapper.getConfig().gpuEnabled)
        
        llamaWrapper.setGPUEnabled(false)
        XCTAssertFalse(llamaWrapper.getConfig().gpuEnabled)
    }
    
    func testConfigurationUpdate() {
        let newConfig = LlamaConfig(
            contextSize: 4096,
            threads: 8,
            gpuEnabled: true,
            temperature: 0.8,
            topP: 0.95,
            maxTokens: 1024
        )
        
        llamaWrapper.updateConfig(newConfig)
        
        let currentConfig = llamaWrapper.getConfig()
        XCTAssertEqual(currentConfig.contextSize, 4096)
        XCTAssertEqual(currentConfig.threads, 8)
        XCTAssertTrue(currentConfig.gpuEnabled)
        XCTAssertEqual(currentConfig.temperature, 0.8, accuracy: 0.01)
        XCTAssertEqual(currentConfig.topP, 0.95, accuracy: 0.01)
        XCTAssertEqual(currentConfig.maxTokens, 1024)
    }
    
    func testConfigurationReset() {
        // Change config first
        llamaWrapper.setThreads(8)
        llamaWrapper.setGPUEnabled(true)
        
        // Reset to default
        llamaWrapper.resetConfig()
        
        let config = llamaWrapper.getConfig()
        XCTAssertEqual(config.threads, 4)
        XCTAssertFalse(config.gpuEnabled)
        XCTAssertEqual(config.temperature, 0.7, accuracy: 0.01)
    }
    
    func testClearCache() throws {
        let tempURL = createMockModelFile()
        defer { try? FileManager.default.removeItem(at: tempURL) }
        
        try await llamaWrapper.loadModel(at: tempURL.path)
        
        // Should not crash
        llamaWrapper.clearCache()
    }
    
    // MARK: - Model Information Tests
    
    func testModelInfo() throws {
        let tempURL = createMockModelFile()
        defer { try? FileManager.default.removeItem(at: tempURL) }
        
        // Test without loaded model
        var modelInfo = llamaWrapper.getModelInfo()
        XCTAssertFalse(modelInfo.isLoaded)
        XCTAssertNil(modelInfo.modelPath)
        XCTAssertEqual(modelInfo.vocabularySize, 0)
        XCTAssertEqual(modelInfo.contextSize, 0)
        XCTAssertEqual(modelInfo.embeddingSize, 0)
        XCTAssertEqual(modelInfo.memoryUsage, 0)
        
        // Test with loaded model
        try await llamaWrapper.loadModel(at: tempURL.path, contextSize: 1024)
        
        modelInfo = llamaWrapper.getModelInfo()
        XCTAssertTrue(modelInfo.isLoaded)
        XCTAssertEqual(modelInfo.modelPath, tempURL.path)
        XCTAssertEqual(modelInfo.contextSize, 1024)
        XCTAssertGreaterThan(modelInfo.vocabularySize, 0)
        XCTAssertGreaterThan(modelInfo.embeddingSize, 0)
        XCTAssertGreaterThan(modelInfo.memoryUsage, 0)
    }
    
    // MARK: - Error Handling Tests
    
    func testErrorMessagePublishing() async throws {
        let expectation = XCTestExpectation(description: "Error published")
        
        llamaWrapper.$errorMessage
            .dropFirst() // Skip initial nil
            .sink { errorMessage in
                if errorMessage != nil {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // Try to load a non-existent model to trigger an error
        do {
            try await llamaWrapper.loadModel(at: "/nonexistent/path.gguf")
        } catch {
            // Expected to fail
        }
        
        await fulfillment(of: [expectation], timeout: 5.0)
        
        XCTAssertNotNil(llamaWrapper.errorMessage)
    }
    
    // MARK: - Performance Tests
    
    func testModelLoadingPerformance() throws {
        let tempURL = createMockModelFile()
        defer { try? FileManager.default.removeItem(at: tempURL) }
        
        measure {
            let expectation = XCTestExpectation(description: "Model loaded")
            
            Task {
                do {
                    try await llamaWrapper.loadModel(at: tempURL.path)
                    await llamaWrapper.unloadModel()
                    expectation.fulfill()
                } catch {
                    XCTFail("Model loading failed: \(error)")
                }
            }
            
            wait(for: [expectation], timeout: 10.0)
        }
    }
    
    func testTextGenerationPerformance() throws {
        let tempURL = createMockModelFile()
        defer { try? FileManager.default.removeItem(at: tempURL) }
        
        try await llamaWrapper.loadModel(at: tempURL.path)
        
        measure {
            let expectation = XCTestExpectation(description: "Text generated")
            
            Task {
                do {
                    _ = try await llamaWrapper.generateText(
                        prompt: "Performance test",
                        maxTokens: 10,
                        temperature: 0.7,
                        topP: 0.9
                    )
                    expectation.fulfill()
                } catch {
                    XCTFail("Text generation failed: \(error)")
                }
            }
            
            wait(for: [expectation], timeout: 10.0)
        }
    }
    
    // MARK: - Helper Methods
    
    private func createMockModelFile() -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let tempURL = tempDir.appendingPathComponent("mock_model_\(UUID().uuidString).gguf")
        
        // Create a small mock file
        let mockData = "Mock GGUF model file for testing".data(using: .utf8)!
        try! mockData.write(to: tempURL)
        
        return tempURL
    }
}