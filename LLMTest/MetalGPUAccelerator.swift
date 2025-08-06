//
//  MetalGPUAccelerator.swift
//  LLMTest
//
//  Created by Uttam Kumar Panasala on 8/6/25.
//

import Foundation
import Metal
import MetalPerformanceShaders
import Accelerate

// MARK: - Metal GPU Accelerator

/// Provides GPU acceleration for LLM inference using Metal Performance Shaders
@MainActor
class MetalGPUAccelerator: ObservableObject {
    
    // MARK: - Properties
    
    @Published var isGPUAvailable: Bool = false
    @Published var gpuMemoryUsage: Int64 = 0
    @Published var isGPUEnabled: Bool = false
    
    private var device: MTLDevice?
    private var commandQueue: MTLCommandQueue?
    private var library: MTLLibrary?
    
    // Metal Performance Shaders
    private var matrixMultiplication: MPSMatrixMultiplication?
    private var neuralNetworkGraph: MPSNNGraph?
    
    // Memory management
    private var allocatedBuffers: [MTLBuffer] = []
    private var bufferPool: [MTLBuffer] = []
    private let maxBufferPoolSize = 10
    
    // Performance monitoring
    private var lastGPUOperationTime: CFTimeInterval = 0
    private var totalGPUOperations: Int = 0
    
    // MARK: - Initialization
    
    init() {
        setupMetal()
    }
    
    deinit {
        Task { @MainActor in
            cleanup()
        }
    }
    
    private func setupMetal() {
        // Get the default Metal device
        guard let metalDevice = MTLCreateSystemDefaultDevice() else {
            print("Metal is not supported on this device")
            isGPUAvailable = false
            return
        }
        
        device = metalDevice
        commandQueue = metalDevice.makeCommandQueue()
        
        // Check if Metal Performance Shaders are supported
        guard MPSSupportsMTLDevice(metalDevice) else {
            print("Metal Performance Shaders not supported on this device")
            isGPUAvailable = false
            return
        }
        
        // Create default library
        library = metalDevice.makeDefaultLibrary()
        
        isGPUAvailable = true
        isGPUEnabled = true
        
        print("Metal GPU Accelerator initialized successfully")
        print("GPU: \(metalDevice.name)")
        print("Max buffer length: \(metalDevice.maxBufferLength)")
        print("Supports unified memory: \(metalDevice.hasUnifiedMemory)")
    }
    
    // MARK: - GPU Operations
    
    /// Perform matrix multiplication using Metal Performance Shaders
    func performMatrixMultiplication(
        matrixA: [Float],
        matrixB: [Float],
        rowsA: Int,
        columnsA: Int,
        columnsB: Int
    ) async throws -> [Float] {
        guard isGPUAvailable && isGPUEnabled,
              let device = device,
              let commandQueue = commandQueue else {
            throw MetalGPUError.gpuNotAvailable
        }
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                do {
                    // Create matrix descriptors
                    let matrixADescriptor = MPSMatrixDescriptor(
                        rows: rowsA,
                        columns: columnsA,
                        rowBytes: columnsA * MemoryLayout<Float>.stride,
                        dataType: .float32
                    )
                    
                    let matrixBDescriptor = MPSMatrixDescriptor(
                        rows: columnsA,
                        columns: columnsB,
                        rowBytes: columnsB * MemoryLayout<Float>.stride,
                        dataType: .float32
                    )
                    
                    let resultDescriptor = MPSMatrixDescriptor(
                        rows: rowsA,
                        columns: columnsB,
                        rowBytes: columnsB * MemoryLayout<Float>.stride,
                        dataType: .float32
                    )
                    
                    // Create buffers
                    guard let strongSelf = self else {
                        throw MetalGPUError.gpuNotAvailable
                    }
                    let bufferA = try strongSelf.createBuffer(from: matrixA, device: device)
                    let bufferB = try strongSelf.createBuffer(from: matrixB, device: device)
                    let resultBuffer = device.makeBuffer(
                        length: rowsA * columnsB * MemoryLayout<Float>.stride,
                        options: .storageModeShared
                    )
                    
                    guard let resultBuffer = resultBuffer else {
                        throw MetalGPUError.bufferCreationFailed
                    }
                    
                    // Create matrices
                    let matrixA = MPSMatrix(buffer: bufferA, descriptor: matrixADescriptor)
                    let matrixB = MPSMatrix(buffer: bufferB, descriptor: matrixBDescriptor)
                    let resultMatrix = MPSMatrix(buffer: resultBuffer, descriptor: resultDescriptor)
                    
                    // Create matrix multiplication kernel
                    let matrixMultiplication = MPSMatrixMultiplication(
                        device: device,
                        transposeLeft: false,
                        transposeRight: false,
                        resultRows: rowsA,
                        resultColumns: columnsB,
                        interiorColumns: columnsA,
                        alpha: 1.0,
                        beta: 0.0
                    )
                    
                    // Create command buffer and encode operation
                    guard let commandBuffer = commandQueue.makeCommandBuffer() else {
                        throw MetalGPUError.commandBufferCreationFailed
                    }
                    
                    matrixMultiplication.encode(
                        commandBuffer: commandBuffer,
                        leftMatrix: matrixA,
                        rightMatrix: matrixB,
                        resultMatrix: resultMatrix
                    )
                    
                    // Commit and wait for completion
                    commandBuffer.commit()
                    commandBuffer.waitUntilCompleted()
                    
                    // Extract results
                    let resultPointer = resultBuffer.contents().bindMemory(
                        to: Float.self,
                        capacity: rowsA * columnsB
                    )
                    let result = Array(UnsafeBufferPointer(start: resultPointer, count: rowsA * columnsB))
                    
                    // Update performance metrics
                    let operationTime = CFAbsoluteTimeGetCurrent() - startTime
                    Task { @MainActor in
                        self?.lastGPUOperationTime = operationTime
                        self?.totalGPUOperations += 1
                        self?.updateMemoryUsage()
                    }
                    
                    continuation.resume(returning: result)
                    
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// Perform neural network inference using Metal Performance Shaders
    func performNeuralNetworkInference(
        input: [Float],
        weights: [[Float]],
        biases: [Float]
    ) async throws -> [Float] {
        guard isGPUAvailable && isGPUEnabled,
              let device = device,
              let commandQueue = commandQueue else {
            throw MetalGPUError.gpuNotAvailable
        }
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                do {
                    // Create neural network layers
                    var layers: [MPSCNNKernel] = []
                    
                    // For simplicity, we'll create a basic fully connected layer
                    // In a real implementation, this would be more sophisticated
                    let inputChannels = input.count
                    let outputChannels = biases.count
                    
                    // Create convolution descriptor for fully connected layer
                    let convDesc = MPSCNNConvolutionDescriptor(
                        kernelWidth: 1,
                        kernelHeight: 1,
                        inputFeatureChannels: inputChannels,
                        outputFeatureChannels: outputChannels
                    )
                    
                    // Create weight and bias data
                    let weightData = weights.flatMap { $0 }
                    let weightDataSource = BasicWeightDataSource(
                        weights: weightData,
                        biases: biases
                    )
                    
                    let convolution = MPSCNNConvolution(
                        device: device,
                        convolutionDescriptor: convDesc,
                        kernelWeights: weightDataSource.weights,
                        biasTerms: weightDataSource.biases,
                        flags: .none
                    )
                    
                    layers.append(convolution)
                    
                    // Create input and output images
                    let inputImageDesc = MPSImageDescriptor(
                        channelFormat: .float32,
                        width: 1,
                        height: 1,
                        featureChannels: inputChannels
                    )
                    
                    let outputImageDesc = MPSImageDescriptor(
                        channelFormat: .float32,
                        width: 1,
                        height: 1,
                        featureChannels: outputChannels
                    )
                    
                    let inputImage = MPSImage(device: device, imageDescriptor: inputImageDesc)
                    let outputImage = MPSImage(device: device, imageDescriptor: outputImageDesc)
                    
                    // Copy input data to GPU
                    let inputBuffer = try self?.createBuffer(from: input, device: device)
                    guard let inputBuffer = inputBuffer else {
                        throw MetalGPUError.bufferCreationFailed
                    }
                    
                    // Create command buffer
                    guard let commandBuffer = commandQueue.makeCommandBuffer() else {
                        throw MetalGPUError.commandBufferCreationFailed
                    }
                    
                    // Encode neural network operations
                    for layer in layers {
                        layer.encode(commandBuffer: commandBuffer, sourceImage: inputImage, destinationImage: outputImage)
                    }
                    
                    // Commit and wait
                    commandBuffer.commit()
                    commandBuffer.waitUntilCompleted()
                    
                    // Extract results (simplified)
                    let result = Array(repeating: Float(0.0), count: outputChannels) // Placeholder
                    
                    // Update performance metrics
                    let operationTime = CFAbsoluteTimeGetCurrent() - startTime
                    Task { @MainActor in
                        self?.lastGPUOperationTime = operationTime
                        self?.totalGPUOperations += 1
                        self?.updateMemoryUsage()
                    }
                    
                    continuation.resume(returning: result)
                    
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Memory Management
    
    private func createBuffer(from data: [Float], device: MTLDevice) throws -> MTLBuffer {
        let bufferSize = data.count * MemoryLayout<Float>.stride
        
        // Try to reuse buffer from pool
        if let reusableBuffer = bufferPool.first(where: { $0.length >= bufferSize }) {
            bufferPool.removeAll { $0 === reusableBuffer }
            return reusableBuffer
        }
        
        // Create new buffer
        guard let buffer = device.makeBuffer(bytes: data, length: bufferSize, options: .storageModeShared) else {
            throw MetalGPUError.bufferCreationFailed
        }
        
        allocatedBuffers.append(buffer)
        return buffer
    }
    
    private func returnBufferToPool(_ buffer: MTLBuffer) {
        if bufferPool.count < maxBufferPoolSize {
            bufferPool.append(buffer)
        }
    }
    
    private func updateMemoryUsage() {
        let totalMemory = allocatedBuffers.reduce(0) { $0 + $1.length }
        gpuMemoryUsage = Int64(totalMemory)
    }
    
    func clearMemoryPool() {
        bufferPool.removeAll()
        allocatedBuffers.removeAll()
        gpuMemoryUsage = 0
    }
    
    // MARK: - Configuration
    
    func setGPUEnabled(_ enabled: Bool) {
        isGPUEnabled = enabled && isGPUAvailable
    }
    
    func getGPUInfo() -> GPUInfo {
        return GPUInfo(
            name: device?.name ?? "Unknown",
            isAvailable: isGPUAvailable,
            isEnabled: isGPUEnabled,
            memoryUsage: gpuMemoryUsage,
            totalOperations: totalGPUOperations,
            lastOperationTime: lastGPUOperationTime,
            maxBufferLength: device?.maxBufferLength ?? 0,
            hasUnifiedMemory: device?.hasUnifiedMemory ?? false
        )
    }
    
    // MARK: - Cleanup
    
    private func cleanup() {
        clearMemoryPool()
        commandQueue = nil
        library = nil
        device = nil
    }
}

// MARK: - Supporting Types

struct GPUInfo {
    let name: String
    let isAvailable: Bool
    let isEnabled: Bool
    let memoryUsage: Int64
    let totalOperations: Int
    let lastOperationTime: CFTimeInterval
    let maxBufferLength: Int
    let hasUnifiedMemory: Bool
}

enum MetalGPUError: LocalizedError {
    case gpuNotAvailable
    case bufferCreationFailed
    case commandBufferCreationFailed
    case operationFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .gpuNotAvailable:
            return "GPU is not available or not enabled"
        case .bufferCreationFailed:
            return "Failed to create Metal buffer"
        case .commandBufferCreationFailed:
            return "Failed to create Metal command buffer"
        case .operationFailed(let reason):
            return "GPU operation failed: \(reason)"
        }
    }
}

// MARK: - Weight Data Source

class BasicWeightDataSource: NSObject {
    let weights: UnsafePointer<Float>
    let biases: UnsafePointer<Float>?
    
    private let weightData: [Float]
    private let biasData: [Float]
    
    init(weights: [Float], biases: [Float]) {
        self.weightData = weights
        self.biasData = biases
        self.weights = UnsafePointer(weightData)
        self.biases = UnsafePointer(biasData)
        super.init()
    }
}
