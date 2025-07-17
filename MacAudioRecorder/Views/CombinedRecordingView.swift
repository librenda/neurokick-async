import SwiftUI
import AVFoundation
import CoreMedia
#if os(macOS)
import AppKit
#endif

#if os(macOS)
/// NSVisualEffectView wrapper for blur / vibrancy backgrounds (macOS 11+)
struct VisualEffectBlur: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
#endif

@available(macOS 11.0, *)
struct GlassBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                VisualEffectBlur(material: .sidebar) // choose material that provides blur on most macOS versions
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            )
            .shadow(color: .black.opacity(0.2), radius: 5, x: 0, y: 2)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(.white.opacity(0.3), lineWidth: 1)
            )
    }
}

extension View {
    func glassEffect() -> some View {
        modifier(GlassBackground())
    }
}

@available(macOS 11.0, *)
struct CombinedRecordingView: View {
    // Environment variable to control the view's presentation state (for dismissing the sheet)
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    // Active session binding from parent
    @Binding var activeSession: RecordingSession?

    // StateObject for the combined audio engine
    @StateObject private var combinedEngine = CombinedAudioEngine()
    // Transcriber + View-Model
    @StateObject private var transcriber: WhisperTranscriber
    @StateObject private var viewModel: TranscriptionViewModel

    // Session management
    @StateObject private var sessionManager = SessionManager.shared
    @State private var showingSessionTitleSheet = false
    @State private var sessionTitle = ""
    @State private var recordingStartTime: Date?

    // Playback state
    @State private var audioPlayer: AVAudioPlayer?
    @State private var isPlaying = false

    init(activeSession: Binding<RecordingSession?>) {
        self._activeSession = activeSession
        let t = WhisperTranscriber()
        _transcriber = StateObject(wrappedValue: t)
        _viewModel = StateObject(wrappedValue: TranscriptionViewModel(transcriber: t, localLLMService: LocalLLMService.shared))
    }
    
    private func cleanup(isTabSwitch: Bool = false) {
        // Only cancel analysis tasks and clear UI state during tab switch
        if isTabSwitch {
            viewModel.cancelCurrentAnalysis()
            return
        }
        
        // Full cleanup only when truly leaving the view
        viewModel.teardownAllResources()
        combinedEngine.cleanup()
        audioPlayer?.stop()
        audioPlayer = nil
        isPlaying = false
    }

    var body: some View {
        VStack(spacing: 0) {
            // Background gradient + glass container
            ZStack {
                // Underlying gradient to visualize blur
                LinearGradient(colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.6)],
                               startPoint: .topLeading,
                               endPoint: .bottomTrailing)
                    .ignoresSafeArea()

                // Main glass container
                ScrollView {
                    VStack(spacing: 20) {
                        // Logo
                        Image("nk_logo")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 150, height: 150)
                        Text("NeuroKick")
                            .font(.largeTitle)
                            .foregroundColor(.black)
                            .padding(.top, 40)
                        
                        // Active Session Status
                        HStack {
                            Image(systemName: activeSession != nil ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(activeSession != nil ? .green : .gray)
                            
                            if let session = activeSession {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Active Session: \(session.title)")
                                        .font(.headline)
                                        .foregroundColor(.black)
                                    Text("Created: \(session.createdAt, style: .date)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            } else {
                                Text("No Active Session")
                                    .font(.headline)
                                    .foregroundColor(.gray)
                            }
                            
                            Spacer()
                            
                            if activeSession != nil {
                                Button("Clear Session") {
                                    activeSession = nil
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }
                        .padding()
                        .background(Color.white.opacity(0.8))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(activeSession != nil ? Color.green : Color.gray, lineWidth: 1)
                        )

                        // Live transcript
                        ScrollView {
                            Text(viewModel.transcript.isEmpty ? "(Listening...)" : viewModel.transcript)
                                .textSelection(.enabled) // Enable text selection
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                                .foregroundColor(.black)
                        }
                        .frame(height: 320)
                        .glassEffect()

                        HStack(spacing: 20) {
                            // Record / Stop Button
                            Button {
                                if combinedEngine.isRecording {
                                    stopRecording()
                                } else {
                                    startRecording()
                                }
                            } label: {
                                Label(combinedEngine.isRecording ? "Stop Recording" : "Record Mic + System",
                                      systemImage: combinedEngine.isRecording ? "stop.circle.fill" : "record.circle.fill")
                                    .frame(minWidth: 120)
                            }
                            .applyButtonStyling(color: .red)

                            // Play / Pause Button
                            // Button {
                            //     togglePlayback()
                            // } label: {
                            //     Label(isPlaying ? "Pause" : "Play",
                            //           systemImage: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            //         .frame(minWidth: 120)
                            // }
                            // .applyButtonStyling(color: .blue)
                            // .disabled(combinedEngine.isRecording || combinedEngine.completedRecordingURL == nil)

                            // Save Transcript Button
                            Button {
                                saveTranscript()
                            } label: {
                                Label("Save Transcript", systemImage: "doc.text.fill")
                                    .frame(minWidth: 120)
                            }
                            .applyButtonStyling(color: .orange)
                            .disabled(viewModel.transcript.isEmpty)
                        }

                        // Auto-Save Status Section
                        VStack(spacing: 8) {
                            HStack {
                                Text("Auto-Save Status")
                                    .font(.headline)
                                    .foregroundColor(.black)
                                
                                Spacer()
                                
                                Toggle("Auto-Save", isOn: $viewModel.autoSaveEnabled)
                                    .toggleStyle(SwitchToggleStyle())
                            }
                            
                            if !viewModel.lastSavedPath.isEmpty {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Files saved to:")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        
                                        Text("~/Documents/")
                                            .font(.caption)
                                            .foregroundColor(.blue)
                                            .onTapGesture {
                                                openDocumentsFolder()
                                            }
                                            .help("Click to open Documents folder")
                                    }
                                    
                                    Spacer()
                                    
                                    Button("Open Folder") {
                                        openDocumentsFolder()
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                }
                            } else if viewModel.autoSaveEnabled {
                                HStack {
                                    Image(systemName: "clock")
                                        .foregroundColor(.orange)
                                    
                                    Text("Waiting for transcript to auto-save...")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    Spacer()
                                }
                            } else {
                                HStack {
                                    Image(systemName: "pause.circle")
                                        .foregroundColor(.gray)
                                    
                                    Text("Auto-save disabled")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    Spacer()
                                }
                            }
                        }
                        .padding()
                        .glassEffect()

                        // DeepSeek analysis controls
                        VStack(spacing: 8) {
                            if activeSession == nil {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle")
                                        .foregroundColor(.orange)
                                    Text("No active session. Record new audio to enable analysis.")
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                }
                                .padding()
                                .background(Color.orange.opacity(0.1))
                                .cornerRadius(8)
                            }
                            
                            HStack {
                                Button("Workplace Analysis") {
                                    performAnalysis(.workplace)
                                }
                                .applyButtonStyling(color: .blue)
                                .disabled(viewModel.isAnalyzing || viewModel.transcript.isEmpty || activeSession == nil)

                                Button("General Summary") {
                                    performAnalysis(.summary)
                                }
                                .applyButtonStyling(color: .purple)
                                .disabled(viewModel.isAnalyzing || viewModel.transcript.isEmpty || activeSession == nil)

                                Button("Behavioural Analysis") {
                                    performAnalysis(.behavioral)
                                }
                                .applyButtonStyling(color: .green)
                                .disabled(viewModel.isAnalyzing || viewModel.transcript.isEmpty || activeSession == nil)

                                if viewModel.isAnalyzing {
                                    ProgressView()
                                }
                            }
                        }

                        // Test Input Section
                        VStack(spacing: 12) {
                            // Header with clear button
                            HStack {
                                Text("Test Analysis")
                                    .font(.headline)
                                    .foregroundColor(.black)
                                
                                Spacer()
                                
                                if !viewModel.testInput.isEmpty {
                                    VStack(spacing: 8) {
                                        ScrollView {
                                            Button(action: { viewModel.testInput = "" }) {
                                                Image(systemName: "xmark.circle.fill")
                                                    .foregroundColor(.secondary)
                                            }
                                            .buttonStyle(.plain)
                                            .help("Clear input")

                                            Button {
                                                saveSummary()
                                            } label: {
                                                Label("Save Summary", systemImage: "square.and.arrow.down")
                                                    .frame(minWidth: 120)
                                            }
                                            .applyButtonStyling(color: .green)
                                        }
                                    }
                                }
                
                            }
                            
                            // Text input
                            TextEditor(text: $viewModel.testInput)
                                .frame(height: 100)
                                .padding(8)
                                .background(Color.white.opacity(0.8))
                                .cornerRadius(8)
                                .foregroundColor(.black)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                )
                                .disabled(viewModel.isAnalyzing)
                                .overlay(
                                    Group {
                                        if viewModel.testInput.isEmpty {
                                            Text("Paste or type text to analyze...")
                                                .foregroundColor(.secondary)
                                                .padding(12)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                    },
                                    alignment: .topLeading
                                )
                            
                            // Add the HStack with Picker and Analyze button here
                            HStack(spacing: 12) {
                                Picker("Analysis Type", selection: $viewModel.selectedAnalysisType) {
                                    ForEach(TranscriptionViewModel.AnalysisType.allCases) { type in
                                        Text(type.rawValue).tag(type)
                                    }
                                }
                                .pickerStyle(.menu)
                                .frame(width: 200)
                                .disabled(viewModel.isAnalyzing)
                                
                                Button(action: {
                                    performTestAnalysis()
                                }) {
                                    HStack {
                                        if viewModel.isAnalyzing {
                                            ProgressView()
                                                .scaleEffect(0.8)
                                                .padding(.trailing, 4)
                                        }
                                        Text(viewModel.isAnalyzing ? "Analyzing..." : "Analyze Text")
                                    }
                                    .frame(minWidth: 120)
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(viewModel.testInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || 
                                        viewModel.isAnalyzing)
                            }
                            
                
                        }
                        .padding()
                        .glassEffect()

                        // Summary output
                        if !viewModel.summary.isEmpty {
                            VStack(spacing: 8) {
                                ScrollView {
                                    Text(viewModel.summary)
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding()
                                    .foregroundColor(.black)
                                }
                                .frame(height: 150)
                                .glassEffect()

                                Button {
                                    saveSummary()
                                } label: {
                                    Label("Save Summary", systemImage: "square.and.arrow.down")
                                        .frame(minWidth: 120)
                                }
                                .applyButtonStyling(color: .green)
                            }
                        }
                    }
                    .padding(.horizontal, 30)
                }

                Spacer()

                // Back button to dismiss the sheet
                // Button("Back") {
                //     presentationMode.wrappedValue.dismiss()
                // }
                // .padding(.bottom, 20)
                // .applyButtonStyling(color: .gray)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor).opacity(0.98))  // Clean, off-white background
        .environment(\.colorScheme, .light)  // Ensuring light mode for consistency
        .onAppear {
            combinedEngine.transcriber = transcriber
        }
        .onDisappear {
            cleanup(isTabSwitch: true)  // Less aggressive cleanup for tab switches
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .inactive || newPhase == .background {
                cleanup(isTabSwitch: false)  // Full cleanup when app goes to background
            }
        }
        .sheet(isPresented: $showingSessionTitleSheet) {
            sessionTitleSheet
        }
    }

    // MARK: - Playback
    private func togglePlayback() {
        if isPlaying {
            audioPlayer?.stop()
            isPlaying = false
            combinedEngine.statusMessage = "Playback stopped."
            return
        }

        guard let url = combinedEngine.completedRecordingURL else {
            combinedEngine.statusMessage = "No recording to play."
            return
        }

        do {
            let fileSize = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.intValue ?? 0
            print("[Playback] Attempting to play file at \(url.path) size: \(fileSize) bytes")

            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.volume = 1.0 // ensure audible
            audioPlayer?.prepareToPlay()
            if audioPlayer?.play() == true {
                print("[Playback] AVAudioPlayer started successfully. duration: \(audioPlayer?.duration ?? 0)s")
                isPlaying = true
                combinedEngine.statusMessage = "Playing..."

                // Automatically reset state when finished
                DispatchQueue.main.asyncAfter(deadline: .now() + (audioPlayer?.duration ?? 0)) {
                    isPlaying = false
                    combinedEngine.statusMessage = "Playback finished."
                }
            } else {
                print("[Playback] AVAudioPlayer failed to start.")
                // Convert to M4A for playback
                exportM4A(from: url, to: url.deletingPathExtension().appendingPathExtension("m4a"))
                combinedEngine.statusMessage = "Failed to play, converting to M4A..."
            }
        } catch {
            combinedEngine.statusMessage = "Playback error: \(error.localizedDescription)"
        }
    }

    // MARK: - Save Recording
    private func saveRecording() {
        guard let sourceURL = combinedEngine.completedRecordingURL else {
            combinedEngine.statusMessage = "Error: No recording available to save."
            return
        }

        let panel = NSSavePanel()
        panel.title = "Save NeuroKick"
        panel.nameFieldStringValue = "NeuroKick.m4a"
        panel.allowedFileTypes = ["m4a"]
        panel.canCreateDirectories = true

        panel.begin { response in
            if response == .OK, let destURL = panel.url {
                exportM4A(from: sourceURL, to: destURL)
            } else {
                combinedEngine.statusMessage = "Save cancelled."
            }
        }
    }

    // MARK: - Save Transcript
    private func saveTranscript() {
        let panel = NSSavePanel()
        panel.title = "Save Transcript"
        panel.nameFieldStringValue = "Transcript.txt"
        panel.allowedFileTypes = ["txt"]
        panel.canCreateDirectories = true

        panel.begin { response in
            if response == .OK, let destURL = panel.url {
                do {
                    try viewModel.transcript.write(to: destURL, atomically: true, encoding: .utf8)
                    combinedEngine.statusMessage = "Transcript saved to \(destURL.lastPathComponent)"
                } catch {
                    combinedEngine.statusMessage = "Failed to save transcript: \(error.localizedDescription)"
                }
            } else {
                combinedEngine.statusMessage = "Save transcript cancelled."
            }
        }
    }

    // MARK: - Save Summary
    private func saveSummary() {
        guard !viewModel.summary.isEmpty else { return }

        let panel = NSSavePanel()
        panel.title = "Save Summary"
        panel.nameFieldStringValue = "Summary.txt"
        panel.allowedFileTypes = ["txt"]
        panel.canCreateDirectories = true

        panel.begin { response in
            if response == .OK, let destURL = panel.url {
                do {
                    try viewModel.summary.write(to: destURL, atomically: true, encoding: .utf8)
                    combinedEngine.statusMessage = "Summary saved to \(destURL.lastPathComponent)"
                } catch {
                    combinedEngine.statusMessage = "Failed to save summary: \(error.localizedDescription)"
                }
            } else {
                combinedEngine.statusMessage = "Save summary cancelled."
            }
        }
    }
    
    // MARK: - Open Documents Folder
    private func openDocumentsFolder() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        NSWorkspace.shared.open(documentsPath)
    }

    // Convert CAF/PCM to M4A using AVAssetExportSession
    private func exportM4A(from sourceURL: URL, to destURL: URL) {
        let asset = AVAsset(url: sourceURL)

        guard let exporter = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            combinedEngine.statusMessage = "M4A export not supported."
            return
        }

        exporter.outputURL = destURL
        exporter.outputFileType = .m4a

        exporter.exportAsynchronously {
            DispatchQueue.main.async {
                switch exporter.status {
                case .completed:
                    self.combinedEngine.statusMessage = "Saved M4A to \(destURL.lastPathComponent)"
                case .failed, .cancelled:
                    self.combinedEngine.statusMessage = "Export failed: \(exporter.error?.localizedDescription ?? "Unknown error")"
                default:
                    break
                }
            }
        }
    }
    
    // MARK: - Session Management
    
    /// Session title input sheet
    private var sessionTitleSheet: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Create New Recording Session")
                    .font(.title2)
                    .fontWeight(.bold)
                
                TextField("Session Title", text: $sessionTitle)
                    .textFieldStyle(.roundedBorder)
                
                HStack {
                    Button("Cancel") {
                        showingSessionTitleSheet = false
                        sessionTitle = ""
                    }
                    .buttonStyle(.bordered)
                    
                    Spacer()
                    
                    Button("Start Recording") {
                        createSessionAndStartRecording()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(sessionTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding()
            .frame(width: 400, height: 200)
        }
    }
    
    /// Starts a new recording with session management
    private func startRecording() {
        // Generate a default session title
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d, yyyy 'at' h:mm a"
        sessionTitle = "Session \(dateFormatter.string(from: Date()))"
        
        // Directly create session and start recording (no dialog)
        createSessionAndStartRecording()
    }
    
    /// Creates a new session and starts recording
    private func createSessionAndStartRecording() {
        do {
            let (session, _) = sessionManager.createNewSession(title: sessionTitle)
            activeSession = session
            
            // Insert session into SwiftData context but don't save yet (will save when recording completes)
            modelContext.insert(session)
            
            showingSessionTitleSheet = false
            sessionTitle = ""
            
            // Capture recording start time
            recordingStartTime = Date()
            
            // Start the actual recording
            combinedEngine.startRecording()
            
            combinedEngine.statusMessage = "Recording session '\(session.title)' started..."
            
        } catch {
            combinedEngine.statusMessage = "Failed to create session: \(error.localizedDescription)"
        }
    }
    
    /// Stops recording and saves the session
    private func stopRecording() {
        guard let session = activeSession else {
            // Fallback to normal stop recording if no session
            combinedEngine.stopRecording()
            recordingStartTime = nil
            return
        }
        
        // Stop the recording
        combinedEngine.stopRecording()
        
        // Wait for the recording to complete, then save the session
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.saveRecordingToSession(session: session)
        }
    }
    
    /// Saves the completed recording to the session
    private func saveRecordingToSession(session: RecordingSession) {
        guard let recordingURL = combinedEngine.completedRecordingURL else {
            combinedEngine.statusMessage = "Error: No recording file found to save"
            return
        }
        
        do {
            // Calculate recording duration using the actual start time
            let duration: TimeInterval
            if let startTime = recordingStartTime {
                duration = Date().timeIntervalSince(startTime)
            } else {
                // Fallback: try to get duration from audio file metadata
                let asset = AVAsset(url: recordingURL)
                duration = CMTimeGetSeconds(asset.duration)
            }
            session.duration = duration
            
            // Save the audio recording to the session directory
            try sessionManager.saveAudioRecording(
                for: session,
                from: recordingURL,
                modelContext: modelContext
            )
            
            // Save transcript if available
            if !viewModel.transcript.isEmpty {
                try sessionManager.saveTranscript(
                    for: session,
                    content: viewModel.transcript,
                    modelContext: modelContext
                )
            }
            
            combinedEngine.statusMessage = "✅ Session '\(session.title)' saved successfully!"
            recordingStartTime = nil
            // Keep activeSession for future transcription/analysis
            
        } catch {
            combinedEngine.statusMessage = "❌ Failed to save session: \(error.localizedDescription)"
            recordingStartTime = nil
            // Keep activeSession even on error so user can retry
        }
    }
    
    // MARK: - Analysis with Session Management
    
    /// Performs analysis and automatically saves to session directory
    private func performAnalysis(_ analysisType: TranscriptionViewModel.AnalysisType) {
        Task {
            do {
                // Call the appropriate analysis method
                switch analysisType {
                case .workplace:
                    viewModel.analyze()
                case .summary:
                    viewModel.summarize()
                case .behavioral:
                    viewModel.behavioralAnalyze()
                }
                
                // Wait for analysis to complete
                while viewModel.isAnalyzing {
                    try await Task.sleep(nanoseconds: 100_000_000) // Check every 0.1 seconds
                }
                
                // Save to session if analysis was successful
                if !viewModel.summary.isEmpty && !viewModel.summary.contains("failed") {
                    try await saveAnalysisToSession(analysisType: analysisType)
                }
                
            } catch {
                combinedEngine.statusMessage = "❌ Failed to complete analysis: \(error.localizedDescription)"
            }
        }
    }
    
    /// Saves analysis results to session directory
    private func saveAnalysisToSession(analysisType: TranscriptionViewModel.AnalysisType) async throws {
        // Must have an active session for analysis
        guard let session = activeSession else {
            throw NSError(domain: "SessionError", code: 0, userInfo: [NSLocalizedDescriptionKey: "No active session available for analysis"])
        }
        
        // Save the analysis to the session directory
        try sessionManager.saveAnalysis(
            for: session,
            content: viewModel.summary,
            analysisType: analysisType.rawValue,
            originalText: viewModel.transcript.isEmpty ? viewModel.testInput : viewModel.transcript,
            modelContext: modelContext
        )
        
        combinedEngine.statusMessage = "✅ \(analysisType.rawValue) saved to session '\(session.title)'"
    }
    
    /// Performs test input analysis and automatically saves to session directory
    private func performTestAnalysis() {
        Task {
            do {
                // Call the test analysis method
                await viewModel.analyzeTextInput()
                
                // Save to session if analysis was successful
                if !viewModel.summary.isEmpty && !viewModel.summary.contains("failed") {
                    try await saveAnalysisToSession(analysisType: viewModel.selectedAnalysisType)
                }
                
            } catch {
                combinedEngine.statusMessage = "❌ Failed to complete test analysis: \(error.localizedDescription)"
            }
        }
    }
}

@available(macOS 11.0, *)
struct CombinedRecordingView_Previews: PreviewProvider {
    static var previews: some View {
        CombinedRecordingView(activeSession: .constant(nil))
            .modelContainer(for: RecordingSession.self, inMemory: true)
    }
}
