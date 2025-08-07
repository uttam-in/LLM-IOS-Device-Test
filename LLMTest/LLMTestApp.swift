//
//  LLMTestApp.swift
//  LLMTest
//
//  Created by Uttam Kumar Panasala on 8/6/25.
//

import SwiftUI
import SpeziLLM
import SpeziLLMLocal

@main
struct LLMTestApp: App {
    // Create LLMRunner for SpeziLLM
    private let llmRunner = LLMRunner {
        LLMLocalPlatform()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(llmRunner)
        }
    }
}
