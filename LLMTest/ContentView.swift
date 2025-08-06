//
//  ContentView.swift
//  LLMTest
//
//  Created by Uttam Kumar Panasala on 8/6/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var settingsManager = SettingsManager.shared
    @State private var showingSettings = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "message.circle.fill")
                    .imageScale(.large)
                    .foregroundStyle(.tint)
                    .font(.system(size: 60))
                
                Text("LLM Chat")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Offline AI Chat with Gemma 2B")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                VStack(spacing: 12) {
                    Button("Start Chatting") {
                        // TODO: Navigate to chat view
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    
                    Button("Settings") {
                        showingSettings = true
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
                
                Spacer()
                
                // Display current settings
                VStack(alignment: .leading, spacing: 8) {
                    Text("Current Settings:")
                        .font(.headline)
                    
                    HStack {
                        Text("Temperature:")
                        Spacer()
                        Text(String(format: "%.2f", settingsManager.temperature))
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Max Tokens:")
                        Spacer()
                        Text("\(settingsManager.maxTokens)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Theme:")
                        Spacer()
                        Text(settingsManager.selectedTheme.displayName)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Text Size:")
                        Spacer()
                        Text(settingsManager.textSize.displayName)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(.systemGroupedBackground))
                .cornerRadius(12)
            }
            .padding()
            .navigationTitle("LLM Test")
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
    }
}

#Preview {
    ContentView()
}
