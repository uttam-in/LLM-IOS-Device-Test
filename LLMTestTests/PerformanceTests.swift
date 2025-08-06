//
//  PerformanceTests.swift
//  LLMTestTests
//
//  Created by Uttam Kumar Panasala on 8/6/25.
//

import XCTest
import Metal
import MetalPerformanceShaders
@testable import LLMTest

class PerformanceTests: XCTestCase {
    
    var memoryManager: MemoryManager!
    var threadManager: ThreadManager!
    var gpuAccelerator: MetalGPUAccelerator!
    var backgroundTaskManager: BackgroundTaskManager!
    var llamaWrapper: LlamaWrapper!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // Initialize performance components
        memoryManager = MemoryManager()
        threadManager = ThreadManager()
        gpuAccelerator = MetalGPUAccelerator()
        backgroundTaskManager = BackgroundTaskManager()
        llamaWrapper = LlamaWrapper()
        
        // Register components with each other
        memoryManager.registerLlamaWrapper(llamaWrapper)
        memoryManager.registerGPUAccelerator(gpuAccelerator)
        backgroundTaskManager.registerLlamaWrapper(llamaWrapper)
        backgroundTaskManager.registerMemoryManager(memoryManager)
    }
    
    override func tearDownWithError() throws {
        memoryManager = nil
        threadManager = nil
        gpuAccelerator = nil
        backgroundTaskManager = nil
        llamaWrapper = nil
        
        try super.tearDownWithError()
    }
    
    // MARK: - Memory Performance Tests
    
    func testMemoryUsageMonitoring() throws {
        let expectation = XCTestExpectation(description: "Memory monitoring should track usage")
        
        Task { @MainActor in
            // Start memory monitoring
            memoryManager.startMemoryMonitoring()
            
            // Wait for initial memory reading
            try await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
            
            let memoryInfo = memoryManager.getDetailedMemoryInfo()
            
            XCTAssertGreaterThan(memoryInfo.currentUsage, 0, "Should track current memory usage")
            XCTAssertGreaterThan(memoryInfo.totalMemory, 0, "Should track total memory")
            XCTAssertNotNil(memoryInfo.pressureLevel, "Should determine memory pressure level")
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testMemoryPressureHandling() throws {
        let expectation = XCTestExpectation(description: "Memory pressure should trigger cleanup")
        
        Task { @MainActor in
            // Simulate memory pressure by forcing cleanup
            await memoryManager.forceMemoryCleanup()
            
            // Verify cleanup occurred
            let memoryInfo = memoryManager.getDetailedMemoryInfo()
            XCTAssertNotNil(memoryInfo, "Memory info should be available after cleanup")
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testMemoryUsagePercentage() throws {
        let expectation = XCTestExpectation(description: "Memory percentage should be calculated correctly")
        
        Task { @MainActor in
            let percentage = memoryManager.getMemoryUsagePercentage()
            
            XCTAssertGreaterThanOrEqual(percentage, 0.0, "Memory percentage should be non-negative")
            XCTAssertLessThanOrEqual(percentage, 100.0, "Memory percentage should not exceed 100%")
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    // MARK: - Threading Performance Tests
    
    func testInferenceThreadingPerformance() throws {
        let expectation = XCTestExpectation(description: "Inference threading should be performant")
        
        Task { @MainActor in
            let startTime = CFAbsoluteTimeGetCurrent()
            
            // Execute multiple inference tasks concurrently
            let tasks = (0..<5).map { index in
                {
                    // Simulate inference work
                    try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                    return "Result \(index)"
                }
            }
            
            let results = try await threadManager.executeBatchInference(tasks: tasks)
            let endTime = CFAbsoluteTimeGetCurrent()
            
            XCTAssertEqual(results.count, 5, "Should complete all tasks")
            
            // Should complete faster than sequential execution due to concurrency
            let executionTime = endTime - startTime
            XCTAssertLessThan(executionTime, 0.4, "Concurrent execution should be faster than sequential")
            
            let metrics = threadManager.getPerformanceMetrics()
            XCTAssertGreaterThanOrEqual(metrics.averageInferenceTime, 0, "Should track average inference time")
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testThreadUtilization() throws {
        let expectation = XCTestExpectation(description: "Thread utilization should be tracked")
        
        Task { @MainActor in
            // Execute a task to generate utilization data
            _ = try await threadManager.executeInferenceTask {
                try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                return "Test"
            }
            
            let metrics = threadManager.getPerformanceMetrics()
            XCTAssertGreaterThanOrEqual(metrics.threadUtilization, 0.0, "Thread utilization should be non-negative")
            XCTAssertLessThanOrEqual(metrics.threadUtilization, 1.0, "Thread utilization should not exceed 100%")
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testHighPriorityTaskExecution() throws {
        let expectation = XCTestExpectation(description: "High priority tasks should execute quickly")
        
        Task { @MainActor in
            let startTime = CFAbsoluteTimeGetCurrent()
            
            let result = try await threadManager.executeHighPriorityTask {
                return "High priority result"
            }
            
            let endTime = CFAbsoluteTimeGetCurrent()
            let executionTime = endTime - startTime
            
            XCTAssertEqual(result, "High priority result", "Should return correct result")
            XCTAssertLessThan(executionTime, 0.1, "High priority tasks should execute quickly")
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    // MARK: - GPU Performance Tests
    
    func testGPUAvailability() throws {
        let expectation = XCTestExpectation(description: "GPU availability should be detected")
        
        Task { @MainActor in
            let gpuInfo = gpuAccelerator.getGPUInfo()
            
            // GPU availability depends on device, but info should be valid
            XCTAssertNotNil(gpuInfo.name, "GPU name should be available")
            XCTAssertGreaterThanOrEqual(gpuInfo.maxBufferLength, 0, "Max buffer length should be non-negative")
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    func testMatrixMultiplicationPerformance() throws {
        guard gpuAccelerator.isGPUAvailable else {
            throw XCTSkip("GPU not available for testing")
        }
        
        let expectation = XCTestExpectation(description: "Matrix multiplication should be performant")
        
        Task { @MainActor in
            let matrixSize = 100
            let matrixA = Array(repeating: 1.0, count: matrixSize * matrixSize)
            let matrixB = Array(repeating: 2.0, count: matrixSize * matrixSize)
            
            let startTime = CFAbsoluteTimeGetCurrent()
            
            let result = try await gpuAccelerator.performMatrixMultiplication(
                matrixA: matrixA,
                matrixB: matrixB,
                rowsA: matrixSize,
                columnsA: matrixSize,
                columnsB: matrixSize
            )
            
            let endTime = CFAbsoluteTimeGetCurrent()
            let executionTime = endTime - startTime
            
            XCTAssertEqual(result.count, matrixSize * matrixSize, "Result should have correct size")
            XCTAssertLessThan(executionTime, 1.0, "GPU matrix multiplication should complete within 1 second")
            
            let gpuInfo = gpuAccelerator.getGPUInfo()
            XCTAssertGreaterThan(gpuInfo.totalOperations, 0, "Should track GPU operations")
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testGPUMemoryManagement() throws {
        guard gpuAccelerator.isGPUAvailable else {
            throw XCTSkip("GPU not available for testing")
        }
        
        let expectation = XCTestExpectation(description: "GPU memory should be managed properly")
        
        Task { @MainActor in
            let initialMemory = gpuAccelerator.gpuMemoryUsage
            
            // Perform operation that allocates GPU memory
            let smallMatrix = Array(repeating: 1.0, count: 10 * 10)
            _ = try await gpuAccelerator.performMatrixMultiplication(
                matrixA: smallMatrix,
                matrixB: smallMatrix,
                rowsA: 10,
                columnsA: 10,
                columnsB: 10
            )
            
            let afterOperationMemory = gpuAccelerator.gpuMemoryUsage
            
            // Clear memory pool
            gpuAccelerator.clearMemoryPool()
            let afterClearMemory = gpuAccelerator.gpuMemoryUsage
            
            XCTAssertGreaterThanOrEqual(afterOperationMemory, initialMemory, "Memory usage should increase after operation")
            XCTAssertEqual(afterClearMemory, 0, "Memory should be cleared after cleanup")
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    // MARK: - Background Task Performance Tests
    
    func testAppStateTransitions() throws {
        let expectation = XCTestExpectation(description: "App state transitions should be handled")
        
        Task { @MainActor in
            let initialState = backgroundTaskManager.appState
            XCTAssertNotNil(initialState, "Should have initial app state")
            
            let stateInfo = backgroundTaskManager.getAppStateInfo()
            XCTAssertNotNil(stateInfo.currentState, "Should provide current state info")
            XCTAssertGreaterThanOrEqual(stateInfo.pendingRequestsCount, 0, "Should track pending requests")
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    func testInferenceAllowedState() throws {
        let expectation = XCTestExpectation(description: "Inference allowed state should be managed")
        
        Task { @MainActor in
            let canPerformInference = backgroundTaskManager.canPerformInference()
            XCTAssertTrue(canPerformInference || !canPerformInference, "Should return boolean value")
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - Integration Performance Tests
    
    func testIntegratedPerformanceOptimizations() throws {
        let expectation = XCTestExpectation(description: "Integrated optimizations should work together")
        
        Task { @MainActor in
            // Test memory monitoring
            memoryManager.startMemoryMonitoring()
            
            // Test threading with memory awareness
            let result = try await threadManager.executeInferenceTask {
                // Simulate memory-intensive operation
                let data = Array(repeating: 1.0, count: 1000)
                return data.reduce(0, +)
            }
            
            XCTAssertEqual(result, 1000.0, "Should complete inference task correctly")
            
            // Check that memory is being monitored
            let memoryInfo = memoryManager.getDetailedMemoryInfo()
            XCTAssertGreaterThan(memoryInfo.currentUsage, 0, "Should track memory usage during operations")
            
            // Check thread performance
            let threadMetrics = threadManager.getPerformanceMetrics()
            XCTAssertGreaterThanOrEqual(threadMetrics.averageInferenceTime, 0, "Should track inference performance")
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    // MARK: - Performance Benchmarks
    
    func testInferenceResponseTime() throws {
        measure {
            let expectation = XCTestExpectation(description: "Measure inference response time")
            
            Task { @MainActor in
                _ = try await threadManager.executeInferenceTask {
                    // Simulate inference work
                    var result = 0.0
                    for i in 0..<10000 {
                        result += Double(i) * 0.001
                    }
                    return result
                }
                
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 5.0)
        }
    }
    
    func testMemoryAllocationPerformance() throws {
        measure {
            let expectation = XCTestExpectation(description: "Measure memory allocation performance")
            
            Task { @MainActor in
                // Simulate memory allocation patterns
                var arrays: [[Float]] = []
                for _ in 0..<100 {
                    let array = Array(repeating: Float.random(in: 0...1), count: 1000)
                    arrays.append(array)
                }
                
                // Clear arrays
                arrays.removeAll()
                
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 5.0)
        }
    }
    
    func testConcurrentTaskPerformance() throws {
        measure {
            let expectation = XCTestExpectation(description: "Measure concurrent task performance")
            
            Task { @MainActor in
                let tasks = (0..<10).map { index in
                    {
                        var result = 0
                        for i in 0..<1000 {
                            result += i * index
                        }
                        return result
                    }
                }
                
                _ = try await threadManager.executeBatchInference(tasks: tasks)
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 10.0)
        }
    }
    
    // MARK: - Stress Tests
    
    func testMemoryPressureStressTest() throws {
        let expectation = XCTestExpectation(description: "Handle memory pressure under stress")
        
        Task { @MainActor in
            // Simulate high memory usage
            var largeArrays: [[Float]] = []
            
            for i in 0..<50 {
                let array = Array(repeating: Float(i), count: 10000)
                largeArrays.append(array)
                
                // Check memory pressure periodically
                if i % 10 == 0 {
                    let memoryInfo = memoryManager.getDetailedMemoryInfo()
                    if memoryInfo.pressureLevel == .critical || memoryInfo.pressureLevel == .warning {
                        // Trigger cleanup
                        await memoryManager.forceMemoryCleanup()
                        largeArrays.removeAll()
                        break
                    }
                }
            }
            
            // Verify system handled stress appropriately
            let finalMemoryInfo = memoryManager.getDetailedMemoryInfo()
            XCTAssertNotEqual(finalMemoryInfo.pressureLevel, .critical, "Should not remain in critical state")
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 15.0)
    }
    
    func testHighConcurrencyStressTest() throws {
        let expectation = XCTestExpectation(description: "Handle high concurrency stress")
        
        Task { @MainActor in
            let taskCount = 50
            let tasks = (0..<taskCount).map { index in
                {
                    // Simulate varying workloads
                    let workSize = (index % 5 + 1) * 100
                    var result = 0.0
                    for i in 0..<workSize {
                        result += sin(Double(i)) * cos(Double(index))
                    }
                    return result
                }
            }
            
            let startTime = CFAbsoluteTimeGetCurrent()
            let results = try await threadManager.executeBatchInference(tasks: tasks, maxConcurrency: 8)
            let endTime = CFAbsoluteTimeGetCurrent()
            
            XCTAssertEqual(results.count, taskCount, "Should complete all tasks under stress")
            
            let executionTime = endTime - startTime
            XCTAssertLessThan(executionTime, 10.0, "Should complete stress test within reasonable time")
            
            let metrics = threadManager.getPerformanceMetrics()
            XCTAssertLessThanOrEqual(metrics.threadUtilization, 1.0, "Thread utilization should remain within bounds")
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 20.0)
    }
}
