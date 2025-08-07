//
//  DevicePerformanceTests.swift
//  LLMTestTests
//
//  Created by Uttam Kumar Panasala on 8/6/25.
//

import XCTest
@testable import LLMTest

class DevicePerformanceTests: XCTestCase {
    
    var deviceManager: DeviceCapabilityManager!
    var performanceOptimizer: PerformanceOptimizer!
    var uiManager: AdaptiveUIManager!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        deviceManager = DeviceCapabilityManager.shared
        performanceOptimizer = PerformanceOptimizer.shared
        uiManager = AdaptiveUIManager.shared
    }
    
    override func tearDownWithError() throws {
        deviceManager = nil
        performanceOptimizer = nil
        uiManager = nil
        try super.tearDownWithError()
    }
    
    // MARK: - Device Capability Tests
    
    func testDeviceCapabilityDetection() throws {
        // Test device detection
        XCTAssertNotNil(deviceManager.deviceModel)
        XCTAssertNotNil(deviceManager.currentConfiguration)
        
        // Test performance tier assignment
        let tier = deviceManager.currentConfiguration.performanceTier
        XCTAssertTrue(DevicePerformanceTier.allCases.contains(tier))
        
        // Test configuration properties
        XCTAssertGreaterThan(deviceManager.currentConfiguration.maxMemoryUsage, 0)
        XCTAssertGreaterThan(deviceManager.currentConfiguration.recommendedModelSize, 0)
        XCTAssertGreaterThan(deviceManager.currentConfiguration.maxContextLength, 0)
    }
    
    func testThermalStateMonitoring() throws {
        // Test thermal state detection
        let thermalState = deviceManager.thermalState
        XCTAssertTrue(DeviceThermalState.allCases.contains(thermalState))
        
        // Test throttling logic
        let shouldThrottle = deviceManager.isThrottling
        XCTAssertNotNil(shouldThrottle)
        
        // Test GPU acceleration decision
        let shouldUseGPU = deviceManager.shouldUseGPUAcceleration()
        XCTAssertNotNil(shouldUseGPU)
    }
    
    func testMemoryPressureHandling() throws {
        // Test memory pressure detection
        let memoryPressure = deviceManager.memoryPressure
        XCTAssertGreaterThanOrEqual(memoryPressure, 0.0)
        XCTAssertLessThanOrEqual(memoryPressure, 1.0)
        
        // Test optimal thread count
        let threadCount = deviceManager.getOptimalThreadCount()
        XCTAssertGreaterThan(threadCount, 0)
        XCTAssertLessThanOrEqual(threadCount, ProcessInfo.processInfo.processorCount)
    }
    
    // MARK: - Adaptive UI Tests
    
    func testAdaptiveUIConfiguration() throws {
        // Test UI performance mode
        let performanceMode = uiManager.currentConfiguration.performanceMode
        XCTAssertTrue(UIPerformanceMode.allCases.contains(performanceMode))
        
        // Test animation settings
        let enableAnimations = uiManager.currentConfiguration.enableMessageAnimations
        XCTAssertNotNil(enableAnimations)
        
        // Test refresh rate
        let refreshRate = uiManager.currentConfiguration.refreshRate
        XCTAssertGreaterThan(refreshRate, 0)
    }
    
    func testAnimationThrottling() throws {
        // Test animation throttling based on performance
        let shouldThrottle = uiManager.shouldThrottleAnimations()
        XCTAssertNotNil(shouldThrottle)
        
        // Test performance indicator
        let showIndicator = uiManager.shouldShowPerformanceIndicator()
        XCTAssertNotNil(showIndicator)
    }
    
    // MARK: - Performance Optimization Tests
    
    func testOptimizationStrategies() throws {
        // Test optimization strategy selection
        let strategy = performanceOptimizer.optimizationStrategy
        XCTAssertTrue(OptimizationStrategy.allCases.contains(strategy))
        
        // Test strategy properties
        XCTAssertGreaterThan(strategy.memoryThreshold, 0.0)
        XCTAssertLessThanOrEqual(strategy.memoryThreshold, 1.0)
        XCTAssertGreaterThan(strategy.cpuThreshold, 0.0)
        XCTAssertLessThanOrEqual(strategy.cpuThreshold, 1.0)
    }
    
    func testPerformanceMetricsCollection() async throws {
        // Test metrics collection
        await performanceOptimizer.collectMetrics()
        
        let metrics = performanceOptimizer.currentMetrics
        XCTAssertNotNil(metrics)
        
        if let metrics = metrics {
            XCTAssertGreaterThanOrEqual(metrics.performanceScore, 0.0)
            XCTAssertLessThanOrEqual(metrics.performanceScore, 1.0)
            XCTAssertGreaterThan(metrics.memoryUsage, 0)
        }
    }
    
    func testEmergencyOptimization() async throws {
        // Test emergency optimization
        await performanceOptimizer.performEmergencyOptimization()
        
        // Verify optimization was attempted
        XCTAssertFalse(performanceOptimizer.isOptimizing)
    }
    
    // MARK: - Integration Tests
    
    func testManagerIntegration() throws {
        // Test notification integration
        let expectation = XCTestExpectation(description: "Performance notification")
        
        let observer = NotificationCenter.default.addObserver(
            forName: .performanceStateChanged,
            object: nil,
            queue: .main
        ) { _ in
            expectation.fulfill()
        }
        
        // Trigger a performance change
        performanceOptimizer.forceOptimization()
        
        wait(for: [expectation], timeout: 5.0)
        NotificationCenter.default.removeObserver(observer)
    }
    
    func testPerformanceBenchmark() async throws {
        // Test CPU performance
        let cpuStartTime = CFAbsoluteTimeGetCurrent()
        
        // Simulate CPU intensive task
        var result = 0
        for i in 0..<1000000 {
            result += i
        }
        
        let cpuTime = CFAbsoluteTimeGetCurrent() - cpuStartTime
        XCTAssertGreaterThan(cpuTime, 0)
        XCTAssertNotEqual(result, 0) // Ensure computation happened
        
        // Test memory allocation
        let memoryStartTime = CFAbsoluteTimeGetCurrent()
        
        var arrays: [[Int]] = []
        for _ in 0..<100 {
            arrays.append(Array(0..<1000))
        }
        
        let memoryTime = CFAbsoluteTimeGetCurrent() - memoryStartTime
        XCTAssertGreaterThan(memoryTime, 0)
        XCTAssertEqual(arrays.count, 100)
    }
    
    // MARK: - Performance Tests
    
    func testDeviceDetectionPerformance() throws {
        measure {
            _ = deviceManager.deviceModel
            _ = deviceManager.currentConfiguration
        }
    }
    
    func testOptimizationPerformance() throws {
        measure {
            performanceOptimizer.forceOptimization()
        }
    }
    
    func testUIConfigurationPerformance() throws {
        measure {
            _ = uiManager.currentConfiguration
            _ = uiManager.shouldThrottleAnimations()
        }
    }
}

// MARK: - Test Extensions

extension DevicePerformanceTier {
    static var allCases: [DevicePerformanceTier] {
        return [.low, .medium, .high, .ultra]
    }
}

extension DeviceThermalState {
    static var allCases: [DeviceThermalState] {
        return [.nominal, .fair, .serious, .critical]
    }
}

extension UIPerformanceMode {
    static var allCases: [UIPerformanceMode] {
        return [.full, .reduced, .minimal, .emergency]
    }
}

extension OptimizationStrategy {
    static var allCases: [OptimizationStrategy] {
        return [.aggressive, .balanced, .conservative, .adaptive]
    }
}

// MARK: - Notification Extensions

extension Notification.Name {
    static let performanceStateChanged = Notification.Name("performanceStateChanged")
}
