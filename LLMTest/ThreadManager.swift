//
//  ThreadManager.swift
//  LLMTest
//
//  Created by Uttam Kumar Panasala on 8/6/25.
//

import Foundation
import os.log

// MARK: - Thread Manager

/// Manages threading optimization for LLM inference and UI operations
@MainActor
class ThreadManager: ObservableObject {
    
    // MARK: - Properties
    
    @Published var activeInferenceThreads: Int = 0
    @Published var queuedInferenceTasks: Int = 0
    @Published var averageInferenceTime: TimeInterval = 0
    @Published var threadUtilization: Double = 0
    
    private let logger = Logger(subsystem: "com.llmtest.threadmanager", category: "threading")
    
    // Dispatch queues for different operations
    private let inferenceQueue: DispatchQueue
    private let modelLoadingQueue: DispatchQueue
    private let backgroundProcessingQueue: DispatchQueue
    private let highPriorityQueue: DispatchQueue
    
    // Thread pool management
    private let maxConcurrentInferenceTasks: Int
    private let maxConcurrentModelTasks: Int
    
    // Performance tracking
    private var inferenceStartTimes: [UUID: CFTimeInterval] = [:]
    private var completedInferenceTimes: [TimeInterval] = []
    private let maxStoredTimes = 100
    
    // Task management
    private var activeInferenceTasks: Set<UUID> = []
    private var queuedTasks: [ThreadTask] = []
    
    // System info
    private let processorCount: Int
    private let physicalCores: Int
    private let logicalCores: Int
    
    // MARK: - Initialization
    
    init() {
        // Get system processor information
        processorCount = ProcessInfo.processInfo.processorCount
        physicalCores = ProcessInfo.processInfo.physicalCores
        logicalCores = ProcessInfo.processInfo.logicalCores
        
        // Calculate optimal thread counts based on system capabilities
        maxConcurrentInferenceTasks = max(1, physicalCores - 1) // Leave one core for UI
        maxConcurrentModelTasks = max(1, physicalCores / 2)
        
        // Create optimized dispatch queues
        inferenceQueue = DispatchQueue(
            label: "com.llmtest.inference",
            qos: .userInitiated,
            attributes: .concurrent,
            target: nil
        )
        
        modelLoadingQueue = DispatchQueue(
            label: "com.llmtest.modelLoading",
            qos: .utility,
            attributes: .concurrent,
            target: nil
        )
        
        backgroundProcessingQueue = DispatchQueue(
            label: "com.llmtest.backgroundProcessing",
            qos: .background,
            attributes: .concurrent,
            target: nil
        )
        
        highPriorityQueue = DispatchQueue(
            label: "com.llmtest.highPriority",
            qos: .userInteractive,
            attributes: .concurrent,
            target: nil
        )
        
        logger.info("ThreadManager initialized")
        logger.info("System: \(processorCount) processors, \(physicalCores) physical cores, \(logicalCores) logical cores")
        logger.info("Max concurrent inference tasks: \(maxConcurrentInferenceTasks)")
        logger.info("Max concurrent model tasks: \(maxConcurrentModelTasks)")
        
        startPerformanceMonitoring()
    }
    
    // MARK: - Performance Monitoring
    
    private func startPerformanceMonitoring() {
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateThreadUtilization()
            }
        }
    }
    
    private func updateThreadUtilization() {
        let totalThreads = maxConcurrentInferenceTasks + maxConcurrentModelTasks
        let activeThreads = activeInferenceThreads
        threadUtilization = totalThreads > 0 ? Double(activeThreads) / Double(totalThreads) : 0.0
        
        // Update average inference time
        if !completedInferenceTimes.isEmpty {
            averageInferenceTime = completedInferenceTimes.reduce(0, +) / Double(completedInferenceTimes.count)
        }
    }
    
    // MARK: - Inference Threading
    
    /// Execute inference task on optimized background thread
    func executeInferenceTask<T>(
        priority: TaskPriority = .medium,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        let taskId = UUID()
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Track task start
        await MainActor.run {
            activeInferenceTasks.insert(taskId)
            activeInferenceThreads = activeInferenceTasks.count
            inferenceStartTimes[taskId] = startTime
        }
        
        defer {
            // Track task completion
            Task { @MainActor in
                activeInferenceTasks.remove(taskId)
                activeInferenceThreads = activeInferenceTasks.count
                
                if let startTime = inferenceStartTimes.removeValue(forKey: taskId) {
                    let duration = CFAbsoluteTimeGetCurrent() - startTime
                    completedInferenceTimes.append(duration)
                    
                    // Keep only recent times
                    if completedInferenceTimes.count > maxStoredTimes {
                        completedInferenceTimes.removeFirst()
                    }
                }
            }
        }
        
        // Choose appropriate queue based on priority and system load
        let queue = selectOptimalQueue(for: priority)
        
        return try await withCheckedThrowingContinuation { continuation in
            queue.async {
                Task {
                    do {
                        let result = try await operation()
                        continuation.resume(returning: result)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }
    
    /// Execute model loading task on dedicated thread
    func executeModelLoadingTask<T>(
        operation: @escaping () async throws -> T
    ) async throws -> T {
        return try await withCheckedThrowingContinuation { continuation in
            modelLoadingQueue.async {
                Task {
                    do {
                        let result = try await operation()
                        continuation.resume(returning: result)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }
    
    /// Execute background processing task
    func executeBackgroundTask<T>(
        operation: @escaping () async throws -> T
    ) async throws -> T {
        return try await withCheckedThrowingContinuation { continuation in
            backgroundProcessingQueue.async {
                Task {
                    do {
                        let result = try await operation()
                        continuation.resume(returning: result)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }
    
    /// Execute high priority task (for UI-critical operations)
    func executeHighPriorityTask<T>(
        operation: @escaping () async throws -> T
    ) async throws -> T {
        return try await withCheckedThrowingContinuation { continuation in
            highPriorityQueue.async {
                Task {
                    do {
                        let result = try await operation()
                        continuation.resume(returning: result)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }
    
    // MARK: - Queue Selection
    
    private func selectOptimalQueue(for priority: TaskPriority) -> DispatchQueue {
        switch priority {
        case .high:
            return highPriorityQueue
        case .medium:
            return inferenceQueue
        case .low:
            return backgroundProcessingQueue
        }
    }
    
    // MARK: - Batch Processing
    
    /// Execute multiple inference tasks concurrently with optimal batching
    func executeBatchInference<T>(
        tasks: [() async throws -> T],
        maxConcurrency: Int? = nil
    ) async throws -> [T] {
        let concurrency = maxConcurrency ?? maxConcurrentInferenceTasks
        let semaphore = DispatchSemaphore(value: concurrency)
        
        return try await withThrowingTaskGroup(of: (Int, T).self) { group in
            // Add all tasks to the group
            for (index, task) in tasks.enumerated() {
                group.addTask { [weak self] in
                    semaphore.wait()
                    defer { semaphore.signal() }
                    
                    let result = try await self?.executeInferenceTask(operation: task) ?? task()
                    return (index, result)
                }
            }
            
            // Collect results in order
            var results: [(Int, T)] = []
            for try await result in group {
                results.append(result)
            }
            
            // Sort by original index and return values
            return results.sorted { $0.0 < $1.0 }.map { $1 }
        }
    }
    
    // MARK: - Thread Pool Management
    
    /// Adjust thread pool size based on system performance
    func optimizeThreadPoolSize() {
        let currentLoad = Double(activeInferenceThreads) / Double(maxConcurrentInferenceTasks)
        
        if currentLoad > 0.8 {
            logger.info("High thread utilization detected: \(currentLoad)")
            // Could implement dynamic thread pool adjustment here
        }
        
        // Monitor system thermal state
        let thermalState = ProcessInfo.processInfo.thermalState
        switch thermalState {
        case .critical:
            logger.warning("Critical thermal state - reducing thread usage")
            // Reduce concurrent tasks
        case .serious:
            logger.warning("Serious thermal state - moderating thread usage")
            // Moderate reduction
        default:
            break
        }
    }
    
    // MARK: - Task Queuing
    
    /// Queue task for later execution when resources are available
    func queueTask(_ task: ThreadTask) {
        queuedTasks.append(task)
        queuedInferenceTasks = queuedTasks.count
        
        // Try to execute queued tasks
        processQueuedTasks()
    }
    
    private func processQueuedTasks() {
        guard !queuedTasks.isEmpty,
              activeInferenceThreads < maxConcurrentInferenceTasks else {
            return
        }
        
        let task = queuedTasks.removeFirst()
        queuedInferenceTasks = queuedTasks.count
        
        Task {
            do {
                try await executeInferenceTask(priority: task.priority) {
                    try await task.operation()
                }
            } catch {
                logger.error("Queued task failed: \(error)")
            }
        }
    }
    
    // MARK: - Performance Metrics
    
    func getPerformanceMetrics() -> ThreadPerformanceMetrics {
        return ThreadPerformanceMetrics(
            activeInferenceThreads: activeInferenceThreads,
            queuedTasks: queuedInferenceTasks,
            averageInferenceTime: averageInferenceTime,
            threadUtilization: threadUtilization,
            maxConcurrentTasks: maxConcurrentInferenceTasks,
            processorCount: processorCount,
            physicalCores: physicalCores,
            logicalCores: logicalCores,
            thermalState: ProcessInfo.processInfo.thermalState.rawValue
        )
    }
    
    func getDetailedThreadInfo() -> DetailedThreadInfo {
        return DetailedThreadInfo(
            activeTaskIds: Array(activeInferenceTasks),
            queuedTaskCount: queuedTasks.count,
            recentInferenceTimes: Array(completedInferenceTimes.suffix(10)),
            currentUtilization: threadUtilization,
            optimalConcurrency: maxConcurrentInferenceTasks,
            systemInfo: SystemThreadInfo(
                processorCount: processorCount,
                physicalCores: physicalCores,
                logicalCores: logicalCores,
                thermalState: ProcessInfo.processInfo.thermalState
            )
        )
    }
    
    // MARK: - Thread Safety Utilities
    
    /// Execute operation on main thread safely
    func executeOnMainThread<T>(
        operation: @MainActor @escaping () throws -> T
    ) async rethrows -> T {
        return try await MainActor.run {
            try operation()
        }
    }
    
    /// Execute operation with thread-safe access to shared resource
    func executeWithLock<T>(
        lock: NSLock,
        operation: () throws -> T
    ) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try operation()
    }
}

// MARK: - Supporting Types

enum TaskPriority {
    case high
    case medium
    case low
}

struct ThreadTask {
    let id: UUID = UUID()
    let priority: TaskPriority
    let operation: () async throws -> Void
    let createdAt: Date = Date()
}

struct ThreadPerformanceMetrics {
    let activeInferenceThreads: Int
    let queuedTasks: Int
    let averageInferenceTime: TimeInterval
    let threadUtilization: Double
    let maxConcurrentTasks: Int
    let processorCount: Int
    let physicalCores: Int
    let logicalCores: Int
    let thermalState: Int
}

struct DetailedThreadInfo {
    let activeTaskIds: [UUID]
    let queuedTaskCount: Int
    let recentInferenceTimes: [TimeInterval]
    let currentUtilization: Double
    let optimalConcurrency: Int
    let systemInfo: SystemThreadInfo
}

struct SystemThreadInfo {
    let processorCount: Int
    let physicalCores: Int
    let logicalCores: Int
    let thermalState: ProcessInfo.ThermalState
}
