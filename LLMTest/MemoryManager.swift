//
//  MemoryManager.swift
//  LLMTest
//
//  Created by Uttam Kumar Panasala on 8/6/25.
//

import Foundation
import UIKit
import os.log

// MARK: - Memory Manager

/// Manages memory usage and automatic model unloading under memory pressure
@MainActor
class MemoryManager: ObservableObject {
    
    // MARK: - Properties
    
    @Published var currentMemoryUsage: Int64 = 0
    @Published var availableMemory: Int64 = 0
    @Published var memoryPressureLevel: MemoryPressureLevel = .normal
    @Published var isMemoryWarningActive: Bool = false
    
    private let logger = Logger(subsystem: "com.llmtest.memorymanager", category: "memory")
    
    // Memory thresholds (in bytes)
    private let criticalMemoryThreshold: Int64 = 100 * 1024 * 1024 // 100MB
    private let warningMemoryThreshold: Int64 = 200 * 1024 * 1024  // 200MB
    private let optimalMemoryThreshold: Int64 = 500 * 1024 * 1024  // 500MB
    
    // Weak references to managed components
    private weak var llamaWrapper: LlamaWrapper?
    private weak var modelManager: ModelManager?
    private weak var gpuAccelerator: MetalGPUAccelerator?
    
    // Memory monitoring
    private var memoryMonitorTimer: Timer?
    private var lastMemoryCheck: Date = Date()
    private let memoryCheckInterval: TimeInterval = 2.0 // Check every 2 seconds
    
    // Memory pressure handling
    private var memoryPressureSource: DispatchSourceMemoryPressure?
    private let memoryQueue = DispatchQueue(label: "memory.monitoring", qos: .utility)
    
    // MARK: - Initialization
    
    init() {
        setupMemoryMonitoring()
        setupMemoryPressureHandling()
        startMemoryMonitoring()
    }
    
    deinit {
        Task { @MainActor in
            stopMemoryMonitoring()
        }
        memoryPressureSource?.cancel()
    }
    
    // MARK: - Setup
    
    private func setupMemoryMonitoring() {
        // Monitor memory usage periodically
        memoryMonitorTimer = Timer.scheduledTimer(withTimeInterval: memoryCheckInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.updateMemoryStatus()
            }
        }
    }
    
    private func setupMemoryPressureHandling() {
        memoryPressureSource = DispatchSource.makeMemoryPressureSource(
            eventMask: [.warning, .critical],
            queue: memoryQueue
        )
        
        memoryPressureSource?.setEventHandler { [weak self] in
            Task { @MainActor in
                await self?.handleMemoryPressure()
            }
        }
        
        memoryPressureSource?.resume()
        
        // Also listen for UIKit memory warnings
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
    
    // MARK: - Memory Monitoring
    
    private func updateMemoryStatus() async {
        let memoryInfo = getMemoryInfo()
        
        currentMemoryUsage = memoryInfo.used
        availableMemory = memoryInfo.available
        
        // Determine memory pressure level
        let previousLevel = memoryPressureLevel
        memoryPressureLevel = determineMemoryPressureLevel(availableMemory: availableMemory)
        
        // Log memory status if pressure level changed
        if previousLevel != memoryPressureLevel {
            logger.info("Memory pressure level changed: \(previousLevel.rawValue) -> \(self.memoryPressureLevel.rawValue)")
            logger.info("Memory usage: \(self.formatBytes(self.currentMemoryUsage)), Available: \(self.formatBytes(self.availableMemory))")
        }
        
        // Take action based on memory pressure
        await handleMemoryPressureLevel(memoryPressureLevel)
    }
    
    private func getMemoryInfo() -> (used: Int64, available: Int64, total: Int64) {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            let used = Int64(info.resident_size)
            
            // Get total physical memory
            var size = UInt64(0)
            var sizeSize = MemoryLayout<UInt64>.size
            sysctlbyname("hw.memsize", &size, &sizeSize, nil, 0)
            let total = Int64(size)
            
            let available = total - used
            return (used: used, available: available, total: total)
        } else {
            logger.error("Failed to get memory info: \(kerr)")
            return (used: 0, available: 0, total: 0)
        }
    }
    
    private func determineMemoryPressureLevel(availableMemory: Int64) -> MemoryPressureLevel {
        if availableMemory < criticalMemoryThreshold {
            return .critical
        } else if availableMemory < warningMemoryThreshold {
            return .warning
        } else if availableMemory < optimalMemoryThreshold {
            return .moderate
        } else {
            return .normal
        }
    }
    
    // MARK: - Memory Pressure Handling
    
    private func handleMemoryPressure() async {
        logger.warning("System memory pressure detected")
        isMemoryWarningActive = true
        
        await performMemoryCleanup(aggressive: true)
        
        // Reset warning flag after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
            self?.isMemoryWarningActive = false
        }
    }
    
    private func handleMemoryWarning() async {
        logger.warning("UIKit memory warning received")
        isMemoryWarningActive = true
        
        await performMemoryCleanup(aggressive: true)
        
        // Reset warning flag after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
            self?.isMemoryWarningActive = false
        }
    }
    
    private func handleMemoryPressureLevel(_ level: MemoryPressureLevel) async {
        switch level {
        case .critical:
            await performMemoryCleanup(aggressive: true)
        case .warning:
            await performMemoryCleanup(aggressive: false)
        case .moderate:
            await performLightMemoryCleanup()
        case .normal:
            // No action needed
            break
        }
    }
    
    // MARK: - Memory Cleanup
    
    private func performMemoryCleanup(aggressive: Bool) async {
        logger.info("Performing \(aggressive ? "aggressive" : "standard") memory cleanup")
        
        if aggressive {
            // Unload model if loaded
            if let llamaWrapper = llamaWrapper, llamaWrapper.isModelLoaded {
                logger.info("Unloading LLM model due to memory pressure")
                await llamaWrapper.unloadModel()
            }
            
            // Clear GPU memory
            gpuAccelerator?.clearMemoryPool()
            
            // Clear model manager cache
            modelManager?.clearCache()
        }
        
        // Clear various caches
        await clearImageCaches()
        await clearURLCaches()
        
        // Force garbage collection
        autoreleasepool {
            // Trigger autorelease pool drain
        }
        
        logger.info("Memory cleanup completed")
    }
    
    func performLightMemoryCleanup() async {
        logger.info("Performing light memory cleanup")
        
        // Clear only non-essential caches
        await clearImageCaches()
        URLCache.shared.removeAllCachedResponses()
    }
    
    private func clearImageCaches() async {
        // Clear any image caches if present
        // This would be implemented based on your specific image caching solution
    }
    
    private func clearURLCaches() async {
        URLCache.shared.removeAllCachedResponses()
    }
    
    // MARK: - Component Registration
    
    func registerLlamaWrapper(_ wrapper: LlamaWrapper) {
        self.llamaWrapper = wrapper
        logger.info("LlamaWrapper registered with MemoryManager")
    }
    
    func registerModelManager(_ manager: ModelManager) {
        self.modelManager = manager
        logger.info("ModelManager registered with MemoryManager")
    }
    
    func registerGPUAccelerator(_ accelerator: MetalGPUAccelerator) {
        self.gpuAccelerator = accelerator
        logger.info("MetalGPUAccelerator registered with MemoryManager")
    }
    
    // MARK: - Memory Control
    
    func startMemoryMonitoring() {
        memoryMonitorTimer?.fire()
        logger.info("Memory monitoring started")
    }
    
    func stopMemoryMonitoring() {
        memoryMonitorTimer?.invalidate()
        memoryMonitorTimer = nil
        logger.info("Memory monitoring stopped")
    }
    
    func forceMemoryCleanup() async {
        logger.info("Force memory cleanup requested")
        await performMemoryCleanup(aggressive: true)
    }
    
    // MARK: - Memory Information
    
    func getDetailedMemoryInfo() -> DetailedMemoryInfo {
        let memoryInfo = getMemoryInfo()
        
        return DetailedMemoryInfo(
            currentUsage: memoryInfo.used,
            availableMemory: memoryInfo.available,
            totalMemory: memoryInfo.total,
            pressureLevel: memoryPressureLevel,
            isWarningActive: isMemoryWarningActive,
            llamaWrapperMemory: Int64(llamaWrapper?.memoryUsage ?? 0),
            gpuMemory: Int64(gpuAccelerator?.gpuMemoryUsage ?? 0),
            lastCheckTime: lastMemoryCheck
        )
    }
    
    func getMemoryUsagePercentage() -> Double {
        let memoryInfo = getMemoryInfo()
        guard memoryInfo.total > 0 else { return 0.0 }
        return Double(memoryInfo.used) / Double(memoryInfo.total) * 100.0
    }
    
    // MARK: - Utilities
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .memory
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - Supporting Types

enum MemoryPressureLevel: String, CaseIterable {
    case normal = "Normal"
    case moderate = "Moderate"
    case warning = "Warning"
    case critical = "Critical"
    
    var color: String {
        switch self {
        case .normal: return "green"
        case .moderate: return "yellow"
        case .warning: return "orange"
        case .critical: return "red"
        }
    }
}

struct DetailedMemoryInfo {
    let currentUsage: Int64
    let availableMemory: Int64
    let totalMemory: Int64
    let pressureLevel: MemoryPressureLevel
    let isWarningActive: Bool
    let llamaWrapperMemory: Int64
    let gpuMemory: Int64
    let lastCheckTime: Date
    
    var usagePercentage: Double {
        guard totalMemory > 0 else { return 0.0 }
        return Double(currentUsage) / Double(totalMemory) * 100.0
    }
}
