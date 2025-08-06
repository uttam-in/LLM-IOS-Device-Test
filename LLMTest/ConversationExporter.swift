//
//  ConversationExporter.swift
//  LLMTest
//
//  Created by Uttam Kumar Panasala on 8/6/25.
//

import Foundation
import CoreData
import UniformTypeIdentifiers

class ConversationExporter: ObservableObject {
    private let persistentContainer: NSPersistentContainer
    
    init(persistentContainer: NSPersistentContainer) {
        self.persistentContainer = persistentContainer
    }
    
    func exportConversations(format: ExportFormat) async throws -> Data {
        let context = persistentContainer.viewContext
        let request: NSFetchRequest<Conversation> = Conversation.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Conversation.createdAt, ascending: true)]
        
        let conversations = try context.fetch(request)
        
        switch format {
        case .json:
            return try exportToJSON(conversations: conversations)
        case .csv:
            return try exportToCSV(conversations: conversations)
        case .txt:
            return try exportToText(conversations: conversations)
        }
    }
    
    private func exportToJSON(conversations: [Conversation]) throws -> Data {
        let exportData = conversations.map { conversation in
            ConversationExportData(
                id: conversation.id?.uuidString ?? "",
                title: conversation.title ?? "Untitled",
                createdAt: conversation.createdAt ?? Date(),
                updatedAt: conversation.updatedAt ?? Date(),
                messages: conversation.messagesArray.map { message in
                    MessageExportData(
                        id: message.id?.uuidString ?? "",
                        content: message.content ?? "",
                        isFromUser: message.isFromUser,
                        timestamp: message.timestamp ?? Date()
                    )
                }
            )
        }
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        return try encoder.encode(exportData)
    }
    
    private func exportToCSV(conversations: [Conversation]) throws -> Data {
        var csvContent = "Conversation ID,Conversation Title,Message ID,Sender,Content,Timestamp\n"
        
        for conversation in conversations {
            let conversationId = conversation.id?.uuidString ?? ""
            let conversationTitle = conversation.title ?? "Untitled"
            
            for message in conversation.messagesArray {
                let messageId = message.id?.uuidString ?? ""
                let sender = message.isFromUser ? "User" : "AI"
                let content = message.content?.replacingOccurrences(of: "\"", with: "\"\"") ?? ""
                let timestamp = ISO8601DateFormatter().string(from: message.timestamp ?? Date())
                
                csvContent += "\"\(conversationId)\",\"\(conversationTitle)\",\"\(messageId)\",\"\(sender)\",\"\(content)\",\"\(timestamp)\"\n"
            }
        }
        
        return csvContent.data(using: .utf8) ?? Data()
    }
    
    private func exportToText(conversations: [Conversation]) throws -> Data {
        var textContent = "Chat Export - Generated on \(DateFormatter.readable.string(from: Date()))\n"
        textContent += "=" + String(repeating: "=", count: 60) + "\n\n"
        
        for conversation in conversations {
            textContent += "Conversation: \(conversation.title ?? "Untitled")\n"
            textContent += "Created: \(DateFormatter.readable.string(from: conversation.createdAt ?? Date()))\n"
            textContent += "-" + String(repeating: "-", count: 40) + "\n\n"
            
            for message in conversation.messagesArray {
                let sender = message.isFromUser ? "You" : "AI"
                let timestamp = DateFormatter.readable.string(from: message.timestamp ?? Date())
                
                textContent += "[\(timestamp)] \(sender):\n"
                textContent += "\(message.content ?? "")\n\n"
            }
            
            textContent += "\n" + String(repeating: "=", count: 60) + "\n\n"
        }
        
        return textContent.data(using: .utf8) ?? Data()
    }
}

// MARK: - Export Data Models

struct ConversationExportData: Codable {
    let id: String
    let title: String
    let createdAt: Date
    let updatedAt: Date
    let messages: [MessageExportData]
}

struct MessageExportData: Codable {
    let id: String
    let content: String
    let isFromUser: Bool
    let timestamp: Date
}

// MARK: - Extensions

extension Conversation {
    var messagesArray: [ChatMessage] {
        let set = messages as? Set<ChatMessage> ?? []
        return set.sorted { ($0.timestamp ?? Date()) < ($1.timestamp ?? Date()) }
    }
}

extension DateFormatter {
    static let readable: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}