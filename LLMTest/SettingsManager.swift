//
//  SettingsManager.swift
//  LLMTest
//
//  Created by Uttam Kumar Panasala on 8/6/25.
//

import Foundation
import CoreData
import Combine

@MainActor
class SettingsManager: ObservableObject {
    static let shared = SettingsManager()
    
    @Published var temperature: Double = 0.7
    @Published var maxTokens: Int = 2048
    @Published var selectedTheme: AppTheme = .system
    @Published var textSize: TextSize = .medium
    
    private let persistentContainer: NSPersistentContainer
    private var settings: AppSettings?
    
    private init() {
        persistentContainer = NSPersistentContainer(name: "LLMTest")
        persistentContainer.loadPersistentStores { _, error in
            if let error = error {
                print("Core Data error: \(error)")
            }
        }
        
        Task {
            await loadSettings()
        }
    }
    
    private func loadSettings() async {
        let context = persistentContainer.viewContext
        let request: NSFetchRequest<AppSettings> = AppSettings.fetchRequest()
        
        do {
            let results = try context.fetch(request)
            if let existingSettings = results.first {
                settings = existingSettings
                updatePublishedValues()
            } else {
                // Create default settings
                await createDefaultSettings()
            }
        } catch {
            print("Failed to load settings: \(error)")
            await createDefaultSettings()
        }
    }
    
    private func createDefaultSettings() async {
        let context = persistentContainer.viewContext
        let newSettings = AppSettings(context: context)
        newSettings.id = UUID()
        newSettings.temperature = 0.7
        newSettings.maxTokens = 2048
        newSettings.selectedTheme = AppTheme.system.rawValue
        newSettings.textSize = TextSize.medium.rawValue
        
        settings = newSettings
        await saveSettings()
        updatePublishedValues()
    }
    
    private func updatePublishedValues() {
        guard let settings = settings else { return }
        
        temperature = settings.temperature
        maxTokens = Int(settings.maxTokens)
        selectedTheme = AppTheme(rawValue: settings.selectedTheme ?? "system") ?? .system
        textSize = TextSize(rawValue: settings.textSize ?? "medium") ?? .medium
    }
    
    func updateTemperature(_ newValue: Double) async {
        temperature = newValue
        settings?.temperature = newValue
        await saveSettings()
    }
    
    func updateMaxTokens(_ newValue: Int) async {
        maxTokens = newValue
        settings?.maxTokens = Int32(newValue)
        await saveSettings()
    }
    
    func updateTheme(_ newTheme: AppTheme) async {
        selectedTheme = newTheme
        settings?.selectedTheme = newTheme.rawValue
        await saveSettings()
    }
    
    func updateTextSize(_ newSize: TextSize) async {
        textSize = newSize
        settings?.textSize = newSize.rawValue
        await saveSettings()
    }
    
    private func saveSettings() async {
        let context = persistentContainer.viewContext
        
        do {
            try context.save()
        } catch {
            print("Failed to save settings: \(error)")
        }
    }
    
    func resetToDefaults() async {
        await updateTemperature(0.7)
        await updateMaxTokens(2048)
        await updateTheme(.system)
        await updateTextSize(.medium)
    }
}

// Note: Core Data automatically generates the fetchRequest() method
// so we don't need to define it manually