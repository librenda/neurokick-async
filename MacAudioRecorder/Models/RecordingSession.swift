import Foundation
import SwiftData

/// SwiftData model representing a recording session
@Model
final class RecordingSession {
    var id: UUID
    var title: String
    var createdAt: Date
    var updatedAt: Date
    var duration: TimeInterval
    var audioFilePath: String
    var transcriptFilePath: String?
    var analysisFilePath: String?
    var tags: [String]
    var notes: String
    
    init(
        title: String,
        audioFilePath: String,
        transcriptFilePath: String? = nil,
        analysisFilePath: String? = nil,
        duration: TimeInterval = 0,
        tags: [String] = [],
        notes: String = ""
    ) {
        self.id = UUID()
        self.title = title
        self.createdAt = Date()
        self.updatedAt = Date()
        self.duration = duration
        self.audioFilePath = audioFilePath
        self.transcriptFilePath = transcriptFilePath
        self.analysisFilePath = analysisFilePath
        self.tags = tags
        self.notes = notes
    }
    
    /// Updates the session's last modified date
    func updateModificationDate() {
        self.updatedAt = Date()
    }
    
    /// Formatted duration string (e.g., "1:23:45" or "5:30")
    var formattedDuration: String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    /// Check if audio file exists on disk
    var audioFileExists: Bool {
        FileManager.default.fileExists(atPath: audioFilePath)
    }
    
    /// Check if transcript file exists on disk
    var transcriptFileExists: Bool {
        guard let path = transcriptFilePath else { return false }
        return FileManager.default.fileExists(atPath: path)
    }
    
    /// Check if analysis file exists on disk
    var analysisFileExists: Bool {
        guard let path = analysisFilePath else { return false }
        return FileManager.default.fileExists(atPath: path)
    }
} 