//
//  ErrorLogger.swift
//  LLMTest
//
//  Created by Uttam Kumar Panasala on 8/6/25.
//

import Foundation
import os.log
import UIKit

// MARK: - Error Logger

class ErrorLogger {
    static let shared = ErrorLogger()
    
    // MARK: - Properties
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "LLMTest", category: "ErrorHandling")
    private let fileLogger: FileLogger
    private let maxLogFileSize: Int = 10 * 1024 * 1024 // 10MB
    private let maxLogFiles: Int = 5
    
    // MARK: - Initialization
    private init() {
        self.fileLogger = FileLogger()
    }
    
    // MARK: - Logging Methods
    
    func logError(_ error: any AppError, context: ErrorContext? = nil) {
        let logMessage = createLogMessage(for: error, context: context)
        
        // Log to system logger based on severity
        switch error.severity {
        case .low:
            logger.info("\(logMessage)")
        case .medium:
            logger.notice("\(logMessage)")
        case .high:
            logger.error("\(logMessage)")
        case .critical:
            logger.critical("\(logMessage)")
        }
        
        // Log to file (sanitized)
        let sanitizedMessage = sanitizeForFileLogging(logMessage)
        fileLogger.log(sanitizedMessage, level: error.severity)
    }
    
    func logRetryAttempt(_ error: any AppError, attempt: Int, delay: TimeInterval) {
        let message = "RETRY_ATTEMPT: [\(error.errorCode)] Attempt \(attempt) after \(delay)s delay"
        logger.info("\(message)")
        fileLogger.log(message, level: .medium)
    }
    
    func logRetrySuccess(_ error: any AppError) {
        let message = "RETRY_SUCCESS: [\(error.errorCode)] Operation succeeded after retry"
        logger.info("\(message)")
        fileLogger.log(message, level: .low)
    }
    
    func logRecoveryAction(_ action: ErrorRecoveryAction, for error: any AppError) {
        let message = "RECOVERY_ACTION: [\(error.errorCode)] Executing '\(action.title)'"
        logger.info("\(message)")
        fileLogger.log(message, level: .medium)
    }
    
    func logCriticalError(_ error: any AppError) {
        let message = "CRITICAL_ERROR: [\(error.errorCode)] \(error.userFriendlyMessage)"
        logger.critical("\(message)")
        fileLogger.log(message, level: .critical)
        
        // Send to crash reporting service if available
        sendToCrashReporting(error)
    }
    
    func logSystemInfo() {
        let systemInfo = SystemInfoCollector.collect()
        let message = "SYSTEM_INFO: \(systemInfo.description)"
        logger.info("\(message)")
        fileLogger.log(message, level: .low)
    }
    
    // MARK: - Log Retrieval
    
    func getRecentLogs(limit: Int = 100) -> [String] {
        return fileLogger.getRecentLogs(limit: limit)
    }
    
    func exportLogs() -> URL? {
        return fileLogger.exportLogs()
    }
    
    func clearLogs() {
        fileLogger.clearLogs()
    }
    
    // MARK: - Private Methods
    
    private func createLogMessage(for error: any AppError, context: ErrorContext?) -> String {
        var components: [String] = []
        
        // Basic error info
        components.append("[\(error.errorCode)]")
        components.append("[\(error.category.description)]")
        components.append("[\(error.severity.description)]")
        
        // Error message
        components.append(error.userFriendlyMessage)
        
        // Context information
        if let context = context {
            components.append("Operation: \(context.operation)")
            if let params = context.parameters {
                let paramString = params.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
                components.append("Parameters: {\(paramString)}")
            }
        }
        
        // Underlying error
        if let underlyingError = error.underlyingError {
            components.append("Underlying: \(underlyingError.localizedDescription)")
        }
        
        // Device info (for critical errors)
        if error.severity == .critical {
            components.append("Device: \(UIDevice.current.model)")
            components.append("iOS: \(UIDevice.current.systemVersion)")
        }
        
        return components.joined(separator: " | ")
    }
    
    private func sanitizeForFileLogging(_ message: String) -> String {
        // Remove any potentially sensitive information
        var sanitized = message
        
        // Remove file paths (keep only filename)
        let pathRegex = try! NSRegularExpression(pattern: "/[^/\\s]+/[^/\\s]+/[^\\s]+", options: [])
        sanitized = pathRegex.stringByReplacingMatches(
            in: sanitized,
            options: [],
            range: NSRange(location: 0, length: sanitized.count),
            withTemplate: "[PATH]"
        )
        
        // Remove potential user data patterns
        let userDataPatterns = [
            "user_\\w+": "[USER_ID]",
            "\\b\\d{10,}\\b": "[LARGE_NUMBER]",
            "\\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Z|a-z]{2,}\\b": "[EMAIL]"
        ]
        
        for (pattern, replacement) in userDataPatterns {
            let regex = try! NSRegularExpression(pattern: pattern, options: [])
            sanitized = regex.stringByReplacingMatches(
                in: sanitized,
                options: [],
                range: NSRange(location: 0, length: sanitized.count),
                withTemplate: replacement
            )
        }
        
        return sanitized
    }
    
    private func sendToCrashReporting(_ error: any AppError) {
        // Placeholder for crash reporting integration
        // In a real app, this would integrate with services like Crashlytics, Sentry, etc.
        print("CRASH_REPORT: \(error.errorCode) - \(error.userFriendlyMessage)")
    }
}

// MARK: - File Logger

private class FileLogger {
    private let logDirectory: URL
    private let dateFormatter: DateFormatter
    private let queue = DispatchQueue(label: "com.llmtest.filelogger", qos: .utility)
    
    init() {
        // Create logs directory
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.logDirectory = documentsPath.appendingPathComponent("Logs")
        
        try? FileManager.default.createDirectory(at: logDirectory, withIntermediateDirectories: true)
        
        // Setup date formatter
        self.dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        dateFormatter.timeZone = TimeZone.current
    }
    
    func log(_ message: String, level: ErrorSeverity) {
        queue.async { [weak self] in
            self?.writeToFile(message, level: level)
        }
    }
    
    private func writeToFile(_ message: String, level: ErrorSeverity) {
        let timestamp = dateFormatter.string(from: Date())
        let logEntry = "[\(timestamp)] [\(level.description.uppercased())] \(message)\n"
        
        let logFile = getCurrentLogFile()
        
        if let data = logEntry.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: logFile.path) {
                if let fileHandle = try? FileHandle(forWritingTo: logFile) {
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                    fileHandle.closeFile()
                }
            } else {
                try? data.write(to: logFile)
            }
        }
        
        // Rotate logs if needed
        rotateLogsIfNeeded()
    }
    
    private func getCurrentLogFile() -> URL {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: Date())
        return logDirectory.appendingPathComponent("error-\(dateString).log")
    }
    
    private func rotateLogsIfNeeded() {
        do {
            let logFiles = try FileManager.default.contentsOfDirectory(at: logDirectory, includingPropertiesForKeys: [.fileSizeKey, .creationDateKey])
            
            // Check current log file size
            let currentLogFile = getCurrentLogFile()
            if let fileSize = try? currentLogFile.resourceValues(forKeys: [.fileSizeKey]).fileSize,
               fileSize > 10 * 1024 * 1024 { // 10MB
                
                // Sort files by creation date
                let sortedFiles = logFiles.sorted { file1, file2 in
                    let date1 = (try? file1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
                    let date2 = (try? file2.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
                    return date1 < date2
                }
                
                // Remove oldest files if we have too many
                if sortedFiles.count > 5 {
                    for i in 0..<(sortedFiles.count - 5) {
                        try? FileManager.default.removeItem(at: sortedFiles[i])
                    }
                }
            }
        } catch {
            print("Error rotating logs: \(error)")
        }
    }
    
    func getRecentLogs(limit: Int) -> [String] {
        var logs: [String] = []
        
        do {
            let logFiles = try FileManager.default.contentsOfDirectory(at: logDirectory, includingPropertiesForKeys: [.creationDateKey])
            
            // Sort by creation date (newest first)
            let sortedFiles = logFiles.sorted { file1, file2 in
                let date1 = (try? file1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
                let date2 = (try? file2.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
                return date1 > date2
            }
            
            // Read logs from newest files first
            for file in sortedFiles {
                if logs.count >= limit { break }
                
                if let content = try? String(contentsOf: file) {
                    let lines = content.components(separatedBy: .newlines)
                        .filter { !$0.isEmpty }
                        .reversed() // Most recent first
                    
                    for line in lines {
                        if logs.count >= limit { break }
                        logs.append(line)
                    }
                }
            }
        } catch {
            print("Error reading logs: \(error)")
        }
        
        return logs
    }
    
    func exportLogs() -> URL? {
        let exportFile = logDirectory.appendingPathComponent("exported-logs-\(Date().timeIntervalSince1970).txt")
        
        do {
            let logFiles = try FileManager.default.contentsOfDirectory(at: logDirectory, includingPropertiesForKeys: [.creationDateKey])
            
            var allLogs = ""
            for file in logFiles.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
                if let content = try? String(contentsOf: file) {
                    allLogs += "=== \(file.lastPathComponent) ===\n"
                    allLogs += content
                    allLogs += "\n\n"
                }
            }
            
            try allLogs.write(to: exportFile, atomically: true, encoding: .utf8)
            return exportFile
        } catch {
            print("Error exporting logs: \(error)")
            return nil
        }
    }
    
    func clearLogs() {
        do {
            let logFiles = try FileManager.default.contentsOfDirectory(at: logDirectory, includingPropertiesForKeys: nil)
            for file in logFiles {
                try FileManager.default.removeItem(at: file)
            }
        } catch {
            print("Error clearing logs: \(error)")
        }
    }
}

// MARK: - System Info Collector

private struct SystemInfoCollector {
    static func collect() -> SystemInfo {
        let device = UIDevice.current
        let processInfo = ProcessInfo.processInfo
        
        return SystemInfo(
            deviceModel: device.model,
            deviceName: device.name,
            systemVersion: device.systemVersion,
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown",
            buildNumber: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown",
            processorCount: processInfo.processorCount,
            physicalMemory: processInfo.physicalMemory,
            availableMemory: getAvailableMemory(),
            diskSpace: getDiskSpace(),
            timestamp: Date()
        )
    }
    
    private static func getAvailableMemory() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return info.resident_size
        }
        
        return 0
    }
    
    private static func getDiskSpace() -> (total: UInt64, available: UInt64) {
        do {
            let systemAttributes = try FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory())
            let totalSpace = (systemAttributes[.systemSize] as? NSNumber)?.uint64Value ?? 0
            let freeSpace = (systemAttributes[.systemFreeSize] as? NSNumber)?.uint64Value ?? 0
            return (total: totalSpace, available: freeSpace)
        } catch {
            return (total: 0, available: 0)
        }
    }
}

private struct SystemInfo {
    let deviceModel: String
    let deviceName: String
    let systemVersion: String
    let appVersion: String
    let buildNumber: String
    let processorCount: Int
    let physicalMemory: UInt64
    let availableMemory: UInt64
    let diskSpace: (total: UInt64, available: UInt64)
    let timestamp: Date
    
    var description: String {
        return """
        Device: \(deviceModel) (\(deviceName))
        iOS: \(systemVersion)
        App: \(appVersion) (\(buildNumber))
        CPU Cores: \(processorCount)
        Memory: \(formatBytes(availableMemory))/\(formatBytes(physicalMemory))
        Disk: \(formatBytes(diskSpace.available))/\(formatBytes(diskSpace.total))
        """
    }
    
    private func formatBytes(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: Int64(bytes))
    }
}
