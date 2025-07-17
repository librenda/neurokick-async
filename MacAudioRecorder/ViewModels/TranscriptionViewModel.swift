import Foundation
import Combine

/// View-model that bridges Whisper live transcript and Qwen analysis.
@available(macOS 12.0, *)
@MainActor
final class TranscriptionViewModel: ObservableObject {
    // Dependencies
    private let transcriber: WhisperTranscriber
    private let localLLMService: LocalLLMService

    // Task management
    private var currentAnalysisTask: Task<Void, Never>?
    private var currentAutoSaveTask: Task<Void, Never>?
    
    // Published state
    @Published var transcript: String = ""
    @Published var summary: String = ""
    @Published var isAnalyzing = false
    
    // Auto-save state
    @Published var lastSavedPath: String = ""
    @Published var autoSaveEnabled: Bool = true

    // Brenda - for text test analysis:
    @Published var testInput: String = ""
    @Published var selectedAnalysisType: AnalysisType = .workplace
    @Published var lastAnalysisType: AnalysisType? // Track last used type

    // Brenda - for text test analysis:
    enum AnalysisType: String, CaseIterable, Identifiable {
        case workplace = "Workplace Analysis"
        case summary = "General Summary"
        case behavioral = "Behavioral Analysis"
        
        var id: String { self.rawValue }
        
        var filePrefix: String {
            switch self {
            case .workplace: return "Workplace"
            case .summary: return "Summary"
            case .behavioral: return "Behavioral"
            }
        }
    }
    // End of Brenda's TEST add-ons
    // Rest of code:

    private var cancellables = Set<AnyCancellable>()
    private var currentSessionId: String = ""

    init(transcriber: WhisperTranscriber, localLLMService: LocalLLMService) {
        self.transcriber = transcriber
        self.localLLMService = localLLMService
        
        // Generate session ID for this transcription session
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd-HHmmss"
        self.currentSessionId = dateFormatter.string(from: Date())

        // Bridge transcriber's live text -> our transcript property
        transcriber.$liveTranscript
            .receive(on: RunLoop.main)
            .assign(to: &self.$transcript)
            
        // Auto-save transcript when it changes (with debouncing)
        $transcript
            .debounce(for: .seconds(2), scheduler: RunLoop.main)
            .sink { [weak self] newTranscript in
                self?.autoSaveTranscript(newTranscript)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Auto-Save Functionality
    private func autoSaveTranscript(_ transcript: String) {
        guard autoSaveEnabled, !transcript.isEmpty else { return }
        
        Task {
            await saveTranscriptToFile(transcript)
        }
    }
    
    private func saveTranscriptToFile(_ transcript: String) async {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileName = "transcript-\(currentSessionId).txt"
        let fileURL = documentsPath.appendingPathComponent(fileName)
        
        /*
        let neuroKickFolder = documentsPath.appendingPathComponent("NeuroKick_Results")
        
        // Create NeuroKick_Results folder if it doesn't exist
        do {
            try FileManager.default.createDirectory(at: neuroKickFolder, withIntermediateDirectories: true, attributes: nil)
        } catch {
            print("❌ Failed to create NeuroKick_Results folder: \(error)")
            return
        }
        
        let fileName = "NeuroKick_Transcript_\(currentSessionId).txt"
        let fileURL = neuroKickFolder.appendingPathComponent(fileName)
        
        */
        let content = """
        === NEUROKICK MEETING TRANSCRIPT ===
        Session: \(currentSessionId)
        Generated: \(Date())
        
        \(transcript)
        
        === END TRANSCRIPT ===
        """
        
        do {
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
            await MainActor.run {
                lastSavedPath = fileURL.path
                print("✅ Transcript auto-saved to: \(fileURL.path)")
            }
        } catch {
            print("❌ Failed to save transcript: \(error)")
        }
    }
    
    // MARK: - Manual Save Functions
    func saveCurrentTranscript() {
        guard !transcript.isEmpty else { return }
        
        Task {
            await saveTranscriptToFile(transcript)
        }
    }
    
    func saveAnalysisResult() {
        guard !summary.isEmpty else { return }
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let analysisType = lastAnalysisType?.filePrefix ?? "Analysis"
        let fileName = "\(analysisType)-\(currentSessionId).txt"
        let fileURL = documentsPath.appendingPathComponent(fileName)
        
        let content = """
        === NEUROKICK \(analysisType.uppercased()) RESULT ===
        Session: \(currentSessionId)
        Generated: \(Date())
        Analysis Type: \(lastAnalysisType?.rawValue ?? "Unknown")
        
        === ORIGINAL TRANSCRIPT ===
        \(transcript.isEmpty ? testInput : transcript)
        
        === \(analysisType.uppercased()) RESULT ===
        \(summary)
        
        === END ANALYSIS ===
        """
        
        do {
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
            lastSavedPath = fileURL.path
            print("✅ Analysis saved to: \(fileURL.path)")
        } catch {
            print("❌ Failed to save analysis: \(error)")
        }
    }

    /// Triggers Workplace Analysis via local Qwen model.
    func analyze() {
        guard !transcript.isEmpty, !isAnalyzing else { return }
        
        // Cancel any existing analysis
        cancelCurrentAnalysis()
        isAnalyzing = true
        summary = ""
        lastAnalysisType = .workplace

        currentAnalysisTask = Task {
            do {
                guard !Task.isCancelled else { return }
                let result = try await localLLMService.analyze(text: transcript)
                
                // Check for cancellation before updating state
                guard !Task.isCancelled else { return }
                summary = result
                // Auto-save analysis result
                saveAnalysisResult()
            } catch {
                if !Task.isCancelled {
                    summary = "[Analysis failed: \(error.localizedDescription)]"
                }
            }
            if !Task.isCancelled {
                isAnalyzing = false
            }
        }
    }

    /// Performs a general concise summary via local Qwen model.
    func summarize() {
        guard !transcript.isEmpty, !isAnalyzing else { return }
        
        // Cancel any existing analysis
        cancelCurrentAnalysis()
        isAnalyzing = true
        summary = ""
        lastAnalysisType = .summary

        currentAnalysisTask = Task {
            do {
                guard !Task.isCancelled else { return }
                let result = try await localLLMService.summarize(text: transcript)
                
                // Check for cancellation before updating state
                guard !Task.isCancelled else { return }
                summary = result
                // Auto-save analysis result
                saveAnalysisResult()
            } catch {
                if !Task.isCancelled {
                    summary = "[Summary failed: \(error.localizedDescription)]"
                }
            }
            if !Task.isCancelled {
                isAnalyzing = false
            }
        }
    }

    /// Performs behavioural analysis via local Qwen model.
    func behavioralAnalyze() {
        guard !transcript.isEmpty, !isAnalyzing else { return }
        
        // Cancel any existing analysis
        cancelCurrentAnalysis()
        isAnalyzing = true
        summary = ""
        lastAnalysisType = .behavioral

        currentAnalysisTask = Task {
            do {
                guard !Task.isCancelled else { return }
                let result = try await localLLMService.behavioralAnalyze(text: transcript)
                
                // Check for cancellation before updating state
                guard !Task.isCancelled else { return }
                summary = result
                // Auto-save analysis result
                saveAnalysisResult()
            } catch {
                if !Task.isCancelled {
                    summary = "[Enhanced behavioural analysis failed: \(error.localizedDescription)]"
                }
            }
            if !Task.isCancelled {
                isAnalyzing = false
            }
        }
    }

    // Brenda: 
    // MARK: - Analysis
    func analyzeTextInput() async {
        let trimmedInput = testInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedInput.isEmpty, !isAnalyzing else { return }
        
        isAnalyzing = true
        lastAnalysisType = selectedAnalysisType
        summary = "Starting \(selectedAnalysisType.rawValue.lowercased())..."
        
        // Test connection first
        let isConnected = await testOllamaConnection()
        guard isConnected else {
            summary = """
            ❌ Cannot connect to Ollama server.
            
            Please make sure:
            1. Ollama is installed and running
            2. The server is accessible at http://127.0.0.1:11434
            3. You've downloaded the model with: ollama pull qwen3:4b
            4. Created extended context model with: ollama create qwen3:4b-8192 -f Modelfile
            """
            isAnalyzing = false
            return
        }
        
        do {
            let result: String
            switch selectedAnalysisType {
            case .workplace:
                result = try await localLLMService.analyze(text: trimmedInput)
            case .summary:
                result = try await localLLMService.summarize(text: trimmedInput)
            case .behavioral:
                result = try await localLLMService.behavioralAnalyze(text: trimmedInput)
            }
            summary = result
            // Auto-save analysis result for text input too
            saveAnalysisResult()
        } catch {
            let errorMessage: String
            if let localError = error as? URLError, localError.code == .timedOut {
                errorMessage = "⚠️ \(selectedAnalysisType.rawValue) timed out. The server took too long to respond."
            } else {
                errorMessage = "❌ \(selectedAnalysisType.rawValue) failed: \(error.localizedDescription)"
            }
            summary = errorMessage
            print("Analysis Error: \(error)")
        }
        
        isAnalyzing = false
    }

    // MARK: - Ollama Connection
    private func testOllamaConnection() async -> Bool {
        guard let url = URL(string: "http://127.0.0.1:11434/api/tags") else {
            return false
        }
        
        do {
            let (_, response) = try await URLSession.shared.data(from: url)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            print("Ollama connection test failed: \(error)")
            return false
        }
    }

    // MARK: - Cleanup & Resource Management
    
    /// Cancels any ongoing analysis task
    func cancelCurrentAnalysis() {
        currentAnalysisTask?.cancel()
        currentAnalysisTask = nil
        isAnalyzing = false
    }
    
    /// Cancels any ongoing auto-save task
    private func cancelAutoSave() {
        currentAutoSaveTask?.cancel()
        currentAutoSaveTask = nil
    }
    
    /// Tears down all resources and cancels ongoing tasks
    nonisolated func teardownAllResources() {
        Task { @MainActor in
            cancelCurrentAnalysis()
            cancelAutoSave()
            cancellables.removeAll()
            
            // Clear state
            transcript = ""
            summary = ""
            lastSavedPath = ""
            testInput = ""
        }
    }
    
    deinit {
        teardownAllResources()
    }
}

