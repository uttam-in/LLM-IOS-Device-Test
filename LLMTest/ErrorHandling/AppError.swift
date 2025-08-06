//
//  AppError.swift
//  LLMTest
//
//  Created by Uttam Kumar Panasala on 8/6/25.
//

import Foundation

// MARK: - Core App Error Protocol

protocol AppError: LocalizedError {
    var errorCode: String { get }
    var userFriendlyMessage: String { get }
    var isRetryable: Bool { get }
    var severity: ErrorSeverity { get }
    var category: ErrorCategory { get }
    var underlyingError: Error? { get }
    var recoveryActions: [ErrorRecoveryAction] { get }
}

// MARK: - Error Severity

enum ErrorSeverity: String, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"
    
    var description: String {
        switch self {
        case .low:
            return "Low"
        case .medium:
            return "Medium"
        case .high:
            return "High"
        case .critical:
            return "Critical"
        }
    }
}

// MARK: - Error Category

enum ErrorCategory: String, CaseIterable {
    case network = "network"
    case storage = "storage"
    case model = "model"
    case gpu = "gpu"
    case memory = "memory"
    case user = "user"
    case system = "system"
    case chat = "chat"
    case export = "export"
    
    var description: String {
        switch self {
        case .network:
            return "Network"
        case .storage:
            return "Storage"
        case .model:
            return "Model"
        case .gpu:
            return "GPU"
        case .memory:
            return "Memory"
        case .user:
            return "User"
        case .system:
            return "System"
        case .chat:
            return "Chat"
        case .export:
            return "Export"
        }
    }
}

// MARK: - Error Recovery Actions

enum ErrorRecoveryAction: Equatable {
    case retry
    case retryWithDelay(TimeInterval)
    case redownloadModel(String)
    case clearCache
    case freeMemory
    case restartApp
    case checkNetworkConnection
    case checkStorageSpace
    case contactSupport
    case dismissError
    case navigateToSettings
    case switchToFallbackModel
    
    var title: String {
        switch self {
        case .retry:
            return "Try Again"
        case .retryWithDelay:
            return "Retry"
        case .redownloadModel:
            return "Redownload Model"
        case .clearCache:
            return "Clear Cache"
        case .freeMemory:
            return "Free Memory"
        case .restartApp:
            return "Restart App"
        case .checkNetworkConnection:
            return "Check Network"
        case .checkStorageSpace:
            return "Check Storage"
        case .contactSupport:
            return "Contact Support"
        case .dismissError:
            return "Dismiss"
        case .navigateToSettings:
            return "Open Settings"
        case .switchToFallbackModel:
            return "Use Different Model"
        }
    }
    
    var description: String {
        switch self {
        case .retry:
            return "Try the operation again"
        case .retryWithDelay(let delay):
            return "Wait \(Int(delay)) seconds and try again"
        case .redownloadModel(let modelName):
            return "Redownload the \(modelName) model"
        case .clearCache:
            return "Clear temporary files and cache"
        case .freeMemory:
            return "Free up device memory"
        case .restartApp:
            return "Restart the application"
        case .checkNetworkConnection:
            return "Check your internet connection"
        case .checkStorageSpace:
            return "Free up device storage space"
        case .contactSupport:
            return "Contact technical support"
        case .dismissError:
            return "Dismiss this error"
        case .navigateToSettings:
            return "Open app settings"
        case .switchToFallbackModel:
            return "Switch to a different model"
        }
    }
}

// MARK: - Comprehensive App Errors

enum LLMAppError: AppError {
    // Network Errors
    case networkUnavailable
    case networkTimeout
    case downloadFailed(String, Error?)
    case uploadFailed(String, Error?)
    case serverError(Int, String?)
    
    // Model Errors
    case modelNotFound(String)
    case modelLoadFailed(String, Error?)
    case modelCorrupted(String)
    case modelIncompatible(String, String)
    case modelDownloadFailed(String, Error?)
    case modelVerificationFailed(String)
    case modelAlreadyExists(String)
    
    // Storage Errors
    case insufficientStorage(required: Int64, available: Int64)
    case storageAccessDenied
    case fileNotFound(String)
    case fileCorrupted(String)
    case diskFull
    
    // Memory Errors
    case outOfMemory(required: Int64, available: Int64)
    case memoryAllocationFailed
    case memoryFragmentation
    
    // GPU Errors
    case gpuNotAvailable
    case gpuInitializationFailed(Error?)
    case gpuOperationFailed(String, Error?)
    case gpuMemoryExhausted
    
    // Chat Errors
    case chatSessionExpired
    case messageValidationFailed(String)
    case conversationLoadFailed(Error?)
    case conversationSaveFailed(Error?)
    case inferenceTimeout
    case inferenceFailed(Error?)
    
    // Export Errors
    case exportFailed(String, Error?)
    case exportFormatUnsupported(String)
    case exportPermissionDenied
    
    // System Errors
    case systemResourcesUnavailable
    case permissionDenied(String)
    case configurationError(String)
    case unexpectedError(Error)
    
    // User Errors
    case invalidInput(String)
    case operationCancelled
    case featureNotAvailable(String)
    
    var errorCode: String {
        switch self {
        case .networkUnavailable: return "NET_001"
        case .networkTimeout: return "NET_002"
        case .downloadFailed: return "NET_003"
        case .uploadFailed: return "NET_004"
        case .serverError: return "NET_005"
        case .modelNotFound: return "MDL_001"
        case .modelLoadFailed: return "MDL_002"
        case .modelCorrupted: return "MDL_003"
        case .modelIncompatible: return "MDL_004"
        case .modelDownloadFailed: return "MDL_005"
        case .modelVerificationFailed: return "MDL_006"
        case .modelAlreadyExists: return "MDL_007"
        case .insufficientStorage: return "STG_001"
        case .storageAccessDenied: return "STG_002"
        case .fileNotFound: return "STG_003"
        case .fileCorrupted: return "STG_004"
        case .diskFull: return "STG_005"
        case .outOfMemory: return "MEM_001"
        case .memoryAllocationFailed: return "MEM_002"
        case .memoryFragmentation: return "MEM_003"
        case .gpuNotAvailable: return "GPU_001"
        case .gpuInitializationFailed: return "GPU_002"
        case .gpuOperationFailed: return "GPU_003"
        case .gpuMemoryExhausted: return "GPU_004"
        case .chatSessionExpired: return "CHT_001"
        case .messageValidationFailed: return "CHT_002"
        case .conversationLoadFailed: return "CHT_003"
        case .conversationSaveFailed: return "CHT_004"
        case .inferenceTimeout: return "CHT_005"
        case .inferenceFailed: return "CHT_006"
        case .exportFailed: return "EXP_001"
        case .exportFormatUnsupported: return "EXP_002"
        case .exportPermissionDenied: return "EXP_003"
        case .systemResourcesUnavailable: return "SYS_001"
        case .permissionDenied: return "SYS_002"
        case .configurationError: return "SYS_003"
        case .unexpectedError: return "SYS_004"
        case .invalidInput: return "USR_001"
        case .operationCancelled: return "USR_002"
        case .featureNotAvailable: return "USR_003"
        }
    }
    
    var userFriendlyMessage: String {
        switch self {
        case .networkUnavailable:
            return "No internet connection available. Please check your network settings."
        case .networkTimeout:
            return "The request took too long to complete. Please try again."
        case .downloadFailed(let item, _):
            return "Failed to download \(item). Please check your connection and try again."
        case .uploadFailed(let item, _):
            return "Failed to upload \(item). Please check your connection and try again."
        case .serverError(let code, _):
            return "Server error (\(code)). Please try again later."
        case .modelNotFound(let model):
            return "The model '\(model)' could not be found. Please try downloading it again."
        case .modelLoadFailed(let model, _):
            return "Failed to load the '\(model)' model. The file may be corrupted."
        case .modelCorrupted(let model):
            return "The '\(model)' model file is corrupted. Please redownload it."
        case .modelIncompatible(let model, let reason):
            return "The '\(model)' model is not compatible: \(reason)"
        case .modelDownloadFailed(let model, _):
            return "Failed to download the '\(model)' model. Please try again."
        case .modelVerificationFailed(let model):
            return "The '\(model)' model failed verification. Please redownload it."
        case .modelAlreadyExists(let model):
            return "The '\(model)' model is already downloaded."
        case .insufficientStorage(let required, let available):
            let requiredGB = Double(required) / 1_073_741_824
            let availableGB = Double(available) / 1_073_741_824
            return "Not enough storage space. Need \(String(format: "%.1f", requiredGB))GB, but only \(String(format: "%.1f", availableGB))GB available."
        case .storageAccessDenied:
            return "Cannot access device storage. Please check app permissions."
        case .fileNotFound(let file):
            return "The file '\(file)' could not be found."
        case .fileCorrupted(let file):
            return "The file '\(file)' is corrupted or unreadable."
        case .diskFull:
            return "Device storage is full. Please free up space and try again."
        case .outOfMemory(let required, let available):
            let requiredMB = Double(required) / 1_048_576
            let availableMB = Double(available) / 1_048_576
            return "Not enough memory. Need \(String(format: "%.0f", requiredMB))MB, but only \(String(format: "%.0f", availableMB))MB available."
        case .memoryAllocationFailed:
            return "Failed to allocate memory. Please close other apps and try again."
        case .memoryFragmentation:
            return "Memory is fragmented. Please restart the app."
        case .gpuNotAvailable:
            return "GPU acceleration is not available on this device."
        case .gpuInitializationFailed:
            return "Failed to initialize GPU acceleration."
        case .gpuOperationFailed(let operation, _):
            return "GPU operation '\(operation)' failed. Falling back to CPU processing."
        case .gpuMemoryExhausted:
            return "GPU memory is exhausted. Please try with a smaller model."
        case .chatSessionExpired:
            return "Your chat session has expired. Please start a new conversation."
        case .messageValidationFailed(let reason):
            return "Message validation failed: \(reason)"
        case .conversationLoadFailed:
            return "Failed to load conversation. The data may be corrupted."
        case .conversationSaveFailed:
            return "Failed to save conversation. Please check storage space."
        case .inferenceTimeout:
            return "The AI response took too long to generate. Please try again."
        case .inferenceFailed:
            return "Failed to generate AI response. Please try again."
        case .exportFailed(let format, _):
            return "Failed to export conversation as \(format). Please try again."
        case .exportFormatUnsupported(let format):
            return "Export format '\(format)' is not supported."
        case .exportPermissionDenied:
            return "Permission denied for exporting files. Please check app permissions."
        case .systemResourcesUnavailable:
            return "System resources are unavailable. Please restart the app."
        case .permissionDenied(let permission):
            return "Permission denied for \(permission). Please check app settings."
        case .configurationError(let details):
            return "Configuration error: \(details)"
        case .unexpectedError:
            return "An unexpected error occurred. Please try again."
        case .invalidInput(let details):
            return "Invalid input: \(details)"
        case .operationCancelled:
            return "Operation was cancelled."
        case .featureNotAvailable(let feature):
            return "The feature '\(feature)' is not available on this device."
        }
    }
    
    var isRetryable: Bool {
        switch self {
        case .networkUnavailable, .networkTimeout, .downloadFailed, .uploadFailed, .serverError:
            return true
        case .modelLoadFailed, .modelDownloadFailed, .modelVerificationFailed:
            return true
        case .insufficientStorage, .diskFull:
            return false
        case .outOfMemory, .memoryAllocationFailed:
            return true
        case .gpuOperationFailed, .gpuMemoryExhausted:
            return true
        case .conversationLoadFailed, .conversationSaveFailed, .inferenceTimeout, .inferenceFailed:
            return true
        case .exportFailed:
            return true
        case .systemResourcesUnavailable:
            return true
        case .modelAlreadyExists, .operationCancelled, .invalidInput:
            return false
        default:
            return false
        }
    }
    
    var severity: ErrorSeverity {
        switch self {
        case .networkUnavailable, .networkTimeout:
            return .medium
        case .downloadFailed, .uploadFailed:
            return .medium
        case .serverError:
            return .high
        case .modelNotFound, .modelLoadFailed, .modelCorrupted, .modelDownloadFailed, .modelVerificationFailed:
            return .high
        case .modelIncompatible, .modelAlreadyExists:
            return .low
        case .insufficientStorage, .diskFull:
            return .high
        case .storageAccessDenied, .fileNotFound, .fileCorrupted:
            return .medium
        case .outOfMemory, .memoryAllocationFailed, .memoryFragmentation:
            return .high
        case .gpuNotAvailable:
            return .low
        case .gpuInitializationFailed, .gpuOperationFailed, .gpuMemoryExhausted:
            return .medium
        case .chatSessionExpired, .messageValidationFailed:
            return .low
        case .conversationLoadFailed, .conversationSaveFailed:
            return .medium
        case .inferenceTimeout, .inferenceFailed:
            return .medium
        case .exportFailed, .exportFormatUnsupported, .exportPermissionDenied:
            return .low
        case .systemResourcesUnavailable, .permissionDenied, .configurationError:
            return .high
        case .unexpectedError:
            return .critical
        case .invalidInput, .operationCancelled, .featureNotAvailable:
            return .low
        }
    }
    
    var category: ErrorCategory {
        switch self {
        case .networkUnavailable, .networkTimeout, .downloadFailed, .uploadFailed, .serverError:
            return .network
        case .modelNotFound, .modelLoadFailed, .modelCorrupted, .modelIncompatible, .modelDownloadFailed, .modelVerificationFailed, .modelAlreadyExists:
            return .model
        case .insufficientStorage, .storageAccessDenied, .fileNotFound, .fileCorrupted, .diskFull:
            return .storage
        case .outOfMemory, .memoryAllocationFailed, .memoryFragmentation:
            return .memory
        case .gpuNotAvailable, .gpuInitializationFailed, .gpuOperationFailed, .gpuMemoryExhausted:
            return .gpu
        case .chatSessionExpired, .messageValidationFailed, .conversationLoadFailed, .conversationSaveFailed, .inferenceTimeout, .inferenceFailed:
            return .chat
        case .exportFailed, .exportFormatUnsupported, .exportPermissionDenied:
            return .export
        case .systemResourcesUnavailable, .permissionDenied, .configurationError, .unexpectedError:
            return .system
        case .invalidInput, .operationCancelled, .featureNotAvailable:
            return .user
        }
    }
    
    var underlyingError: Error? {
        switch self {
        case .downloadFailed(_, let error), .uploadFailed(_, let error):
            return error
        case .modelLoadFailed(_, let error), .modelDownloadFailed(_, let error):
            return error
        case .gpuInitializationFailed(let error), .gpuOperationFailed(_, let error):
            return error
        case .conversationLoadFailed(let error), .conversationSaveFailed(let error):
            return error
        case .inferenceFailed(let error):
            return error
        case .exportFailed(_, let error):
            return error
        case .unexpectedError(let error):
            return error
        default:
            return nil
        }
    }
    
    var recoveryActions: [ErrorRecoveryAction] {
        switch self {
        case .networkUnavailable, .networkTimeout:
            return [.checkNetworkConnection, .retryWithDelay(5), .dismissError]
        case .downloadFailed, .uploadFailed:
            return [.retry, .checkNetworkConnection, .dismissError]
        case .serverError:
            return [.retryWithDelay(10), .contactSupport, .dismissError]
        case .modelNotFound, .modelCorrupted, .modelVerificationFailed:
            return [.redownloadModel("model"), .dismissError]
        case .modelLoadFailed:
            return [.redownloadModel("model"), .restartApp, .dismissError]
        case .modelIncompatible:
            return [.switchToFallbackModel, .dismissError]
        case .modelDownloadFailed:
            return [.retry, .checkNetworkConnection, .checkStorageSpace, .dismissError]
        case .modelAlreadyExists:
            return [.dismissError]
        case .insufficientStorage, .diskFull:
            return [.checkStorageSpace, .clearCache, .dismissError]
        case .storageAccessDenied, .exportPermissionDenied:
            return [.navigateToSettings, .dismissError]
        case .fileNotFound, .fileCorrupted:
            return [.retry, .clearCache, .dismissError]
        case .outOfMemory, .memoryAllocationFailed, .memoryFragmentation:
            return [.freeMemory, .restartApp, .dismissError]
        case .gpuNotAvailable:
            return [.dismissError]
        case .gpuInitializationFailed, .gpuOperationFailed, .gpuMemoryExhausted:
            return [.retry, .restartApp, .dismissError]
        case .chatSessionExpired:
            return [.dismissError]
        case .messageValidationFailed:
            return [.dismissError]
        case .conversationLoadFailed, .conversationSaveFailed:
            return [.retry, .clearCache, .dismissError]
        case .inferenceTimeout, .inferenceFailed:
            return [.retry, .switchToFallbackModel, .dismissError]
        case .exportFailed:
            return [.retry, .checkStorageSpace, .dismissError]
        case .exportFormatUnsupported:
            return [.dismissError]
        case .systemResourcesUnavailable:
            return [.restartApp, .contactSupport, .dismissError]
        case .permissionDenied:
            return [.navigateToSettings, .dismissError]
        case .configurationError, .unexpectedError:
            return [.restartApp, .contactSupport, .dismissError]
        case .invalidInput:
            return [.dismissError]
        case .operationCancelled:
            return [.dismissError]
        case .featureNotAvailable:
            return [.dismissError]
        }
    }
    
    var errorDescription: String? {
        return userFriendlyMessage
    }
}
