//
//  ConversationListView.swift
//  LLMTest
//
//  Created by Uttam Kumar Panasala on 8/6/25.
//

import SwiftUI

struct ConversationListView: View {
    @StateObject private var storageManager = StorageManager.shared
    @StateObject private var chatManager = ChatManager.shared
    @State private var showingSettings = false
    @State private var showingNewChat = false
    @State private var searchText = ""
    
    var filteredConversations: [Conversation] {
        if searchText.isEmpty {
            return storageManager.conversations.filter { !($0.isArchived) }
        } else {
            return storageManager.conversations.filter { conversation in
                !conversation.isArchived && 
                (conversation.title?.localizedCaseInsensitiveContains(searchText) == true)
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                if filteredConversations.isEmpty {
                    EmptyStateView {
                        startNewConversation()
                    }
                } else {
                    List {
                        ForEach(filteredConversations, id: \.id) { conversation in
                            NavigationLink(destination: ChatView(conversation: conversation)) {
                                ConversationRowView(conversation: conversation)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button("Delete", role: .destructive) {
                                    deleteConversation(conversation)
                                }
                                
                                Button("Archive") {
                                    storageManager.toggleArchiveConversation(conversation)
                                }
                                .tint(.orange)
                            }
                        }
                    }
                    .listStyle(.plain)
                    .searchable(text: $searchText, prompt: "Search conversations")
                }
            }
            .navigationTitle("Chats")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        Button("Settings") {
                            showingSettings = true
                        }
                        
                        NavigationLink(destination: ModelDownloadView()) {
                            Label("Manage Models", systemImage: "arrow.down.circle")
                        }
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { startNewConversation() }) {
                        Image(systemName: "square.and.pencil")
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .onAppear {
                storageManager.loadConversations()
            }
        }
    }
    
    private func startNewConversation() {
        let conversation = chatManager.startNewConversation()
        showingNewChat = true
    }
    
    private func deleteConversation(_ conversation: Conversation) {
        storageManager.deleteConversation(conversation)
    }
}

// MARK: - Conversation Row View
struct ConversationRowView: View {
    let conversation: Conversation
    @StateObject private var storageManager = StorageManager.shared
    
    private var lastMessage: ChatMessage? {
        storageManager.getMessages(for: conversation).last
    }
    
    private var lastMessagePreview: String {
        guard let lastMessage = lastMessage else {
            return "No messages yet"
        }
        
        let content = lastMessage.content ?? ""
        let maxLength = 60
        
        if content.count > maxLength {
            return String(content.prefix(maxLength)) + "..."
        }
        
        return content
    }
    
    private var lastMessageTime: String {
        guard let timestamp = lastMessage?.timestamp ?? conversation.updatedAt else {
            return ""
        }
        
        let formatter = DateFormatter()
        
        if Calendar.current.isDateInToday(timestamp) {
            formatter.timeStyle = .short
            return formatter.string(from: timestamp)
        } else if Calendar.current.isDateInYesterday(timestamp) {
            return "Yesterday"
        } else {
            let daysDifference = Calendar.current.dateComponents([.day], from: timestamp, to: Date()).day ?? 0
            
            if daysDifference < 7 {
                formatter.dateFormat = "EEEE" // Day of week
                return formatter.string(from: timestamp)
            } else {
                formatter.dateStyle = .short
                return formatter.string(from: timestamp)
            }
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Conversation Avatar
            Circle()
                .fill(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 50, height: 50)
                .overlay(
                    Text(String(conversation.title?.first?.uppercased() ?? "C"))
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(conversation.title ?? "New Conversation")
                        .font(.headline)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Text(lastMessageTime)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text(lastMessagePreview)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                    
                    Spacer()
                    
                    if conversation.messageCount > 0 {
                        Text("\(conversation.messageCount)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(.systemGray5))
                            .cornerRadius(8)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Empty State View
struct EmptyStateView: View {
    let onCreateChat: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "message.circle")
                .font(.system(size: 80))
                .foregroundColor(.gray)
            
            VStack(spacing: 8) {
                Text("No Conversations Yet")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Start your first conversation with the AI assistant")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button(action: onCreateChat) {
                HStack {
                    Image(systemName: "plus")
                    Text("Start New Chat")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.blue)
                .cornerRadius(12)
            }
        }
        .padding(.horizontal, 40)
    }
}

#Preview {
    ConversationListView()
}