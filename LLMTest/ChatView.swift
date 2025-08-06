//
//  ChatView.swift
//  LLMTest
//
//  Created by Uttam Kumar Panasala on 8/6/25.
//

import SwiftUI

struct ChatView: View {
    @StateObject private var chatManager = ChatManager.shared
    @State private var messageText = ""
    @State private var showingSettings = false
    @FocusState private var isInputFocused: Bool
    
    let conversation: Conversation
    
    init(conversation: Conversation) {
        self.conversation = conversation
    }
    
    var messages: [ChatMessage] {
        chatManager.getMessages(for: conversation)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Messages List
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(messages, id: \.id) { message in
                            ChatMessageView(message: message)
                                .id(message.id)
                        }
                        
                        if chatManager.isProcessing {
                            HStack {
                                TypingIndicatorView()
                                Spacer()
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                }
                .onChange(of: messages.count) { _, _ in
                    // Auto-scroll to bottom when new messages are added
                    if let lastMessage = messages.last {
                        withAnimation(.easeOut(duration: 0.3)) {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
                .onAppear {
                    // Scroll to bottom when view appears
                    if let lastMessage = messages.last {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
            
            Divider()
            
            // Input Area
            MessageInputView(
                messageText: $messageText,
                isLoading: .constant(chatManager.isProcessing),
                isInputFocused: $isInputFocused,
                onSend: sendMessage
            )
        }
        .navigationTitle(conversation.title ?? "Chat")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingSettings = true }) {
                    Image(systemName: "gearshape")
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .onTapGesture {
            // Dismiss keyboard when tapping outside
            isInputFocused = false
        }
    }
    
    private func sendMessage() {
        guard chatManager.isValidMessage(messageText) else {
            return
        }
        
        let trimmedMessage = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Clear input immediately
        messageText = ""
        isInputFocused = false
        
        // Send message through ChatManager
        Task {
            await chatManager.sendMessage(trimmedMessage, to: conversation)
        }
    }
}

// MARK: - Message Input View
struct MessageInputView: View {
    @Binding var messageText: String
    @Binding var isLoading: Bool
    @FocusState.Binding var isInputFocused: Bool
    let onSend: () -> Void
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            // Text Input
            TextField("Type a message...", text: $messageText, axis: .vertical)
                .textFieldStyle(.plain)
                .padding(12)
                .background(Color(.systemGray6))
                .cornerRadius(20)
                .lineLimit(1...6)
                .focused($isInputFocused)
                .onSubmit {
                    if !messageText.isEmpty {
                        onSend()
                    }
                }
            
            // Send Button
            Button(action: onSend) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundColor(canSend ? .blue : .gray)
            }
            .disabled(!canSend)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }
    
    private var canSend: Bool {
        !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isLoading
    }
}

// MARK: - Typing Indicator
struct TypingIndicatorView: View {
    @State private var animationOffset: CGFloat = 0
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.gray)
                    .frame(width: 8, height: 8)
                    .scaleEffect(animationOffset == CGFloat(index) ? 1.2 : 1.0)
                    .animation(
                        .easeInOut(duration: 0.6)
                        .repeatForever()
                        .delay(Double(index) * 0.2),
                        value: animationOffset
                    )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemGray5))
        .cornerRadius(18)
        .onAppear {
            animationOffset = 2
        }
    }
}

#Preview {
    NavigationView {
        ChatView(conversation: {
            let storage = StorageManager.shared
            let conv = storage.createConversation(title: "Preview Chat")
            _ = storage.addMessage(to: conv, content: "Hello! How are you?", isFromUser: true)
            _ = storage.addMessage(to: conv, content: "I'm doing great! How can I help you today?", isFromUser: false)
            return conv
        }())
    }
}