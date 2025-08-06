//
//  ContentView.swift
//  LLMTest
//
//  Created by Uttam Kumar Panasala on 8/6/25.
//

import SwiftUI

struct ContentView: View {
    @State private var hasCompletedSetup = UserDefaults.standard.bool(forKey: "hasCompletedFirstTimeSetup")
    @StateObject private var modelManager = ModelManager.shared
    
    var body: some View {
        Group {
            if hasCompletedSetup || !modelManager.downloadedModels.isEmpty {
                ConversationListView()
            } else {
                FirstTimeSetupView()
                    .onReceive(NotificationCenter.default.publisher(for: .init("FirstTimeSetupCompleted"))) { _ in
                        hasCompletedSetup = true
                    }
            }
        }
        .onAppear {
            // Check if setup was completed while app was running
            hasCompletedSetup = UserDefaults.standard.bool(forKey: "hasCompletedFirstTimeSetup")
        }
    }
}

#Preview {
    ContentView()
}
