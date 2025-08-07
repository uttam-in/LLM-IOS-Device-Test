//
//  DeviceCapabilityManager.swift
//  LLMTest
//
//  Created by Uttam Kumar Panasala on 8/6/25.
//

import Foundation
import UIKit
import Combine

// MARK: - Device Performance Tier

enum DevicePerformanceTier: String, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case ultra = "ultra"
    
    var description: String {
        switch self {
        case .low:
            return "Low Performance"
        case .medium:
            return "Medium Performance"
        case .high:
            return "High Performance"
        case .ultra:
            return "Ultra Performance"
        }
    }
    
    var maxModelSize: Int64 {
        switch self {
        case .low:
            return 1_073_741_824 // 1GB
        case .medium:
            return 2_147_483_648 // 2GB
        case .high:
            return 4_294_967_296 // 4GB
        case .ultra:
            return 8_589_934_592 // 8GB
        }
    }
    
    var maxContextLength: Int {
        switch self {
        case .low:
            return 512
        case .medium:
            return 1024
        case .high:
            return 2048
        case .ultra:
            return 4096
        }
    }
    
    var maxBatchSize: Int {
        switch self {
        case .low:
            return 1
        case .medium:
            return 2
        case .high:
            return 4
        case .ultra:
            return 8
        }
    }
    
    var recommendedThreadCount: Int {
        switch self {
        case .low:
            return 2
        case .medium:
            return 4
        case .high:
            return 6
        case .ultra:
            return 8
        }
    }
}

// MARK: - Device Thermal State

enum DeviceThermalState: String, CaseIterable {
    case nominal = "nominal"
    case fair = "fair"
    case serious = "serious"
    case critical = "critical"
    
    var description: String {
        switch self {
        case .nominal:
            return "Normal Temperature"
        case .fair:
            return "Warm"
        case .serious:
            return "Hot"
        case .critical:
            return "Very Hot"
        }
    }
    
    var performanceMultiplier: Double {
        switch self {
        case .nominal:
            return 1.0
        case .fair:
            return 0.85
        case .serious:
            return 0.7
        case .critical:
            return 0.5
        }
    }
}

// MARK: - Device Capability Configuration

struct DeviceCapabilityConfiguration {
    let performanceTier: DevicePerformanceTier
    let supportsMetalGPU: Bool
    let supportsNeuralEngine: Bool
    let maxMemoryUsage: Int64
    let recommendedModelSize: Int64
    let maxConcurrentInferences: Int
    let adaptiveUIEnabled: Bool
    let thermalThrottlingEnabled: Bool
    
    // Performance parameters based on device tier
    var contextLength: Int {
        return performanceTier.maxContextLength
    }
    
    var batchSize: Int {
        return performanceTier.maxBatchSize
    }
    
    var threadCount: Int {
        return performanceTier.recommendedThreadCount
    }
}

// MARK: - Device Capability Manager

@MainActor
class DeviceCapabilityManager: ObservableObject {
    static let shared = DeviceCapabilityManager()
    
    // MARK: - Published Properties
    @Published var currentConfiguration: DeviceCapabilityConfiguration
    @Published var thermalState: DeviceThermalState = .nominal
    @Published var isThrottling: Bool = false
    @Published var memoryPressure: Float = 0.0
    @Published var batteryLevel: Float = 1.0
    @Published var isLowPowerModeEnabled: Bool = false
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    private let logger = ErrorLogger.shared
    private var thermalStateObserver: NSObjectProtocol?
    private var memoryWarningObserver: NSObjectProtocol?
    private var batteryStateObserver: NSObjectProtocol?
    
    // MARK: - Device Detection Cache
    private let deviceModel: String
    private let deviceIdentifier: String
    private let systemVersion: String
    private let processorCount: Int
    private let physicalMemory: UInt64
    
    // MARK: - Initialization
    private init() {
        // Cache device information
        self.deviceModel = UIDevice.current.model
        self.deviceIdentifier = Self.getDeviceIdentifier()
        self.systemVersion = UIDevice.current.systemVersion
        self.processorCount = ProcessInfo.processInfo.processorCount
        self.physicalMemory = ProcessInfo.processInfo.physicalMemory
        
        // Initialize configuration based on device
        self.currentConfiguration = Self.determineDeviceConfiguration(
            identifier: deviceIdentifier,
            processorCount: processorCount,
            physicalMemory: physicalMemory
        )
        
        setupMonitoring()
        logDeviceCapabilities()
    }
    
    // MARK: - Device Detection
    
    private static func getDeviceIdentifier() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(Int(value)) ?? UnicodeScalar(0)!)
        }
        return identifier
    }
    
    private static func determineDeviceConfiguration(
        identifier: String,
        processorCount: Int,
        physicalMemory: UInt64
    ) -> DeviceCapabilityConfiguration {
        
        let performanceTier = determinePerformanceTier(
            identifier: identifier,
            processorCount: processorCount,
            physicalMemory: physicalMemory
        )
        
        let supportsMetalGPU = checkMetalGPUSupport()
        let supportsNeuralEngine = checkNeuralEngineSupport(identifier: identifier)
        
        // Calculate memory limits based on available RAM
        let maxMemoryUsage = Int64(Double(physicalMemory) * 0.3) // Use max 30% of RAM
        let recommendedModelSize = min(performanceTier.maxModelSize, maxMemoryUsage)
        
        return DeviceCapabilityConfiguration(
            performanceTier: performanceTier,
            supportsMetalGPU: supportsMetalGPU,
            supportsNeuralEngine: supportsNeuralEngine,
            maxMemoryUsage: maxMemoryUsage,
            recommendedModelSize: recommendedModelSize,
            maxConcurrentInferences: performanceTier.maxBatchSize,
            adaptiveUIEnabled: true,
            thermalThrottlingEnabled: true
        )
    }
    
    private static func determinePerformanceTier(
        identifier: String,
        processorCount: Int,
        physicalMemory: UInt64
    ) -> DevicePerformanceTier {
        
        // iPhone 15 Pro/Pro Max (A17 Pro)
        if identifier.hasPrefix("iPhone16,") {
            return .ultra
        }
        
        // iPhone 15/15 Plus (A16 Bionic)
        if identifier.hasPrefix("iPhone15,") {
            return .high
        }
        
        // iPhone 14 Pro/Pro Max (A16 Bionic)
        if identifier.hasPrefix("iPhone14,") && (identifier.contains("iPhone14,7") || identifier.contains("iPhone14,8")) {
            return .high
        }
        
        // iPhone 14/14 Plus (A15 Bionic)
        if identifier.hasPrefix("iPhone14,") {
            return .medium
        }
        
        // iPhone 13 series (A15 Bionic)
        if identifier.hasPrefix("iPhone13,") {
            return .medium
        }
        
        // iPhone 12 series (A14 Bionic)
        if identifier.hasPrefix("iPhone12,") {
            return .medium
        }
        
        // iPhone 11 series (A13 Bionic)
        if identifier.hasPrefix("iPhone11,") {
            return .medium
        }
        
        // iPhone XS/XR series (A12 Bionic)
        if identifier.hasPrefix("iPhone10,") {
            return .low
        }
        
        // Fallback based on memory and processor count
        let memoryGB = physicalMemory / 1_073_741_824
        
        if memoryGB >= 8 && processorCount >= 6 {
            return .ultra
        } else if memoryGB >= 6 && processorCount >= 6 {
            return .high
        } else if memoryGB >= 4 && processorCount >= 4 {
            return .medium
        } else {
            return .low
        }
    }
    
    private static func checkMetalGPUSupport() -> Bool {
        guard let device = MTLCreateSystemDefaultDevice() else {
            return false
        }
        return device.supportsFamily(.apple4) // A11 Bionic and later
    }
    
    private static func checkNeuralEngineSupport(identifier: String) -> Bool {
        // Neural Engine available on A12 Bionic and later (iPhone XS and newer)
        return !identifier.hasPrefix("iPhone9,") && !identifier.hasPrefix("iPhone8,") && !identifier.hasPrefix("iPhone7,")
    }
    
    // MARK: - Monitoring Setup
    
    private func setupMonitoring() {
        setupThermalStateMonitoring()
        setupMemoryPressureMonitoring()
        setupBatteryMonitoring()
    }
    
    private func setupThermalStateMonitoring() {
        // Monitor thermal state changes
        thermalStateObserver = NotificationCenter.default.addObserver(forName: ProcessInfo.thermalStateDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.updateThermalState()
            }
        }
        
        updateThermalState()
    }
    
    private func setupMemoryPressureMonitoring() {
        // Monitor memory warnings
        memoryWarningObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleMemoryWarning()
            }
        }
        
        // Start periodic memory monitoring
        Timer.publish(every: 5.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateMemoryPressure()
            }
            .store(in: &cancellables)
    }
    
    private func setupBatteryMonitoring() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        
        batteryStateObserver = NotificationCenter.default.addObserver(
            forName: UIDevice.batteryStateDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.updateBatteryState()
            }
        }
        
        // Monitor low power mode
        NotificationCenter.default.addObserver(
            forName: .NSProcessInfoPowerStateDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.updatePowerState()
            }
        }
        
        updateBatteryState()
        updatePowerState()
    }
    
    // MARK: - State Updates
    
    private func updateThermalState() {
        let processInfoState = ProcessInfo.processInfo.thermalState
        
        switch processInfoState {
        case .nominal:
            thermalState = .nominal
        case .fair:
            thermalState = .fair
        case .serious:
            thermalState = .serious
        case .critical:
            thermalState = .critical
        @unknown default:
            thermalState = .nominal
        }
        
        updateThrottlingState()
        logger.logSystemInfo()
    }
    
    private func updateMemoryPressure() {
        let memoryInfo = getMemoryInfo()
        let usedMemory = memoryInfo.used
        let totalMemory = memoryInfo.total
        
        memoryPressure = Float(usedMemory) / Float(totalMemory)
        
        // Trigger throttling if memory usage is high
        if memoryPressure > 0.85 {
            isThrottling = true
        } else if memoryPressure < 0.7 {
            isThrottling = false
        }
    }
    
    private func updateBatteryState() {
        batteryLevel = UIDevice.current.batteryLevel
    }
    
    private func updatePowerState() {
        isLowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled
        updateThrottlingState()
    }
    
    private func updateThrottlingState() {
        let shouldThrottle = thermalState == .serious || 
                           thermalState == .critical || 
                           isLowPowerModeEnabled ||
                           memoryPressure > 0.8
        
        if shouldThrottle != isThrottling {
            isThrottling = shouldThrottle
            notifyPerformanceChange()
        }
    }
    
    private func handleMemoryWarning() {
        logger.logError(LLMAppError.memoryAllocationFailed)
        
        // Trigger immediate memory cleanup
        NotificationCenter.default.post(
            name: .memoryWarningReceived,
            object: nil
        )
        
        // Enable throttling temporarily
        isThrottling = true
        
        // Re-evaluate throttling after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) { [weak self] in
            self?.updateThrottlingState()
        }
    }
    
    // MARK: - Performance Optimization
    
    func getOptimizedConfiguration() -> DeviceCapabilityConfiguration {
        var config = currentConfiguration
        
        // Apply thermal throttling
        if isThrottling {
            let multiplier = thermalState.performanceMultiplier
            
            // Reduce performance parameters
            config = DeviceCapabilityConfiguration(
                performanceTier: config.performanceTier,
                supportsMetalGPU: config.supportsMetalGPU,
                supportsNeuralEngine: config.supportsNeuralEngine,
                maxMemoryUsage: Int64(Double(config.maxMemoryUsage) * multiplier),
                recommendedModelSize: Int64(Double(config.recommendedModelSize) * multiplier),
                maxConcurrentInferences: max(1, Int(Double(config.maxConcurrentInferences) * multiplier)),
                adaptiveUIEnabled: config.adaptiveUIEnabled,
                thermalThrottlingEnabled: config.thermalThrottlingEnabled
            )
        }
        
        return config
    }
    
    func shouldUseGPUAcceleration() -> Bool {
        return currentConfiguration.supportsMetalGPU && 
               !isThrottling && 
               thermalState != .critical
    }
    
    func shouldUseNeuralEngine() -> Bool {
        return currentConfiguration.supportsNeuralEngine && 
               !isThrottling && 
               thermalState != .critical
    }
    
    func getRecommendedModelSize() -> Int64 {
        let config = getOptimizedConfiguration()
        return config.recommendedModelSize
    }
    
    func getOptimalThreadCount() -> Int {
        let config = getOptimizedConfiguration()
        let baseThreads = config.threadCount
        
        if isThrottling {
            return max(1, baseThreads / 2)
        }
        
        return baseThreads
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
            return (used: info.resident_size, total: physicalMemory)
        }
        
        return (used: 0, total: physicalMemory)
    }
    
    private func notifyPerformanceChange() {
        NotificationCenter.default.post(
            name: .devicePerformanceChanged,
            object: self,
            userInfo: [
                "isThrottling": isThrottling,
                "thermalState": thermalState,
                "memoryPressure": memoryPressure
            ]
        )
    }
    
    private func logDeviceCapabilities() {
        let message = """
        Device Capabilities Detected:
        Model: \(deviceModel)
        Identifier: \(deviceIdentifier)
        iOS Version: \(systemVersion)
        Performance Tier: \(currentConfiguration.performanceTier.description)
        Processor Cores: \(processorCount)
        Physical Memory: \(formatBytes(physicalMemory))
        Max Memory Usage: \(formatBytes(currentConfiguration.maxMemoryUsage))
        Metal GPU Support: \(currentConfiguration.supportsMetalGPU)
        Neural Engine Support: \(currentConfiguration.supportsNeuralEngine)
        Recommended Model Size: \(formatBytes(currentConfiguration.recommendedModelSize))
        Max Context Length: \(currentConfiguration.contextLength)
        Recommended Threads: \(currentConfiguration.threadCount)
        """
        
        logger.logSystemInfo()
        print(message)
    }
    
    private func formatBytes(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: Int64(bytes))
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: bytes)
    }
    
    // MARK: - Cleanup
    
    deinit {
        if let observer = thermalStateObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = memoryWarningObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = batteryStateObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let devicePerformanceChanged = Notification.Name("devicePerformanceChanged")
    static let memoryWarningReceived = Notification.Name("memoryWarningReceived")
    static let thermalStateChanged = Notification.Name("thermalStateChanged")
}

// MARK: - Metal Import

import Metal
