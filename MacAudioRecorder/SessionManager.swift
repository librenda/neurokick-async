import Foundation
import SwiftData
import AppKit

/// Service responsible for managing recording sessions and their associated files
@available(macOS 12.0, *)
class SessionManager: ObservableObject {
    
    // MARK: - Singleton
    static let shared = SessionManager()
    
    // MARK: - Private Properties
    private let documentsPath: URL
    private let sessionsDirectory: URL
    
    private init() {
        // Set up sessions directory in Documents
        self.documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.sessionsDirectory = documentsPath.appendingPathComponent("NeuroKick_Sessions")
        
        // Create sessions directory if it doesn't exist
        createSessionsDirectoryIfNeeded()
    }
    
    // MARK: - Directory Management
    
    /// Creates the sessions directory if it doesn't exist
    private func createSessionsDirectoryIfNeeded() {
        if !FileManager.default.fileExists(atPath: sessionsDirectory.path) {
            do {
                try FileManager.default.createDirectory(
                    at: sessionsDirectory,
                    withIntermediateDirectories: true,
                    attributes: nil
                )
                print("✅ Created sessions directory at: \(sessionsDirectory.path)")
            } catch {
                print("❌ Failed to create sessions directory: \(error)")
            }
        }
    }
    
    /// Creates a unique directory for a new session
    private func createSessionDirectory(for sessionId: UUID) -> URL {
        let sessionDir = sessionsDirectory.appendingPathComponent(sessionId.uuidString)
        
        do {
            try FileManager.default.createDirectory(
                at: sessionDir,
                withIntermediateDirectories: true,
                attributes: nil
            )
        } catch {
            print("❌ Failed to create session directory: \(error)")
        }
        
        return sessionDir
    }
    
    // MARK: - Session Creation
    
    /// Creates a new recording session with the given title and returns the session directory path
    func createNewSession(title: String) -> (session: RecordingSession, directory: URL) {
        let session = RecordingSession(
            title: title,
            audioFilePath: "" // Will be set when recording is saved
        )
        
        let sessionDirectory = createSessionDirectory(for: session.id)
        
        return (session, sessionDirectory)
    }
    
    /// Saves an audio recording to the session directory and updates the session model
    func saveAudioRecording(
        for session: RecordingSession,
        from sourceURL: URL,
        modelContext: ModelContext
    ) throws {
        let sessionDir = sessionsDirectory.appendingPathComponent(session.id.uuidString)
        let destinationURL = sessionDir.appendingPathComponent("recording.m4a")
        
        // Copy the audio file to the session directory
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }
        
        try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
        
        // Update session model with the new path
        session.audioFilePath = destinationURL.path
        session.updateModificationDate()
        
        // Save to SwiftData
        modelContext.insert(session)
        try modelContext.save()
        
        print("✅ Audio recording saved to: \(destinationURL.path)")
    }
    
    /// Saves a transcript to the session directory and updates the session model
    func saveTranscript(
        for session: RecordingSession,
        content: String,
        modelContext: ModelContext
    ) throws {
        let sessionDir = sessionsDirectory.appendingPathComponent(session.id.uuidString)
        let transcriptURL = sessionDir.appendingPathComponent("transcript.txt")
        
        let fullContent = """
        === NEUROKICK TRANSCRIPT ===
        Session: \(session.title)
        Created: \(session.createdAt)
        Generated: \(Date())
        
        \(content)
        
        === END TRANSCRIPT ===
        """
        
        try fullContent.write(to: transcriptURL, atomically: true, encoding: .utf8)
        
        // Update session model
        session.transcriptFilePath = transcriptURL.path
        session.updateModificationDate()
        
        try modelContext.save()
        
        print("✅ Transcript saved to: \(transcriptURL.path)")
    }
    
    /// Saves an analysis result to the session directory and updates the session model
    func saveAnalysis(
        for session: RecordingSession,
        content: String,
        analysisType: String,
        originalText: String,
        modelContext: ModelContext
    ) throws {
        let sessionDir = sessionsDirectory.appendingPathComponent(session.id.uuidString)
        let analysisURL = sessionDir.appendingPathComponent("analysis.txt")
        
        let newAnalysisContent = """
        === NEUROKICK \(analysisType.uppercased()) ANALYSIS ===
        Session: \(session.title)
        Generated: \(Date())
        Analysis Type: \(analysisType)
        
        === ORIGINAL CONTENT ===
        \(originalText)
        
        === \(analysisType.uppercased()) RESULT ===
        \(content)
        
        === END ANALYSIS ===
        """
        
        // Check if analysis file already exists
        if FileManager.default.fileExists(atPath: analysisURL.path) {
            // Append to existing file instead of overwriting
            let existingContent = try String(contentsOf: analysisURL, encoding: .utf8)
            let combinedContent = existingContent + "\n\n" + newAnalysisContent
            try combinedContent.write(to: analysisURL, atomically: true, encoding: .utf8)
            print("✅ Analysis appended to existing file: \(analysisURL.path)")
        } else {
            // Create new analysis file
            try newAnalysisContent.write(to: analysisURL, atomically: true, encoding: .utf8)
            // Update session model only if this is the first analysis
            session.analysisFilePath = analysisURL.path
            print("✅ Analysis saved to new file: \(analysisURL.path)")
        }
        
        session.updateModificationDate()
        try modelContext.save()
    }
    
    // MARK: - Session Retrieval
    
    /// Fetches all sessions sorted by creation date (newest first)
    func fetchAllSessions(modelContext: ModelContext) throws -> [RecordingSession] {
        let descriptor = FetchDescriptor<RecordingSession>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }
    
    /// Fetches sessions created within a specific date range
    func fetchSessions(
        from startDate: Date,
        to endDate: Date,
        modelContext: ModelContext
    ) throws -> [RecordingSession] {
        let predicate = #Predicate<RecordingSession> { session in
            session.createdAt >= startDate && session.createdAt <= endDate
        }
        
        let descriptor = FetchDescriptor<RecordingSession>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        
        return try modelContext.fetch(descriptor)
    }
    
    // MARK: - Session Updates
    
    /// Updates a session's metadata
    func updateSession(
        _ session: RecordingSession,
        title: String? = nil,
        tags: [String]? = nil,
        notes: String? = nil,
        duration: TimeInterval? = nil,
        modelContext: ModelContext
    ) throws {
        if let title = title {
            session.title = title
        }
        if let tags = tags {
            session.tags = tags
        }
        if let notes = notes {
            session.notes = notes
        }
        if let duration = duration {
            session.duration = duration
        }
        
        session.updateModificationDate()
        try modelContext.save()
    }
    
    // MARK: - Session Deletion
    
    /// Deletes a session and all its associated files
    func deleteSession(
        _ session: RecordingSession,
        modelContext: ModelContext
    ) throws {
        let sessionDir = sessionsDirectory.appendingPathComponent(session.id.uuidString)
        
        // Delete the session directory and all its contents
        if FileManager.default.fileExists(atPath: sessionDir.path) {
            try FileManager.default.removeItem(at: sessionDir)
            print("✅ Deleted session directory: \(sessionDir.path)")
        }
        
        // Remove from SwiftData
        modelContext.delete(session)
        try modelContext.save()
        
        print("✅ Session deleted: \(session.title)")
    }
    
    // MARK: - File Operations
    
    /// Opens a session's directory in Finder
    func openSessionInFinder(_ session: RecordingSession) {
        let sessionDir = sessionsDirectory.appendingPathComponent(session.id.uuidString)
        NSWorkspace.shared.open(sessionDir)
    }
    
    /// Opens the main sessions directory in Finder
    func openSessionsDirectory() {
        NSWorkspace.shared.open(sessionsDirectory)
    }
    
    /// Returns the URL for a session's directory
    func getSessionDirectory(for session: RecordingSession) -> URL {
        return sessionsDirectory.appendingPathComponent(session.id.uuidString)
    }
} 