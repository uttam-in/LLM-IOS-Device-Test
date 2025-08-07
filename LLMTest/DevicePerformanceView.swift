//
//  DevicePerformanceView.swift
//  LLMTest
//
//  Created by Uttam Kumar Panasala on 8/6/25.
//

import SwiftUI

// MARK: - Device Performance Settings View

struct DevicePerformanceView: View {
    @StateObject private var deviceManager = DeviceCapabilityManager.shared
    @StateObject private var performanceOptimizer = PerformanceOptimizer.shared
    @StateObject private var uiManager = AdaptiveUIManager.shared
    
    @State private var showingAdvancedSettings = false
    @State private var showingPerformanceReport = false
    @State private var isRunningBenchmark = false
    @State private var benchmarkResults: String = ""
    
    var body: some View {
        NavigationView {
            List {
                deviceInfoSection
                performanceMetricsSection
                optimizationSettingsSection
                adaptiveUISection
                thermalManagementSection
                performanceActionsSection
            }
            .navigationTitle("Device Performance")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Advanced") {
                        showingAdvancedSettings = true
                    }
                }
            }
            .sheet(isPresented: $showingAdvancedSettings) {
                AdvancedPerformanceSettingsView()
            }
            .sheet(isPresented: $showingPerformanceReport) {
                PerformanceReportView()
            }
        }
        .adaptivePerformance()
    }
    
    // MARK: - Device Information Section
    
    private var deviceInfoSection: some View {
        Section("Device Information") {
            HStack {
                Label("Performance Tier", systemImage: "speedometer")
                Spacer()
                Text(deviceManager.currentConfiguration.performanceTier.description)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Label("Metal GPU", systemImage: "gpu")
                Spacer()
                Image(systemName: deviceManager.currentConfiguration.supportsMetalGPU ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(deviceManager.currentConfiguration.supportsMetalGPU ? .green : .red)
            }
            
            HStack {
                Label("Neural Engine", systemImage: "brain")
                Spacer()
                Image(systemName: deviceManager.currentConfiguration.supportsNeuralEngine ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(deviceManager.currentConfiguration.supportsNeuralEngine ? .green : .red)
            }
            
            HStack {
                Label("Max Memory", systemImage: "memorychip")
                Spacer()
                Text(formatBytes(deviceManager.currentConfiguration.maxMemoryUsage))
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Label("Recommended Model Size", systemImage: "doc.text")
                Spacer()
                Text(formatBytes(deviceManager.currentConfiguration.recommendedModelSize))
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Performance Metrics Section
    
    private var performanceMetricsSection: some View {
        Section("Current Performance") {
            if let metrics = performanceOptimizer.currentMetrics {
                VStack(spacing: 12) {
                    // Performance Score
                    HStack {
                        Label("Performance Score", systemImage: "gauge.high")
                        Spacer()
                        Text("\(Int(metrics.performanceScore * 100))%")
                            .foregroundColor(performanceScoreColor(metrics.performanceScore))
                            .fontWeight(.semibold)
                    }
                    
                    // Memory Usage
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Label("Memory Usage", systemImage: "memorychip.fill")
                            Spacer()
                            Text("\(Int(deviceManager.memoryPressure * 100))%")
                                .foregroundColor(memoryPressureColor(deviceManager.memoryPressure))
                        }
                        
                        ProgressView(value: deviceManager.memoryPressure)
                            .progressViewStyle(LinearProgressViewStyle(tint: memoryPressureColor(deviceManager.memoryPressure)))
                    }
                    
                    // Thermal State
                    HStack {
                        Label("Thermal State", systemImage: thermalStateIcon(deviceManager.thermalState))
                        Spacer()
                        Text(deviceManager.thermalState.description)
                            .foregroundColor(thermalStateColor(deviceManager.thermalState))
                    }
                    
                    // Battery Level
                    HStack {
                        Label("Battery Level", systemImage: batteryIcon(deviceManager.batteryLevel))
                        Spacer()
                        Text("\(Int(deviceManager.batteryLevel * 100))%")
                            .foregroundColor(batteryColor(deviceManager.batteryLevel))
                    }
                    
                    // Throttling Status
                    if deviceManager.isThrottling {
                        HStack {
                            Label("Performance Throttling", systemImage: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Spacer()
                            Text("Active")
                                .foregroundColor(.orange)
                                .fontWeight(.medium)
                        }
                    }
                }
            } else {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Collecting performance data...")
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    // MARK: - Optimization Settings Section
    
    private var optimizationSettingsSection: some View {
        Section("Optimization Settings") {
            Picker("Strategy", selection: $performanceOptimizer.optimizationStrategy) {
                ForEach(OptimizationStrategy.allCases, id: \.self) { strategy in
                    Text(strategy.description).tag(strategy)
                }
            }
            .pickerStyle(MenuPickerStyle())
            
            HStack {
                Label("Auto-Optimization", systemImage: "gearshape.2")
                Spacer()
                Toggle("", isOn: .constant(true))
                    .disabled(true) // Always enabled for now
            }
            
            if performanceOptimizer.isOptimizing {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Optimizing performance...")
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    // MARK: - Adaptive UI Section
    
    private var adaptiveUISection: some View {
        Section("Adaptive UI") {
            HStack {
                Label("UI Performance Mode", systemImage: "display")
                Spacer()
                Text(uiManager.currentConfiguration.performanceMode.description)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Label("Animations", systemImage: "sparkles")
                Spacer()
                Image(systemName: uiManager.currentConfiguration.enableMessageAnimations ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(uiManager.currentConfiguration.enableMessageAnimations ? .green : .red)
            }
            
            HStack {
                Label("Haptic Feedback", systemImage: "hand.tap")
                Spacer()
                Image(systemName: uiManager.currentConfiguration.enableHaptics ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(uiManager.currentConfiguration.enableHaptics ? .green : .red)
            }
            
            HStack {
                Label("Max Visible Messages", systemImage: "text.bubble")
                Spacer()
                Text("\(uiManager.currentConfiguration.performanceMode.maxVisibleMessages)")
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Label("Refresh Rate", systemImage: "timer")
                Spacer()
                Text("\(Int(uiManager.currentConfiguration.refreshRate)) Hz")
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Thermal Management Section
    
    private var thermalManagementSection: some View {
        Section("Thermal Management") {
            HStack {
                Label("GPU Acceleration", systemImage: "gpu")
                Spacer()
                Image(systemName: deviceManager.shouldUseGPUAcceleration() ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(deviceManager.shouldUseGPUAcceleration() ? .green : .red)
            }
            
            HStack {
                Label("Neural Engine", systemImage: "brain")
                Spacer()
                Image(systemName: deviceManager.shouldUseNeuralEngine() ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(deviceManager.shouldUseNeuralEngine() ? .green : .red)
            }
            
            HStack {
                Label("Optimal Thread Count", systemImage: "cpu")
                Spacer()
                Text("\(deviceManager.getOptimalThreadCount())")
                    .foregroundColor(.secondary)
            }
            
            if deviceManager.isLowPowerModeEnabled {
                HStack {
                    Label("Low Power Mode", systemImage: "battery.25")
                        .foregroundColor(.orange)
                    Spacer()
                    Text("Enabled")
                        .foregroundColor(.orange)
                        .fontWeight(.medium)
                }
            }
        }
    }
    
    // MARK: - Performance Actions Section
    
    private var performanceActionsSection: some View {
        Section("Actions") {
            Button(action: {
                performanceOptimizer.forceOptimization()
            }) {
                Label("Force Optimization", systemImage: "gearshape.arrow.triangle.2.circlepath")
            }
            .disabled(performanceOptimizer.isOptimizing)
            
            Button(action: {
                showingPerformanceReport = true
            }) {
                Label("View Performance Report", systemImage: "chart.line.uptrend.xyaxis")
            }
            
            Button(action: {
                runPerformanceBenchmark()
            }) {
                Label("Run Benchmark", systemImage: "stopwatch")
            }
            .disabled(isRunningBenchmark)
            
            if isRunningBenchmark {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Running benchmark...")
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func performanceScoreColor(_ score: Double) -> Color {
        if score >= 0.8 {
            return .green
        } else if score >= 0.6 {
            return .yellow
        } else if score >= 0.4 {
            return .orange
        } else {
            return .red
        }
    }
    
    private func memoryPressureColor(_ pressure: Float) -> Color {
        if pressure < 0.6 {
            return .green
        } else if pressure < 0.8 {
            return .yellow
        } else {
            return .red
        }
    }
    
    private func thermalStateColor(_ state: DeviceThermalState) -> Color {
        switch state {
        case .nominal:
            return .green
        case .fair:
            return .yellow
        case .serious:
            return .orange
        case .critical:
            return .red
        }
    }
    
    private func thermalStateIcon(_ state: DeviceThermalState) -> String {
        switch state {
        case .nominal:
            return "thermometer.low"
        case .fair:
            return "thermometer.medium"
        case .serious:
            return "thermometer.high"
        case .critical:
            return "thermometer.high"
        }
    }
    
    private func batteryColor(_ level: Float) -> Color {
        if level > 0.5 {
            return .green
        } else if level > 0.2 {
            return .yellow
        } else {
            return .red
        }
    }
    
    private func batteryIcon(_ level: Float) -> String {
        if level > 0.75 {
            return "battery.100"
        } else if level > 0.5 {
            return "battery.75"
        } else if level > 0.25 {
            return "battery.25"
        } else {
            return "battery.0"
        }
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: bytes)
    }
    
    private func runPerformanceBenchmark() {
        isRunningBenchmark = true
        
        Task {
            // Simulate benchmark
            try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
            
            await MainActor.run {
                isRunningBenchmark = false
                benchmarkResults = "Benchmark completed successfully"
            }
        }
    }
}

// MARK: - Advanced Performance Settings View

struct AdvancedPerformanceSettingsView: View {
    @StateObject private var deviceManager = DeviceCapabilityManager.shared
    @StateObject private var performanceOptimizer = PerformanceOptimizer.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section("Memory Management") {
                    HStack {
                        Text("Memory Threshold")
                        Spacer()
                        Text("\(Int(performanceOptimizer.optimizationStrategy.memoryThreshold * 100))%")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Current Usage")
                        Spacer()
                        Text("\(Int(deviceManager.memoryPressure * 100))%")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("CPU Management") {
                    HStack {
                        Text("Processor Cores")
                        Spacer()
                        Text("\(ProcessInfo.processInfo.processorCount)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Optimal Threads")
                        Spacer()
                        Text("\(deviceManager.getOptimalThreadCount())")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("GPU Management") {
                    HStack {
                        Text("Metal Support")
                        Spacer()
                        Image(systemName: deviceManager.currentConfiguration.supportsMetalGPU ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(deviceManager.currentConfiguration.supportsMetalGPU ? .green : .red)
                    }
                    
                    HStack {
                        Text("GPU Acceleration")
                        Spacer()
                        Image(systemName: deviceManager.shouldUseGPUAcceleration() ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(deviceManager.shouldUseGPUAcceleration() ? .green : .red)
                    }
                }
                
                Section("Performance History") {
                    if !performanceOptimizer.performanceHistory.isEmpty {
                        PerformanceHistoryChart(history: performanceOptimizer.performanceHistory)
                            .frame(height: 200)
                    } else {
                        Text("No performance data available")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Advanced Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Performance Report View

struct PerformanceReportView: View {
    @StateObject private var performanceOptimizer = PerformanceOptimizer.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(performanceOptimizer.getPerformanceReport())
                        .font(.system(.body, design: .monospaced))
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    
                    if !performanceOptimizer.performanceHistory.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Performance Trend")
                                .font(.headline)
                            
                            PerformanceHistoryChart(history: performanceOptimizer.performanceHistory)
                                .frame(height: 200)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Performance Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Performance History Chart

struct PerformanceHistoryChart: View {
    let history: [PerformanceMetrics]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Performance Trend")
                .font(.headline)
            
            if let latest = history.last {
                VStack(spacing: 4) {
                    HStack {
                        Text("Performance Score")
                        Spacer()
                        Text("\(Int(latest.performanceScore * 100))%")
                            .foregroundColor(.blue)
                    }
                    ProgressView(value: latest.performanceScore)
                        .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                    
                    HStack {
                        Text("Memory Usage")
                        Spacer()
                        Text("\(Int(Double(latest.memoryUsage) / Double(ProcessInfo.processInfo.physicalMemory) * 100))%")
                            .foregroundColor(.red)
                    }
                    ProgressView(value: Double(latest.memoryUsage) / Double(ProcessInfo.processInfo.physicalMemory))
                        .progressViewStyle(LinearProgressViewStyle(tint: .red))
                }
            } else {
                Text("No performance data available")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

// MARK: - Preview

#Preview {
    DevicePerformanceView()
}
