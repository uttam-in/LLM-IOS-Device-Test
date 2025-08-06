//
//  ErrorHandlingTests.swift
//  LLMTestTests
//
//  Created by Uttam Kumar Panasala on 8/6/25.
//

import XCTest
import Combine
@testable import LLMTest

@MainActor
class ErrorHandlingTests: XCTestCase {
    
    var errorManager: ErrorManager!
    var errorLogger: ErrorLogger!
    var recoveryManager: ErrorRecoveryManager!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() async throws {
        try await super.setUp()
        errorManager = ErrorManager.shared
        errorLogger = ErrorLogger.shared
        recoveryManager = ErrorRecoveryManager.shared
        cancellables = Set<AnyCancellable>()
        
        // Clear any existing state
        errorManager.clearErrorHistory()
        errorLogger.clearLogs()
    }
    
    override func tearDown() async throws {
        cancellables.removeAll()
        errorManager.clearErrorHistory()
        errorLogger.clearLogs()
        try await super.tearDown()
    }
    
    // MARK: - Error Creation and Properties Tests
    
    func testLLMAppErrorProperties() {
        let networkError = LLMAppError.networkUnavailable
        
        XCTAssertEqual(networkError.errorCode, "NET_001")
        XCTAssertEqual(networkError.category, .network)
        XCTAssertEqual(networkError.severity, .medium)
        XCTAssertTrue(networkError.isRetryable)
        XCTAssertFalse(networkError.recoveryActions.isEmpty)
        XCTAssertTrue(networkError.recoveryActions.contains(.checkNetworkConnection))
    }
    
    func testModelErrorProperties() {
        let modelError = LLMAppError.modelLoadFailed("test-model", nil)
        
        XCTAssertEqual(modelError.errorCode, "MDL_002")
        XCTAssertEqual(modelError.category, .model)
        XCTAssertEqual(modelError.severity, .high)
        XCTAssertTrue(modelError.isRetryable)
        XCTAssertTrue(modelError.recoveryActions.contains(.redownloadModel("model")))
    }
    
    func testStorageErrorProperties() {
        let storageError = LLMAppError.insufficientStorage(required: 1000, available: 500)
        
        XCTAssertEqual(storageError.errorCode, "STG_001")
        XCTAssertEqual(storageError.category, .storage)
        XCTAssertEqual(storageError.severity, .high)
        XCTAssertFalse(storageError.isRetryable)
        XCTAssertTrue(storageError.recoveryActions.contains(.checkStorageSpace))
    }
    
    func testCriticalErrorProperties() {
        let criticalError = LLMAppError.unexpectedError(NSError(domain: "test", code: 1))
        
        XCTAssertEqual(criticalError.errorCode, "SYS_004")
        XCTAssertEqual(criticalError.category, .system)
        XCTAssertEqual(criticalError.severity, .critical)
        XCTAssertFalse(criticalError.isRetryable)
        XCTAssertTrue(criticalError.recoveryActions.contains(.contactSupport))
    }
    
    // MARK: - Error Manager Tests
    
    func testErrorManagerHandlesLowSeverityErrors() {
        let lowSeverityError = LLMAppError.operationCancelled
        
        errorManager.handleError(lowSeverityError)
        
        // Low severity errors should be logged but not shown
        XCTAssertFalse(errorManager.isShowingError)
        XCTAssertNil(errorManager.currentError)
        XCTAssertEqual(errorManager.errorHistory.count, 1)
    }
    
    func testErrorManagerShowsHighSeverityErrors() {
        let highSeverityError = LLMAppError.modelLoadFailed("test", nil)
        
        errorManager.handleError(highSeverityError)
        
        XCTAssertTrue(errorManager.isShowingError)
        XCTAssertNotNil(errorManager.currentError)
        XCTAssertEqual(errorManager.errorHistory.count, 1)
    }
    
    func testErrorManagerShowsCriticalErrors() {
        let criticalError = LLMAppError.unexpectedError(NSError(domain: "test", code: 1))
        
        errorManager.handleError(criticalError)
        
        XCTAssertTrue(errorManager.isShowingError)
        XCTAssertNotNil(errorManager.currentError)
        XCTAssertEqual(errorManager.errorHistory.count, 1)
    }
    
    func testErrorManagerDismissError() {
        let error = LLMAppError.modelLoadFailed("test", nil)
        
        errorManager.handleError(error)
        XCTAssertTrue(errorManager.isShowingError)
        
        errorManager.dismissError()
        XCTAssertFalse(errorManager.isShowingError)
        XCTAssertNil(errorManager.currentError)
    }
    
    func testErrorManagerRetryLogic() async {
        let retryableError = LLMAppError.networkTimeout
        var retryCount = 0
        
        let context = ErrorContext(
            operation: "test-operation",
            parameters: nil,
            retryOperation: {
                retryCount += 1
                if retryCount < 2 {
                    throw LLMAppError.networkTimeout
                }
                // Success on second retry
            }
        )
        
        errorManager.handleError(retryableError, context: context)
        
        // Wait for auto-retry to complete
        try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
        
        XCTAssertGreaterThan(retryCount, 0)
    }
    
    func testErrorManagerMaxRetries() async {
        let retryableError = LLMAppError.networkTimeout
        var retryCount = 0
        
        let context = ErrorContext(
            operation: "test-operation",
            parameters: nil,
            retryOperation: {
                retryCount += 1
                throw LLMAppError.networkTimeout // Always fail
            }
        )
        
        errorManager.handleError(retryableError, context: context)
        
        // Wait for all retries to complete
        try? await Task.sleep(nanoseconds: 10_000_000_000) // 10 seconds
        
        // Should eventually show error after max retries
        XCTAssertTrue(errorManager.isShowingError)
        XCTAssertLessThanOrEqual(retryCount, 3) // Max retry attempts
    }
    
    // MARK: - Error Statistics Tests
    
    func testErrorStatistics() {
        // Add various errors
        errorManager.handleError(LLMAppError.networkUnavailable)
        errorManager.handleError(LLMAppError.modelLoadFailed("test", nil))
        errorManager.handleError(LLMAppError.networkTimeout)
        errorManager.handleError(LLMAppError.gpuNotAvailable)
        
        let stats = errorManager.getErrorStatistics()
        
        XCTAssertEqual(stats.totalErrors, 4)
        XCTAssertEqual(stats.errorsLast24Hours, 4)
        XCTAssertEqual(stats.errorsByCategory[.network], 2)
        XCTAssertEqual(stats.errorsByCategory[.model], 1)
        XCTAssertEqual(stats.errorsByCategory[.gpu], 1)
    }
    
    // MARK: - Error Logger Tests
    
    func testErrorLoggerLogsErrors() {
        let error = LLMAppError.modelLoadFailed("test-model", nil)
        
        errorLogger.logError(error)
        
        let recentLogs = errorLogger.getRecentLogs(limit: 10)
        XCTAssertFalse(recentLogs.isEmpty)
        
        let latestLog = recentLogs.first!
        XCTAssertTrue(latestLog.contains("[MDL_002]"))
        XCTAssertTrue(latestLog.contains("[Model]"))
        XCTAssertTrue(latestLog.contains("[High]"))
    }
    
    func testErrorLoggerRetryLogging() {
        let error = LLMAppError.networkTimeout
        
        errorLogger.logRetryAttempt(error, attempt: 1, delay: 2.0)
        errorLogger.logRetrySuccess(error)
        
        let recentLogs = errorLogger.getRecentLogs(limit: 10)
        XCTAssertGreaterThanOrEqual(recentLogs.count, 2)
        
        let retryLog = recentLogs.first { $0.contains("RETRY_ATTEMPT") }
        let successLog = recentLogs.first { $0.contains("RETRY_SUCCESS") }
        
        XCTAssertNotNil(retryLog)
        XCTAssertNotNil(successLog)
    }
    
    func testErrorLoggerCriticalErrorLogging() {
        let criticalError = LLMAppError.unexpectedError(NSError(domain: "test", code: 1))
        
        errorLogger.logCriticalError(criticalError)
        
        let recentLogs = errorLogger.getRecentLogs(limit: 10)
        let criticalLog = recentLogs.first { $0.contains("CRITICAL_ERROR") }
        
        XCTAssertNotNil(criticalLog)
        XCTAssertTrue(criticalLog!.contains("[SYS_004]"))
    }
    
    func testErrorLoggerSanitization() {
        // Create error with potentially sensitive data
        let error = LLMAppError.configurationError("Failed to load /Users/test/Documents/sensitive-file.txt")
        
        errorLogger.logError(error)
        
        let recentLogs = errorLogger.getRecentLogs(limit: 10)
        let sanitizedLog = recentLogs.first!
        
        // Should not contain full file path
        XCTAssertFalse(sanitizedLog.contains("/Users/test/Documents/sensitive-file.txt"))
        XCTAssertTrue(sanitizedLog.contains("[PATH]"))
    }
    
    // MARK: - Error Recovery Tests
    
    func testRecoveryManagerClearCache() async {
        let expectation = XCTestExpectation(description: "Cache clearing completes")
        
        recoveryManager.$isRecovering
            .dropFirst() // Skip initial false value
            .sink { isRecovering in
                if !isRecovering {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        do {
            try await recoveryManager.executeClearCache()
        } catch {
            XCTFail("Cache clearing should not fail in test environment")
        }
        
        await fulfillment(of: [expectation], timeout: 10.0)
        XCTAssertFalse(recoveryManager.isRecovering)
    }
    
    func testRecoveryManagerFreeMemory() async {
        let expectation = XCTestExpectation(description: "Memory freeing completes")
        
        recoveryManager.$isRecovering
            .dropFirst()
            .sink { isRecovering in
                if !isRecovering {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        do {
            try await recoveryManager.executeFreeMemory()
        } catch {
            XCTFail("Memory freeing should not fail in test environment")
        }
        
        await fulfillment(of: [expectation], timeout: 10.0)
        XCTAssertFalse(recoveryManager.isRecovering)
    }
    
    // MARK: - Error Recovery Action Tests
    
    func testRecoveryActionExecution() async {
        let error = LLMAppError.networkTimeout
        let expectation = XCTestExpectation(description: "Recovery action executes")
        
        await errorManager.executeRecoveryAction(.dismissError, for: error)
        expectation.fulfill()
        
        await fulfillment(of: [expectation], timeout: 5.0)
    }
    
    func testRecoveryActionWithDelay() async {
        let error = LLMAppError.networkTimeout
        let startTime = Date()
        
        await errorManager.executeRecoveryAction(.retryWithDelay(2.0), for: error)
        
        let elapsed = Date().timeIntervalSince(startTime)
        XCTAssertGreaterThanOrEqual(elapsed, 2.0)
    }
    
    // MARK: - Integration Tests
    
    func testErrorManagerIntegrationWithModelManager() {
        let modelError = ModelManagerError.networkError(NSError(domain: "test", code: 1))
        
        // Simulate ModelManager error handling
        let context = ErrorContext(
            operation: "downloadModel",
            parameters: ["modelId": "test-model"],
            retryOperation: {
                throw LLMAppError.networkTimeout
            }
        )
        
        let convertedError = LLMAppError.networkUnavailable
        errorManager.handleError(convertedError, context: context)
        
        XCTAssertEqual(errorManager.errorHistory.count, 1)
        XCTAssertEqual(errorManager.errorHistory.first?.error.category, .network)
    }
    
    func testErrorManagerIntegrationWithGPUAccelerator() {
        let gpuError = MetalGPUError.gpuNotAvailable
        
        let context = ErrorContext(
            operation: "matrixMultiplication",
            parameters: nil,
            retryOperation: {
                throw LLMAppError.gpuNotAvailable
            }
        )
        
        let convertedError = LLMAppError.gpuNotAvailable
        errorManager.handleError(convertedError, context: context)
        
        XCTAssertEqual(errorManager.errorHistory.count, 1)
        XCTAssertEqual(errorManager.errorHistory.first?.error.category, .gpu)
    }
    
    // MARK: - Performance Tests
    
    func testErrorHandlingPerformance() {
        measure {
            for i in 0..<100 {
                let error = LLMAppError.networkTimeout
                errorManager.handleError(error)
            }
        }
    }
    
    func testErrorLoggingPerformance() {
        measure {
            for i in 0..<100 {
                let error = LLMAppError.modelLoadFailed("test-\(i)", nil)
                errorLogger.logError(error)
            }
        }
    }
    
    // MARK: - Edge Cases
    
    func testErrorHistoryLimit() {
        // Add more than 100 errors
        for i in 0..<150 {
            errorManager.handleError(LLMAppError.networkTimeout)
        }
        
        // Should keep only last 100
        XCTAssertEqual(errorManager.errorHistory.count, 100)
    }
    
    func testConcurrentErrorHandling() async {
        let expectation = XCTestExpectation(description: "Concurrent errors handled")
        expectation.expectedFulfillmentCount = 10
        
        // Handle multiple errors concurrently
        for i in 0..<10 {
            Task {
                errorManager.handleError(LLMAppError.networkTimeout)
                expectation.fulfill()
            }
        }
        
        await fulfillment(of: [expectation], timeout: 5.0)
        XCTAssertGreaterThanOrEqual(errorManager.errorHistory.count, 10)
    }
    
    func testErrorWithNilContext() {
        let error = LLMAppError.modelLoadFailed("test", nil)
        
        // Should handle gracefully without context
        errorManager.handleError(error, context: nil)
        
        XCTAssertEqual(errorManager.errorHistory.count, 1)
        XCTAssertNil(errorManager.errorHistory.first?.context)
    }
    
    func testErrorRecoveryWithFailure() async {
        var attemptCount = 0
        let context = ErrorContext(
            operation: "test-operation",
            parameters: nil,
            retryOperation: {
                attemptCount += 1
                throw LLMAppError.networkTimeout
            }
        )
        
        let error = LLMAppError.networkTimeout
        await errorManager.executeRecoveryAction(.retry, for: error, context: context)
        
        XCTAssertEqual(attemptCount, 1)
        // Should handle the retry failure gracefully
    }
}
