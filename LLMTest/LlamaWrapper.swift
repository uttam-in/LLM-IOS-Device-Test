//
//  LlamaWrapper.swift
//  LLMTest
//
//  Created by Uttam Kumar Panasala on 8/6/25.
//

import Foundation
import Combine

// MARK: - Protocol Definition

/// Protocol defining the interface for LLM inference engines
protocol LLMInferenceEngine: AnyObject {
    // MARK: - Model Management
    func loadModel(at path: String, contextSize: Int) async throws
    func unloadModel() async
    var isModelLoaded: Bool { get }
    
    // MARK: - Text Generation
    func generateText(prompt: String, maxTokens: Int, temperature: Float, topP: Float) async throws -> String
    func generateTextStream(prompt: String, maxTokens: Int, temperature: Float, topP: Float) -> AsyncThrowingStream<String, Error>
    
    // MARK: - Model Information
    var vocabularySize: Int { get }
    var contextSize: Int { get }
    var embeddingSize: Int { get }
    var memoryUsage: Int { get }
    
    // MARK: - Configuration
    func setThreads(_ count: Int)
    func setGPUEnabled(_ enabled: Bool)
    func clearCache()
    
    // MARK: - Tokenization
    func tokenize(_ text: String) async throws -> [Int]
    func detokenize(_ tokens: [Int]) async throws -> String
}

// MARK: - Error Types

enum LlamaWrapperError: LocalizedError {
    case modelNotFound(String)
    case modelLoadFailed(String)
    case inferenceError(String)
    case invalidParameters(String)
    case outOfMemory
    case tokenizationFailed(String)
    case noModelLoaded
    case bridgeError(Error)
    
    var errorDescription: String? {
        switch self {
        case .modelNotFound(let path):
            return "Model file not found at path: \(path)"
        case .modelLoadFailed(let reason):
            return "Failed to load model: \(reason)"
        case .inferenceError(let reason):
            return "Inference failed: \(reason)"
        case .invalidParameters(let reason):
            return "Invalid parameters: \(reason)"
        case .outOfMemory:
            return "Out of memory"
        case .tokenizationFailed(let reason):
            return "Tokenization failed: \(reason)"
        case .noModelLoaded:
            return "No model is currently loaded"
        case .bridgeError(let error):
            return "Bridge error: \(error.localizedDescription)"
        }
    }
}

// MARK: - Configuration Structure

struct LlamaConfig {
    let contextSize: Int
    let threads: Int
    let gpuEnabled: Bool
    let temperature: Float
    let topP: Float
    let maxTokens: Int
    
    static let `default` = LlamaConfig(
        contextSize: 2048,
        threads: 4,
        gpuEnabled: false,
        temperature: 0.7,
        topP: 0.9,
        maxTokens: 512
    )
}

// MARK: - Llama Model Information

struct LlamaModelInfo {
    let vocabularySize: Int
    let contextSize: Int
    let embeddingSize: Int
    let memoryUsage: Int
    let isLoaded: Bool
    let modelPath: String?
}

// MARK: - Mock Bridge (Temporary)

class MockLlamaCppBridge {
    private var modelLoaded = false
    private var threads: Int32 = 4
    private var gpuEnabled = false
    
    func loadModel(atPath path: String, contextSize: Int32, error: inout NSError?) -> Bool {
        // Mock implementation
        modelLoaded = true
        return true
    }
    
    func unloadModel() {
        modelLoaded = false
    }
    
    func isModelLoaded() -> Bool {
        return modelLoaded
    }
    
    func generateText(_ prompt: String, maxTokens: Int32, temperature: Float, topP: Float, error: inout NSError?) -> String? {
        // Mock response
        return "This is a mock response to: \(prompt)"
    }
    
    func getVocabularySize() -> Int32 { return 32000 }
    func getContextSize() -> Int32 { return 2048 }
    func getEmbeddingSize() -> Int32 { return 4096 }
    func getMemoryUsage() -> Int32 { return 1024 * 1024 * 1024 } // 1GB
    
    func setThreads(_ count: Int32) {
        threads = count
    }
    
    func setGPUEnabled(_ enabled: Bool) {
        gpuEnabled = enabled
    }
    
    func clearKVCache() {
        // Mock implementation
    }
    
    func tokenizeText(_ text: String, error: inout NSError?) -> [NSNumber]? {
        // Mock tokenization - split by spaces and assign arbitrary token IDs
        let words = text.components(separatedBy: " ")
        return words.enumerated().map { NSNumber(value: $0.offset + 1) }
    }
    
    func detokenizeTokenIds(_ tokenIds: [NSNumber], error: inout NSError?) -> String? {
        // Mock detokenization
        return tokenIds.map { "token\($0.intValue)" }.joined(separator: " ")
    }
    
    func generateTextStream(withPrompt prompt: String, maxTokens: Int32, temperature: Float, topP: Float, error: inout NSError?) -> Bool {
        // Mock streaming implementation - just return success
        return true
    }
}

// MARK: - LlamaWrapper Implementation

/// Swift wrapper for llama.cpp integration
@MainActor
class LlamaWrapper: ObservableObject, @preconcurrency LLMInferenceEngine {
    
    // MARK: - Published Properties
    @Published var isModelLoaded: Bool = false
    @Published var currentModelPath: String?
    @Published var isGenerating: Bool = false
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    private let bridge: MockLlamaCppBridge
    private var config: LlamaConfig
    private let queue = DispatchQueue(label: "llama.wrapper", qos: .userInitiated)
    
    // MARK: - Initialization
    
    init(config: LlamaConfig = .default) {
        self.bridge = MockLlamaCppBridge()
        self.config = config
        
        // Apply initial configuration
        bridge.setThreads(Int32(config.threads))
        bridge.setGPUEnabled(config.gpuEnabled)
    }
    
    deinit {
        bridge.unloadModel()
    }
    
    // MARK: - Model Management
    
    func loadModel(at path: String, contextSize: Int = 2048) async throws {
        guard !path.isEmpty else {
            throw LlamaWrapperError.invalidParameters("Model path cannot be empty")
        }
        
        guard FileManager.default.fileExists(atPath: path) else {
            throw LlamaWrapperError.modelNotFound(path)
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            queue.async { [weak self] in
                guard let self = self else { 
                    continuation.resume(throwing: LlamaWrapperError.bridgeError(NSError(domain: "LlamaWrapper", code: -1, userInfo: [NSLocalizedDescriptionKey: "Wrapper deallocated"])))
                    return 
                }
                
                var error: NSError?
                let success = self.bridge.loadModel(atPath: path, contextSize: Int32(contextSize), error: &error)
                
                DispatchQueue.main.async {
                    if success {
                        self.isModelLoaded = true
                        self.currentModelPath = path
                        self.config = LlamaConfig(
                            contextSize: contextSize,
                            threads: self.config.threads,
                            gpuEnabled: self.config.gpuEnabled,
                            temperature: self.config.temperature,
                            topP: self.config.topP,
                            maxTokens: self.config.maxTokens
                        )
                        continuation.resume()
                    } else {
                        self.isModelLoaded = false
                        self.currentModelPath = nil
                        let wrapperError = error.map { LlamaWrapperError.bridgeError($0) } ?? LlamaWrapperError.modelLoadFailed("Unknown error")
                        continuation.resume(throwing: wrapperError)
                    }
                }
            }
        }
    }
    
    func unloadModel() async {
        return await withCheckedContinuation { continuation in
            queue.async { [weak self] in
                self?.bridge.unloadModel()
                
                DispatchQueue.main.async {
                    self?.isModelLoaded = false
                    self?.currentModelPath = nil
                    continuation.resume()
                }
            }
        }
    }
    
    // MARK: - Text Generation
    
    func generateText(prompt: String, maxTokens: Int, temperature: Float, topP: Float) async throws -> String {
        guard isModelLoaded else {
            throw LlamaWrapperError.noModelLoaded
        }
        
        guard !prompt.isEmpty else {
            throw LlamaWrapperError.invalidParameters("Prompt cannot be empty")
        }
        
        isGenerating = true
        defer { isGenerating = false }
        
        return try await withCheckedThrowingContinuation { continuation in
            queue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: LlamaWrapperError.bridgeError(NSError(domain: "LlamaWrapper", code: -1, userInfo: [NSLocalizedDescriptionKey: "Wrapper deallocated"])))
                    return
                }
                
                var error: NSError?
                let result = self.bridge.generateText(prompt,
                                                    maxTokens: Int32(maxTokens),
                                                    temperature: temperature,
                                                    topP: topP,
                                                    error: &error)
                
                DispatchQueue.main.async {
                    if let result = result {
                        continuation.resume(returning: result)
                    } else {
                        let wrapperError = error.map { LlamaWrapperError.bridgeError($0) } ?? LlamaWrapperError.inferenceError("Unknown error")
                        continuation.resume(throwing: wrapperError)
                    }
                }
            }
        }
    }
    
    nonisolated func generateTextStream(prompt: String, maxTokens: Int, temperature: Float, topP: Float) -> AsyncThrowingStream<String, Error> {
        return AsyncThrowingStream<String, Error> { continuation in
            Task { @MainActor in
                guard isModelLoaded else {
                    continuation.finish(throwing: LlamaWrapperError.noModelLoaded)
                    return
                }
                
                guard !prompt.isEmpty else {
                    continuation.finish(throwing: LlamaWrapperError.invalidParameters("Prompt cannot be empty"))
                    return
                }
                
                isGenerating = true
                
                queue.async { [weak self] in
                    guard let self = self else {
                        continuation.finish(throwing: LlamaWrapperError.bridgeError(NSError(domain: "LlamaWrapper", code: -1, userInfo: [NSLocalizedDescriptionKey: "Wrapper deallocated"])))
                        return
                    }
                    
                    var error: NSError?
                    let success = self.bridge.generateTextStream(withPrompt: prompt,
                                                               maxTokens: Int32(maxTokens),
                                                               temperature: temperature,
                                                               topP: topP,
                                                               error: &error)
                    
                    // Mock streaming - just yield a single response and finish
                    if success {
                        continuation.yield("This is a mock streaming response to: \(prompt)")
                        Task { @MainActor in
                            self.isGenerating = false
                        }
                        continuation.finish()
                    }
                    
                    if !success {
                        Task { @MainActor in
                            self.isGenerating = false
                        }
                        let wrapperError = error.map { LlamaWrapperError.bridgeError($0) } ?? LlamaWrapperError.inferenceError("Unknown error")
                        continuation.finish(throwing: wrapperError)
                    }
                }
            }
        }
    }
    
    // MARK: - Model Information
    
    var vocabularySize: Int {
        return Int(bridge.getVocabularySize())
    }
    
    var contextSize: Int {
        return Int(bridge.getContextSize())
    }
    
    var embeddingSize: Int {
        return Int(bridge.getEmbeddingSize())
    }
    
    var memoryUsage: Int {
        return Int(bridge.getMemoryUsage())
    }
    
    func getModelInfo() -> LlamaModelInfo {
        return LlamaModelInfo(
            vocabularySize: vocabularySize,
            contextSize: contextSize,
            embeddingSize: embeddingSize,
            memoryUsage: memoryUsage,
            isLoaded: isModelLoaded,
            modelPath: currentModelPath
        )
    }
    
    // MARK: - Configuration
    
    func setThreads(_ count: Int) {
        let clampedCount = max(1, min(count, 16))
        bridge.setThreads(Int32(clampedCount))
        Task { @MainActor in
            config = LlamaConfig(
                contextSize: config.contextSize,
                threads: clampedCount,
                gpuEnabled: config.gpuEnabled,
                temperature: config.temperature,
                topP: config.topP,
                maxTokens: config.maxTokens
            )
        }
    }
    
    func setGPUEnabled(_ enabled: Bool) {
        bridge.setGPUEnabled(enabled)
        Task { @MainActor in
            config = LlamaConfig(
                contextSize: config.contextSize,
                threads: config.threads,
                gpuEnabled: enabled,
                temperature: config.temperature,
                topP: config.topP,
                maxTokens: config.maxTokens
            )
        }
    }
    
    func clearCache() {
        bridge.clearKVCache()
    }
    
    func updateConfig(_ newConfig: LlamaConfig) {
        self.config = newConfig
        setThreads(newConfig.threads)
        setGPUEnabled(newConfig.gpuEnabled)
    }
    
    // MARK: - Tokenization
    
    func tokenize(_ text: String) async throws -> [Int] {
        // Note: We check isModelLoaded in a Task since it's @MainActor isolated
        let modelLoaded = Task { @MainActor in
            return isModelLoaded
        }
        
        guard try await modelLoaded.value else {
            throw LlamaWrapperError.noModelLoaded
        }
        
        var error: NSError?
        let tokenIds = await Task { @MainActor in
            return bridge.tokenizeText(text, error: &error)
        }.value
        
        guard let tokenIds = tokenIds else {
            throw error.map { LlamaWrapperError.bridgeError($0) } ?? LlamaWrapperError.tokenizationFailed("Unknown error")
        }
        
        return tokenIds.compactMap { $0.intValue }
    }
    
    func detokenize(_ tokens: [Int]) async throws -> String {
        // Note: We check isModelLoaded in a Task since it's @MainActor isolated
        let modelLoaded = Task { @MainActor in
            return isModelLoaded
        }
        
        guard try await modelLoaded.value else {
            throw LlamaWrapperError.noModelLoaded
        }
        
        let tokenNumbers = tokens.map { NSNumber(value: $0) }
        var error: NSError?
        let text = await Task { @MainActor in
            return bridge.detokenizeTokenIds(tokenNumbers, error: &error)
        }.value
        
        guard let text = text else {
            throw error.map { LlamaWrapperError.bridgeError($0) } ?? LlamaWrapperError.tokenizationFailed("Unknown error")
        }
        
        return text
    }
    
    // MARK: - Convenience Methods
    
    /// Generate text with current configuration
    func generateText(prompt: String) async throws -> String {
        return try await generateText(
            prompt: prompt,
            maxTokens: config.maxTokens,
            temperature: config.temperature,
            topP: config.topP
        )
    }
    
    /// Generate streaming text with current configuration
    func generateTextStream(prompt: String) -> AsyncThrowingStream<String, Error> {
        return generateTextStream(
            prompt: prompt,
            maxTokens: config.maxTokens,
            temperature: config.temperature,
            topP: config.topP
        )
    }
    
    /// Get current configuration
    func getConfig() -> LlamaConfig {
        return config
    }
    
    /// Reset to default configuration
    func resetConfig() {
        updateConfig(.default)
    }
}