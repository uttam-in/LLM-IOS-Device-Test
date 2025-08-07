//
//  NavigationMenuView.swift
//  LLMTest
//
//  Created by Uttam Kumar Panasala on 8/6/25.
//

import SwiftUI

struct NavigationMenuView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var chatManager = ChatManager.shared
    @Binding var showingModelDownload: Bool
    @Binding var showingConversationList: Bool
    @Binding var showingDevicePerformance: Bool
    @Binding var showingExport: Bool
    @Binding var showingSettings: Bool
    
    var body: some View {
        NavigationView {
            List {
                Section("Conversations") {
                    NavigationMenuItem(
                        icon: "bubble.left.and.bubble.right",
                        title: "All Conversations",
                        subtitle: "View and manage your chat history",
                        color: .blue
                    ) {
                        showingConversationList = true
                        dismiss()
                    }
                    
                    NavigationMenuItem(
                        icon: "square.and.arrow.up",
                        title: "Export Conversations",
                        subtitle: "Export your chat data",
                        color: .green
                    ) {
                        showingExport = true
                        dismiss()
                    }
                }
                
                Section("Models & AI") {
                    NavigationMenuItem(
                        icon: "brain",
                        title: "Model Management",
                        subtitle: "Download and manage AI models",
                        color: .purple
                    ) {
                        showingModelDownload = true
                        dismiss()
                    }
                    
                    NavigationMenuItem(
                        icon: "cpu",
                        title: "Device Performance",
                        subtitle: "Monitor device capabilities and optimization",
                        color: .orange
                    ) {
                        showingDevicePerformance = true
                        dismiss()
                    }
                }
                
                Section("Settings & Configuration") {
                    NavigationMenuItem(
                        icon: "gearshape",
                        title: "Settings",
                        subtitle: "App preferences and model parameters",
                        color: .gray
                    ) {
                        showingSettings = true
                        dismiss()
                    }
                }
                
                Section("Quick Actions") {
                    NavigationMenuItem(
                        icon: "plus.bubble",
                        title: "New Conversation",
                        subtitle: "Start a fresh chat",
                        color: .blue
                    ) {
                        createNewConversation()
                        dismiss()
                    }
                    
                    NavigationMenuItem(
                        icon: "trash",
                        title: "Clear Cache",
                        subtitle: "Free up storage space",
                        color: .red
                    ) {
                        // TODO: Implement cache clearing
                        dismiss()
                    }
                }
                
                Section("Information") {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                            .font(.title2)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("LLM Test App")
                                .font(.headline)
                            Text("Version 1.0.0")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Navigation")
            .navigationBarTitleDisplayMode(.large)
            .navigationBarBackButtonHidden()
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    private func createNewConversation() {
        let _ = chatManager.startNewConversation(title: "New Chat")
        // The new conversation is now available in the conversation list
    }
}

struct NavigationMenuItem: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title2)
                    .frame(width: 24, height: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationMenuView(
        showingModelDownload: .constant(false),
        showingConversationList: .constant(false),
        showingDevicePerformance: .constant(false),
        showingExport: .constant(false),
        showingSettings: .constant(false)
    )
}
