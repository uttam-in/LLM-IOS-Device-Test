//
//  QuickSettingsView.swift
//  LLMTest
//
//  Created by Uttam Kumar Panasala on 8/6/25.
//

import SwiftUI

struct QuickSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var settingsManager = SettingsManager.shared
    @StateObject private var chatManager = ChatManager.shared
    
    var body: some View {
        NavigationView {
            Form {
                Section("Model Parameters") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Temperature")
                            Spacer()
                            Text(String(format: "%.2f", settingsManager.temperature))
                                .foregroundColor(.secondary)
                        }
                        Slider(value: .init(
                            get: { settingsManager.temperature },
                            set: { newValue in
                                Task {
                                    await settingsManager.updateTemperature(newValue)
                                }
                            }
                        ), in: 0.1...2.0, step: 0.1)
                        Text("Controls randomness: lower = more focused, higher = more creative")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Max Tokens")
                            Spacer()
                            Text("\(settingsManager.maxTokens)")
                                .foregroundColor(.secondary)
                        }
                        Slider(value: .init(
                            get: { Double(settingsManager.maxTokens) },
                            set: { newValue in
                                Task {
                                    await settingsManager.updateMaxTokens(Int(newValue))
                                }
                            }
                        ), in: 256...4096, step: 256)
                        Text("Maximum length of AI responses")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("Current Model") {
                    HStack {
                        Image(systemName: "brain")
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            if chatManager.isModelLoaded {
                                let modelInfo = chatManager.getModelInfo()
                                Text(getModelDisplayName(from: modelInfo))
                                    .font(.headline)
                                Text("Model loaded and ready")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            } else {
                                Text("No Model Loaded")
                                    .font(.headline)
                                Text("Tap to select a model")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                        }
                        
                        Spacer()
                        
                        if chatManager.isModelLoaded {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        } else {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundColor(.orange)
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                Section("Quick Actions") {
                    Button(action: { 
                        dismiss()
                        createNewConversation()
                    }) {
                        HStack {
                            Image(systemName: "plus.bubble")
                                .foregroundColor(.blue)
                            Text("New Conversation")
                            Spacer()
                        }
                    }
                    
                    Button(action: {
                        Task {
                            await settingsManager.resetToDefaults()
                        }
                    }) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                                .foregroundColor(.orange)
                            Text("Reset to Defaults")
                            Spacer()
                        }
                    }
                    
                    if chatManager.isModelLoaded {
                        Button(action: {
                            unloadModel()
                        }) {
                            HStack {
                                Image(systemName: "xmark.circle")
                                    .foregroundColor(.red)
                                Text("Unload Model")
                                Spacer()
                            }
                        }
                    }
                }
                
                Section("App Info") {
                    HStack {
                        Text("Total Conversations")
                        Spacer()
                        Text("\(chatManager.getTotalConversationCount())")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Total Messages")
                        Spacer()
                        Text("\(chatManager.getTotalMessageCount())")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Quick Settings")
            .navigationBarTitleDisplayMode(.large)
            .navigationBarBackButtonHidden()
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Full Settings") {
                        dismiss()
                        // This would typically show the full SettingsView
                    }
                    .foregroundColor(.blue)
                }
                
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
        // In a real app, you might want to navigate to this new conversation
    }
    
    private func resetToDefaults() {
        Task {
            await settingsManager.resetToDefaults()
        }
    }
    
    private func unloadModel() {
        Task {
            await chatManager.unloadModel()
        }
    }
    
    private func getModelDisplayName(from modelInfo: LlamaModelInfo) -> String {
        if let modelPath = modelInfo.modelPath {
            let modelName = URL(fileURLWithPath: modelPath).lastPathComponent
            return modelName.replacingOccurrences(of: ".gguf", with: "")
        } else {
            return "Unknown Model"
        }
    }
}

#Preview {
    QuickSettingsView()
}
