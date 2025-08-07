//
//  ChatView.swift
//  LLMTest
//
//  Created by Uttam Kumar Panasala on 8/6/25.
//

import SwiftUI

struct ChatView: View {
    @StateObject private var chatManager = ChatManager.shared
    @StateObject private var modelManager = ModelManager.shared
    @StateObject private var settingsManager = SettingsManager.shared
    @State private var messageText = ""
    @State private var showingSettings = false
    @State private var showingNavigationMenu = false
    @State private var showingModelDownload = false
    @State private var showingConversationList = false
    @State private var showingDevicePerformance = false
    @State private var showingExport = false
    @State private var showingModelSelector = false
    @State private var showingQuickSettings = false
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
            ToolbarItem(placement: .navigationBarLeading) {
                HStack(spacing: 16) {
                    Button(action: { showingNavigationMenu = true }) {
                        Image(systemName: "line.3.horizontal")
                            .font(.title3)
                    }
                    
                    Button(action: { showingModelSelector = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "brain")
                            Text(getCurrentModelName())
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.blue)
                    }
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 12) {
                    Button(action: { createNewChat() }) {
                        Image(systemName: "plus.bubble")
                            .font(.title3)
                    }
                    
                    Button(action: { showingQuickSettings = true }) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.title3)
                    }
                    
                    Button(action: { showingSettings = true }) {
                        Image(systemName: "gearshape")
                            .font(.title3)
                    }
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showingNavigationMenu) {
            NavigationMenuView(
                showingModelDownload: $showingModelDownload,
                showingConversationList: $showingConversationList,
                showingDevicePerformance: $showingDevicePerformance,
                showingExport: $showingExport,
                showingSettings: $showingSettings
            )
        }
        .sheet(isPresented: $showingModelDownload) {
            NavigationView {
                ModelDownloadView()
            }
        }
        .sheet(isPresented: $showingConversationList) {
            NavigationView {
                ConversationListView()
            }
        }
        .sheet(isPresented: $showingDevicePerformance) {
            NavigationView {
                DevicePerformanceView()
            }
        }
        .sheet(isPresented: $showingExport) {
            // Use the ExportView from SettingsView
            ExportView()
        }
        .sheet(isPresented: $showingModelSelector) {
            ModelSelectorView()
        }
        .sheet(isPresented: $showingQuickSettings) {
            QuickSettingsView()
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
    
    private func getCurrentModelName() -> String {
        if chatManager.isModelLoaded {
            let modelInfo = chatManager.getModelInfo()
            if let modelPath = modelInfo.modelPath {
                let modelName = URL(fileURLWithPath: modelPath).lastPathComponent
                return modelName.replacingOccurrences(of: ".gguf", with: "")
            } else {
                return "Model"
            }
        } else {
            return "No Model"
        }
    }
    
    private func createNewChat() {
        let _ = chatManager.startNewConversation(title: "New Chat")
        // Note: In a real app, you might want to navigate to this new conversation
        // For now, we'll just create it and it will be available in the conversation list
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