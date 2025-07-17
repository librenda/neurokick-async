import SwiftUI
import SwiftData
import AVFoundation

@available(macOS 12.0, *)
struct SessionsListView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var sessionManager = SessionManager.shared
    
    // Active session binding from parent
    @Binding var activeSession: RecordingSession?
    
    // State for managing sessions list
    @State private var sessions: [RecordingSession] = []
    @State private var selectedSession: RecordingSession?
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    // State for session creation
    @State private var showingNewSessionSheet = false
    @State private var newSessionTitle = ""
    
    // State for session editing
    @State private var showingEditSheet = false
    @State private var editingSession: RecordingSession?
    @State private var editTitle = ""
    @State private var editNotes = ""
    @State private var editTags = ""
    
    // State for playback
    @State private var audioPlayer: AVAudioPlayer?
    @State private var playingSession: RecordingSession?
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with title and actions
            HStack {
                Text("Recording Sessions")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button(action: {
                    sessionManager.openSessionsDirectory()
                }) {
                    Label("Open Folder", systemImage: "folder")
                }
                .buttonStyle(.bordered)
                
                Button(action: {
                    newSessionTitle = "Session \(DateFormatter.sessionTitle.string(from: Date()))"
                    showingNewSessionSheet = true
                }) {
                    Label("New Session", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
                
            // Error message display
            if let errorMessage = errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                    Text(errorMessage)
                        .foregroundColor(.primary)
                    Spacer()
                    Button("Dismiss") {
                        self.errorMessage = nil
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
                .padding(.horizontal)
            }
            
            // Sessions table content - takes up remaining space
            if isLoading {
                ProgressView("Loading sessions...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if sessions.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "waveform.path.ecg")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    
                    Text("No recording sessions yet")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    
                    Text("Create your first session to get started")
                        .foregroundColor(.secondary)
                    
                    Button("Create Session") {
                        newSessionTitle = "Session \(DateFormatter.sessionTitle.string(from: Date()))"
                        showingNewSessionSheet = true
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Sessions table - expands to fill available space
                Table(sessions) {
                    TableColumn("Title") { session in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(session.title)
                                .fontWeight(.medium)
                            
                            if !session.tags.isEmpty {
                                HStack {
                                    ForEach(session.tags.prefix(3), id: \.self) { tag in
                                        Text(tag)
                                            .font(.caption)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.blue.opacity(0.2))
                                            .cornerRadius(4)
                                    }
                                    if session.tags.count > 3 {
                                        Text("+\(session.tags.count - 3)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                    }
                    .width(200)
                    
                    TableColumn("Created") { session in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(session.createdAt, style: .date)
                                .fontWeight(.medium)
                            Text(session.createdAt, style: .time)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .width(120)
                    
                    TableColumn("Duration") { session in
                        Text(session.formattedDuration)
                            .font(.system(.body, design: .monospaced))
                    }
                    .width(80)
                    
                    TableColumn("Files") { session in
                        HStack(spacing: 8) {
                            // Audio file indicator
                            if session.audioFileExists {
                                Image(systemName: "waveform")
                                    .foregroundColor(.blue)
                                    .help("Audio file available")
                            } else {
                                Image(systemName: "waveform")
                                    .foregroundColor(.gray)
                                    .help("Audio file missing")
                            }
                            
                            // Transcript file indicator
                            if session.transcriptFileExists {
                                Image(systemName: "doc.text")
                                    .foregroundColor(.green)
                                    .help("Transcript available")
                            } else {
                                Image(systemName: "doc.text")
                                    .foregroundColor(.gray)
                                    .help("No transcript")
                            }
                            
                            // Analysis file indicator
                            if session.analysisFileExists {
                                Image(systemName: "brain")
                                    .foregroundColor(.purple)
                                    .help("Analysis available")
                            } else {
                                Image(systemName: "brain")
                                    .foregroundColor(.gray)
                                    .help("No analysis")
                            }
                        }
                    }
                    .width(100)
                    
                    TableColumn("Actions") { session in
                        HStack(spacing: 8) {
                            // Play button
                            if session.audioFileExists {
                                Button(action: {
                                    togglePlayback(for: session)
                                }) {
                                    Image(systemName: playingSession?.id == session.id ? "pause.circle.fill" : "play.circle.fill")
                                }
                                .buttonStyle(.borderless)
                                .help("Play/Pause audio")
                            }
                            
                            // Edit button
                            Button(action: {
                                editingSession = session
                                editTitle = session.title
                                editNotes = session.notes
                                editTags = session.tags.joined(separator: ", ")
                                showingEditSheet = true
                            }) {
                                Image(systemName: "pencil")
                            }
                            .buttonStyle(.borderless)
                            .help("Edit session")
                            
                            // Open in Finder button
                            Button(action: {
                                sessionManager.openSessionInFinder(session)
                            }) {
                                Image(systemName: "folder")
                            }
                            .buttonStyle(.borderless)
                            .help("Open in Finder")
                            
                            // Delete button
                            Button(action: {
                                deleteSession(session)
                            }) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.borderless)
                            .help("Delete session")
                        }
                    }
                    .width(150)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contextMenu(forSelectionType: RecordingSession.ID.self) { selection in
                    if let sessionId = selection.first,
                       let session = sessions.first(where: { $0.id == sessionId }) {
                        
                        Button("Edit") {
                            editingSession = session
                            editTitle = session.title
                            editNotes = session.notes
                            editTags = session.tags.joined(separator: ", ")
                            showingEditSheet = true
                        }
                        
                        Button("Open in Finder") {
                            sessionManager.openSessionInFinder(session)
                        }
                        
                        Divider()
                        
                        Button("Delete", role: .destructive) {
                            deleteSession(session)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            loadSessions()
        }
        .sheet(isPresented: $showingNewSessionSheet) {
            newSessionSheet
        }
        .sheet(isPresented: $showingEditSheet) {
            editSessionSheet
        }
        .listStyle(InsetListStyle())
        .background(Color(NSColor.windowBackgroundColor).opacity(0.98))  // Clean, off-white background
        .environment(\.colorScheme, .light)  // Ensuring light mode for consistency
    }
    
    // MARK: - New Session Sheet
    private var newSessionSheet: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Create New Session")
                    .font(.title2)
                    .fontWeight(.bold)
                
                TextField("Session Title", text: $newSessionTitle)
                    .textFieldStyle(.roundedBorder)
                
                HStack {
                    Button("Cancel") {
                        showingNewSessionSheet = false
                    }
                    .buttonStyle(.bordered)
                    
                    Spacer()
                    
                    Button("Create") {
                        createNewSession()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(newSessionTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding()
            .frame(width: 400, height: 200)
        }
    }
    
    // MARK: - Edit Session Sheet
    private var editSessionSheet: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Edit Session")
                    .font(.title2)
                    .fontWeight(.bold)
                
                TextField("Session Title", text: $editTitle)
                    .textFieldStyle(.roundedBorder)
                
                TextField("Tags (comma-separated)", text: $editTags)
                    .textFieldStyle(.roundedBorder)
                
                TextField("Notes", text: $editNotes, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(3...6)
                
                HStack {
                    Button("Cancel") {
                        showingEditSheet = false
                        editingSession = nil
                    }
                    .buttonStyle(.bordered)
                    
                    Spacer()
                    
                    Button("Save") {
                        saveSessionEdits()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(editTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding()
            .frame(width: 400, height: 300)
        }
    }
    
    // MARK: - Methods
    
    private func loadSessions() {
        isLoading = true
        errorMessage = nil
        
        do {
            sessions = try sessionManager.fetchAllSessions(modelContext: modelContext)
            isLoading = false
        } catch {
            errorMessage = "Failed to load sessions: \(error.localizedDescription)"
            isLoading = false
        }
    }
    
    private func createNewSession() {
        do {
            let (session, _) = sessionManager.createNewSession(title: newSessionTitle)
            modelContext.insert(session)
            try modelContext.save()
            
            sessions.insert(session, at: 0) // Add to beginning of list
            showingNewSessionSheet = false
            newSessionTitle = ""
        } catch {
            errorMessage = "Failed to create session: \(error.localizedDescription)"
        }
    }
    
    private func saveSessionEdits() {
        guard let session = editingSession else { return }
        
        do {
            let tags = editTags.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
            
            try sessionManager.updateSession(
                session,
                title: editTitle,
                tags: tags,
                notes: editNotes,
                modelContext: modelContext
            )
            
            loadSessions() // Reload to reflect changes
            showingEditSheet = false
            editingSession = nil
        } catch {
            errorMessage = "Failed to update session: \(error.localizedDescription)"
        }
    }
    
    private func deleteSession(_ session: RecordingSession) {
        do {
            try sessionManager.deleteSession(session, modelContext: modelContext)
            sessions.removeAll { $0.id == session.id }
            
            // Clear active session if we deleted it
            if activeSession?.id == session.id {
                activeSession = nil
            }
        } catch {
            errorMessage = "Failed to delete session: \(error.localizedDescription)"
        }
    }
    
    private func togglePlayback(for session: RecordingSession) {
        // Stop current playback if playing a different session
        if let currentPlaying = playingSession, currentPlaying.id != session.id {
            audioPlayer?.stop()
            playingSession = nil
        }
        
        // Toggle playback for the selected session
        if playingSession?.id == session.id {
            // Currently playing this session, so pause
            audioPlayer?.pause()
            playingSession = nil
        } else {
            // Start playing this session
            guard session.audioFileExists else { return }
            
            do {
                let audioURL = URL(fileURLWithPath: session.audioFilePath)
                audioPlayer = try AVAudioPlayer(contentsOf: audioURL)
                audioPlayer?.play()
                playingSession = session
                
                // Set up completion handler to reset state when finished
                DispatchQueue.global().async {
                    while self.audioPlayer?.isPlaying == true {
                        usleep(100000) // Check every 0.1 seconds
                    }
                    DispatchQueue.main.async {
                        self.playingSession = nil
                    }
                }
                
            } catch {
                errorMessage = "Failed to play audio: \(error.localizedDescription)"
            }
        }
    }
}

// MARK: - Extensions

extension DateFormatter {
    static let sessionTitle: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy 'at' h:mm a"
        return formatter
    }()
}

// MARK: - Preview

@available(macOS 12.0, *)
struct SessionsListView_Previews: PreviewProvider {
    static var previews: some View {
        SessionsListView(activeSession: .constant(nil))
            .modelContainer(for: RecordingSession.self, inMemory: true)
            .frame(width: 800, height: 600)
    }
} 