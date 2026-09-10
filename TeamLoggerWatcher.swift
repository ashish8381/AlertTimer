import Foundation

class TeamLoggerWatcher {
    var onCaptureStarted: ((CaptureEvent) -> Void)?
    
    private var process: Process?
    private var activeAttributions: Set<String> = []
    private var buffer: String = ""
    
    // The specific bundle ID to track as requested by the requirements.
    private let targetBundleID = "27KU2G7D8T.com.build80.teamloggertimer"
    
    func start() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/log")
        task.arguments = [
            "stream",
            "--style", "ndjson",
            "--predicate", "subsystem == 'com.apple.controlcenter' AND category == 'sensor-indicators' AND process == 'ControlCenter'"
        ]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        // We use readabilityHandler to process the log stream in real time.
        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            
            if let string = String(data: data, encoding: .utf8) {
                self?.processLogOutput(string)
            }
        }
        
        self.process = task
        
        do {
            try task.run()
        } catch {
            print("TeamLoggerWatcher: failed to start log stream - \(error)")
        }
    }
    
    func stop() {
        process?.terminate()
        process = nil
    }
    
    private func processLogOutput(_ output: String) {
        buffer += output
        var lines = buffer.components(separatedBy: .newlines)
        
        // The last element is either a partial line or empty string (if it ended with newline)
        buffer = lines.removeLast()
        
        for line in lines where !line.isEmpty {
            guard let data = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                  let eventMessage = json["eventMessage"] as? String else {
                continue
            }
            
            let prefix = "Active activity attributions changed to ["
            guard eventMessage.hasPrefix(prefix), eventMessage.hasSuffix("]") else {
                continue
            }
            
            // Extract the contents of the array
            let arrayString = eventMessage.dropFirst(prefix.count).dropLast()
            
            // Split by comma if there are multiple attributions
            let entries = arrayString.components(separatedBy: ",")
                .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: " \"")) }
                .filter { !$0.isEmpty }
            
            var newAttributions = Set<String>()
            
            for entry in entries {
                let parts = entry.components(separatedBy: ":")
                if parts.count >= 2 {
                    let bundleID = parts.dropFirst().joined(separator: ":")
                    
                    // FR3: ignore com.apple.* bundle IDs
                    if !bundleID.hasPrefix("com.apple.") {
                        newAttributions.insert(entry)
                    }
                }
            }
            
            // Find attributions that were not active previously
            let added = newAttributions.subtracting(activeAttributions)
            for entry in added {
                let parts = entry.components(separatedBy: ":")
                let type = parts[0]
                let bundleID = parts.dropFirst().joined(separator: ":")
                
                // FR2: Detect TeamLogger screen-capture event
                if bundleID == targetBundleID {
                    let event = CaptureEvent(timestamp: Date(), type: type, bundleID: bundleID)
                    DispatchQueue.main.async {
                        self.onCaptureStarted?(event)
                    }
                }
            }
            
            activeAttributions = newAttributions
        }
    }
}
