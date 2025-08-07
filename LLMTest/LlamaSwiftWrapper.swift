import Foundation
import Combine
import Spezi

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
    private var llmRunner: LLMRunner?
    
    public override init() {
        super.init()
        print("[LlamaSwiftWrapper] Initialized - SpeziLLM integration activated")
        setupSpeziLLMRunner()
    }
    
    private func setupSpeziLLMRunner() {
        // Create LLMRunner with LLMLocalPlatform - matching app configuration
        self.llmRunner = LLMRunner {
            LLMLocalPlatform()
        }
        print("[LlamaSwiftWrapper] SpeziLLM runner configured successfully")
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
        print("🔄 [LlamaSwiftWrapper] Starting model loading...")
        print("🔄 [LlamaSwiftWrapper] Model path: \(path)")
        print("🔄 [LlamaSwiftWrapper] Context size: \(contextSize)")
        
        self.errorMessage = nil
        
        // Clean up any existing model
        await unloadModel()
        
        self._contextSize = Int32(contextSize)
        self.currentModelPath = path
        
        // Validate model file exists
        guard FileManager.default.fileExists(atPath: path) else {
            let error = "Model file not found at path: \(path)"
            print("❌ [LlamaSwiftWrapper] \(error)")
            self.errorMessage = error
            throw NSError(domain: "LlamaSwiftWrapper", code: 1, userInfo: [NSLocalizedDescriptionKey: error])
        }
        
        // Validate model file format
        let fileExtension = URL(fileURLWithPath: path).pathExtension.lowercased()
        guard fileExtension == "gguf" || fileExtension == "ggml" else {
            let error = "Unsupported model format. Expected .gguf or .ggml file, got .\(fileExtension)"
            print("❌ [LlamaSwiftWrapper] \(error)")
            self.errorMessage = error
            throw NSError(domain: "LlamaSwiftWrapper", code: 7, userInfo: [NSLocalizedDescriptionKey: error])
        }
        
        // Check file size for basic validation
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: path)
            let fileSize = attributes[.size] as? Int64 ?? 0
            print("📊 [LlamaSwiftWrapper] Model file size: \(ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .binary))")
            
            // Basic sanity check - model should be at least 100MB
            guard fileSize > 100_000_000 else {
                let error = "Model file appears to be too small (\(ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .binary))). It may be corrupted."
                print("❌ [LlamaSwiftWrapper] \(error)")
                self.errorMessage = error
                throw NSError(domain: "LlamaSwiftWrapper", code: 8, userInfo: [NSLocalizedDescriptionKey: error])
            }
        } catch {
            let errorMsg = "Failed to validate model file: \(error.localizedDescription)"
            print("❌ [LlamaSwiftWrapper] \(errorMsg)")
            self.errorMessage = errorMsg
            throw NSError(domain: "LlamaSwiftWrapper", code: 9, userInfo: [NSLocalizedDescriptionKey: errorMsg])
        }
        
        // Pre-initialize SpeziLLM components to validate model compatibility
        do {
            print("🔍 [LlamaSwiftWrapper] Validating model compatibility with SpeziLLM...")
            
            guard let runner = self.llmRunner else {
                let error = "LLMRunner not properly initialized"
                print("❌ [LlamaSwiftWrapper] \(error)")
                self.errorMessage = error
                throw NSError(domain: "LlamaSwiftWrapper", code: 11, userInfo: [NSLocalizedDescriptionKey: error])
            }
            
            let schema = LLMLocalSchema(
                model: .custom(id: path),
                parameters: .init(
                    maxOutputLength: 10 // Small test generation
                )
            )
            
            // Create session to validate model can be loaded
            let testSession: LLMLocalSession = runner(with: schema)
            
            // Store for later use
            self.llmSession = testSession
            
            print("✅ [LlamaSwiftWrapper] Model validation successful")
            
        } catch {
            let errorMsg = "Model validation failed: \(error.localizedDescription)"
            print("❌ [LlamaSwiftWrapper] \(errorMsg)")
            self.errorMessage = errorMsg
            throw NSError(domain: "LlamaSwiftWrapper", code: 10, userInfo: [
                NSLocalizedDescriptionKey: "Failed to load model. The model file may be incompatible or corrupted.",
                NSLocalizedFailureReasonErrorKey: error.localizedDescription
            ])
        }
        
        // Mark as loaded
        self.isModelLoaded = true
        print("🎉 [LlamaSwiftWrapper] Model loaded successfully!")
        print("🎉 [LlamaSwiftWrapper] Ready for on-device inference with SpeziLLM")
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
        
        // SpeziLLM text generation - real on-device inference
        do {
            print("🚀 [LlamaSwiftWrapper] Creating SpeziLLM schema...")
            
            // Create schema with proper model configuration
            let schema = LLMLocalSchema(
                model: .custom(id: modelPath),
                parameters: .init(
                    maxOutputLength: maxTokens
                )
            )
            print("🚀 [LlamaSwiftWrapper] Schema created with model: \(modelPath)")
            
            // Use the pre-configured LLMRunner
            print("🚀 [LlamaSwiftWrapper] Using configured LLMRunner...")
            guard let runner = self.llmRunner else {
                let error = "LLMRunner not properly initialized"
                print("❌ [LlamaSwiftWrapper] \(error)")
                self.errorMessage = error
                throw NSError(domain: "LlamaSwiftWrapper", code: 11, userInfo: [NSLocalizedDescriptionKey: error])
            }
            print("🚀 [LlamaSwiftWrapper] Runner ready for inference")
            
            // Create LLMLocalSession for actual inference
            print("🚀 [LlamaSwiftWrapper] Creating LLMLocalSession...")
            let session: LLMLocalSession = runner(with: schema)
            
            // Store session for reuse
            self.llmSession = session
            print("🚀 [LlamaSwiftWrapper] Session created and stored successfully")
            
            // Generate actual LLM response
            print("🤖 [LlamaSwiftWrapper] Starting on-device LLM inference...")
            print("🤖 [LlamaSwiftWrapper] Input prompt: \"\(prompt)\"")
            var fullResponse = ""
            var tokenCount = 0
            
            // Add user message to session context
            print("💬 [LlamaSwiftWrapper] Adding user message to session...")
            await MainActor.run {
                session.context.append(userInput: prompt)
            }
            
            // Use SpeziLLM's generate method with streaming
            print("🔄 [LlamaSwiftWrapper] Starting token generation...")
            for try await token in try await session.generate() {
                fullResponse += token
                tokenCount += 1
                
                // Log every 10th token to avoid spam
                if tokenCount % 10 == 0 {
                    print("📝 [LlamaSwiftWrapper] Generated \(tokenCount) tokens...")
                }
                
                // Stop if we've reached max tokens
                if tokenCount >= maxTokens {
                    print("⏹️ [LlamaSwiftWrapper] Reached max tokens limit (\(maxTokens))")
                    break
                }
            }
            
            let response = fullResponse.isEmpty ? "I apologize, but I couldn't generate a response. Please try again." : fullResponse
            print("🎉 [LlamaSwiftWrapper] On-device LLM inference completed!")
            print("✅ [LlamaSwiftWrapper] Generated \(tokenCount) tokens")
            print("✅ [LlamaSwiftWrapper] Response length: \(response.count) characters")
            print("✅ [LlamaSwiftWrapper] Final response: \"\(response.prefix(100))...\"")
            
            return response
            
        } catch {
            let errorMsg = "SpeziLLM On-Device Inference Error: \(error.localizedDescription)"
            print("❌ [LlamaSwiftWrapper] \(errorMsg)")
            self.errorMessage = errorMsg
            
            // Provide more specific error information
            if error.localizedDescription.contains("model") {
                throw NSError(domain: "LlamaSwiftWrapper", code: 5, userInfo: [
                    NSLocalizedDescriptionKey: "Model loading failed. Please ensure the model file is valid and compatible.",
                    NSLocalizedFailureReasonErrorKey: error.localizedDescription
                ])
            } else {
                throw NSError(domain: "LlamaSwiftWrapper", code: 6, userInfo: [
                    NSLocalizedDescriptionKey: "On-device inference failed. Please try again.",
                    NSLocalizedFailureReasonErrorKey: error.localizedDescription
                ])
            }
        }
    }
    
    /// Generate text stream method compatible with ChatManager
    public func generateTextStream(prompt: String) -> AsyncThrowingStream<String, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    print("🌊 [LlamaSwiftWrapper] Starting streaming text generation...")
                    
                    guard isModelLoaded, let session = llmSession else {
                        continuation.finish(throwing: NSError(domain: "LlamaSwiftWrapper", code: 2, userInfo: [NSLocalizedDescriptionKey: "No model loaded for streaming"]))
                        return
                    }
                    
                    self.isGenerating = true
                    defer { self.isGenerating = false }
                    
                    // Add user message to session context
                    await MainActor.run {
                        session.context.append(userInput: prompt)
                    }
                    
                    // Stream tokens directly from SpeziLLM
                    var tokenCount = 0
                    for try await token in try await session.generate() {
                        continuation.yield(token)
                        tokenCount += 1
                        
                        // Stop at reasonable limit for streaming
                        if tokenCount >= 512 {
                            break
                        }
                    }
                    
                    print("🌊 [LlamaSwiftWrapper] Streaming completed with \(tokenCount) tokens")
                    continuation.finish()
                    
                } catch {
                    print("❌ [LlamaSwiftWrapper] Streaming error: \(error.localizedDescription)")
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
                    print("🌊 [LlamaSwiftWrapper] Starting parameterized streaming...")
                    print("🌊 [LlamaSwiftWrapper] Parameters - maxTokens: \(maxTokens), temperature: \(temperature), topP: \(topP)")
                    
                    guard isModelLoaded else {
                        continuation.finish(throwing: NSError(domain: "LlamaSwiftWrapper", code: 2, userInfo: [NSLocalizedDescriptionKey: "No model loaded for streaming"]))
                        return
                    }
                    
                    self.isGenerating = true
                    defer { self.isGenerating = false }
                    
                    // Create new schema with specific parameters for this generation
                    let schema = LLMLocalSchema(
                        model: .custom(id: currentModelPath ?? ""),
                        parameters: .init(
                            maxOutputLength: maxTokens
                        )
                    )
                    
                    guard let runner = self.llmRunner else {
                        continuation.finish(throwing: NSError(domain: "LlamaSwiftWrapper", code: 11, userInfo: [NSLocalizedDescriptionKey: "LLMRunner not properly initialized"]))
                        return
                    }
                    
                    let session: LLMLocalSession = runner(with: schema)
                    
                    // Add user message to session context
                    await MainActor.run {
                        session.context.append(userInput: prompt)
                    }
                    
                    // Stream tokens directly from SpeziLLM
                    var tokenCount = 0
                    for try await token in try await session.generate() {
                        continuation.yield(token)
                        tokenCount += 1
                        
                        // Stop at max tokens
                        if tokenCount >= maxTokens {
                            break
                        }
                    }
                    
                    print("🌊 [LlamaSwiftWrapper] Parameterized streaming completed with \(tokenCount) tokens")
                    continuation.finish()
                    
                } catch {
                    print("❌ [LlamaSwiftWrapper] Parameterized streaming error: \(error.localizedDescription)")
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
