//
//  SettingsView.swift
//  LLMTest
//
//  Created by Uttam Kumar Panasala on 8/6/25.
//

import SwiftUI

struct SettingsView: View {
    @StateObject private var settingsManager = SettingsManager.shared
    @State private var showingExportSheet = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("Model Parameters") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Temperature")
                            Spacer()
                            Text(String(format: "%.2f", settingsManager.temperature))
                                .foregroundColor(.secondary)
                        }
                        Slider(value: .init(
                            get: { settingsManager.temperature },
                            set: { newValue in
                                Task {
                                    await settingsManager.updateTemperature(newValue)
                                }
                            }
                        ), in: 0.1...2.0, step: 0.1)
                        Text("Higher values make output more random, lower values more focused")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Max Tokens")
                            Spacer()
                            Text("\(settingsManager.maxTokens)")
                                .foregroundColor(.secondary)
                        }
                        Slider(value: .init(
                            get: { Double(settingsManager.maxTokens) },
                            set: { newValue in
                                Task {
                                    await settingsManager.updateMaxTokens(Int(newValue))
                                }
                            }
                        ), in: 256...4096, step: 256)
                        Text("Maximum length of the AI response")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("Appearance") {
                    HStack {
                        Text("Theme")
                        Spacer()
                        Picker("Theme", selection: .init(
                            get: { settingsManager.selectedTheme },
                            set: { newTheme in
                                Task {
                                    await settingsManager.updateTheme(newTheme)
                                }
                            }
                        )) {
                            ForEach(AppTheme.allCases, id: \.self) { theme in
                                Text(theme.displayName).tag(theme)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    
                    HStack {
                        Text("Text Size")
                        Spacer()
                        Picker("Text Size", selection: .init(
                            get: { settingsManager.textSize },
                            set: { newSize in
                                Task {
                                    await settingsManager.updateTextSize(newSize)
                                }
                            }
                        )) {
                            ForEach(TextSize.allCases, id: \.self) { size in
                                Text(size.displayName).tag(size)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }
                
                Section("Data") {
                    Button("Export Conversations") {
                        showingExportSheet = true
                    }
                    .foregroundColor(.blue)
                    
                    Button("Clear All Data") {
                        // TODO: Implement clear all data functionality
                    }
                    .foregroundColor(.red)
                }
                
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Model")
                        Spacer()
                        Text("Gemma 2B")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .navigationBarBackButtonHidden()
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingExportSheet) {
                ExportView()
            }
        }
    }
}

enum AppTheme: String, CaseIterable {
    case light = "light"
    case dark = "dark"
    case system = "system"
    
    var displayName: String {
        switch self {
        case .light: return "Light"
        case .dark: return "Dark"
        case .system: return "System"
        }
    }
}

enum TextSize: String, CaseIterable {
    case small = "small"
    case medium = "medium"
    case large = "large"
    
    var displayName: String {
        switch self {
        case .small: return "Small"
        case .medium: return "Medium"
        case .large: return "Large"
        }
    }
    
    var scaleFactor: CGFloat {
        switch self {
        case .small: return 0.9
        case .medium: return 1.0
        case .large: return 1.2
        }
    }
}

struct ExportView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedFormat: ExportFormat = .json
    @State private var isExporting = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Export Conversations")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Choose a format to export your conversation history")
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                Picker("Export Format", selection: $selectedFormat) {
                    ForEach(ExportFormat.allCases, id: \.self) { format in
                        VStack(alignment: .leading) {
                            Text(format.displayName)
                                .fontWeight(.medium)
                            Text(format.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .tag(format)
                    }
                }
                .pickerStyle(.wheel)
                
                Button(action: exportConversations) {
                    HStack {
                        if isExporting {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                        Text(isExporting ? "Exporting..." : "Export")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(isExporting)
                
                Spacer()
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden()
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func exportConversations() {
        isExporting = true
        
        // Simulate export process
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            isExporting = false
            // TODO: Implement actual export functionality
            dismiss()
        }
    }
}

enum ExportFormat: String, CaseIterable {
    case json = "json"
    case csv = "csv"
    case txt = "txt"
    
    var displayName: String {
        switch self {
        case .json: return "JSON"
        case .csv: return "CSV"
        case .txt: return "Plain Text"
        }
    }
    
    var description: String {
        switch self {
        case .json: return "Structured data format, preserves all metadata"
        case .csv: return "Spreadsheet compatible, good for analysis"
        case .txt: return "Simple text format, easy to read"
        }
    }
}

#Preview {
    SettingsView()
}