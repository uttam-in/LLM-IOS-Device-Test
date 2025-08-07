//
//  ContentView.swift
//  LLMTest
//
//  Created by Uttam Kumar Panasala on 8/6/25.
//

import SwiftUI

struct ContentView: View {
    @AppStorage("hasCompletedFirstTimeSetup") private var hasCompletedFirstTimeSetup = false
    @StateObject private var errorManager = ErrorManager.shared
    @StateObject private var recoveryManager = ErrorRecoveryManager.shared
    @State private var currentConversation: Conversation?
    
    var body: some View {
        ZStack {
            if hasCompletedFirstTimeSetup {
                if let conversation = currentConversation {
                    NavigationView {
                        ChatView(conversation: conversation)
                    }
                    .navigationViewStyle(StackNavigationViewStyle())
                } else {
                    ProgressView("Loading...")
                        .onAppear {
                            loadOrCreateConversation()
                        }
                }
            } else {
                FirstTimeSetupView()
            }
            
            // Recovery progress overlay
            VStack {
                Spacer()
                RecoveryProgressView()
                    .padding(.bottom, 100)
            }
        }
        .errorHandling() // Apply error handling modifier
        .onAppear {
            // Log system info on app start
            ErrorLogger.shared.logSystemInfo()
            
            // Load conversation if setup is complete
            if hasCompletedFirstTimeSetup {
                loadOrCreateConversation()
            }
        }
    }
    
    private func loadOrCreateConversation() {
        // Try to get the most recent conversation, or create a new one
        let storage = StorageManager.shared
        let conversations = storage.getRecentConversations(limit: 1)
        
        if let recentConversation = conversations.first {
            currentConversation = recentConversation
        } else {
            // Create a new conversation
            currentConversation = storage.createConversation(title: "New Chat")
        }
    }
}

#Preview {
    ContentView()
}
