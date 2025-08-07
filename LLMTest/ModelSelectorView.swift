//
//  ModelSelectorView.swift
//  LLMTest
//
//  Created by Uttam Kumar Panasala on 8/6/25.
//

import SwiftUI

struct ModelSelectorView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var modelManager = ModelManager.shared
    @StateObject private var chatManager = ChatManager.shared
    @State private var selectedModel: ModelInfo?
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Current Model Status
                if chatManager.isModelLoaded {
                    VStack(spacing: 8) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Current Model")
                                .font(.headline)
                            Spacer()
                        }
                        
                        HStack {
                            Text(getCurrentModelDisplayName())
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    .padding(.top)
                }
                
                // Available Models List
                List {
                    Section("Available Models") {
                        ForEach(modelManager.availableModels, id: \.id) { model in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(model.name)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    
                                    Spacer()
                                    
                                    if modelManager.isModelDownloaded(model) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                    }
                                }
                                
                                Text(model.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                HStack {
                                    Text(formatFileSize(model.fileSize))
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    
                                    Spacer()
                                    
                                    Text("RAM: \(formatFileSize(model.requiredRAM))")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                            .onTapGesture {
                                selectedModel = model
                            }
                        }
                    }
                    
                    if !modelManager.downloadedModels.isEmpty {
                        Section("Downloaded Models") {
                            ForEach(modelManager.downloadedModels, id: \.id) { model in
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(model.name)
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                        
                                        Spacer()
                                        
                                        if modelManager.isModelDownloaded(model) {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.green)
                                        }
                                    }
                                    
                                    Text(model.description)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    HStack {
                                        Text(formatFileSize(model.fileSize))
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                        
                                        Spacer()
                                        
                                        Text("RAM: \(formatFileSize(model.requiredRAM))")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding(.vertical, 4)
                                .onTapGesture {
                                    selectedModel = model
                                }
                            }
                        }
                    }
                }
                
                // Action Buttons
                VStack(spacing: 12) {
                    if let error = errorMessage {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                            .multilineTextAlignment(.center)
                    }
                    
                    if let selected = selectedModel {
                        if modelManager.isModelDownloaded(selected) {
                            Button(action: { loadSelectedModel() }) {
                                HStack {
                                    if isLoading {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                    }
                                    Text(isLoading ? "Loading Model..." : "Load \(selected.name)")
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                            }
                            .disabled(isLoading)
                        } else {
                            Button(action: { downloadSelectedModel() }) {
                                HStack {
                                    if isLoading {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                    }
                                    Text(isLoading ? "Downloading..." : "Download \(selected.name)")
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                            }
                            .disabled(isLoading)
                        }
                    }
                    
                    Button("Manage Models") {
                        dismiss()
                        // This would typically trigger showing the ModelDownloadView
                    }
                    .foregroundColor(.blue)
                }
                .padding()
            }
            .navigationTitle("Select Model")
            .navigationBarTitleDisplayMode(.large)
            .navigationBarBackButtonHidden()
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            // Set currently loaded model as selected if available
            if chatManager.isModelLoaded {
                let currentModelInfo = chatManager.getModelInfo()
                if let modelPath = currentModelInfo.modelPath {
                    let modelFileName = URL(fileURLWithPath: modelPath).lastPathComponent
                    selectedModel = modelManager.availableModels.first { model in
                        modelFileName.contains(model.id)
                    }
                }
            }
        }
    }
    
    private func loadSelectedModel() {
        guard let model = selectedModel else { return }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let modelPath = modelManager.getModelFileURL(for: model).path
                try await chatManager.loadModel(at: modelPath)
                await MainActor.run {
                    isLoading = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "Failed to load model: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func downloadSelectedModel() {
        guard let model = selectedModel else { return }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                try await modelManager.downloadModel(model)
                await MainActor.run {
                    isLoading = false
                    // After download, automatically load the model
                    loadSelectedModel()
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "Failed to download model: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    private func getCurrentModelDisplayName() -> String {
        if chatManager.isModelLoaded {
            let modelInfo = chatManager.getModelInfo()
            if let modelPath = modelInfo.modelPath {
                let modelName = URL(fileURLWithPath: modelPath).lastPathComponent
                return modelName.replacingOccurrences(of: ".gguf", with: "")
            } else {
                return "Unknown Model"
            }
        } else {
            return "No Model"
        }
    }
}



#Preview {
    ModelSelectorView()
}
