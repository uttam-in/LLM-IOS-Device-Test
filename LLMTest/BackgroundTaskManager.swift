//
//  BackgroundTaskManager.swift
//  LLMTest
//
//  Created by Uttam Kumar Panasala on 8/6/25.
//

import Foundation
import UIKit
import os.log

// MARK: - Background Task Manager

/// Manages background/foreground transitions and pauses inference appropriately
@MainActor
class BackgroundTaskManager: ObservableObject {
    
    // MARK: - Properties
    
    @Published var appState: AppState = .active
    @Published var isInferenceAllowed: Bool = true
    @Published var backgroundTimeRemaining: TimeInterval = 0
    
    private let logger = Logger(subsystem: "com.llmtest.backgroundtask", category: "lifecycle")
    
    // Background task management
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
    private var backgroundTimer: Timer?
    
    // Weak references to managed components
    private weak var llamaWrapper: LlamaWrapper?
    private weak var chatManager: ChatManager?
    private weak var memoryManager: MemoryManager?
    
    // State tracking
    private var wasInferenceActiveWhenBackgrounded: Bool = false
    private var pendingInferenceRequests: [InferenceRequest] = []
    
    // MARK: - Initialization
    
    init() {
        setupNotificationObservers()
        updateAppState()
    }
    
    deinit {
        endBackgroundTask()
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Setup
    
    private func setupNotificationObservers() {
        // App lifecycle notifications
        NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.handleWillResignActive()
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.handleDidEnterBackground()
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.handleWillEnterForeground()
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.handleDidBecomeActive()
            }
        }
        
        // Memory warning notifications
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.handleMemoryWarning()
            }
        }
    }
    
    // MARK: - App State Handling
    
    private func handleWillResignActive() async {
        logger.info("App will resign active")
        appState = .inactive
        
        // Pause inference if active
        if let chatManager = chatManager, chatManager.isProcessing {
            wasInferenceActiveWhenBackgrounded = true
            await pauseInference()
        }
        
        isInferenceAllowed = false
    }
    
    private func handleDidEnterBackground() async {
        logger.info("App did enter background")
        appState = .background
        
        // Start background task to allow cleanup
        beginBackgroundTask()
        
        // Perform background cleanup
        await performBackgroundCleanup()
        
        // Start monitoring background time
        startBackgroundTimeMonitoring()
    }
    
    private func handleWillEnterForeground() async {
        logger.info("App will enter foreground")
        appState = .foreground
        
        // Stop background monitoring
        stopBackgroundTimeMonitoring()
        
        // End background task
        endBackgroundTask()
        
        // Prepare for active state
        await prepareForForeground()
    }
    
    private func handleDidBecomeActive() async {
        logger.info("App did become active")
        appState = .active
        isInferenceAllowed = true
        
        // Resume inference if it was active before backgrounding
        if wasInferenceActiveWhenBackgrounded {
            await resumeInference()
            wasInferenceActiveWhenBackgrounded = false
        }
        
        // Process any pending inference requests
        await processPendingInferenceRequests()
    }
    
    private func handleMemoryWarning() async {
        logger.warning("Memory warning received in background task manager")
        
        if appState == .background {
            // More aggressive cleanup when in background
            await performAggressiveBackgroundCleanup()
        }
    }
    
    // MARK: - Background Task Management
    
    private func beginBackgroundTask() {
        guard backgroundTaskID == .invalid else { return }
        
        backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "LLMInferenceCleanup") { [weak self] in
            Task { @MainActor in
                await self?.handleBackgroundTaskExpiration()
            }
        }
        
        logger.info("Background task started: \(backgroundTaskID.rawValue)")
    }
    
    private func endBackgroundTask() {
        guard backgroundTaskID != .invalid else { return }
        
        UIApplication.shared.endBackgroundTask(backgroundTaskID)
        logger.info("Background task ended: \(backgroundTaskID.rawValue)")
        backgroundTaskID = .invalid
    }
    
    private func handleBackgroundTaskExpiration() async {
        logger.warning("Background task is about to expire")
        
        // Perform final cleanup
        await performAggressiveBackgroundCleanup()
        
        // End the background task
        endBackgroundTask()
    }
    
    // MARK: - Background Time Monitoring
    
    private func startBackgroundTimeMonitoring() {
        backgroundTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateBackgroundTimeRemaining()
            }
        }
    }
    
    private func stopBackgroundTimeMonitoring() {
        backgroundTimer?.invalidate()
        backgroundTimer = nil
        backgroundTimeRemaining = 0
    }
    
    private func updateBackgroundTimeRemaining() {
        backgroundTimeRemaining = UIApplication.shared.backgroundTimeRemaining
        
        // If time is running low, perform cleanup
        if backgroundTimeRemaining < 10.0 && backgroundTimeRemaining > 0 {
            Task {
                await performAggressiveBackgroundCleanup()
            }
        }
    }
    
    // MARK: - Inference Management
    
    private func pauseInference() async {
        logger.info("Pausing inference due to app state change")
        
        // Cancel any ongoing inference
        if let llamaWrapper = llamaWrapper, llamaWrapper.isGenerating {
            // Note: In a real implementation, you'd need a way to cancel ongoing inference
            // For now, we'll just mark it as paused
        }
    }
    
    private func resumeInference() async {
        logger.info("Resuming inference after returning to foreground")
        
        // Resume any paused inference
        // This would depend on your specific implementation
    }
    
    func queueInferenceRequest(_ request: InferenceRequest) {
        if isInferenceAllowed {
            // Process immediately
            Task {
                await processInferenceRequest(request)
            }
        } else {
            // Queue for later processing
            pendingInferenceRequests.append(request)
            logger.info("Queued inference request for later processing")
        }
    }
    
    private func processPendingInferenceRequests() async {
        guard !pendingInferenceRequests.isEmpty else { return }
        
        logger.info("Processing \(pendingInferenceRequests.count) pending inference requests")
        
        for request in pendingInferenceRequests {
            await processInferenceRequest(request)
        }
        
        pendingInferenceRequests.removeAll()
    }
    
    private func processInferenceRequest(_ request: InferenceRequest) async {
        // Process the inference request
        // This would integrate with your ChatManager or LlamaWrapper
        logger.info("Processing inference request: \(request.id)")
    }
    
    // MARK: - Background Cleanup
    
    private func performBackgroundCleanup() async {
        logger.info("Performing background cleanup")
        
        // Clear non-essential caches
        URLCache.shared.removeAllCachedResponses()
        
        // Reduce memory footprint
        await memoryManager?.performLightMemoryCleanup()
        
        // Save any pending data
        await savePendingData()
    }
    
    private func performAggressiveBackgroundCleanup() async {
        logger.info("Performing aggressive background cleanup")
        
        // Unload model if loaded and not actively being used
        if let llamaWrapper = llamaWrapper, 
           llamaWrapper.isModelLoaded && 
           !llamaWrapper.isGenerating {
            logger.info("Unloading model due to background state")
            await llamaWrapper.unloadModel()
        }
        
        // Clear all caches
        await memoryManager?.forceMemoryCleanup()
        
        // Save critical data
        await savePendingData()
    }
    
    private func prepareForForeground() async {
        logger.info("Preparing for foreground state")
        
        // Reload model if it was unloaded
        // This would depend on your app's state management
    }
    
    private func savePendingData() async {
        // Save any pending data to persistent storage
        // This would integrate with your StorageManager
        logger.info("Saving pending data")
    }
    
    // MARK: - Component Registration
    
    func registerLlamaWrapper(_ wrapper: LlamaWrapper) {
        self.llamaWrapper = wrapper
        logger.info("LlamaWrapper registered with BackgroundTaskManager")
    }
    
    func registerChatManager(_ manager: ChatManager) {
        self.chatManager = manager
        logger.info("ChatManager registered with BackgroundTaskManager")
    }
    
    func registerMemoryManager(_ manager: MemoryManager) {
        self.memoryManager = manager
        logger.info("MemoryManager registered with BackgroundTaskManager")
    }
    
    // MARK: - State Management
    
    private func updateAppState() {
        switch UIApplication.shared.applicationState {
        case .active:
            appState = .active
            isInferenceAllowed = true
        case .inactive:
            appState = .inactive
            isInferenceAllowed = false
        case .background:
            appState = .background
            isInferenceAllowed = false
        @unknown default:
            appState = .active
            isInferenceAllowed = true
        }
    }
    
    // MARK: - Public Interface
    
    func canPerformInference() -> Bool {
        return isInferenceAllowed && appState == .active
    }
    
    func getAppStateInfo() -> AppStateInfo {
        return AppStateInfo(
            currentState: appState,
            isInferenceAllowed: isInferenceAllowed,
            backgroundTimeRemaining: backgroundTimeRemaining,
            pendingRequestsCount: pendingInferenceRequests.count,
            wasInferenceActive: wasInferenceActiveWhenBackgrounded
        )
    }
}

// MARK: - Supporting Types

enum AppState: String, CaseIterable {
    case active = "Active"
    case inactive = "Inactive"
    case foreground = "Foreground"
    case background = "Background"
    
    var description: String {
        switch self {
        case .active:
            return "App is active and ready for inference"
        case .inactive:
            return "App is inactive, inference paused"
        case .foreground:
            return "App is entering foreground"
        case .background:
            return "App is in background, inference suspended"
        }
    }
}

struct InferenceRequest {
    let id: UUID = UUID()
    let prompt: String
    let maxTokens: Int
    let temperature: Float
    let topP: Float
    let timestamp: Date = Date()
}

struct AppStateInfo {
    let currentState: AppState
    let isInferenceAllowed: Bool
    let backgroundTimeRemaining: TimeInterval
    let pendingRequestsCount: Int
    let wasInferenceActive: Bool
}
