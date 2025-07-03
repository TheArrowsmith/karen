//
//  BackendProcess.swift
//  karen
//
//  Created by Build Script on 01/07/2025.
//

import Foundation

final class BackendProcess {
    static let shared = BackendProcess()
    private var task: Process?
    
    private init() {}
    
    func start() {
        guard task == nil else {
            print("⚠️ Backend process already running")
            return
        }
        
        guard let execPath = Bundle.main.path(forResource: "karen_backend", ofType: nil) else {
            print("❌ Backend binary not found in bundle")
            return
        }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: execPath)
        
        // Inherit environment variables (including OPENAI_API_KEY if set)
        var environment = ProcessInfo.processInfo.environment
        
        // You can also set environment variables directly if needed:
        // environment["OPENAI_API_KEY"] = "your-key-here"
        
        process.environment = environment
        
        // Redirect output for debugging (optional)
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        do {
            try process.run()
            task = process
            print("✅ Started backend server (pid \(process.processIdentifier))")
            
            // Optional: Monitor process output in background
            pipe.fileHandleForReading.readabilityHandler = { fileHandle in
                let data = fileHandle.availableData
                if !data.isEmpty {
                    let output = String(data: data, encoding: .utf8) ?? ""
                    print("📡 Backend: \(output.trimmingCharacters(in: .whitespacesAndNewlines))")
                }
            }
            
        } catch {
            print("❌ Failed to start backend: \(error)")
        }
    }
    
    func stop() {
        guard let task = task else { return }
        
        print("🛑 Stopping backend server...")
        task.terminate()
        
        // Wait a moment for graceful shutdown
        DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) { [weak self] in
            if task.isRunning {
                print("⚠️ Force killing backend process")
                task.interrupt()
            }
            self?.task = nil
        }
    }
    
    var isRunning: Bool {
        return task?.isRunning ?? false
    }
}