//
//  LlamaCppBridgeTests.swift
//  LLMTestTests
//
//  Created by Uttam Kumar Panasala on 8/6/25.
//

import XCTest
@testable import LLMTest

final class LlamaCppBridgeTests: XCTestCase {
    var bridge: LlamaCppBridge!
    
    override func setUp() {
        super.setUp()
        bridge = LlamaCppBridge()
    }
    
    override func tearDown() {
        bridge?.unloadModel()
        bridge = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testBridgeInitialization() {
        XCTAssertNotNil(bridge)
        XCTAssertFalse(bridge.isModelLoaded)
        XCTAssertEqual(bridge.getVocabularySize(), 0)
        XCTAssertEqual(bridge.getContextSize(), 0)
        XCTAssertEqual(bridge.getEmbeddingSize(), 0)
    }
    
    // MARK: - Model Loading Tests
    
    func testModelLoadingWithValidParameters() {
        // Create a temporary mock model file
        let tempURL = createMockModelFile()
        defer { try? FileManager.default.removeItem(at: tempURL) }
        
        var error: NSError?
        let success = bridge.loadModel(atPath: tempURL.path, contextSize: 2048, error: &error)
        
        XCTAssertTrue(success)
        XCTAssertNil(error)
        XCTAssertTrue(bridge.isModelLoaded)
        XCTAssertEqual(bridge.getContextSize(), 2048)
        XCTAssertGreaterThan(bridge.getVocabularySize(), 0)
        XCTAssertGreaterThan(bridge.getEmbeddingSize(), 0)
    }
    
    func testModelLoadingWithInvalidPath() {
        var error: NSError?
        let success = bridge.loadModel(atPath: "/nonexistent/path/model.gguf", contextSize: 2048, error: &error)
        
        XCTAssertFalse(success)
        XCTAssertNotNil(error)
        XCTAssertEqual(error?.domain, "LlamaCppBridgeErrorDomain")
        XCTAssertEqual(error?.code, 1000) // ModelNotFound
        XCTAssertFalse(bridge.isModelLoaded)
    }
    
    func testModelLoadingWithEmptyPath() {
        var error: NSError?
        let success = bridge.loadModel(atPath: "", contextSize: 2048, error: &error)
        
        XCTAssertFalse(success)
        XCTAssertNotNil(error)
        XCTAssertEqual(error?.domain, "LlamaCppBridgeErrorDomain")
        XCTAssertEqual(error?.code, 1003) // InvalidParameters
        XCTAssertFalse(bridge.isModelLoaded)
    }
    
    func testModelLoadingWithInvalidContextSize() {
        let tempURL = createMockModelFile()
        defer { try? FileManager.default.removeItem(at: tempURL) }
        
        var error: NSError?
        let success = bridge.loadModel(atPath: tempURL.path, contextSize: 0, error: &error)
        
        XCTAssertFalse(success)
        XCTAssertNotNil(error)
        XCTAssertEqual(error?.domain, "LlamaCppBridgeErrorDomain")
        XCTAssertEqual(error?.code, 1003) // InvalidParameters
        XCTAssertFalse(bridge.isModelLoaded)
    }
    
    func testModelUnloading() {
        // Load a model first
        let tempURL = createMockModelFile()
        defer { try? FileManager.default.removeItem(at: tempURL) }
        
        _ = bridge.loadModel(atPath: tempURL.path, contextSize: 2048, error: nil)
        XCTAssertTrue(bridge.isModelLoaded)
        
        // Unload the model
        bridge.unloadModel()
        XCTAssertFalse(bridge.isModelLoaded)
        XCTAssertEqual(bridge.getVocabularySize(), 0)
        XCTAssertEqual(bridge.getContextSize(), 0)
        XCTAssertEqual(bridge.getEmbeddingSize(), 0)
    }
    
    // MARK: - Text Generation Tests
    
    func testTextGenerationWithLoadedModel() {
        // Load a model first
        let tempURL = createMockModelFile()
        defer { try? FileManager.default.removeItem(at: tempURL) }
        
        _ = bridge.loadModel(atPath: tempURL.path, contextSize: 2048, error: nil)
        
        var error: NSError?
        let result = bridge.generateText(withPrompt: "Hello, how are you?",
                                       maxTokens: 50,
                                       temperature: 0.7,
                                       topP: 0.9,
                                       error: &error)
        
        XCTAssertNotNil(result)
        XCTAssertNil(error)
        XCTAssertFalse(result!.isEmpty)
    }
    
    func testTextGenerationWithoutLoadedModel() {
        var error: NSError?
        let result = bridge.generateText(withPrompt: "Hello, how are you?",
                                       maxTokens: 50,
                                       temperature: 0.7,
                                       topP: 0.9,
                                       error: &error)
        
        XCTAssertNil(result)
        XCTAssertNotNil(error)
        XCTAssertEqual(error?.domain, "LlamaCppBridgeErrorDomain")
        XCTAssertEqual(error?.code, 1006) // NoModelLoaded
    }
    
    func testTextGenerationWithEmptyPrompt() {
        // Load a model first
        let tempURL = createMockModelFile()
        defer { try? FileManager.default.removeItem(at: tempURL) }
        
        _ = bridge.loadModel(atPath: tempURL.path, contextSize: 2048, error: nil)
        
        var error: NSError?
        let result = bridge.generateText(withPrompt: "",
                                       maxTokens: 50,
                                       temperature: 0.7,
                                       topP: 0.9,
                                       error: &error)
        
        XCTAssertNil(result)
        XCTAssertNotNil(error)
        XCTAssertEqual(error?.domain, "LlamaCppBridgeErrorDomain")
        XCTAssertEqual(error?.code, 1003) // InvalidParameters
    }
    
    func testTextGenerationWithInvalidMaxTokens() {
        // Load a model first
        let tempURL = createMockModelFile()
        defer { try? FileManager.default.removeItem(at: tempURL) }
        
        _ = bridge.loadModel(atPath: tempURL.path, contextSize: 2048, error: nil)
        
        var error: NSError?
        let result = bridge.generateText(withPrompt: "Hello",
                                       maxTokens: 0,
                                       temperature: 0.7,
                                       topP: 0.9,
                                       error: &error)
        
        XCTAssertNil(result)
        XCTAssertNotNil(error)
        XCTAssertEqual(error?.domain, "LlamaCppBridgeErrorDomain")
        XCTAssertEqual(error?.code, 1003) // InvalidParameters
    }
    
    // MARK: - Streaming Text Generation Tests
    
    func testStreamingTextGeneration() {
        // Load a model first
        let tempURL = createMockModelFile()
        defer { try? FileManager.default.removeItem(at: tempURL) }
        
        _ = bridge.loadModel(atPath: tempURL.path, contextSize: 2048, error: nil)
        
        let expectation = XCTestExpectation(description: "Streaming completion")
        var receivedTokens: [String] = []
        var isComplete = false
        
        var error: NSError?
        let success = bridge.generateTextStream(withPrompt: "Tell me a story",
                                              maxTokens: 20,
                                              temperature: 0.7,
                                              topP: 0.9,
                                              callback: { token, complete in
            receivedTokens.append(token)
            if complete {
                isComplete = true
                expectation.fulfill()
            }
        }, error: &error)
        
        XCTAssertTrue(success)
        XCTAssertNil(error)
        
        wait(for: [expectation], timeout: 5.0)
        
        XCTAssertTrue(isComplete)
        XCTAssertFalse(receivedTokens.isEmpty)
    }
    
    func testStreamingTextGenerationWithoutModel() {
        let expectation = XCTestExpectation(description: "Streaming failure")
        
        var error: NSError?
        let success = bridge.generateTextStream(withPrompt: "Hello",
                                              maxTokens: 20,
                                              temperature: 0.7,
                                              topP: 0.9,
                                              callback: { _, _ in
            // Should not be called
            XCTFail("Callback should not be called without a loaded model")
        }, error: &error)
        
        XCTAssertFalse(success)
        XCTAssertNotNil(error)
        XCTAssertEqual(error?.domain, "LlamaCppBridgeErrorDomain")
        XCTAssertEqual(error?.code, 1006) // NoModelLoaded
        
        expectation.fulfill()
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - Tokenization Tests
    
    func testTokenization() {
        // Load a model first
        let tempURL = createMockModelFile()
        defer { try? FileManager.default.removeItem(at: tempURL) }
        
        _ = bridge.loadModel(atPath: tempURL.path, contextSize: 2048, error: nil)
        
        var error: NSError?
        let tokens = bridge.tokenizeText("Hello, world!", error: &error)
        
        XCTAssertNotNil(tokens)
        XCTAssertNil(error)
        XCTAssertFalse(tokens!.isEmpty)
        
        // Test that all tokens are numbers
        for token in tokens! {
            XCTAssertTrue(token.intValue >= 0)
        }
    }
    
    func testDetokenization() {
        // Load a model first
        let tempURL = createMockModelFile()
        defer { try? FileManager.default.removeItem(at: tempURL) }
        
        _ = bridge.loadModel(atPath: tempURL.path, contextSize: 2048, error: nil)
        
        let tokenIds = [1, 2, 3, 4, 5].map { NSNumber(value: $0) }
        
        var error: NSError?
        let text = bridge.detokenizeTokenIds(tokenIds, error: &error)
        
        XCTAssertNotNil(text)
        XCTAssertNil(error)
        XCTAssertFalse(text!.isEmpty)
    }
    
    func testTokenizationWithoutModel() {
        var error: NSError?
        let tokens = bridge.tokenizeText("Hello", error: &error)
        
        XCTAssertNil(tokens)
        XCTAssertNotNil(error)
        XCTAssertEqual(error?.domain, "LlamaCppBridgeErrorDomain")
        XCTAssertEqual(error?.code, 1006) // NoModelLoaded
    }
    
    // MARK: - Configuration Tests
    
    func testThreadConfiguration() {
        // This should not crash
        bridge.setThreads(8)
        bridge.setThreads(1)
        bridge.setThreads(16)
    }
    
    func testGPUConfiguration() {
        // This should not crash
        bridge.setGPUEnabled(true)
        bridge.setGPUEnabled(false)
    }
    
    func testMemoryManagement() {
        // Load a model first
        let tempURL = createMockModelFile()
        defer { try? FileManager.default.removeItem(at: tempURL) }
        
        _ = bridge.loadModel(atPath: tempURL.path, contextSize: 2048, error: nil)
        
        let memoryUsage = bridge.getMemoryUsage()
        XCTAssertGreaterThan(memoryUsage, 0)
        
        // Clear cache should not crash
        bridge.clearKVCache()
    }
    
    // MARK: - Performance Tests
    
    func testModelLoadingPerformance() {
        let tempURL = createMockModelFile()
        defer { try? FileManager.default.removeItem(at: tempURL) }
        
        measure {
            _ = bridge.loadModel(atPath: tempURL.path, contextSize: 1024, error: nil)
            bridge.unloadModel()
        }
    }
    
    func testTextGenerationPerformance() {
        // Load a model first
        let tempURL = createMockModelFile()
        defer { try? FileManager.default.removeItem(at: tempURL) }
        
        _ = bridge.loadModel(atPath: tempURL.path, contextSize: 2048, error: nil)
        
        measure {
            _ = bridge.generateText(withPrompt: "Performance test prompt",
                                  maxTokens: 10,
                                  temperature: 0.7,
                                  topP: 0.9,
                                  error: nil)
        }
    }
    
    // MARK: - Helper Methods
    
    private func createMockModelFile() -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let tempURL = tempDir.appendingPathComponent("mock_model_\(UUID().uuidString).gguf")
        
        // Create a small mock file
        let mockData = "Mock GGUF model file".data(using: .utf8)!
        try! mockData.write(to: tempURL)
        
        return tempURL
    }
    
    // MARK: - Error Handling Tests
    
    func testErrorDomainAndCodes() {
        XCTAssertEqual(LlamaCppBridgeErrorDomain, "LlamaCppBridgeErrorDomain")
        
        // Test that error codes are properly defined
        XCTAssertEqual(LlamaCppBridgeError.modelNotFound.rawValue, 1000)
        XCTAssertEqual(LlamaCppBridgeError.modelLoadFailed.rawValue, 1001)
        XCTAssertEqual(LlamaCppBridgeError.inferenceFailed.rawValue, 1002)
        XCTAssertEqual(LlamaCppBridgeError.invalidParameters.rawValue, 1003)
        XCTAssertEqual(LlamaCppBridgeError.outOfMemory.rawValue, 1004)
        XCTAssertEqual(LlamaCppBridgeError.tokenizationFailed.rawValue, 1005)
        XCTAssertEqual(LlamaCppBridgeError.noModelLoaded.rawValue, 1006)
    }
    
    func testConcurrentAccess() {
        let tempURL = createMockModelFile()
        defer { try? FileManager.default.removeItem(at: tempURL) }
        
        _ = bridge.loadModel(atPath: tempURL.path, contextSize: 2048, error: nil)
        
        let expectation = XCTestExpectation(description: "Concurrent access")
        expectation.expectedFulfillmentCount = 5
        
        // Test concurrent text generation
        for i in 0..<5 {
            DispatchQueue.global().async {
                _ = self.bridge.generateText(withPrompt: "Concurrent test \(i)",
                                           maxTokens: 10,
                                           temperature: 0.7,
                                           topP: 0.9,
                                           error: nil)
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
}