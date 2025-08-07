import Foundation

/// Minimal test wrapper to check if Stanford BDHG llama.cpp package is accessible
@objc public class LlamaTestWrapper: NSObject {
    
    @objc public override init() {
        super.init()
        print("LlamaTestWrapper initialized")
    }
    
    @objc public func testPackageAccess() -> Bool {
        // Try to access any llama.cpp functionality without importing
        // This will help us understand if the package is accessible at all
        print("Testing package access...")
        
        // For now, return false since we can't access the package
        return false
    }
}
