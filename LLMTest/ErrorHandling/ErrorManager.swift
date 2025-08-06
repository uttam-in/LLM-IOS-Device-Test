//
//  ErrorManager.swift
//  LLMTest
//
//  Created by Uttam Kumar Panasala on 8/6/25.
//

import Foundation
import Combine
import UIKit

// MARK: - Error Manager

@MainActor
class ErrorManager: ObservableObject {
    static let shared = ErrorManager()
    
    // MARK: - Published Properties
    @Published var currentError: (any AppError)? = nil
    @Published var errorHistory: [ErrorLogEntry] = []
    @Published var isShowingError: Bool = false
    
    // MARK: - Private Properties
    private var retryAttempts: [String: Int] = [:]
    private var retryTimers: [String: Timer] = [:]
    private let maxRetryAttempts = 3
    private let logger = ErrorLogger.shared
    
    // MARK: - Initialization
    private init() {}
    
    // MARK: - Error Handling
    
    func handleError(_ error: any AppError, context: ErrorContext? = nil) {
        logger.logError(error, context: context)
        
        // Add to error history
        let logEntry = ErrorLogEntry(
            error: error,
            timestamp: Date(),
            context: context,
            wasRetried: false
        )
        errorHistory.append(logEntry)
        
        // Keep only last 100 errors
        if errorHistory.count > 100 {
            errorHistory.removeFirst(errorHistory.count - 100)
        }
        
        // Handle based on severity
        switch error.severity {
        case .critical:
            showCriticalError(error)
        case .high:
            showError(error)
        case .medium:
            if error.isRetryable {
                attemptAutoRetry(error, context: context)
            } else {
                showError(error)
            }
        case .low:
            // Log but don't show UI for low severity errors
            break
        }
    }
    
    func showError(_ error: any AppError) {
        currentError = error
        isShowingError = true
    }
    
    func dismissError() {
        currentError = nil
        isShowingError = false
    }
    
    private func showCriticalError(_ error: any AppError) {
        // For critical errors, always show immediately
        showError(error)
        
        // Also send to crash reporting if available
        logger.logCriticalError(error)
    }
    
    // MARK: - Retry Logic
    
    func attemptAutoRetry(_ error: any AppError, context: ErrorContext? = nil) {
        let errorKey = error.errorCode
        let currentAttempts = retryAttempts[errorKey, default: 0]
        
        guard currentAttempts < maxRetryAttempts else {
            // Max retries reached, show error to user
            showError(error)
            return
        }
        
        retryAttempts[errorKey] = currentAttempts + 1
        
        // Calculate retry delay (exponential backoff)
        let baseDelay: TimeInterval = 2.0
        let delay = baseDelay * pow(2.0, Double(currentAttempts))
        
        logger.logRetryAttempt(error, attempt: currentAttempts + 1, delay: delay)
        
        // Schedule retry
        let timer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.executeRetry(error, context: context)
            }
        }
        
        retryTimers[errorKey] = timer
    }
    
    func manualRetry(_ error: any AppError, context: ErrorContext? = nil) {
        dismissError()
        executeRetry(error, context: context)
    }
    
    private func executeRetry(_ error: any AppError, context: ErrorContext? = nil) {
        let errorKey = error.errorCode
        retryTimers[errorKey]?.invalidate()
        retryTimers.removeValue(forKey: errorKey)
        
        // Mark as retried in history
        if let lastEntry = errorHistory.last, lastEntry.error.errorCode == error.errorCode {
            errorHistory[errorHistory.count - 1].wasRetried = true
        }
        
        // Execute the retry based on context
        guard let context = context else {
            logger.logError(LLMAppError.configurationError("No context provided for retry"))
            return
        }
        
        Task {
            do {
                try await context.retryOperation()
                // Success - reset retry count
                retryAttempts.removeValue(forKey: errorKey)
                logger.logRetrySuccess(error)
            } catch {
                // Retry failed - handle the new error
                if let appError = error as? (any AppError) {
                    handleError(appError, context: context)
                } else {
                    handleError(LLMAppError.unexpectedError(error), context: context)
                }
            }
        }
    }
    
    // MARK: - Recovery Actions
    
    func executeRecoveryAction(_ action: ErrorRecoveryAction, for error: any AppError, context: ErrorContext? = nil) async {
        logger.logRecoveryAction(action, for: error)
        
        switch action {
        case .retry:
            manualRetry(error, context: context)
            
        case .retryWithDelay(let delay):
            dismissError()
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            executeRetry(error, context: context)
            
        case .redownloadModel(let modelName):
            await executeModelRedownload(modelName)
            
        case .clearCache:
            await executeClearCache()
            
        case .freeMemory:
            await executeFreeMemory()
            
        case .restartApp:
            executeRestartApp()
            
        case .checkNetworkConnection:
            executeCheckNetwork()
            
        case .checkStorageSpace:
            executeCheckStorage()
            
        case .contactSupport:
            executeContactSupport(error)
            
        case .dismissError:
            dismissError()
            
        case .navigateToSettings:
            executeNavigateToSettings()
            
        case .switchToFallbackModel:
            await executeSwitchToFallbackModel()
        }
    }
    
    // MARK: - Recovery Action Implementations
    
    private func executeModelRedownload(_ modelName: String) async {
        // Implementation would integrate with ModelManager
        NotificationCenter.default.post(
            name: .redownloadModelRequested,
            object: modelName
        )
    }
    
    private func executeClearCache() async {
        // Implementation would integrate with StorageManager
        NotificationCenter.default.post(
            name: .clearCacheRequested,
            object: nil
        )
    }
    
    private func executeFreeMemory() async {
        // Implementation would integrate with MemoryManager
        NotificationCenter.default.post(
            name: .freeMemoryRequested,
            object: nil
        )
    }
    
    private func executeRestartApp() {
        // Show restart prompt to user
        NotificationCenter.default.post(
            name: .restartAppRequested,
            object: nil
        )
    }
    
    private func executeCheckNetwork() {
        // Open network settings or show network status
        if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsURL)
        }
    }
    
    private func executeCheckStorage() {
        // Navigate to storage management view
        NotificationCenter.default.post(
            name: .navigateToStorageRequested,
            object: nil
        )
    }
    
    private func executeContactSupport(_ appError: any AppError) {
        // Prepare support email with error details
        let errorDetails = """
        Error Code: \(appError.errorCode)
        Category: \(appError.category.description)
        Severity: \(appError.severity.description)
        Message: \(appError.userFriendlyMessage)
        Timestamp: \(Date())
        
        Device: \(UIDevice.current.model)
        iOS Version: \(UIDevice.current.systemVersion)
        App Version: \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown")
        """
        
        NotificationCenter.default.post(
            name: .contactSupportRequested,
            object: errorDetails
        )
    }
    
    private func executeNavigateToSettings() {
        if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsURL)
        }
    }
    
    private func executeSwitchToFallbackModel() async {
        NotificationCenter.default.post(
            name: .switchToFallbackModelRequested,
            object: nil
        )
    }
    
    // MARK: - Error Statistics
    
    func getErrorStatistics() -> ErrorStatistics {
        let now = Date()
        let last24Hours = now.addingTimeInterval(-24 * 60 * 60)
        let last7Days = now.addingTimeInterval(-7 * 24 * 60 * 60)
        
        let recent24h = errorHistory.filter { $0.timestamp >= last24Hours }
        let recent7d = errorHistory.filter { $0.timestamp >= last7Days }
        
        let categoryCounts = Dictionary(grouping: errorHistory) { $0.error.category }
            .mapValues { $0.count }
        
        let severityCounts = Dictionary(grouping: errorHistory) { $0.error.severity }
            .mapValues { $0.count }
        
        return ErrorStatistics(
            totalErrors: errorHistory.count,
            errorsLast24Hours: recent24h.count,
            errorsLast7Days: recent7d.count,
            errorsByCategory: categoryCounts,
            errorsBySeverity: severityCounts,
            mostCommonError: findMostCommonError(),
            retrySuccessRate: calculateRetrySuccessRate()
        )
    }
    
    private func findMostCommonError() -> String? {
        let errorCounts = Dictionary(grouping: errorHistory) { $0.error.errorCode }
            .mapValues { $0.count }
        
        return errorCounts.max(by: { $0.value < $1.value })?.key
    }
    
    private func calculateRetrySuccessRate() -> Double {
        let retriedErrors = errorHistory.filter { $0.wasRetried }
        guard !retriedErrors.isEmpty else { return 0.0 }
        
        // This is a simplified calculation
        // In a real implementation, you'd track retry outcomes more precisely
        return 0.75 // Placeholder
    }
    
    // MARK: - Cleanup
    
    func clearErrorHistory() {
        errorHistory.removeAll()
        retryAttempts.removeAll()
        retryTimers.values.forEach { $0.invalidate() }
        retryTimers.removeAll()
    }
}

// MARK: - Supporting Types

struct ErrorContext {
    let operation: String
    let parameters: [String: Any]?
    let retryOperation: () async throws -> Void
    
    init(operation: String, parameters: [String: Any]? = nil, retryOperation: @escaping () async throws -> Void) {
        self.operation = operation
        self.parameters = parameters
        self.retryOperation = retryOperation
    }
}

struct ErrorLogEntry {
    let error: any AppError
    let timestamp: Date
    let context: ErrorContext?
    var wasRetried: Bool
    
    var id: String {
        return "\(error.errorCode)-\(timestamp.timeIntervalSince1970)"
    }
}

struct ErrorStatistics {
    let totalErrors: Int
    let errorsLast24Hours: Int
    let errorsLast7Days: Int
    let errorsByCategory: [ErrorCategory: Int]
    let errorsBySeverity: [ErrorSeverity: Int]
    let mostCommonError: String?
    let retrySuccessRate: Double
}

// MARK: - Notification Names

extension Notification.Name {
    static let redownloadModelRequested = Notification.Name("redownloadModelRequested")
    static let clearCacheRequested = Notification.Name("clearCacheRequested")
    static let freeMemoryRequested = Notification.Name("freeMemoryRequested")
    static let restartAppRequested = Notification.Name("restartAppRequested")
    static let navigateToStorageRequested = Notification.Name("navigateToStorageRequested")
    static let contactSupportRequested = Notification.Name("contactSupportRequested")
    static let switchToFallbackModelRequested = Notification.Name("switchToFallbackModelRequested")
}
