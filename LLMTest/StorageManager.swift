//
//  StorageManager.swift
//  LLMTest
//
//  Created by Uttam Kumar Panasala on 8/6/25.
//

import Foundation
import CoreData
import Combine

/// Manages Core Data operations for the LLM chat application
@MainActor
class StorageManager: ObservableObject {
    static let shared = StorageManager()
    
    // MARK: - Published Properties
    @Published var conversations: [Conversation] = []
    @Published var currentConversation: Conversation?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // MARK: - Core Data Stack
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "LLMTest")
        container.loadPersistentStores { _, error in
            if let error = error {
                print("Core Data error: \(error)")
                self.errorMessage = "Failed to load data store: \(error.localizedDescription)"
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        return container
    }()
    
    var context: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    // MARK: - Initialization
    private init() {
        loadConversations()
    }
    
    // MARK: - Save Context
    func saveContext() {
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                print("Save error: \(error)")
                errorMessage = "Failed to save: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - Conversation Management
    
    /// Load all conversations from Core Data
    func loadConversations() {
        isLoading = true
        let request: NSFetchRequest<Conversation> = Conversation.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Conversation.updatedAt, ascending: false)]
        
        do {
            conversations = try context.fetch(request)
            isLoading = false
        } catch {
            print("Load conversations error: \(error)")
            errorMessage = "Failed to load conversations: \(error.localizedDescription)"
            isLoading = false
        }
    }
    
    /// Create a new conversation
    func createConversation(title: String? = nil) -> Conversation {
        let conversation = Conversation(context: context)
        conversation.id = UUID()
        conversation.title = title ?? "New Conversation"
        conversation.createdAt = Date()
        conversation.updatedAt = Date()
        conversation.messageCount = 0
        conversation.isArchived = false
        
        saveContext()
        loadConversations()
        
        return conversation
    }
    
    /// Update conversation title
    func updateConversation(_ conversation: Conversation, title: String) {
        conversation.title = title
        conversation.updatedAt = Date()
        saveContext()
        loadConversations()
    }
    
    /// Archive/unarchive a conversation
    func toggleArchiveConversation(_ conversation: Conversation) {
        conversation.isArchived.toggle()
        conversation.updatedAt = Date()
        saveContext()
        loadConversations()
    }
    
    /// Delete a conversation and all its messages
    func deleteConversation(_ conversation: Conversation) {
        context.delete(conversation)
        saveContext()
        loadConversations()
        
        if currentConversation == conversation {
            currentConversation = nil
        }
    }
    
    /// Get conversation by ID
    func getConversation(by id: UUID) -> Conversation? {
        let request: NSFetchRequest<Conversation> = Conversation.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        
        do {
            return try context.fetch(request).first
        } catch {
            print("Get conversation error: \(error)")
            return nil
        }
    }
    
    // MARK: - Message Management
    
    /// Add a new message to a conversation
    func addMessage(to conversation: Conversation, content: String, isFromUser: Bool, messageType: String = "text", metadata: String? = nil) -> ChatMessage {
        let message = ChatMessage(context: context)
        message.id = UUID()
        message.content = content
        message.isFromUser = isFromUser
        message.timestamp = Date()
        message.messageType = messageType
        message.metadata = metadata
        message.conversation = conversation
        
        // Update conversation
        conversation.updatedAt = Date()
        conversation.messageCount = Int32((conversation.messages?.count ?? 0) + 1)
        
        // Auto-generate title from first user message if needed
        if conversation.title == "New Conversation" && isFromUser && !content.isEmpty {
            let title = String(content.prefix(50))
            conversation.title = title.count < content.count ? title + "..." : title
        }
        
        saveContext()
        loadConversations()
        
        return message
    }
    
    /// Get messages for a specific conversation
    func getMessages(for conversation: Conversation) -> [ChatMessage] {
        let request: NSFetchRequest<ChatMessage> = ChatMessage.fetchRequest()
        request.predicate = NSPredicate(format: "conversation == %@", conversation)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ChatMessage.timestamp, ascending: true)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Get messages error: \(error)")
            errorMessage = "Failed to load messages: \(error.localizedDescription)"
            return []
        }
    }
    
    /// Update message content
    func updateMessage(_ message: ChatMessage, content: String) {
        message.content = content
        message.conversation?.updatedAt = Date()
        saveContext()
    }
    
    /// Delete a specific message
    func deleteMessage(_ message: ChatMessage) {
        let conversation = message.conversation
        context.delete(message)
        
        // Update conversation message count
        if let conv = conversation {
            conv.messageCount = Int32(max(0, Int(conv.messageCount) - 1))
            conv.updatedAt = Date()
        }
        
        saveContext()
        loadConversations()
    }
    
    /// Delete all messages in a conversation
    func deleteAllMessages(in conversation: Conversation) {
        let request: NSFetchRequest<ChatMessage> = ChatMessage.fetchRequest()
        request.predicate = NSPredicate(format: "conversation == %@", conversation)
        
        do {
            let messages = try context.fetch(request)
            for message in messages {
                context.delete(message)
            }
            
            conversation.messageCount = 0
            conversation.updatedAt = Date()
            
            saveContext()
            loadConversations()
        } catch {
            print("Delete all messages error: \(error)")
            errorMessage = "Failed to delete messages: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Search and Filtering
    
    /// Search messages by content
    func searchMessages(query: String) -> [ChatMessage] {
        let request: NSFetchRequest<ChatMessage> = ChatMessage.fetchRequest()
        request.predicate = NSPredicate(format: "content CONTAINS[cd] %@", query)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ChatMessage.timestamp, ascending: false)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Search messages error: \(error)")
            return []
        }
    }
    
    /// Get recent conversations (not archived)
    func getRecentConversations(limit: Int = 10) -> [Conversation] {
        let request: NSFetchRequest<Conversation> = Conversation.fetchRequest()
        request.predicate = NSPredicate(format: "isArchived == NO")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Conversation.updatedAt, ascending: false)]
        request.fetchLimit = limit
        
        do {
            return try context.fetch(request)
        } catch {
            print("Get recent conversations error: \(error)")
            return []
        }
    }
    
    // MARK: - Statistics
    
    /// Get total number of conversations
    func getTotalConversationsCount() -> Int {
        let request: NSFetchRequest<Conversation> = Conversation.fetchRequest()
        do {
            return try context.count(for: request)
        } catch {
            return 0
        }
    }
    
    /// Get total number of messages
    func getTotalMessagesCount() -> Int {
        let request: NSFetchRequest<ChatMessage> = ChatMessage.fetchRequest()
        do {
            return try context.count(for: request)
        } catch {
            return 0
        }
    }
    
    // MARK: - Data Management
    
    /// Clear all data (for testing or reset)
    func clearAllData() {
        // Delete all conversations (cascade will delete messages)
        let conversationRequest: NSFetchRequest<NSFetchRequestResult> = Conversation.fetchRequest()
        let deleteConversationsRequest = NSBatchDeleteRequest(fetchRequest: conversationRequest)
        
        // Delete all app settings
        let settingsRequest: NSFetchRequest<NSFetchRequestResult> = AppSettings.fetchRequest()
        let deleteSettingsRequest = NSBatchDeleteRequest(fetchRequest: settingsRequest)
        
        do {
            try context.execute(deleteConversationsRequest)
            try context.execute(deleteSettingsRequest)
            saveContext()
            loadConversations()
        } catch {
            print("Clear all data error: \(error)")
            errorMessage = "Failed to clear data: \(error.localizedDescription)"
        }
    }
    
    /// Export conversation data
    func exportConversationData(conversation: Conversation) -> [String: Any] {
        let messages = getMessages(for: conversation)
        return [
            "id": conversation.id?.uuidString ?? "",
            "title": conversation.title ?? "",
            "createdAt": conversation.createdAt ?? Date(),
            "updatedAt": conversation.updatedAt ?? Date(),
            "messageCount": conversation.messageCount,
            "messages": messages.map { message in
                [
                    "id": message.id?.uuidString ?? "",
                    "content": message.content ?? "",
                    "isFromUser": message.isFromUser,
                    "timestamp": message.timestamp ?? Date(),
                    "messageType": message.messageType ?? "text",
                    "metadata": message.metadata ?? ""
                ]
            }
        ]
    }
}

// MARK: - Error Handling Extension
extension StorageManager {
    func clearError() {
        errorMessage = nil
    }
    
    func handleError(_ error: Error, context: String) {
        print("\(context) error: \(error)")
        errorMessage = "\(context): \(error.localizedDescription)"
    }
}