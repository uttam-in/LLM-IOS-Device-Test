//
//  AdaptiveUIManager.swift
//  LLMTest
//
//  Created by Uttam Kumar Panasala on 8/6/25.
//

import SwiftUI
import Combine

// MARK: - UI Performance Mode

enum UIPerformanceMode: String, CaseIterable {
    case full = "full"
    case reduced = "reduced"
    case minimal = "minimal"
    case emergency = "emergency"
    
    var description: String {
        switch self {
        case .full:
            return "Full UI"
        case .reduced:
            return "Reduced UI"
        case .minimal:
            return "Minimal UI"
        case .emergency:
            return "Emergency UI"
        }
    }
    
    var animationDuration: Double {
        switch self {
        case .full:
            return 0.3
        case .reduced:
            return 0.2
        case .minimal:
            return 0.1
        case .emergency:
            return 0.0
        }
    }
    
    var enableAnimations: Bool {
        switch self {
        case .full, .reduced:
            return true
        case .minimal, .emergency:
            return false
        }
    }
    
    var enableBlur: Bool {
        switch self {
        case .full:
            return true
        case .reduced, .minimal, .emergency:
            return false
        }
    }
    
    var enableShadows: Bool {
        switch self {
        case .full, .reduced:
            return true
        case .minimal, .emergency:
            return false
        }
    }
    
    var maxVisibleMessages: Int {
        switch self {
        case .full:
            return 100
        case .reduced:
            return 50
        case .minimal:
            return 25
        case .emergency:
            return 10
        }
    }
}

// MARK: - Adaptive UI Configuration

struct AdaptiveUIConfiguration {
    let performanceMode: UIPerformanceMode
    let enableHaptics: Bool
    let enableSoundEffects: Bool
    let enableBackgroundEffects: Bool
    let enableTypingIndicator: Bool
    let enableMessageAnimations: Bool
    let enableScrollAnimations: Bool
    let maxConcurrentAnimations: Int
    let refreshRate: Double
    
    @MainActor
    static func forDevice(_ deviceManager: DeviceCapabilityManager) -> AdaptiveUIConfiguration {
        let performanceMode = determineUIPerformanceMode(deviceManager)
        
        return AdaptiveUIConfiguration(
            performanceMode: performanceMode,
            enableHaptics: !deviceManager.isThrottling && !deviceManager.isLowPowerModeEnabled,
            enableSoundEffects: !deviceManager.isLowPowerModeEnabled,
            enableBackgroundEffects: performanceMode == .full,
            enableTypingIndicator: performanceMode != .emergency,
            enableMessageAnimations: performanceMode.enableAnimations,
            enableScrollAnimations: performanceMode.enableAnimations,
            maxConcurrentAnimations: performanceMode == .full ? 5 : (performanceMode == .reduced ? 3 : 1),
            refreshRate: deviceManager.isThrottling ? 30.0 : 60.0
        )
    }
    
    @MainActor
    private static func determineUIPerformanceMode(_ deviceManager: DeviceCapabilityManager) -> UIPerformanceMode {
        if deviceManager.thermalState == .critical || deviceManager.memoryPressure > 0.9 {
            return .emergency
        } else if deviceManager.isThrottling || deviceManager.memoryPressure > 0.8 {
            return .minimal
        } else if deviceManager.isLowPowerModeEnabled || deviceManager.thermalState == .serious {
            return .reduced
        } else {
            return .full
        }
    }
}

// MARK: - Adaptive UI Manager

@MainActor
class AdaptiveUIManager: ObservableObject {
    static let shared = AdaptiveUIManager()
    
    // MARK: - Published Properties
    @Published var currentConfiguration: AdaptiveUIConfiguration
    @Published var isPerformanceModeActive: Bool = false
    @Published var showPerformanceIndicator: Bool = false
    
    // MARK: - Private Properties
    private let deviceManager = DeviceCapabilityManager.shared
    private var cancellables = Set<AnyCancellable>()
    private let logger = ErrorLogger.shared
    
    // MARK: - Animation State
    private var activeAnimations: Set<String> = []
    private let maxAnimations: Int = 5
    
    // MARK: - Initialization
    private init() {
        // Initialize with default configuration, will be updated in setupInitialConfiguration
        self.currentConfiguration = AdaptiveUIConfiguration(
            performanceMode: .full,
            enableHaptics: true,
            enableSoundEffects: true,
            enableBackgroundEffects: true,
            enableTypingIndicator: true,
            enableMessageAnimations: true,
            enableScrollAnimations: true,
            maxConcurrentAnimations: 5,
            refreshRate: 60.0
        )
        setupDeviceMonitoring()
        setupPerformanceMonitoring()
        setupInitialConfiguration()
    }
    
    private func setupInitialConfiguration() {
        Task { @MainActor in
            self.currentConfiguration = AdaptiveUIConfiguration.forDevice(self.deviceManager)
        }
    }
    
    // MARK: - Setup
    
    private func setupDeviceMonitoring() {
        // Monitor device performance changes
        NotificationCenter.default.publisher(for: .devicePerformanceChanged)
            .sink { [weak self] _ in
                self?.updateUIConfiguration()
            }
            .store(in: &cancellables)
        
        // Monitor device capability changes
        deviceManager.$isThrottling
            .combineLatest(deviceManager.$thermalState, deviceManager.$memoryPressure)
            .sink { [weak self] _, _, _ in
                self?.updateUIConfiguration()
            }
            .store(in: &cancellables)
    }
    
    private func setupPerformanceMonitoring() {
        // Monitor UI performance metrics
        Timer.publish(every: 2.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.evaluateUIPerformance()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Configuration Updates
    
    private func updateUIConfiguration() {
        Task { @MainActor in
            let newConfiguration = AdaptiveUIConfiguration.forDevice(deviceManager)
            self.applyConfiguration(newConfiguration)
        }
    }
    
    @MainActor
    private func applyConfiguration(_ newConfiguration: AdaptiveUIConfiguration) {
        
        if newConfiguration.performanceMode != currentConfiguration.performanceMode {
            logger.logSystemInfo()
            
            withAnimation(newConfiguration.enableMessageAnimations ? .easeInOut(duration: 0.3) : .none) {
                currentConfiguration = newConfiguration
                isPerformanceModeActive = newConfiguration.performanceMode != .full
                showPerformanceIndicator = isPerformanceModeActive
            }
            
            // Auto-hide performance indicator after delay
            if showPerformanceIndicator {
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                    withAnimation(.easeOut(duration: 0.5)) {
                        self?.showPerformanceIndicator = false
                    }
                }
            }
            
            notifyConfigurationChange()
        }
    }
    
    private func evaluateUIPerformance() {
        // Check if we need to further reduce UI performance
        if activeAnimations.count > maxAnimations {
            // Force minimal mode if too many animations
            if currentConfiguration.performanceMode != .minimal {
                let minimalConfig = AdaptiveUIConfiguration(
                    performanceMode: .minimal,
                    enableHaptics: false,
                    enableSoundEffects: false,
                    enableBackgroundEffects: false,
                    enableTypingIndicator: true,
                    enableMessageAnimations: false,
                    enableScrollAnimations: false,
                    maxConcurrentAnimations: 1,
                    refreshRate: 30.0
                )
                
                currentConfiguration = minimalConfig
                isPerformanceModeActive = true
            }
        }
    }
    
    // MARK: - Animation Management
    
    func requestAnimation(id: String, duration: TimeInterval = 0.3, completion: @escaping () -> Void = {}) -> Bool {
        guard currentConfiguration.enableMessageAnimations else {
            completion()
            return false
        }
        
        guard activeAnimations.count < currentConfiguration.maxConcurrentAnimations else {
            completion()
            return false
        }
        
        activeAnimations.insert(id)
        
        let animationDuration = currentConfiguration.performanceMode.animationDuration
        
        withAnimation(.easeInOut(duration: animationDuration)) {
            completion()
        }
        
        // Clean up animation tracking
        DispatchQueue.main.asyncAfter(deadline: .now() + animationDuration + 0.1) { [weak self] in
            self?.activeAnimations.remove(id)
        }
        
        return true
    }
    
    func cancelAnimation(id: String) {
        activeAnimations.remove(id)
    }
    
    func clearAllAnimations() {
        activeAnimations.removeAll()
    }
    
    // MARK: - UI Helpers
    
    func adaptiveAnimation<V: Equatable>(_ value: V) -> Animation? {
        guard currentConfiguration.enableMessageAnimations else { return nil }
        
        let duration = currentConfiguration.performanceMode.animationDuration
        return .easeInOut(duration: duration)
    }
    
    func adaptiveTransition() -> AnyTransition {
        guard currentConfiguration.enableMessageAnimations else {
            return .identity
        }
        
        switch currentConfiguration.performanceMode {
        case .full:
            return .asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            )
        case .reduced:
            return .opacity
        case .minimal, .emergency:
            return .identity
        }
    }
    
    func adaptiveShadow() -> some View {
        Group {
            if currentConfiguration.performanceMode.enableShadows {
                Color.clear
                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
            } else {
                Color.clear
            }
        }
    }
    
    func adaptiveBlur() -> some View {
        Group {
            if currentConfiguration.performanceMode.enableBlur {
                Color.clear
                    .background(.ultraThinMaterial)
            } else {
                Color.clear
                    .background(Color(.systemBackground))
            }
        }
    }
    
    // MARK: - Performance Indicators
    
    func shouldShowTypingIndicator() -> Bool {
        return currentConfiguration.enableTypingIndicator
    }
    
    func shouldPlayHaptics() -> Bool {
        return currentConfiguration.enableHaptics
    }
    
    func shouldPlaySounds() -> Bool {
        return currentConfiguration.enableSoundEffects
    }
    
    func getMaxVisibleMessages() -> Int {
        return currentConfiguration.performanceMode.maxVisibleMessages
    }
    
    func getOptimalRefreshRate() -> Double {
        return currentConfiguration.refreshRate
    }
    
    // MARK: - Notifications
    
    private func notifyConfigurationChange() {
        NotificationCenter.default.post(
            name: .adaptiveUIConfigurationChanged,
            object: self,
            userInfo: [
                "configuration": currentConfiguration,
                "performanceMode": currentConfiguration.performanceMode.rawValue
            ]
        )
    }
}

// MARK: - SwiftUI View Modifiers

struct AdaptivePerformanceModifier: ViewModifier {
    @StateObject private var uiManager = AdaptiveUIManager.shared
    
    func body(content: Content) -> some View {
        content
            .animation(uiManager.adaptiveAnimation(uiManager.currentConfiguration.performanceMode), value: uiManager.currentConfiguration.performanceMode)
            .overlay(alignment: .top) {
                if uiManager.showPerformanceIndicator {
                    PerformanceIndicatorView()
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
    }
}

struct AdaptiveAnimationModifier: ViewModifier {
    @StateObject private var uiManager = AdaptiveUIManager.shared
    let animationId: String
    
    func body(content: Content) -> some View {
        content
            .transition(uiManager.adaptiveTransition())
            .onAppear {
                _ = uiManager.requestAnimation(id: animationId)
            }
            .onDisappear {
                uiManager.cancelAnimation(id: animationId)
            }
    }
}

// MARK: - Performance Indicator View

struct PerformanceIndicatorView: View {
    @StateObject private var deviceManager = DeviceCapabilityManager.shared
    @StateObject private var uiManager = AdaptiveUIManager.shared
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: performanceIcon)
                .foregroundColor(performanceColor)
                .font(.caption)
            
            Text(performanceText)
                .font(.caption2)
                .foregroundColor(.secondary)
            
            if deviceManager.isThrottling {
                Image(systemName: "thermometer")
                    .foregroundColor(.orange)
                    .font(.caption2)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: Capsule())
        .shadow(radius: 2)
    }
    
    private var performanceIcon: String {
        switch uiManager.currentConfiguration.performanceMode {
        case .full:
            return "gauge.high"
        case .reduced:
            return "gauge.medium"
        case .minimal:
            return "gauge.low"
        case .emergency:
            return "exclamationmark.triangle"
        }
    }
    
    private var performanceColor: Color {
        switch uiManager.currentConfiguration.performanceMode {
        case .full:
            return .green
        case .reduced:
            return .yellow
        case .minimal:
            return .orange
        case .emergency:
            return .red
        }
    }
    
    private var performanceText: String {
        switch uiManager.currentConfiguration.performanceMode {
        case .full:
            return "Full Performance"
        case .reduced:
            return "Reduced Performance"
        case .minimal:
            return "Minimal UI"
        case .emergency:
            return "Emergency Mode"
        }
    }
}

// MARK: - View Extensions

extension View {
    func adaptivePerformance() -> some View {
        modifier(AdaptivePerformanceModifier())
    }
    
    func adaptiveAnimation(id: String) -> some View {
        modifier(AdaptiveAnimationModifier(animationId: id))
    }
    
    func adaptiveShadow() -> some View {
        let uiManager = AdaptiveUIManager.shared
        return self.shadow(
            color: uiManager.currentConfiguration.performanceMode.enableShadows ? .black.opacity(0.1) : .clear,
            radius: uiManager.currentConfiguration.performanceMode.enableShadows ? 2 : 0,
            x: 0,
            y: 1
        )
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let adaptiveUIConfigurationChanged = Notification.Name("adaptiveUIConfigurationChanged")
}
