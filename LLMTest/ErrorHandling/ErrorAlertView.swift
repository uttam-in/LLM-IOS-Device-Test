//
//  ErrorAlertView.swift
//  LLMTest
//
//  Created by Uttam Kumar Panasala on 8/6/25.
//

import SwiftUI

// MARK: - Error Alert View

struct ErrorAlertView: View {
    let error: any AppError
    let onRecoveryAction: (ErrorRecoveryAction) async -> Void
    let onDismiss: () -> Void
    
    @State private var isExecutingAction = false
    @State private var selectedAction: ErrorRecoveryAction?
    
    var body: some View {
        VStack(spacing: 20) {
            // Error Icon
            errorIcon
                .font(.system(size: 50))
                .foregroundColor(severityColor)
            
            // Error Title
            Text(errorTitle)
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            // Error Message
            Text(error.userFriendlyMessage)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            // Error Details (for debugging)
            if !error.errorCode.isEmpty {
                DisclosureGroup("Technical Details") {
                    VStack(alignment: .leading, spacing: 8) {
                        DetailRow(label: "Error Code", value: error.errorCode)
                        DetailRow(label: "Category", value: error.category.description)
                        DetailRow(label: "Severity", value: error.severity.description)
                        
                        if let underlyingError = error.underlyingError {
                            DetailRow(label: "Technical Error", value: underlyingError.localizedDescription)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            
            // Recovery Actions
            if !error.recoveryActions.isEmpty {
                VStack(spacing: 12) {
                    ForEach(error.recoveryActions, id: \.title) { action in
                        RecoveryActionButton(
                            action: action,
                            isExecuting: isExecutingAction && selectedAction == action,
                            onTap: {
                                executeRecoveryAction(action)
                            }
                        )
                    }
                }
            }
        }
        .padding(24)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        .padding(.horizontal, 20)
    }
    
    private var errorIcon: Image {
        switch error.severity {
        case .low:
            return Image(systemName: "info.circle.fill")
        case .medium:
            return Image(systemName: "exclamationmark.triangle.fill")
        case .high:
            return Image(systemName: "xmark.circle.fill")
        case .critical:
            return Image(systemName: "exclamationmark.octagon.fill")
        }
    }
    
    private var severityColor: Color {
        switch error.severity {
        case .low:
            return .blue
        case .medium:
            return .orange
        case .high:
            return .red
        case .critical:
            return .purple
        }
    }
    
    private var errorTitle: String {
        switch error.category {
        case .network:
            return "Connection Problem"
        case .storage:
            return "Storage Issue"
        case .model:
            return "Model Problem"
        case .gpu:
            return "Performance Issue"
        case .memory:
            return "Memory Issue"
        case .user:
            return "Input Error"
        case .system:
            return "System Error"
        case .chat:
            return "Chat Error"
        case .export:
            return "Export Error"
        }
    }
    
    private func executeRecoveryAction(_ action: ErrorRecoveryAction) {
        selectedAction = action
        isExecutingAction = true
        
        Task {
            await onRecoveryAction(action)
            
            await MainActor.run {
                isExecutingAction = false
                selectedAction = nil
                
                // Auto-dismiss for certain actions
                if action == .dismissError {
                    onDismiss()
                }
            }
        }
    }
}

// MARK: - Recovery Action Button

struct RecoveryActionButton: View {
    let action: ErrorRecoveryAction
    let isExecuting: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                if isExecuting {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    actionIcon
                }
                
                Text(action.title)
                    .fontWeight(.medium)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(buttonBackground)
            .foregroundColor(buttonForeground)
            .cornerRadius(8)
        }
        .disabled(isExecuting)
        .opacity(isExecuting ? 0.7 : 1.0)
    }
    
    private var actionIcon: Image {
        switch action {
        case .retry, .retryWithDelay:
            return Image(systemName: "arrow.clockwise")
        case .redownloadModel:
            return Image(systemName: "arrow.down.circle")
        case .clearCache:
            return Image(systemName: "trash")
        case .freeMemory:
            return Image(systemName: "memorychip")
        case .restartApp:
            return Image(systemName: "power")
        case .checkNetworkConnection:
            return Image(systemName: "wifi")
        case .checkStorageSpace:
            return Image(systemName: "internaldrive")
        case .contactSupport:
            return Image(systemName: "questionmark.circle")
        case .dismissError:
            return Image(systemName: "xmark")
        case .navigateToSettings:
            return Image(systemName: "gear")
        case .switchToFallbackModel:
            return Image(systemName: "arrow.triangle.swap")
        }
    }
    
    private var buttonBackground: Color {
        switch action {
        case .retry, .retryWithDelay:
            return .blue
        case .dismissError:
            return .gray
        case .contactSupport:
            return .orange
        default:
            return .blue.opacity(0.1)
        }
    }
    
    private var buttonForeground: Color {
        switch action {
        case .retry, .retryWithDelay:
            return .white
        case .dismissError:
            return .white
        case .contactSupport:
            return .white
        default:
            return .blue
        }
    }
}

// MARK: - Detail Row

struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label + ":")
                .fontWeight(.medium)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Error Toast View

struct ErrorToastView: View {
    let error: any AppError
    let onDismiss: () -> Void
    
    @State private var isVisible = false
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: toastIcon)
                .foregroundColor(toastColor)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(toastTitle)
                    .font(.headline)
                    .fontWeight(.medium)
                
                Text(error.userFriendlyMessage)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
        .scaleEffect(isVisible ? 1.0 : 0.8)
        .opacity(isVisible ? 1.0 : 0.0)
        .onAppear {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isVisible = true
            }
            
            // Auto-dismiss for low severity errors
            if error.severity == .low {
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    dismiss()
                }
            }
        }
    }
    
    private var toastIcon: String {
        switch error.severity {
        case .low:
            return "info.circle.fill"
        case .medium:
            return "exclamationmark.triangle.fill"
        case .high, .critical:
            return "xmark.circle.fill"
        }
    }
    
    private var toastColor: Color {
        switch error.severity {
        case .low:
            return .blue
        case .medium:
            return .orange
        case .high, .critical:
            return .red
        }
    }
    
    private var toastTitle: String {
        switch error.severity {
        case .low:
            return "Notice"
        case .medium:
            return "Warning"
        case .high:
            return "Error"
        case .critical:
            return "Critical Error"
        }
    }
    
    private func dismiss() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            isVisible = false
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onDismiss()
        }
    }
}

// MARK: - Error Overlay Modifier

struct ErrorOverlayModifier: ViewModifier {
    @ObservedObject var errorManager = ErrorManager.shared
    
    func body(content: Content) -> some View {
        content
            .overlay(
                Group {
                    if errorManager.isShowingError, let error = errorManager.currentError {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()
                            .onTapGesture {
                                // Prevent dismissing critical errors by tapping background
                                if error.severity != .critical {
                                    errorManager.dismissError()
                                }
                            }
                        
                        ErrorAlertView(
                            error: error,
                            onRecoveryAction: { action in
                                await errorManager.executeRecoveryAction(action, for: error)
                            },
                            onDismiss: {
                                errorManager.dismissError()
                            }
                        )
                        .transition(.scale.combined(with: .opacity))
                    }
                }
            )
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: errorManager.isShowingError)
    }
}

extension View {
    func errorHandling() -> some View {
        modifier(ErrorOverlayModifier())
    }
}
