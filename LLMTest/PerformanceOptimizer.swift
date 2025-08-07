//
//  PerformanceOptimizer.swift
//  LLMTest
//
//  Created by Uttam Kumar Panasala on 8/6/25.
//

import Foundation
import Combine
import UIKit
import os.log

// MARK: - Performance Metrics

struct PerformanceMetrics {
    let timestamp: Date
    let memoryUsage: UInt64
    let cpuUsage: Double
    let thermalState: DeviceThermalState
    let batteryLevel: Float
    let inferenceLatency: TimeInterval?
    let uiFrameRate: Double
    let activeConnections: Int
    
    var performanceScore: Double {
        var score = 1.0
        
        // Memory pressure impact
        let memoryPressure = Double(memoryUsage) / Double(ProcessInfo.processInfo.physicalMemory)
        score *= (1.0 - min(memoryPressure, 0.8))
        
        // CPU usage impact
        score *= (1.0 - min(cpuUsage, 0.8))
        
        // Thermal state impact
        score *= thermalState.performanceMultiplier
        
        // Battery level impact (only when very low)
        if batteryLevel < 0.2 {
            score *= Double(batteryLevel) * 5.0 // Scale 0.0-0.2 to 0.0-1.0
        }
        
        return max(0.0, min(1.0, score))
    }
}

// MARK: - Optimization Strategy

enum OptimizationStrategy: String, CaseIterable {
    case aggressive = "aggressive"
    case balanced = "balanced"
    case conservative = "conservative"
    case adaptive = "adaptive"
    
    var description: String {
        switch self {
        case .aggressive:
            return "Aggressive Optimization"
        case .balanced:
            return "Balanced Performance"
        case .conservative:
            return "Conservative Mode"
        case .adaptive:
            return "Adaptive Optimization"
        }
    }
    
    var memoryThreshold: Double {
        switch self {
        case .aggressive:
            return 0.6
        case .balanced:
            return 0.7
        case .conservative:
            return 0.8
        case .adaptive:
            return 0.75
        }
    }
    
    var thermalThreshold: DeviceThermalState {
        switch self {
        case .aggressive:
            return .fair
        case .balanced:
            return .serious
        case .conservative:
            return .critical
        case .adaptive:
            return .serious
        }
    }
}

// MARK: - Performance Optimizer

@MainActor
class PerformanceOptimizer: ObservableObject {
    static let shared = PerformanceOptimizer()
    
    // MARK: - Published Properties
    @Published var currentMetrics: PerformanceMetrics?
    @Published var optimizationStrategy: OptimizationStrategy = .adaptive
    @Published var isOptimizing: Bool = false
    @Published var performanceHistory: [PerformanceMetrics] = []
    
    // MARK: - Private Properties
    private let deviceManager = DeviceCapabilityManager.shared
    private let uiManager = AdaptiveUIManager.shared
    private var cancellables = Set<AnyCancellable>()
    private let logger = ErrorLogger.shared
    
    // Performance monitoring
    private var metricsTimer: Timer?
    private var optimizationTimer: Timer?
    private let maxHistorySize = 100
    
    // CPU monitoring
    private var lastCPUInfo: processor_info_array_t?
    private var lastCPUInfoCount: mach_msg_type_number_t = 0
    
    // MARK: - Initialization
    private init() {
        setupPerformanceMonitoring()
        setupOptimizationEngine()
        setupDeviceIntegration()
    }
    
    // MARK: - Setup
    
    private func setupPerformanceMonitoring() {
        // Start metrics collection
        metricsTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.collectMetrics()
            }
        }
    }
    
    private func setupOptimizationEngine() {
        // Run optimization checks every 10 seconds
        optimizationTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.evaluateAndOptimize()
            }
        }
    }
    
    private func setupDeviceIntegration() {
        // Monitor device state changes
        deviceManager.$isThrottling
            .combineLatest(deviceManager.$thermalState, deviceManager.$memoryPressure)
            .sink { [weak self] isThrottling, thermalState, memoryPressure in
                if isThrottling || thermalState == .critical || memoryPressure > 0.9 {
                    self?.triggerEmergencyOptimization()
                }
            }
            .store(in: &cancellables)
        
        // Monitor memory warnings
        NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)
            .sink { [weak self] _ in
                self?.handleMemoryPressure()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Metrics Collection
    
    private func collectMetrics() {
        let memoryInfo = getMemoryInfo()
        let cpuUsage = getCPUUsage()
        let thermalState = deviceManager.thermalState
        let batteryLevel = deviceManager.batteryLevel
        let frameRate = getUIFrameRate()
        
        let metrics = PerformanceMetrics(
            timestamp: Date(),
            memoryUsage: memoryInfo.used,
            cpuUsage: cpuUsage,
            thermalState: thermalState,
            batteryLevel: batteryLevel,
            inferenceLatency: getLastInferenceLatency(),
            uiFrameRate: frameRate,
            activeConnections: getActiveConnectionCount()
        )
        
        currentMetrics = metrics
        addToHistory(metrics)
        
        // Log performance if concerning
        if metrics.performanceScore < 0.5 {
            logger.logSystemInfo()
        }
    }
    
    private func addToHistory(_ metrics: PerformanceMetrics) {
        performanceHistory.append(metrics)
        
        // Keep only recent history
        if performanceHistory.count > maxHistorySize {
            performanceHistory.removeFirst(performanceHistory.count - maxHistorySize)
        }
    }
    
    // MARK: - Optimization Engine
    
    private func evaluateAndOptimize() {
        guard let metrics = currentMetrics else { return }
        
        let shouldOptimize = shouldTriggerOptimization(metrics)
        
        if shouldOptimize && !isOptimizing {
            performOptimization(for: metrics)
        }
    }
    
    private func shouldTriggerOptimization(_ metrics: PerformanceMetrics) -> Bool {
        let strategy = optimizationStrategy
        
        // Memory pressure check
        let memoryPressure = Double(metrics.memoryUsage) / Double(ProcessInfo.processInfo.physicalMemory)
        if memoryPressure > strategy.memoryThreshold {
            return true
        }
        
        // Thermal state check
        if metrics.thermalState.rawValue >= strategy.thermalThreshold.rawValue {
            return true
        }
        
        // CPU usage check
        if metrics.cpuUsage > 0.8 {
            return true
        }
        
        // Performance score check
        if metrics.performanceScore < 0.6 {
            return true
        }
        
        // UI frame rate check
        if metrics.uiFrameRate < 30.0 {
            return true
        }
        
        return false
    }
    
    private func performOptimization(for metrics: PerformanceMetrics) {
        isOptimizing = true
        
        Task {
            do {
                try await executeOptimizationStrategy(metrics)
            } catch {
                logger.logError(LLMAppError.systemResourcesUnavailable, context: ErrorContext(
                    operation: "performance_optimization",
                    parameters: ["strategy": optimizationStrategy.rawValue],
                    retryOperation: { [weak self] in
                        await self?.performOptimization(for: metrics)
                    }
                ))
            }
            
            await MainActor.run {
                isOptimizing = false
            }
        }
    }
    
    private func executeOptimizationStrategy(_ metrics: PerformanceMetrics) async throws {
        logger.logSystemInfo()
        
        // 1. Memory optimization
        if shouldOptimizeMemory(metrics) {
            try await optimizeMemory()
        }
        
        // 2. CPU optimization
        if shouldOptimizeCPU(metrics) {
            try await optimizeCPU()
        }
        
        // 3. GPU optimization
        if shouldOptimizeGPU(metrics) {
            try await optimizeGPU()
        }
        
        // 4. UI optimization
        if shouldOptimizeUI(metrics) {
            await optimizeUI()
        }
        
        // 5. Model optimization
        if shouldOptimizeModel(metrics) {
            try await optimizeModel()
        }
        
        // 6. Background task optimization
        if shouldOptimizeBackgroundTasks(metrics) {
            await optimizeBackgroundTasks()
        }
    }
    
    // MARK: - Specific Optimizations
    
    private func shouldOptimizeMemory(_ metrics: PerformanceMetrics) -> Bool {
        let memoryPressure = Double(metrics.memoryUsage) / Double(ProcessInfo.processInfo.physicalMemory)
        return memoryPressure > optimizationStrategy.memoryThreshold
    }
    
    private func optimizeMemory() async throws {
        // Clear caches
        NotificationCenter.default.post(name: .performanceOptimizationRequested, object: ["action": "clearCache"])
        
        // Force garbage collection
        autoreleasepool {
            // Create memory pressure to trigger cleanup
            let _ = Array(repeating: Data(count: 1024), count: 1000)
        }
        
        // Request memory cleanup from managers
        NotificationCenter.default.post(name: .performanceOptimizationRequested, object: ["action": "freeMemory"])
        
        // Wait for cleanup to complete
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
    }
    
    private func shouldOptimizeCPU(_ metrics: PerformanceMetrics) -> Bool {
        return metrics.cpuUsage > 0.7
    }
    
    private func optimizeCPU() async throws {
        // Reduce thread count for inference
        let optimalThreads = deviceManager.getOptimalThreadCount()
        NotificationCenter.default.post(
            name: .optimizeThreadCountRequested,
            object: optimalThreads
        )
        
        // Pause non-essential background tasks
        NotificationCenter.default.post(name: .pauseBackgroundTasksRequested, object: nil)
    }
    
    private func shouldOptimizeGPU(_ metrics: PerformanceMetrics) -> Bool {
        return metrics.thermalState == DeviceThermalState.serious || metrics.thermalState == DeviceThermalState.critical
    }
    
    private func optimizeGPU() async throws {
        // Reduce GPU usage if overheating
        if deviceManager.thermalState == DeviceThermalState.critical {
            NotificationCenter.default.post(name: .performanceOptimizationRequested, object: ["action": "disableGPU"])
        } else {
            NotificationCenter.default.post(name: .performanceOptimizationRequested, object: ["action": "reduceGPU"])
        }
    }
    
    private func shouldOptimizeUI(_ metrics: PerformanceMetrics) -> Bool {
        return metrics.uiFrameRate < 45.0 || metrics.performanceScore < 0.7
    }
    
    private func optimizeUI() async {
        // Force UI to minimal mode
        uiManager.clearAllAnimations()
        
        // Notify UI components to reduce complexity
        NotificationCenter.default.post(name: .reduceUIComplexityRequested, object: nil)
    }
    
    private func shouldOptimizeModel(_ metrics: PerformanceMetrics) -> Bool {
        return metrics.inferenceLatency ?? 0 > 5.0 || metrics.performanceScore < 0.5
    }
    
    private func optimizeModel() async throws {
        // Switch to smaller model if available
        NotificationCenter.default.post(name: .performanceOptimizationRequested, object: ["action": "switchModel"])
        
        // Reduce context length
        let optimalContext = Int(Double(deviceManager.currentConfiguration.contextLength) * 0.7)
        NotificationCenter.default.post(
            name: .optimizeContextLengthRequested,
            object: optimalContext
        )
    }
    
    private func shouldOptimizeBackgroundTasks(_ metrics: PerformanceMetrics) -> Bool {
        return metrics.cpuUsage > 0.6 || metrics.memoryUsage > UInt64(Double(ProcessInfo.processInfo.physicalMemory) * 0.7)
    }
    
    private func optimizeBackgroundTasks() async {
        // Pause non-critical background tasks
        NotificationCenter.default.post(name: .pauseBackgroundTasksRequested, object: nil)
        
        // Reduce background processing frequency
        NotificationCenter.default.post(name: .reduceBackgroundFrequencyRequested, object: nil)
    }
    
    // MARK: - Emergency Optimization
    
    private func triggerEmergencyOptimization() {
        guard !isOptimizing else { return }
        
        Task {
            isOptimizing = true
            
            // Immediate emergency actions
            await emergencyMemoryCleanup()
            await emergencyUIOptimization()
            await emergencyModelOptimization()
            
            isOptimizing = false
        }
    }
    
    private func emergencyMemoryCleanup() async {
        // Aggressive memory cleanup
        NotificationCenter.default.post(name: .emergencyMemoryCleanupRequested, object: nil)
        
        // Clear all caches immediately
        NotificationCenter.default.post(name: .clearAllCachesRequested, object: nil)
        
        // Force garbage collection
        for _ in 0..<3 {
            autoreleasepool {
                let _ = Array(repeating: Data(count: 1024), count: 100)
            }
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }
    }
    
    private func emergencyUIOptimization() async {
        // Force emergency UI mode
        uiManager.clearAllAnimations()
        
        // Disable all non-essential UI features
        NotificationCenter.default.post(name: .enableEmergencyUIRequested, object: nil)
    }
    
    private func emergencyModelOptimization() async {
        // Stop all inference immediately
        NotificationCenter.default.post(name: .stopAllInferenceRequested, object: nil)
        
        // Switch to minimal model
        NotificationCenter.default.post(name: .switchToMinimalModelRequested, object: nil)
    }
    
    private func handleMemoryPressure() {
        Task {
            await emergencyMemoryCleanup()
        }
    }
    
    // MARK: - Utility Methods
    
    private func getMemoryInfo() -> (used: UInt64, total: UInt64) {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return (used: info.resident_size, total: ProcessInfo.processInfo.physicalMemory)
        }
        
        return (used: 0, total: ProcessInfo.processInfo.physicalMemory)
    }
    
    private func getCPUUsage() -> Double {
        var cpuInfo: processor_info_array_t!
        var cpuInfoCount: mach_msg_type_number_t = 0
        var numCPUs: natural_t = 0
        
        let result = host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &numCPUs, &cpuInfo, &cpuInfoCount)
        
        guard result == KERN_SUCCESS else { return 0.0 }
        
        defer {
            if let cpuInfo = cpuInfo {
                vm_deallocate(mach_task_self_, vm_address_t(bitPattern: cpuInfo), vm_size_t(Int(cpuInfoCount) * MemoryLayout<integer_t>.size))
            }
        }
        
        var totalUsage: Double = 0.0
        
        for i in 0..<Int(numCPUs) {
            let cpuLoadInfo = cpuInfo.advanced(by: i * Int(CPU_STATE_MAX))
            
            let user = Double(cpuLoadInfo[Int(CPU_STATE_USER)])
            let system = Double(cpuLoadInfo[Int(CPU_STATE_SYSTEM)])
            let nice = Double(cpuLoadInfo[Int(CPU_STATE_NICE)])
            let idle = Double(cpuLoadInfo[Int(CPU_STATE_IDLE)])
            
            let total = user + system + nice + idle
            if total > 0 {
                totalUsage += (user + system + nice) / total
            }
        }
        
        return totalUsage / Double(numCPUs)
    }
    
    private func getUIFrameRate() -> Double {
        // Simplified frame rate estimation
        // In a real implementation, you would measure actual frame timing
        if uiManager.currentConfiguration.performanceMode == UIPerformanceMode.emergency {
            return 15.0
        } else if uiManager.currentConfiguration.performanceMode == UIPerformanceMode.minimal {
            return 30.0
        } else {
            return 60.0
        }
    }
    
    private func getLastInferenceLatency() -> TimeInterval? {
        // This would be provided by the inference engine
        // Placeholder implementation
        return nil
    }
    
    private func getActiveConnectionCount() -> Int {
        // This would count active network connections, model loading, etc.
        // Placeholder implementation
        return 1
    }
    
    // MARK: - Public Interface
    
    func setOptimizationStrategy(_ strategy: OptimizationStrategy) {
        optimizationStrategy = strategy
        logger.logSystemInfo()
    }
    
    func forceOptimization() {
        guard let metrics = currentMetrics else { return }
        performOptimization(for: metrics)
    }
    
    func getPerformanceReport() -> String {
        guard let metrics = currentMetrics else {
            return "No performance data available"
        }
        
        let memoryPressure = Double(metrics.memoryUsage) / Double(ProcessInfo.processInfo.physicalMemory)
        
        return """
        Performance Report:
        Score: \(String(format: "%.1f%%", metrics.performanceScore * 100))
        Memory Usage: \(String(format: "%.1f%%", memoryPressure * 100))
        CPU Usage: \(String(format: "%.1f%%", metrics.cpuUsage * 100))
        Thermal State: \(metrics.thermalState.description)
        Battery Level: \(String(format: "%.0f%%", metrics.batteryLevel * 100))
        UI Frame Rate: \(String(format: "%.1f fps", metrics.uiFrameRate))
        Optimization Strategy: \(optimizationStrategy.description)
        """
    }
    
    // MARK: - Cleanup
    
    deinit {
        metricsTimer?.invalidate()
        optimizationTimer?.invalidate()
    }
}

// MARK: - Additional Notification Names

extension Notification.Name {
    static let performanceOptimizationRequested = Notification.Name("performanceOptimizationRequested")
    static let optimizeThreadCountRequested = Notification.Name("optimizeThreadCountRequested")
    static let pauseBackgroundTasksRequested = Notification.Name("pauseBackgroundTasksRequested")
    static let disableGPUAccelerationRequested = Notification.Name("disableGPUAccelerationRequested")
    static let reduceGPUUsageRequested = Notification.Name("reduceGPUUsageRequested")
    static let reduceUIComplexityRequested = Notification.Name("reduceUIComplexityRequested")
    static let optimizeContextLengthRequested = Notification.Name("optimizeContextLengthRequested")
    static let reduceBackgroundFrequencyRequested = Notification.Name("reduceBackgroundFrequencyRequested")
    static let emergencyMemoryCleanupRequested = Notification.Name("emergencyMemoryCleanupRequested")
    static let clearAllCachesRequested = Notification.Name("clearAllCachesRequested")
    static let enableEmergencyUIRequested = Notification.Name("enableEmergencyUIRequested")
    static let stopAllInferenceRequested = Notification.Name("stopAllInferenceRequested")
    static let switchToMinimalModelRequested = Notification.Name("switchToMinimalModelRequested")
}
