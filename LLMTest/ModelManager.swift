//
//  ModelManager.swift
//  LLMTest
//
//  Created by Uttam Kumar Panasala on 8/6/25.
//

import Foundation
import Combine
import CryptoKit

// MARK: - Model Information

struct ModelInfo {
    let id: String
    let name: String
    let description: String
    let downloadURL: URL
    let fileSize: Int64
    let checksum: String
    let checksumType: ChecksumType
    let version: String
    let requiredRAM: Int64 // in bytes
    let supportedPlatforms: [String]
}

enum ChecksumType: String, CaseIterable {
    case sha256 = "sha256"
    case md5 = "md5"
}

// MARK: - Download State

enum DownloadState: Equatable {
    case notStarted
    case downloading(progress: Double)
    case paused(progress: Double)
    case completed
    case failed(error: String)
    case verifying
    case verified
    case cancelled
    
    var isActive: Bool {
        switch self {
        case .downloading, .verifying:
            return true
        default:
            return false
        }
    }
    
    var progress: Double {
        switch self {
        case .downloading(let progress), .paused(let progress):
            return progress
        case .completed, .verified:
            return 1.0
        default:
            return 0.0
        }
    }
}

// MARK: - Model Download Item

class ModelDownloadItem: ObservableObject, Identifiable {
    let id = UUID()
    let modelInfo: ModelInfo
    
    @Published var state: DownloadState = .notStarted
    @Published var downloadedBytes: Int64 = 0
    @Published var totalBytes: Int64 = 0
    @Published var downloadSpeed: Double = 0.0 // bytes per second
    @Published var estimatedTimeRemaining: TimeInterval = 0.0
    
    private var downloadTask: URLSessionDownloadTask?
    private var startTime: Date?
    private var lastUpdateTime: Date?
    private var lastDownloadedBytes: Int64 = 0
    
    init(modelInfo: ModelInfo) {
        self.modelInfo = modelInfo
        self.totalBytes = modelInfo.fileSize
    }
    
    func updateProgress(downloadedBytes: Int64, totalBytes: Int64) {
        let now = Date()
        
        self.downloadedBytes = downloadedBytes
        self.totalBytes = totalBytes
        
        let progress = totalBytes > 0 ? Double(downloadedBytes) / Double(totalBytes) : 0.0
        
        // Calculate download speed
        if let lastUpdate = lastUpdateTime {
            let timeInterval = now.timeIntervalSince(lastUpdate)
            if timeInterval > 0 {
                let bytesDownloaded = downloadedBytes - lastDownloadedBytes
                downloadSpeed = Double(bytesDownloaded) / timeInterval
                
                // Estimate time remaining
                if downloadSpeed > 0 {
                    let remainingBytes = totalBytes - downloadedBytes
                    estimatedTimeRemaining = Double(remainingBytes) / downloadSpeed
                }
            }
        }
        
        lastUpdateTime = now
        lastDownloadedBytes = downloadedBytes
        
        if case .downloading = state {
            state = .downloading(progress: progress)
        }
    }
    
    func setDownloadTask(_ task: URLSessionDownloadTask) {
        self.downloadTask = task
        self.startTime = Date()
        self.lastUpdateTime = Date()
    }
    
    func cancel() {
        downloadTask?.cancel()
        state = .cancelled
    }
    
    func pause() {
        downloadTask?.suspend()
        if case .downloading(let progress) = state {
            state = .paused(progress: progress)
        }
    }
    
    func resume() {
        downloadTask?.resume()
        if case .paused(let progress) = state {
            state = .downloading(progress: progress)
        }
    }
}

// MARK: - Model Manager Errors

enum ModelManagerError: LocalizedError {
    case networkError(Error)
    case invalidURL
    case insufficientStorage(required: Int64, available: Int64)
    case checksumMismatch(expected: String, actual: String)
    case fileNotFound
    case invalidModel
    case downloadCancelled
    case downloadFailed(String)
    case verificationFailed(String)
    case unsupportedPlatform
    case modelAlreadyExists
    case corruptedDownload
    
    var errorDescription: String? {
        switch self {
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidURL:
            return "Invalid download URL"
        case .insufficientStorage(let required, let available):
            return "Insufficient storage space. Required: \(ByteCountFormatter.string(fromByteCount: required, countStyle: .binary)), Available: \(ByteCountFormatter.string(fromByteCount: available, countStyle: .binary))"
        case .checksumMismatch(let expected, let actual):
            return "Checksum verification failed. Expected: \(expected), Got: \(actual)"
        case .fileNotFound:
            return "Model file not found"
        case .invalidModel:
            return "Invalid model file"
        case .downloadCancelled:
            return "Download was cancelled"
        case .downloadFailed(let reason):
            return "Download failed: \(reason)"
        case .verificationFailed(let reason):
            return "Model verification failed: \(reason)"
        case .unsupportedPlatform:
            return "Model not supported on this platform"
        case .modelAlreadyExists:
            return "Model already exists"
        case .corruptedDownload:
            return "Downloaded file is corrupted"
        }
    }
}

// MARK: - Model Manager

@MainActor
class ModelManager: NSObject, ObservableObject {
    static let shared = ModelManager()
    
    // MARK: - Published Properties
    @Published var availableModels: [ModelInfo] = []
    @Published var downloadedModels: [ModelInfo] = []
    @Published var activeDownloads: [ModelDownloadItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    private let urlSession: URLSession
    private let fileManager = FileManager.default
    private var cancellables = Set<AnyCancellable>()
    
    // Storage paths
    private let modelsDirectory: URL
    private let tempDirectory: URL
    
    // MARK: - Initialization
    
    private override init() {
        // Create custom URL session for downloads
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30.0
        config.timeoutIntervalForResource = 3600.0 // 1 hour for large downloads
        config.allowsCellularAccess = false // WiFi only by default
        
        self.urlSession = URLSession(configuration: config)
        
        // Set up directories
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.modelsDirectory = documentsPath.appendingPathComponent("Models")
        self.tempDirectory = documentsPath.appendingPathComponent("Temp")
        
        super.init()
        
        setupDirectories()
        loadAvailableModels()
        loadDownloadedModels()
    }
    
    deinit {
        // Cancel all active downloads
        Task { @MainActor in
            activeDownloads.forEach { $0.cancel() }
        }
    }
    
    // MARK: - Setup
    
    private func setupDirectories() {
        do {
            try fileManager.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)
            try fileManager.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        } catch {
            print("Error creating directories: \(error)")
        }
    }
    
    private func loadAvailableModels() {
        // For now, we'll define Gemma 2B model information
        // In a real app, this might come from a server API
        let gemma2B = ModelInfo(
            id: "gemma-2b-it-gguf",
            name: "Gemma 2B Instruct",
            description: "Google's Gemma 2B instruction-tuned model in GGUF format. Optimized for chat and instruction-following tasks.",
            downloadURL: URL(string: "https://huggingface.co/microsoft/DialoGPT-medium/resolve/main/pytorch_model.bin")!, // Placeholder URL
            fileSize: 1_600_000_000, // ~1.6GB
            checksum: "abcd1234567890abcdef1234567890abcdef1234567890abcdef1234567890ab", // Mock checksum
            checksumType: .sha256,
            version: "1.0.0",
            requiredRAM: 2_147_483_648, // 2GB
            supportedPlatforms: ["iOS", "macOS"]
        )
        
        availableModels = [gemma2B]
    }
    
    private func loadDownloadedModels() {
        do {
            let files = try fileManager.contentsOfDirectory(at: modelsDirectory, includingPropertiesForKeys: [.fileSizeKey])
            
            downloadedModels = files.compactMap { url in
                guard url.pathExtension.lowercased() == "gguf" else { return nil }
                
                // Try to match with available models
                let fileName = url.deletingPathExtension().lastPathComponent
                return availableModels.first { $0.id.contains(fileName) || fileName.contains($0.id) }
            }
        } catch {
            print("Error loading downloaded models: \(error)")
        }
    }
    
    // MARK: - Storage Management
    
    func getAvailableStorageSpace() throws -> Int64 {
        let resourceValues = try modelsDirectory.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        return resourceValues.volumeAvailableCapacityForImportantUsage ?? 0
    }
    
    func validateStorageSpace(for modelInfo: ModelInfo) throws {
        let availableSpace = try getAvailableStorageSpace()
        let requiredSpace = modelInfo.fileSize + (100 * 1024 * 1024) // Add 100MB buffer
        
        if availableSpace < requiredSpace {
            throw ModelManagerError.insufficientStorage(required: requiredSpace, available: availableSpace)
        }
    }
    
    func getModelFileURL(for modelInfo: ModelInfo) -> URL {
        return modelsDirectory.appendingPathComponent("\(modelInfo.id).gguf")
    }
    
    func getTempFileURL(for modelInfo: ModelInfo) -> URL {
        return tempDirectory.appendingPathComponent("\(modelInfo.id).gguf.tmp")
    }
    
    // MARK: - Model Status
    
    func isModelDownloaded(_ modelInfo: ModelInfo) -> Bool {
        let fileURL = getModelFileURL(for: modelInfo)
        return fileManager.fileExists(atPath: fileURL.path)
    }
    
    func isModelDownloading(_ modelInfo: ModelInfo) -> Bool {
        return activeDownloads.contains { $0.modelInfo.id == modelInfo.id }
    }
    
    func getDownloadItem(for modelInfo: ModelInfo) -> ModelDownloadItem? {
        return activeDownloads.first { $0.modelInfo.id == modelInfo.id }
    }
    
    // MARK: - Download Management
    
    func downloadModel(_ modelInfo: ModelInfo) async throws {
        // Validate preconditions
        guard !isModelDownloaded(modelInfo) else {
            throw ModelManagerError.modelAlreadyExists
        }
        
        guard !isModelDownloading(modelInfo) else {
            return // Already downloading
        }
        
        // Check platform support
        guard modelInfo.supportedPlatforms.contains("iOS") else {
            throw ModelManagerError.unsupportedPlatform
        }
        
        // Validate storage space
        try validateStorageSpace(for: modelInfo)
        
        // Create download item
        let downloadItem = ModelDownloadItem(modelInfo: modelInfo)
        activeDownloads.append(downloadItem)
        
        do {
            try await performDownload(downloadItem)
        } catch {
            // Remove from active downloads on error
            activeDownloads.removeAll { $0.id == downloadItem.id }
            throw error
        }
    }
    
    private func performDownload(_ downloadItem: ModelDownloadItem) async throws {
        let modelInfo = downloadItem.modelInfo
        let tempFileURL = getTempFileURL(for: modelInfo)
        let finalFileURL = getModelFileURL(for: modelInfo)
        
        downloadItem.state = .downloading(progress: 0.0)
        
        // Create download task
        let downloadTask = urlSession.downloadTask(with: modelInfo.downloadURL) { [weak self, weak downloadItem] tempURL, response, error in
            Task { @MainActor in
                guard let self = self, let downloadItem = downloadItem else { return }
                
                if let error = error {
                    downloadItem.state = .failed(error: error.localizedDescription)
                    self.handleDownloadError(error, for: downloadItem)
                    return
                }
                
                guard let tempURL = tempURL else {
                    downloadItem.state = .failed(error: "No temporary file URL")
                    return
                }
                
                do {
                    // Move temporary file to final location
                    if self.fileManager.fileExists(atPath: tempFileURL.path) {
                        try self.fileManager.removeItem(at: tempFileURL)
                    }
                    try self.fileManager.moveItem(at: tempURL, to: tempFileURL)
                    
                    downloadItem.state = .verifying
                    
                    // Verify checksum
                    try await self.verifyModel(downloadItem, tempFileURL: tempFileURL, finalFileURL: finalFileURL)
                    
                } catch {
                    downloadItem.state = .failed(error: error.localizedDescription)
                    self.handleDownloadError(error, for: downloadItem)
                }
            }
        }
        
        // Set up progress tracking
        let _ = downloadTask.progress.observe(\.fractionCompleted) { [weak downloadItem] progress, _ in
            Task { @MainActor in
                downloadItem?.updateProgress(
                    downloadedBytes: Int64(progress.completedUnitCount),
                    totalBytes: Int64(progress.totalUnitCount)
                )
            }
        }
        
        downloadItem.setDownloadTask(downloadTask)
        downloadTask.resume()
        
        // Wait for completion
        return try await withCheckedThrowingContinuation { continuation in
            // Monitor download item state changes
            downloadItem.$state
                .sink { state in
                    switch state {
                    case .completed:
                        continuation.resume()
                    case .failed(let error):
                        continuation.resume(throwing: ModelManagerError.downloadFailed(error))
                    case .cancelled:
                        continuation.resume(throwing: ModelManagerError.downloadCancelled)
                    default:
                        break
                    }
                }
                .store(in: &cancellables)
        }
    }
    
    private func verifyModel(_ downloadItem: ModelDownloadItem, tempFileURL: URL, finalFileURL: URL) async throws {
        let modelInfo = downloadItem.modelInfo
        
        // Calculate checksum
        let calculatedChecksum = try await calculateChecksum(for: tempFileURL, type: modelInfo.checksumType)
        
        // Verify checksum
        guard calculatedChecksum.lowercased() == modelInfo.checksum.lowercased() else {
            // Clean up temp file
            try? fileManager.removeItem(at: tempFileURL)
            throw ModelManagerError.checksumMismatch(expected: modelInfo.checksum, actual: calculatedChecksum)
        }
        
        // Move to final location
        if fileManager.fileExists(atPath: finalFileURL.path) {
            try fileManager.removeItem(at: finalFileURL)
        }
        try fileManager.moveItem(at: tempFileURL, to: finalFileURL)
        
        // Update state
        downloadItem.state = .completed
        
        // Refresh downloaded models
        loadDownloadedModels()
        
        // Remove from active downloads
        activeDownloads.removeAll { $0.id == downloadItem.id }
    }
    
    private func calculateChecksum(for fileURL: URL, type: ChecksumType) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .background).async {
                do {
                    let data = try Data(contentsOf: fileURL)
                    let checksum: String
                    
                    switch type {
                    case .sha256:
                        let hash = SHA256.hash(data: data)
                        checksum = hash.compactMap { String(format: "%02x", $0) }.joined()
                    case .md5:
                        let hash = Insecure.MD5.hash(data: data)
                        checksum = hash.compactMap { String(format: "%02x", $0) }.joined()
                    }
                    
                    continuation.resume(returning: checksum)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func handleDownloadError(_ error: Error, for downloadItem: ModelDownloadItem) {
        print("Download error for \(downloadItem.modelInfo.name): \(error)")
        
        // Clean up temp files
        let tempFileURL = getTempFileURL(for: downloadItem.modelInfo)
        try? fileManager.removeItem(at: tempFileURL)
        
        // Remove from active downloads
        activeDownloads.removeAll { $0.id == downloadItem.id }
    }
    
    // MARK: - Model Management
    
    func cancelDownload(for modelInfo: ModelInfo) {
        guard let downloadItem = getDownloadItem(for: modelInfo) else { return }
        downloadItem.cancel()
        
        // Clean up temp files
        let tempFileURL = getTempFileURL(for: modelInfo)
        try? fileManager.removeItem(at: tempFileURL)
        
        activeDownloads.removeAll { $0.id == downloadItem.id }
    }
    
    func pauseDownload(for modelInfo: ModelInfo) {
        getDownloadItem(for: modelInfo)?.pause()
    }
    
    func resumeDownload(for modelInfo: ModelInfo) {
        getDownloadItem(for: modelInfo)?.resume()
    }
    
    func deleteModel(_ modelInfo: ModelInfo) throws {
        let fileURL = getModelFileURL(for: modelInfo)
        
        guard fileManager.fileExists(atPath: fileURL.path) else {
            throw ModelManagerError.fileNotFound
        }
        
        try fileManager.removeItem(at: fileURL)
        loadDownloadedModels()
    }
    
    // MARK: - Utility Methods
    
    func refreshAvailableModels() async {
        isLoading = true
        defer { isLoading = false }
        
        // In a real implementation, this would fetch from a server
        // For now, we'll just reload the static list
        try? await Task.sleep(nanoseconds: 1_000_000_000) // Simulate network delay
        loadAvailableModels()
    }
    
    func clearCache() {
        // Clean up temp directory
        do {
            let tempFiles = try fileManager.contentsOfDirectory(at: tempDirectory, includingPropertiesForKeys: nil)
            for file in tempFiles {
                try fileManager.removeItem(at: file)
            }
        } catch {
            print("Error clearing cache: \(error)")
        }
    }
    
    func getStorageInfo() -> (used: Int64, available: Int64, total: Int64) {
        do {
            // Calculate used space by downloaded models
            let files = try fileManager.contentsOfDirectory(at: modelsDirectory, includingPropertiesForKeys: [.fileSizeKey])
            let usedSpace = files.reduce(Int64(0)) { total, url in
                let size = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
                return total + Int64(size)
            }
            
            // Get available space
            let availableSpace = try getAvailableStorageSpace()
            
            // Estimate total space (this is approximate)
            let totalSpace = availableSpace + usedSpace
            
            return (used: usedSpace, available: availableSpace, total: totalSpace)
        } catch {
            return (used: 0, available: 0, total: 0)
        }
    }
}