import Foundation

struct CaptureEvent: Identifiable, Codable {
    var id: UUID = UUID()
    let timestamp: Date
    let type: String
    let bundleID: String
}
