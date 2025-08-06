//
//  ChatManager.swift
//  LLMTest
//
//  Created by Uttam Kumar Panasala on 8/6/25.
//

import Foundation
import Combine

/// Manages chat functionality and coordinates between UI and storage
@MainActor
class ChatManager: ObservableObject {
    static let shared = ChatManager()
    
    @Published var activeConversation: Conversation?
    @Published var isProcessing = false
    @Published var errorMessage: String?
    @Published var isModelLoaded = false
    
    private let storageManager = StorageManager.shared
    private let llamaWrapper = LlamaWrapper()
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        setupObservers()
    }
    
    private func setupObservers() {
        // Observe storage manager error messages
        storageManager.$errorMessage
            .receive(on: DispatchQueue.main)
            .assign(to: \.errorMessage, on: self)
            .store(in: &cancellables)
        
        // Observe llama wrapper state
        llamaWrapper.$isModelLoaded
            .receive(on: DispatchQueue.main)
            .assign(to: \.isModelLoaded, on: self)
            .store(in: &cancellables)
        
        llamaWrapper.$isGenerating
            .receive(on: DispatchQueue.main)
            .assign(to: \.isProcessing, on: self)
            .store(in: &cancellables)
        
        llamaWrapper.$errorMessage
            .receive(on: DispatchQueue.main)
            .assign(to: \.errorMessage, on: self)
            .store(in: &cancellables)
    }
    
    // MARK: - Model Management
    
    /// Load a model for inference
    func loadModel(at path: String, contextSize: Int = 2048) async throws {
        do {
            try await llamaWrapper.loadModel(at: path, contextSize: contextSize)
            clearError()
        } catch {
            handleError(error, context: "Model loading")
            throw error
        }
    }
    
    /// Unload the current model
    func unloadModel() async {
        await llamaWrapper.unloadModel()
    }
    
    /// Get current model information
    func getModelInfo() -> LlamaModelInfo {
        return llamaWrapper.getModelInfo()
    }
    
    /// Configure model parameters
    func configureModel(threads: Int? = nil, gpuEnabled: Bool? = nil) {
        if let threads = threads {
            llamaWrapper.setThreads(threads)
        }
        if let gpuEnabled = gpuEnabled {
            llamaWrapper.setGPUEnabled(gpuEnabled)
        }
    }
    
    // MARK: - Conversation Management
    
    /// Create a new conversation and set it as active
    func startNewConversation(title: String? = nil) -> Conversation {
        let conversation = storageManager.createConversation(title: title)
        activeConversation = conversation
        return conversation
    }
    
    /// Set an existing conversation as active
    func setActiveConversation(_ conversation: Conversation) {
        activeConversation = conversation
    }
    
    /// Get all conversations
    func getAllConversations() -> [Conversation] {
        return storageManager.conversations
    }
    
    /// Get recent conversations (non-archived)
    func getRecentConversations(limit: Int = 10) -> [Conversation] {
        return storageManager.getRecentConversations(limit: limit)
    }
    
    // MARK: - Message Management
    
    /// Send a user message and trigger AI response
    func sendMessage(_ content: String, to conversation: Conversation) async {
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Add user message
        _ = storageManager.addMessage(
            to: conversation,
            content: trimmedContent,
            isFromUser: true,
            messageType: "text"
        )
        
        // Generate AI response
        await generateAIResponse(for: trimmedContent, in: conversation)
    }
    
    /// Send a user message with streaming AI response
    func sendMessageWithStreaming(_ content: String, to conversation: Conversation) async {
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Add user message
        _ = storageManager.addMessage(
            to: conversation,
            content: trimmedContent,
            isFromUser: true,
            messageType: "text"
        )
        
        // Generate streaming AI response
        await generateStreamingAIResponse(for: trimmedContent, in: conversation)
    }
    
    /// Generate AI response using the loaded model
    private func generateAIResponse(for prompt: String, in conversation: Conversation) async {
        do {
            let response: String
            
            if isModelLoaded {
                // Use the actual LLM model
                response = try await llamaWrapper.generateText(prompt: prompt)
            } else {
                // Fallback to placeholder response
                response = generatePlaceholderResponse(for: prompt)
            }
            
            // Add AI message
            _ = storageManager.addMessage(
                to: conversation,
                content: response,
                isFromUser: false,
                messageType: "text",
                metadata: createResponseMetadata(for: response)
            )
            
        } catch {
            handleError(error, context: "AI response generation")
            
            // Add error message as AI response
            _ = storageManager.addMessage(
                to: conversation,
                content: "I apologize, but I encountered an error while generating a response. Please try again.",
                isFromUser: false,
                messageType: "error",
                metadata: "{\"error\": \"\(error.localizedDescription)\"}"
            )
        }
    }
    
    /// Generate streaming AI response using the loaded model
    private func generateStreamingAIResponse(for prompt: String, in conversation: Conversation) async {
        guard isModelLoaded else {
            await generateAIResponse(for: prompt, in: conversation)
            return
        }
        
        do {
            var fullResponse = ""
            let aiMessage = storageManager.addMessage(
                to: conversation,
                content: "",
                isFromUser: false,
                messageType: "text"
            )
            
            // Stream the response
            for try await token in llamaWrapper.generateTextStream(prompt: prompt) {
                fullResponse += token
                
                // Update the message content in real-time
                storageManager.updateMessage(aiMessage, content: fullResponse)
            }
            
            // Update final content
            storageManager.updateMessage(
                aiMessage,
                content: fullResponse
            )
            
        } catch {
            handleError(error, context: "Streaming AI response generation")
            
            // Add error message
            _ = storageManager.addMessage(
                to: conversation,
                content: "I apologize, but I encountered an error while generating a response. Please try again.",
                isFromUser: false,
                messageType: "error",
                metadata: "{\"error\": \"\(error.localizedDescription)\"}"
            )
        }
    }
    
    /// Create metadata for AI response
    private func createResponseMetadata(for response: String) -> String {
        let modelInfo = llamaWrapper.getModelInfo()
        let metadata = [
            "model": isModelLoaded ? "llama.cpp" : "placeholder",
            "tokens": response.count,
            "model_loaded": isModelLoaded,
            "vocabulary_size": modelInfo.vocabularySize,
            "context_size": modelInfo.contextSize,
            "memory_usage": modelInfo.memoryUsage
        ] as [String: Any]
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: metadata),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            return jsonString
        }
        
        return "{\"model\": \"\(isModelLoaded ? "llama.cpp" : "placeholder")\", \"tokens\": \(response.count)}"
    }
    
    /// Get messages for a conversation
    func getMessages(for conversation: Conversation) -> [ChatMessage] {
        return storageManager.getMessages(for: conversation)
    }
    
    /// Delete a message
    func deleteMessage(_ message: ChatMessage) {
        storageManager.deleteMessage(message)
    }
    
    /// Update message content
    func updateMessage(_ message: ChatMessage, content: String) {
        storageManager.updateMessage(message, content: content)
    }
    
    // MARK: - Search and Filtering
    
    /// Search messages across all conversations
    func searchMessages(query: String) -> [ChatMessage] {
        return storageManager.searchMessages(query: query)
    }
    
    // MARK: - Placeholder AI Response Generation
    
    private func generatePlaceholderResponse(for userMessage: String) -> String {
        let responses = [
            "That's an interesting point! I'd be happy to help you explore that further.",
            "I understand what you're asking. Let me think about the best way to approach this.",
            "Thanks for sharing that with me. Here's what I think about your question.",
            "That's a great question! Based on what you've told me, here are some thoughts.",
            "I appreciate you bringing this up. Let me provide some insights on that topic.",
            "Interesting perspective! I can definitely help you with that.",
            "I see what you mean. Let me break this down for you.",
            "That's worth considering. Here's how I would approach this situation.",
            "Good point! I think there are several ways to look at this.",
            "I'm glad you asked about that. This is definitely something worth discussing."
        ]
        
        // Simple response selection based on message characteristics
        let messageLength = userMessage.count
        let hasQuestion = userMessage.contains("?")
        let hasGreeting = userMessage.lowercased().contains("hello") || 
                         userMessage.lowercased().contains("hi") || 
                         userMessage.lowercased().contains("hey")
        
        if hasGreeting {
            return "Hello! It's great to meet you. How can I help you today?"
        } else if hasQuestion {
            return responses.randomElement() ?? responses[0]
        } else if messageLength > 100 {
            return "Thank you for sharing those details. That gives me a good understanding of what you're looking for. Let me provide a thoughtful response to address your points."
        } else {
            return responses.randomElement() ?? responses[0]
        }
    }
    
    // MARK: - Error Handling
    
    func clearError() {
        errorMessage = nil
    }
    
    func handleError(_ error: Error, context: String) {
        print("\(context) error: \(error)")
        errorMessage = "\(context): \(error.localizedDescription)"
    }
    
    // MARK: - Statistics
    
    func getTotalMessageCount() -> Int {
        return storageManager.getTotalMessagesCount()
    }
    
    func getTotalConversationCount() -> Int {
        return storageManager.getTotalConversationsCount()
    }
}

// MARK: - Chat Session Management
extension ChatManager {
    /// Start a new chat session with optional initial message
    func startChatSession(title: String? = nil, initialMessage: String? = nil) async -> Conversation {
        let conversation = startNewConversation(title: title)
        
        if let initialMessage = initialMessage {
            await sendMessage(initialMessage, to: conversation)
        }
        
        return conversation
    }
    
    /// End current chat session
    func endChatSession() {
        activeConversation = nil
        isProcessing = false
    }
}

// MARK: - Message Validation
extension ChatManager {
    /// Validate message content before sending
    func isValidMessage(_ content: String) -> Bool {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed.count <= 4000 // Max message length
    }
    
    /// Get validation error message
    func getValidationError(for content: String) -> String? {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmed.isEmpty {
            return "Message cannot be empty"
        }
        
        if trimmed.count > 4000 {
            return "Message is too long (max 4000 characters)"
        }
        
        return nil
    }
}