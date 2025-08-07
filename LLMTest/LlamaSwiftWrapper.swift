import Foundation
import Combine

// SpeziLLM imports - package products now linked to target
import SpeziLLM
import SpeziLLMLocal
import SpeziLLMLocalDownload

/// Swift wrapper for llama.cpp functionality via SpeziLLM framework
/// This class provides a Swift interface that bridges SpeziLLM to Objective-C++
/// and implements the LLMInferenceEngine protocol for ChatManager compatibility
public class LlamaSwiftWrapper: NSObject, ObservableObject {
    
    // MARK: - Published Properties (for ChatManager compatibility)
    @Published public var isModelLoaded: Bool = false
    @Published public var isGenerating: Bool = false
    @Published public var errorMessage: String?
    
    // MARK: - Private Properties
    private var currentModelPath: String?
    private var _contextSize: Int32 = 2048
    private var _threads: Int32 = 4
    private var _gpuEnabled: Bool = false
    
    // SpeziLLM session - will be created when model is loaded
    private var llmSession: LLMLocalSession?
    
    public override init() {
        super.init()
        print("[LlamaSwiftWrapper] Initialized - SpeziLLM integration activated")
        // Note: LLMRunner is typically used as SwiftUI environment object
        // We'll create sessions directly for our bridge architecture
    }
    
    deinit {
        // Clean up synchronously in deinit
        isModelLoaded = false
        isGenerating = false
        errorMessage = nil
        currentModelPath = nil
        llmSession = nil
    }
    
    // MARK: - ChatManager Compatible Methods
    
    /// Load model method compatible with ChatManager
    public func loadModel(at path: String, contextSize: Int = 2048) async throws {
        self.errorMessage = nil
        
        // Clean up any existing model
        await unloadModel()
        
        self._contextSize = Int32(contextSize)
        self.currentModelPath = path
        
        // Validate model file exists
        guard FileManager.default.fileExists(atPath: path) else {
            let error = "Model file not found at path: \(path)"
            self.errorMessage = error
            throw NSError(domain: "LlamaSwiftWrapper", code: 1, userInfo: [NSLocalizedDescriptionKey: error])
        }
        
        // SpeziLLM integration - simplified approach for bridge compatibility
        self.isModelLoaded = true
        print("[LlamaSwiftWrapper] Model prepared for SpeziLLM loading: \(path)")
    }
    
    /// Unload model method compatible with ChatManager
    public func unloadModel() async {
        self.isModelLoaded = false
        self.isGenerating = false
        self.errorMessage = nil
        self.currentModelPath = nil
        self.llmSession = nil
        print("[LlamaSwiftWrapper] Model unloaded")
    }
    
    /// Generate text method compatible with ChatManager
    public func generateText(prompt: String, maxTokens: Int, temperature: Float, topP: Float) async throws -> String {
        print("🔥 [LlamaSwiftWrapper] Starting text generation...")
        print("🔥 [LlamaSwiftWrapper] Prompt: \"\(prompt)\"")
        print("🔥 [LlamaSwiftWrapper] Parameters - maxTokens: \(maxTokens), temperature: \(temperature), topP: \(topP)")
        
        self.isGenerating = true
        self.errorMessage = nil
        
        defer {
            self.isGenerating = false
            print("🔥 [LlamaSwiftWrapper] Text generation completed")
        }
        
        guard isModelLoaded else {
            let error = "No model loaded for text generation"
            print("❌ [LlamaSwiftWrapper] Error: \(error)")
            self.errorMessage = error
            throw NSError(domain: "LlamaSwiftWrapper", code: 2, userInfo: [NSLocalizedDescriptionKey: error])
        }
        
        guard !prompt.isEmpty else {
            let error = "Empty prompt provided"
            print("❌ [LlamaSwiftWrapper] Error: \(error)")
            self.errorMessage = error
            throw NSError(domain: "LlamaSwiftWrapper", code: 3, userInfo: [NSLocalizedDescriptionKey: error])
        }
        
        guard let modelPath = currentModelPath else {
            let error = "No model path available"
            print("❌ [LlamaSwiftWrapper] Error: \(error)")
            self.errorMessage = error
            throw NSError(domain: "LlamaSwiftWrapper", code: 4, userInfo: [NSLocalizedDescriptionKey: error])
        }
        
        print("🔥 [LlamaSwiftWrapper] Using model at path: \(modelPath)")
        
        // SpeziLLM text generation - now activated with linked packages
        do {
            print("🚀 [LlamaSwiftWrapper] Creating SpeziLLM schema...")
            let schema = LLMLocalSchema(
                model: .custom(id: modelPath)
            )
            print("🚀 [LlamaSwiftWrapper] Schema created: \(schema)")
            
            // Create LLMRunner with LLMLocalPlatform
            print("🚀 [LlamaSwiftWrapper] Creating LLMRunner...")
            let runner = LLMRunner {
                LLMLocalPlatform()
            }
            print("🚀 [LlamaSwiftWrapper] Runner created: \(runner)")
            
            // Create LLMLocalSession for actual inference
            print("🚀 [LlamaSwiftWrapper] Creating LLMLocalSession...")
            let session: LLMLocalSession = runner(with: schema)
            print("🚀 [LlamaSwiftWrapper] Session created successfully")
            
            // Generate actual LLM response
            print("🤖 [LlamaSwiftWrapper] Starting LLM inference...")
            print("🤖 [LlamaSwiftWrapper] Input prompt: \"\(prompt)\"")
            var fullResponse = ""
            
            // Add user message to session context
            print("💬 [LlamaSwiftWrapper] Adding user message to session...")
            await MainActor.run {
                session.context.append(userInput: prompt)
            }
            
            // Use SpeziLLM's generate method with streaming
            for try await token in try await session.generate() {
                fullResponse += token
                print("📝 [LlamaSwiftWrapper] Token: \(token)")
                
                // Stop if we've reached max tokens
                if fullResponse.split(separator: " ").count >= maxTokens {
                    print("⏹️ [LlamaSwiftWrapper] Reached max tokens limit (\(maxTokens))")
                    break
                }
            }
            
            let response = fullResponse.isEmpty ? "No response generated" : fullResponse
            print("🎉 [LlamaSwiftWrapper] Complete LLM response generated!")
            
            print("✅ [LlamaSwiftWrapper] Generated response: \"\(response)\"")
            print("✅ [LlamaSwiftWrapper] Response length: \(response.count) characters")
            
            print("[LlamaSwiftWrapper] SpeziLLM integration active - ready for device testing")
            return response
            
        } catch {
            let errorMsg = "SpeziLLM Error: \(error.localizedDescription)"
            self.errorMessage = errorMsg
            throw error
        }
    }
    
    /// Generate text stream method compatible with ChatManager
    public func generateTextStream(prompt: String) -> AsyncThrowingStream<String, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    let fullResponse = try await generateText(prompt: prompt, maxTokens: 512, temperature: 0.7, topP: 0.9)
                    
                    // Simulate streaming by yielding the response in chunks
                    let words = fullResponse.components(separatedBy: " ")
                    for word in words {
                        continuation.yield(word + " ")
                        try await Task.sleep(nanoseconds: 50_000_000) // 50ms delay
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    /// Get model info method compatible with ChatManager
    public func getModelInfo() -> [String: Any] {
        return [
            "isLoaded": isModelLoaded,
            "modelPath": currentModelPath ?? "",
            "contextSize": Int(_contextSize),
            "threads": Int(_threads),
            "gpuEnabled": _gpuEnabled
        ]
    }
    
    /// Set threads method compatible with ChatManager
    public func setThreads(_ threads: Int) {
        self._threads = Int32(threads)
        print("[LlamaSwiftWrapper] Set threads to: \(threads)")
    }
    
    /// Set GPU enabled method compatible with ChatManager
    @objc public func setGPUEnabled(_ enabled: Bool) {
        self._gpuEnabled = enabled
        print("[LlamaSwiftWrapper] Set GPU enabled: \(enabled)")
    }
    
    // MARK: - Objective-C Bridge Compatibility Methods
    
    /// Load model (Objective-C bridge compatibility method)
    @objc public func loadModel(atPath path: String, contextSize: Int32, threads: Int32, gpuEnabled: Bool) -> Bool {
        self._contextSize = contextSize
        self._threads = threads
        self._gpuEnabled = gpuEnabled
        self.currentModelPath = path
        
        // Validate model file exists
        guard FileManager.default.fileExists(atPath: path) else {
            print("[LlamaSwiftWrapper] Model file not found at path: \(path)")
            return false
        }
        
        self.isModelLoaded = true
        print("[LlamaSwiftWrapper] Model prepared for SpeziLLM loading: \(path)")
        return true
    }
    
    /// Unload model (Objective-C bridge compatibility method)
    @objc public func unloadModel() {
        Task {
            await unloadModel()
        }
    }
    
    // MARK: - Model Information
    
    @objc public var vocabularySize: Int32 {
        guard isModelLoaded else { return 0 }
        // TODO: Get vocabulary size from SpeziLLM
        return 32000 // Typical vocabulary size
    }
    
    @objc public func getContextSize() -> Int32 {
        guard isModelLoaded else { return 0 }
        return _contextSize
    }
    
    @objc public var embeddingSize: Int32 {
        guard isModelLoaded else { return 0 }
        // TODO: Get embedding size from SpeziLLM
        return 4096 // Typical embedding size
    }
    
    @objc public func getModelSize() -> Int64 {
        guard isModelLoaded, let modelPath = currentModelPath else { return 0 }
        
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: modelPath)
            return (attributes[.size] as? Int64) ?? 0
        } catch {
            return 0
        }
    }
    
    @objc public func getMemoryUsage() -> Int64 {
        guard isModelLoaded else { return 0 }
        // Return estimated memory usage
        return 1024 * 1024 // 1MB estimate
    }
    
    @objc public func getThreads() -> Int32 {
        guard isModelLoaded else { return 0 }
        return _threads
    }
    
    // MARK: - Additional Objective-C Bridge Methods
    
    @objc public func getModelLoadedStatus() -> Bool {
        return self.isModelLoaded
    }
    
    @objc public func setThreads(_ threads: Int32) {
        _threads = threads
        print("[LlamaSwiftWrapper] Set threads: \(threads)")
    }
    

    

    
    /// Generate text stream (LLMInferenceEngine protocol method)
    public func generateTextStream(prompt: String, maxTokens: Int, temperature: Float, topP: Float) -> AsyncThrowingStream<String, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    let fullResponse = try await generateText(prompt: prompt, maxTokens: maxTokens, temperature: temperature, topP: topP)
                    
                    // Simulate streaming by yielding the response in chunks
                    let words = fullResponse.components(separatedBy: " ")
                    for word in words {
                        continuation.yield(word + " ")
                        try await Task.sleep(nanoseconds: 50_000_000) // 50ms delay
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    /// Generate text (Objective-C bridge compatibility method)
    @objc public func generateText(prompt: String, maxTokens: Int32, temperature: Float, topP: Float) -> String? {
        // For Objective-C compatibility, we'll run the async method synchronously
        // This is not ideal but necessary for bridge compatibility
        let semaphore = DispatchSemaphore(value: 0)
        var result: String?
        var error: Error?
        
        Task {
            do {
                result = try await generateText(prompt: prompt, maxTokens: Int(maxTokens), temperature: temperature, topP: topP)
            } catch let err {
                error = err
            }
            semaphore.signal()
        }
        
        semaphore.wait()
        
        if let error = error {
            print("[LlamaSwiftWrapper] Error: \(error.localizedDescription)")
            return nil
        }
        
        return result
    }
    
    // MARK: - Objective-C Bridge Compatibility Properties
    
    @objc public var isGPUEnabled: Bool {
        return _gpuEnabled
    }
}
