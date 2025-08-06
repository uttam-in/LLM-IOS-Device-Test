//
//  ChatMessageView.swift
//  LLMTest
//
//  Created by Uttam Kumar Panasala on 8/6/25.
//

import SwiftUI

struct ChatMessageView: View {
    let message: ChatMessage
    @State private var showTimestamp = false
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.isFromUser {
                Spacer(minLength: 60)
                
                VStack(alignment: .trailing, spacing: 4) {
                    MessageBubble(
                        text: message.content ?? "",
                        isFromUser: true
                    )
                    
                    if showTimestamp {
                        TimestampView(date: message.timestamp ?? Date())
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .bottom, spacing: 8) {
                        AIAvatarView()
                        
                        MessageBubble(
                            text: message.content ?? "",
                            isFromUser: false
                        )
                    }
                    
                    if showTimestamp {
                        TimestampView(date: message.timestamp ?? Date())
                            .padding(.leading, 40) // Align with message bubble
                    }
                }
                
                Spacer(minLength: 60)
            }
        }
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                showTimestamp.toggle()
            }
        }
    }
}

// MARK: - Message Bubble
struct MessageBubble: View {
    let text: String
    let isFromUser: Bool
    
    var body: some View {
        Text(text)
            .font(.body)
            .foregroundColor(isFromUser ? .white : .primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(isFromUser ? Color.blue : Color(.systemGray5))
            )
            .overlay(
                // Message tail
                MessageTail(isFromUser: isFromUser),
                alignment: isFromUser ? .bottomTrailing : .bottomLeading
            )
    }
}

// MARK: - Message Tail
struct MessageTail: View {
    let isFromUser: Bool
    
    var body: some View {
        Path { path in
            if isFromUser {
                // User message tail (right side)
                path.move(to: CGPoint(x: 0, y: 0))
                path.addQuadCurve(
                    to: CGPoint(x: 10, y: 10),
                    control: CGPoint(x: 0, y: 10)
                )
                path.addLine(to: CGPoint(x: 0, y: 0))
            } else {
                // AI message tail (left side)
                path.move(to: CGPoint(x: 10, y: 0))
                path.addQuadCurve(
                    to: CGPoint(x: 0, y: 10),
                    control: CGPoint(x: 10, y: 10)
                )
                path.addLine(to: CGPoint(x: 10, y: 0))
            }
        }
        .fill(isFromUser ? Color.blue : Color(.systemGray5))
        .frame(width: 10, height: 10)
        .offset(
            x: isFromUser ? 5 : -5,
            y: -5
        )
    }
}

// MARK: - AI Avatar
struct AIAvatarView: View {
    var body: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [.purple, .blue],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 32, height: 32)
            .overlay(
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
            )
    }
}

// MARK: - Timestamp View
struct TimestampView: View {
    let date: Date
    
    private var formattedTime: String {
        let formatter = DateFormatter()
        
        if Calendar.current.isDateInToday(date) {
            formatter.timeStyle = .short
            return formatter.string(from: date)
        } else if Calendar.current.isDateInYesterday(date) {
            return "Yesterday \(DateFormatter.localizedString(from: date, dateStyle: .none, timeStyle: .short))"
        } else {
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            return formatter.string(from: date)
        }
    }
    
    var body: some View {
        Text(formattedTime)
            .font(.caption2)
            .foregroundColor(.secondary)
    }
}

// MARK: - Message Status View (for future use)
struct MessageStatusView: View {
    enum Status {
        case sending
        case sent
        case delivered
        case read
        case failed
    }
    
    let status: Status
    
    var body: some View {
        Group {
            switch status {
            case .sending:
                Image(systemName: "clock")
                    .foregroundColor(.gray)
            case .sent:
                Image(systemName: "checkmark")
                    .foregroundColor(.gray)
            case .delivered:
                HStack(spacing: -4) {
                    Image(systemName: "checkmark")
                    Image(systemName: "checkmark")
                }
                .foregroundColor(.gray)
            case .read:
                HStack(spacing: -4) {
                    Image(systemName: "checkmark")
                    Image(systemName: "checkmark")
                }
                .foregroundColor(.blue)
            case .failed:
                Image(systemName: "exclamationmark.triangle")
                    .foregroundColor(.red)
            }
        }
        .font(.caption2)
    }
}

// MARK: - Long Press Actions (for future use)
struct MessageActionsView: View {
    let message: ChatMessage
    let onCopy: () -> Void
    let onDelete: () -> Void
    let onReply: () -> Void
    
    var body: some View {
        HStack(spacing: 20) {
            Button("Copy", action: onCopy)
            Button("Reply", action: onReply)
            Button("Delete", role: .destructive, action: onDelete)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 8)
    }
}

#Preview {
    VStack(spacing: 16) {
        // User message
        ChatMessageView(message: {
            let context = StorageManager.shared.context
            let message = ChatMessage(context: context)
            message.id = UUID()
            message.content = "Hello! How are you doing today? I hope everything is going well for you."
            message.isFromUser = true
            message.timestamp = Date()
            return message
        }())
        
        // AI message
        ChatMessageView(message: {
            let context = StorageManager.shared.context
            let message = ChatMessage(context: context)
            message.id = UUID()
            message.content = "I'm doing great, thank you for asking! I'm here and ready to help you with anything you need. How can I assist you today?"
            message.isFromUser = false
            message.timestamp = Date().addingTimeInterval(-60)
            return message
        }())
        
        // Long message example
        ChatMessageView(message: {
            let context = StorageManager.shared.context
            let message = ChatMessage(context: context)
            message.id = UUID()
            message.content = "This is a much longer message to test how the message bubbles handle text wrapping and multiple lines. It should maintain proper padding and styling even with longer content that spans multiple lines."
            message.isFromUser = true
            message.timestamp = Date().addingTimeInterval(-120)
            return message
        }())
    }
    .padding()
}