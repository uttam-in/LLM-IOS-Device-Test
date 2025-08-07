//
//  LlamaWrapper.swift
//  LLMTest
//
//  Created by Uttam Kumar Panasala on 8/6/25.
//

import Foundation
import Combine
import Metal
import MetalPerformanceShaders

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
    private var currentModelPath: String = ""
    
    func loadModel(atPath path: String, contextSize: Int32, error: inout NSError?) -> Bool {
        // Mock implementation
        modelLoaded = true
        currentModelPath = path
        return true
    }
    
    func unloadModel() {
        modelLoaded = false
    }
    
    func isModelLoaded() -> Bool {
        return modelLoaded
    }
    
    func generateText(_ prompt: String, maxTokens: Int32, temperature: Float, topP: Float, error: inout NSError?) -> String? {
        // Model-specific mock responses
        let modelName = URL(fileURLWithPath: currentModelPath).lastPathComponent
        
        if modelName.contains("qwen3") {
            return generateQwenResponse(for: prompt, temperature: temperature)
        } else if modelName.contains("gemma") {
            return generateGemmaResponse(for: prompt, temperature: temperature)
        } else {
            return "I'm an AI assistant. How can I help you today?"
        }
    }
    
    private func generateQwenResponse(for prompt: String, temperature: Float) -> String {
        let responses = [
            "As Qwen3 0.6B, I can help you with that. \(prompt.count < 20 ? "Could you provide more details?" : "Let me think about this carefully.")",
            "I'm Qwen3, a compact but capable AI model. Regarding your question about \(prompt.prefix(30))..., I'd say this is an interesting topic.",
            "Hello! I'm running on the Qwen3 0.6B model. Your query about \(prompt.prefix(20)) is something I can assist with.",
            "As a Qwen3 model, I'm designed to be efficient yet helpful. About \(prompt.prefix(25))... let me provide some insights."
        ]
        
        let index = abs(prompt.hashValue) % responses.count
        return responses[index]
    }
    
    private func generateGemmaResponse(for prompt: String, temperature: Float) -> String {
        let responses = [
            "I'm Gemma 2B, Google's open model. Regarding \(prompt.prefix(30))..., here's what I think.",
            "As Gemma 2B, I can help with that. Your question about \(prompt.prefix(20)) is quite interesting.",
            "Hello! I'm running on Gemma 2B. About \(prompt.prefix(25))... let me share some thoughts.",
            "I'm Gemma, designed to be helpful and harmless. Concerning \(prompt.prefix(30))..., I'd suggest considering this approach."
        ]
        
        let index = abs(prompt.hashValue) % responses.count
        return responses[index]
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

/// Swift wrapper for llama.cpp integration with performance optimizations
@MainActor
class LlamaWrapper: ObservableObject, @preconcurrency LLMInferenceEngine {
    
    // MARK: - Published Properties
    @Published var isModelLoaded: Bool = false
    @Published var currentModelPath: String?
    @Published var isGenerating: Bool = false
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    private let bridge: MockLlamaCppBridge
    private let queue = DispatchQueue(label: "llama.inference", qos: .userInitiated)
    private var config: LlamaConfig
    
    // Performance optimization components
    private let memoryManager = MemoryManager()
    private let threadManager = ThreadManager()
    private let gpuAccelerator = MetalGPUAccelerator()
    private let backgroundTaskManager = BackgroundTaskManager()
    
    // Performance monitoring
    @Published var performanceMetrics: LlamaPerformanceMetrics = LlamaPerformanceMetrics()
    private var inferenceStartTime: CFTimeInterval = 0
    
    // MARK: - Initialization
    
    init(config: LlamaConfig = .default) {
        self.bridge = MockLlamaCppBridge()
        self.config = config
        
        // Apply initial configuration
        bridge.setThreads(Int32(config.threads))
        bridge.setGPUEnabled(config.gpuEnabled)
        
        // Setup performance optimizations
        setupPerformanceOptimizations()
    }
    
    deinit {
        bridge.unloadModel()
        Task { @MainActor in
            cleanupPerformanceComponents()
        }
    }
    
    // MARK: - Performance Setup
    
    private func setupPerformanceOptimizations() {
        // Register components with each other
        memoryManager.registerLlamaWrapper(self)
        memoryManager.registerGPUAccelerator(gpuAccelerator)
        backgroundTaskManager.registerLlamaWrapper(self)
        backgroundTaskManager.registerMemoryManager(memoryManager)
        
        // Start monitoring
        memoryManager.startMemoryMonitoring()
        
        // Configure GPU acceleration if available
        if gpuAccelerator.isGPUAvailable {
            config = LlamaConfig(
                contextSize: config.contextSize,
                threads: config.threads,
                gpuEnabled: true,
                temperature: config.temperature,
                topP: config.topP,
                maxTokens: config.maxTokens
            )
        }
    }
    
    private func cleanupPerformanceComponents() {
        memoryManager.stopMemoryMonitoring()
        gpuAccelerator.clearMemoryPool()
    }
    
    // MARK: - Model Management
    
    func loadModel(at path: String, contextSize: Int = 2048) async throws {
        guard !path.isEmpty else {
            throw LlamaWrapperError.invalidParameters("Model path cannot be empty")
        }
        
        guard FileManager.default.fileExists(atPath: path) else {
            throw LlamaWrapperError.modelNotFound(path)
        }
        
        // Check if inference is allowed (background state handling)
        guard backgroundTaskManager.canPerformInference() else {
            throw LlamaWrapperError.inferenceError("Model loading not allowed in current app state")
        }
        
        // Check memory availability
        let memoryInfo = memoryManager.getDetailedMemoryInfo()
        if memoryInfo.pressureLevel == .critical {
            throw LlamaWrapperError.outOfMemory
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            queue.async { [weak self] in
                guard let strongSelf = self else {
                    continuation.resume(throwing: LlamaWrapperError.modelLoadFailed("LlamaWrapper was deallocated"))
                    return
                }
                
                var error: NSError?
                let success = strongSelf.bridge.loadModel(atPath: path, contextSize: Int32(contextSize), error: &error)
                
                Task { @MainActor in
                    if success {
                        strongSelf.isModelLoaded = true
                        strongSelf.currentModelPath = path
                        strongSelf.config = LlamaConfig(
                            contextSize: contextSize,
                            threads: strongSelf.config.threads,
                            gpuEnabled: strongSelf.gpuAccelerator.isGPUAvailable && strongSelf.config.gpuEnabled,
                            temperature: strongSelf.config.temperature,
                            topP: strongSelf.config.topP,
                            maxTokens: strongSelf.config.maxTokens
                        )
                        
                        // Update performance metrics
                        strongSelf.performanceMetrics.modelLoadTime = CFAbsoluteTimeGetCurrent() - strongSelf.inferenceStartTime
                        strongSelf.performanceMetrics.isGPUEnabled = strongSelf.config.gpuEnabled
                        
                        continuation.resume()
                    } else {
                        let wrapperError = error.map { LlamaWrapperError.bridgeError($0) } ?? LlamaWrapperError.modelLoadFailed("Unknown error")
                        continuation.resume(throwing: wrapperError)
                    }
                }
            }
        }
    }
    
    func unloadModel() async {
        do {
            try await threadManager.executeModelLoadingTask { [weak self] in
                guard let self = self else { return }
                
                return await withCheckedContinuation { continuation in
                    self.bridge.unloadModel()
                    
                    Task { @MainActor in
                        self.isModelLoaded = false
                        self.currentModelPath = nil
                        
                        // Clear GPU memory
                        self.gpuAccelerator.clearMemoryPool()
                        
                        // Update performance metrics
                        self.performanceMetrics.reset()
                        
                        continuation.resume()
                    }
                }
            }
        } catch {
            // Handle error silently for unload operation
            print("Error during model unload: \(error)")
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
        
        // Check if inference is allowed (background state handling)
        guard backgroundTaskManager.canPerformInference() else {
            throw LlamaWrapperError.inferenceError("Inference not allowed in current app state")
        }
        
        // Check memory pressure
        let memoryInfo = memoryManager.getDetailedMemoryInfo()
        if memoryInfo.pressureLevel == .critical {
            throw LlamaWrapperError.outOfMemory
        }
        
        isGenerating = true
        inferenceStartTime = CFAbsoluteTimeGetCurrent()
        
        defer { 
            isGenerating = false
            updatePerformanceMetrics()
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            queue.async { [weak self] in
                guard let strongSelf = self else {
                    continuation.resume(throwing: LlamaWrapperError.inferenceError("LlamaWrapper was deallocated"))
                    return
                }
                
                var error: NSError?
                
                // Try GPU acceleration if available and enabled
                let result: String?
                if strongSelf.config.gpuEnabled && strongSelf.gpuAccelerator.isGPUEnabled {
                    // Use GPU-accelerated inference (simplified implementation)
                    result = strongSelf.bridge.generateText(prompt, maxTokens: Int32(maxTokens), temperature: temperature, topP: topP, error: &error)
                } else {
                    // Use CPU inference
                    result = strongSelf.bridge.generateText(prompt, maxTokens: Int32(maxTokens), temperature: temperature, topP: topP, error: &error)
                }
                
                Task { @MainActor in
                    if let result = result {
                        // Update performance metrics
                        let inferenceTime = CFAbsoluteTimeGetCurrent() - strongSelf.inferenceStartTime
                        strongSelf.performanceMetrics.lastInferenceTime = inferenceTime
                        strongSelf.performanceMetrics.totalInferences += 1
                        strongSelf.performanceMetrics.averageInferenceTime = 
                            (strongSelf.performanceMetrics.averageInferenceTime * Double(strongSelf.performanceMetrics.totalInferences - 1) + inferenceTime) / Double(strongSelf.performanceMetrics.totalInferences)
                        
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
        
        guard await modelLoaded.value else {
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
        
        guard await modelLoaded.value else {
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
    
    // MARK: - Performance Metrics
    
    private func updatePerformanceMetrics() {
        let memoryInfo = memoryManager.getDetailedMemoryInfo()
        let threadMetrics = threadManager.getPerformanceMetrics()
        let gpuInfo = gpuAccelerator.getGPUInfo()
        
        performanceMetrics.memoryUsage = memoryInfo.currentUsage
        performanceMetrics.memoryPressure = memoryInfo.pressureLevel
        performanceMetrics.threadUtilization = threadMetrics.threadUtilization
        performanceMetrics.gpuMemoryUsage = gpuInfo.memoryUsage
        performanceMetrics.activeThreads = threadMetrics.activeInferenceThreads
    }
    
    func getPerformanceMetrics() -> LlamaPerformanceMetrics {
        updatePerformanceMetrics()
        return performanceMetrics
    }
    
    func getDetailedPerformanceInfo() -> DetailedPerformanceInfo {
        let memoryInfo = memoryManager.getDetailedMemoryInfo()
        let threadInfo = threadManager.getDetailedThreadInfo()
        let gpuInfo = gpuAccelerator.getGPUInfo()
        let appStateInfo = backgroundTaskManager.getAppStateInfo()
        
        return DetailedPerformanceInfo(
            llamaMetrics: performanceMetrics,
            memoryInfo: memoryInfo,
            threadInfo: threadInfo,
            gpuInfo: gpuInfo,
            appStateInfo: appStateInfo
        )
    }
}

// MARK: - Performance Metrics Structures

struct LlamaPerformanceMetrics {
    var modelLoadTime: TimeInterval = 0
    var lastInferenceTime: TimeInterval = 0
    var averageInferenceTime: TimeInterval = 0
    var totalInferences: Int = 0
    var memoryUsage: Int64 = 0
    var memoryPressure: MemoryPressureLevel = .normal
    var threadUtilization: Double = 0
    var gpuMemoryUsage: Int64 = 0
    var activeThreads: Int = 0
    var isGPUEnabled: Bool = false
    
    mutating func reset() {
        modelLoadTime = 0
        lastInferenceTime = 0
        averageInferenceTime = 0
        totalInferences = 0
        memoryUsage = 0
        memoryPressure = .normal
        threadUtilization = 0
        gpuMemoryUsage = 0
        activeThreads = 0
        isGPUEnabled = false
    }
}

struct DetailedPerformanceInfo {
    let llamaMetrics: LlamaPerformanceMetrics
    let memoryInfo: DetailedMemoryInfo
    let threadInfo: DetailedThreadInfo
    let gpuInfo: GPUInfo
    let appStateInfo: AppStateInfo
}