//
//  FirstTimeSetupView.swift
//  LLMTest
//
//  Created by Uttam Kumar Panasala on 8/6/25.
//

import SwiftUI

struct FirstTimeSetupView: View {
    @StateObject private var modelManager = ModelManager.shared
    @State private var setupPhase: SetupPhase = .welcome
    @State private var isDownloading = false
    @State private var downloadError: String?
    @State private var showingSkipConfirmation = false
    
    enum SetupPhase {
        case welcome
        case downloading
        case completed
        case error
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Spacer()
                
                // App Icon and Title
                VStack(spacing: 16) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 80))
                        .foregroundColor(.blue)
                    
                    Text("LLM Chat")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("AI-powered conversations on your device")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                Spacer()
                
                // Setup Content
                setupContent
                
                Spacer()
                
                // Action Buttons
                actionButtons
            }
            .padding(.horizontal, 32)
            .navigationBarHidden(true)
        }
        .onAppear {
            checkIfSetupNeeded()
        }
    }
    
    @ViewBuilder
    private var setupContent: some View {
        switch setupPhase {
        case .welcome:
            welcomeContent
        case .downloading:
            downloadingContent
        case .completed:
            completedContent
        case .error:
            errorContent
        }
    }
    
    private var welcomeContent: some View {
        VStack(spacing: 16) {
            Text("Welcome to LLM Chat!")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("To get started, we need to download the Qwen3 0.6B language model. This will enable AI conversations directly on your device.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "shield.fill")
                        .foregroundColor(.green)
                    Text("100% Private - All processing happens on your device")
                }
                
                HStack {
                    Image(systemName: "wifi.slash")
                        .foregroundColor(.blue)
                    Text("Works offline - No internet required after download")
                }
                
                HStack {
                    Image(systemName: "speedometer")
                        .foregroundColor(.orange)
                    Text("Fast responses - Optimized for mobile devices")
                }
            }
            .font(.subheadline)
            .padding(.top, 8)
        }
    }
    
    private var downloadingContent: some View {
        VStack(spacing: 16) {
            Text("Downloading Qwen3 0.6B Model")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Please wait while we download the AI model. This may take a few minutes depending on your internet connection.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            if let downloadItem = modelManager.activeDownloads.first {
                VStack(spacing: 12) {
                    ProgressView(value: downloadItem.state.progress)
                        .progressViewStyle(LinearProgressViewStyle())
                        .scaleEffect(y: 2)
                    
                    HStack {
                        Text("\(Int(downloadItem.state.progress * 100))%")
                            .font(.headline)
                        
                        Spacer()
                        
                        Text(ByteCountFormatter.string(fromByteCount: downloadItem.downloadedBytes, countStyle: .binary))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("of")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(ByteCountFormatter.string(fromByteCount: downloadItem.totalBytes, countStyle: .binary))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if downloadItem.downloadSpeed > 0 {
                        HStack {
                            Text("Speed: \(formatSpeed(downloadItem.downloadSpeed))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Text("ETA: \(formatTimeRemaining(downloadItem.estimatedTimeRemaining))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.top, 8)
            } else {
                ProgressView("Preparing download...")
                    .padding(.top, 8)
            }
        }
    }
    
    private var completedContent: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)
            
            Text("Setup Complete!")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("The Gemma 2B model has been successfully downloaded and is ready to use. You can now start having AI-powered conversations!")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    private var errorContent: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundColor(.red)
            
            Text("Download Failed")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(downloadError ?? "An error occurred while downloading the model. Please check your internet connection and try again.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    @ViewBuilder
    private var actionButtons: some View {
        switch setupPhase {
        case .welcome:
            VStack(spacing: 12) {
                Button(action: startDownload) {
                    HStack {
                        Image(systemName: "arrow.down.circle.fill")
                        Text("Download Model")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
                }
                .disabled(isDownloading)
                
                Button("Skip for now") {
                    showingSkipConfirmation = true
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
            }
            
        case .downloading:
            Button("Cancel Download") {
                cancelDownload()
            }
            .font(.subheadline)
            .foregroundColor(.red)
            
        case .completed:
            Button(action: completeSetup) {
                Text("Get Started")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .cornerRadius(12)
            }
            
        case .error:
            VStack(spacing: 12) {
                Button(action: startDownload) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Try Again")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
                }
                
                Button("Skip for now") {
                    showingSkipConfirmation = true
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func checkIfSetupNeeded() {
        // Check if any models are already downloaded
        if !modelManager.downloadedModels.isEmpty {
            setupPhase = .completed
        }
    }
    
    private func startDownload() {
        guard let qwenModel = modelManager.availableModels.first(where: { $0.id == "qwen3-0.6b-gguf" }) else {
            downloadError = "Qwen3 0.6B model not found in available models"
            setupPhase = .error
            return
        }
        
        isDownloading = true
        setupPhase = .downloading
        
        Task {
            do {
                try await modelManager.downloadModel(qwenModel)
                await MainActor.run {
                    setupPhase = .completed
                    isDownloading = false
                }
            } catch {
                await MainActor.run {
                    downloadError = error.localizedDescription
                    setupPhase = .error
                    isDownloading = false
                }
            }
        }
    }
    
    private func cancelDownload() {
        if let qwenModel = modelManager.availableModels.first(where: { $0.id == "qwen3-0.6b-gguf" }) {
            modelManager.cancelDownload(for: qwenModel)
        }
        isDownloading = false
        setupPhase = .welcome
    }
    
    private func completeSetup() {
        UserDefaults.standard.set(true, forKey: "hasCompletedFirstTimeSetup")
        NotificationCenter.default.post(name: .init("FirstTimeSetupCompleted"), object: nil)
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

// MARK: - Skip Confirmation Extension

extension FirstTimeSetupView {
    private var skipConfirmationDialog: some View {
        EmptyView()
            .confirmationDialog("Skip Model Download", isPresented: $showingSkipConfirmation) {
                Button("Skip", role: .destructive) {
                    UserDefaults.standard.set(true, forKey: "hasCompletedFirstTimeSetup")
                    NotificationCenter.default.post(name: .init("FirstTimeSetupCompleted"), object: nil)
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("You can download the model later from Settings, but you won't be able to use AI features until then.")
            }
    }
}

#Preview {
    FirstTimeSetupView()
}
