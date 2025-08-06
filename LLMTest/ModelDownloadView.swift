//
//  ModelDownloadView.swift
//  LLMTest
//
//  Created by Uttam Kumar Panasala on 8/6/25.
//

import SwiftUI

struct ModelDownloadView: View {
    @StateObject private var modelManager = ModelManager.shared
    @State private var showingStorageInfo = false
    @State private var selectedModel: ModelInfo?
    @State private var lastFailedModel: ModelInfo?
    
    var body: some View {
        NavigationView {
            List {
                // Storage Info Section
                Section("Storage") {
                    StorageInfoView()
                        .onTapGesture {
                            showingStorageInfo = true
                        }
                }
                
                // Available Models Section
                Section("Available Models") {
                    if modelManager.isLoading {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Loading models...")
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 8)
                    } else if modelManager.availableModels.isEmpty {
                        Text("No models available")
                            .foregroundColor(.secondary)
                            .italic()
                    } else {
                        ForEach(modelManager.availableModels, id: \.id) { model in
                            ModelRowView(model: model)
                        }
                    }
                }
                
                // Active Downloads Section
                if !modelManager.activeDownloads.isEmpty {
                    Section("Active Downloads") {
                        ForEach(modelManager.activeDownloads) { downloadItem in
                            DownloadProgressView(downloadItem: downloadItem)
                        }
                    }
                }
                
                // Downloaded Models Section
                if !modelManager.downloadedModels.isEmpty {
                    Section("Downloaded Models") {
                        ForEach(modelManager.downloadedModels, id: \.id) { model in
                            DownloadedModelRowView(model: model)
                        }
                    }
                }
            }
            .navigationTitle("Model Manager")
            .refreshable {
                await modelManager.refreshAvailableModels()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Clear Cache") {
                        modelManager.clearCache()
                    }
                    .font(.caption)
                }
            }
            .sheet(isPresented: $showingStorageInfo) {
                StorageDetailView()
            }
            .alert("Error", isPresented: .constant(modelManager.errorMessage != nil)) {
                Button("Retry") {
                    retryLastFailedOperation()
                }
                Button("OK") {
                    modelManager.errorMessage = nil
                }
            } message: {
                Text(modelManager.errorMessage ?? "")
            }
        }
    }
    
    private func retryLastFailedOperation() {
        guard let failedModel = lastFailedModel else {
            modelManager.errorMessage = nil
            return
        }
        
        Task {
            do {
                try await modelManager.downloadModel(failedModel)
                await MainActor.run {
                    modelManager.errorMessage = nil
                    lastFailedModel = nil
                }
            } catch {
                await MainActor.run {
                    modelManager.errorMessage = "Retry failed: \(error.localizedDescription)"
                }
            }
        }
    }
}

// MARK: - Storage Info View

struct StorageInfoView: View {
    @StateObject private var modelManager = ModelManager.shared
    
    var body: some View {
        let storageInfo = modelManager.getStorageInfo()
        let usedPercentage = storageInfo.total > 0 ? Double(storageInfo.used) / Double(storageInfo.total) : 0.0
        
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "internaldrive")
                        .foregroundColor(.blue)
                    Text("Storage")
                        .font(.headline)
                }
                
                HStack {
                    Text("Used: \(ByteCountFormatter.string(fromByteCount: storageInfo.used, countStyle: .binary))")
                    Spacer()
                    Text("Available: \(ByteCountFormatter.string(fromByteCount: storageInfo.available, countStyle: .binary))")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack {
                CircularProgressView(progress: usedPercentage)
                    .frame(width: 40, height: 40)
                Text("\(Int(usedPercentage * 100))%")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Model Row View

struct ModelRowView: View {
    let model: ModelInfo
    @StateObject private var modelManager = ModelManager.shared
    @State private var showingDownloadConfirmation = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.name)
                        .font(.headline)
                    
                    Text(model.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                downloadButton
            }
            
            // Model details
            HStack {
                Label("\(ByteCountFormatter.string(fromByteCount: model.fileSize, countStyle: .binary))", systemImage: "doc")
                Spacer()
                Label("v\(model.version)", systemImage: "tag")
                Spacer()
                Label("\(ByteCountFormatter.string(fromByteCount: model.requiredRAM, countStyle: .binary)) RAM", systemImage: "memorychip")
            }
            .font(.caption2)
            .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
        .confirmationDialog("Download Model", isPresented: $showingDownloadConfirmation) {
            Button("Download") {
                Task {
                    do {
                        try await modelManager.downloadModel(model)
                    } catch {
                        modelManager.errorMessage = error.localizedDescription
                    }
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Download \(model.name) (\(ByteCountFormatter.string(fromByteCount: model.fileSize, countStyle: .binary)))?")
        }
    }
    
    @ViewBuilder
    private var downloadButton: some View {
        if modelManager.isModelDownloaded(model) {
            Button(action: {}) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }
            .disabled(true)
        } else if modelManager.isModelDownloading(model) {
            Button("Cancel") {
                modelManager.cancelDownload(for: model)
            }
            .font(.caption)
            .foregroundColor(.red)
        } else {
            Button("Download") {
                showingDownloadConfirmation = true
            }
            .font(.caption)
            .buttonStyle(.bordered)
        }
    }
}

// MARK: - Download Progress View

struct DownloadProgressView: View {
    @ObservedObject var downloadItem: ModelDownloadItem
    @StateObject private var modelManager = ModelManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(downloadItem.modelInfo.name)
                    .font(.headline)
                
                Spacer()
                
                Button("Cancel") {
                    modelManager.cancelDownload(for: downloadItem.modelInfo)
                }
                .font(.caption)
                .foregroundColor(.red)
            }
            
            // Progress bar
            ProgressView(value: downloadItem.state.progress)
                .progressViewStyle(LinearProgressViewStyle())
            
            // Download details
            HStack {
                Text(downloadStateText)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if downloadItem.downloadSpeed > 0 {
                    Text("\(formatSpeed(downloadItem.downloadSpeed))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if downloadItem.estimatedTimeRemaining > 0 {
                Text("Time remaining: \(formatTimeRemaining(downloadItem.estimatedTimeRemaining))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
    
    private var downloadStateText: String {
        switch downloadItem.state {
        case .downloading:
            return "\(ByteCountFormatter.string(fromByteCount: downloadItem.downloadedBytes, countStyle: .binary)) of \(ByteCountFormatter.string(fromByteCount: downloadItem.totalBytes, countStyle: .binary))"
        case .paused:
            return "Paused - \(ByteCountFormatter.string(fromByteCount: downloadItem.downloadedBytes, countStyle: .binary)) of \(ByteCountFormatter.string(fromByteCount: downloadItem.totalBytes, countStyle: .binary))"
        case .verifying:
            return "Verifying download..."
        case .completed:
            return "Download completed"
        case .failed(let error):
            return "Failed: \(error)"
        default:
            return "Preparing download..."
        }
    }
    
    private func formatSpeed(_ bytesPerSecond: Double) -> String {
        if bytesPerSecond < 1024 {
            return String(format: "%.0f B/s", bytesPerSecond)
        } else if bytesPerSecond < 1024 * 1024 {
            return String(format: "%.1f KB/s", bytesPerSecond / 1024)
        } else {
            return String(format: "%.1f MB/s", bytesPerSecond / (1024 * 1024))
        }
    }
    
    private func formatTimeRemaining(_ seconds: TimeInterval) -> String {
        if seconds < 60 {
            return String(format: "%.0fs", seconds)
        } else if seconds < 3600 {
            return String(format: "%.0fm", seconds / 60)
        } else {
            return String(format: "%.1fh", seconds / 3600)
        }
    }
}

// MARK: - Downloaded Model Row View

struct DownloadedModelRowView: View {
    let model: ModelInfo
    @StateObject private var modelManager = ModelManager.shared
    @State private var showingDeleteConfirmation = false
    @State private var showingReinstallConfirmation = false
    @State private var showingModelActions = false
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(model.name)
                    .font(.headline)
                
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                    Text("Ready to use")
                        .font(.caption)
                        .foregroundColor(.green)
                }
                
                Text("Size: \(ByteCountFormatter.string(fromByteCount: model.fileSize, countStyle: .binary))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: {
                showingModelActions = true
            }) {
                Image(systemName: "ellipsis.circle")
                    .font(.title2)
                    .foregroundColor(.blue)
            }
        }
        .padding(.vertical, 4)
        .confirmationDialog("Model Actions", isPresented: $showingModelActions) {
            Button("Reinstall") {
                showingReinstallConfirmation = true
            }
            Button("Delete", role: .destructive) {
                showingDeleteConfirmation = true
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Choose an action for \(model.name)")
        }
        .confirmationDialog("Delete Model", isPresented: $showingDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                do {
                    try modelManager.deleteModel(model)
                } catch {
                    modelManager.errorMessage = error.localizedDescription
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete \(model.name)? This will free up \(ByteCountFormatter.string(fromByteCount: model.fileSize, countStyle: .binary)) of storage.")
        }
        .confirmationDialog("Reinstall Model", isPresented: $showingReinstallConfirmation) {
            Button("Reinstall") {
                reinstallModel()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will delete and re-download \(model.name). The model will be unavailable during reinstallation.")
        }
    }
    
    private func reinstallModel() {
        Task {
            do {
                // First delete the existing model
                try modelManager.deleteModel(model)
                
                // Then download it again
                try await modelManager.downloadModel(model)
            } catch {
                await MainActor.run {
                    modelManager.errorMessage = "Reinstallation failed: \(error.localizedDescription)"
                }
            }
        }
    }
}

// MARK: - Circular Progress View

struct CircularProgressView: View {
    let progress: Double
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.3), lineWidth: 3)
            
            Circle()
                .trim(from: 0, to: progress)
                .stroke(Color.blue, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut, value: progress)
        }
    }
}

// MARK: - Storage Detail View

struct StorageDetailView: View {
    @StateObject private var modelManager = ModelManager.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                let storageInfo = modelManager.getStorageInfo()
                
                Section("Storage Overview") {
                    StorageRowView(title: "Used by Models", 
                                 value: storageInfo.used, 
                                 color: .blue)
                    
                    StorageRowView(title: "Available Space", 
                                 value: storageInfo.available, 
                                 color: .green)
                    
                    StorageRowView(title: "Total Space", 
                                 value: storageInfo.total, 
                                 color: .gray)
                }
                
                Section("Downloaded Models") {
                    if modelManager.downloadedModels.isEmpty {
                        Text("No models downloaded")
                            .foregroundColor(.secondary)
                            .italic()
                    } else {
                        ForEach(modelManager.downloadedModels, id: \.id) { model in
                            HStack {
                                Text(model.name)
                                Spacer()
                                Text(ByteCountFormatter.string(fromByteCount: model.fileSize, countStyle: .binary))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Storage Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct StorageRowView: View {
    let title: String
    let value: Int64
    let color: Color
    
    var body: some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)
            
            Text(title)
            
            Spacer()
            
            Text(ByteCountFormatter.string(fromByteCount: value, countStyle: .binary))
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    ModelDownloadView()
}