import Foundation

/// Manages daily behavioral analysis aggregation and counting
@available(macOS 12.0, *)
class DailyBehaviorAnalyzer: ObservableObject {
    
    // MARK: - Data Models
    
    /// Summary of daily behavioral analysis results
    struct DailySummary {
        let date: Date
        let multiplyingCount: Int
        let diminishingCount: Int
        let accidentallyDiminishingCount: Int
        let totalBehaviors: Int
        let keyInsights: [String]
        let rawAnalysisContent: String
        let sessionsAnalyzed: Int
        
        var totalCount: Int {
            multiplyingCount + diminishingCount + accidentallyDiminishingCount
        }
    }
    
    /// Parses behavioral analysis content to extract Net Tilt counts
    struct BehaviorCounts {
        let multiplying: Int
        let diminishing: Int
        let accidentallyDiminishing: Int
        let patterns: [String]
        
        var total: Int {
            multiplying + diminishing + accidentallyDiminishing
        }
    }
    
    // MARK: - Published Properties
    
    @Published var isAnalyzing = false
    @Published private(set) var summary: DailySummary?
    @Published var statusMessage = ""
    
    // MARK: - Computed Properties
    
    /// Returns the dominant behavior type based on counts
    var dominantBehaviorType: String {
        guard let summary = summary else { return "No data" }
        
        let counts = [
            (type: "Multipliers", count: summary.multiplyingCount),
            (type: "Diminishers", count: summary.diminishingCount),
            (type: "Accidental Diminishers", count: summary.accidentallyDiminishingCount)
        ]
        
        if let dominant = counts.max(by: { $0.count < $1.count }) {
            return dominant.count > 0 ? dominant.type : "No behaviors"
        }
        
        return "No behaviors"
    }
    
    // MARK: - Private Properties
    
    private let documentsPath: URL
    private var currentAnalysisTask: Task<Void, Never>?
    
    // MARK: - Initialization
    
    init() {
        self.documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
    
    // MARK: - Public Interface
    
    /// Analyzes all behavioral files for today
    func analyzeTodaysBehaviors() async {
        await analyzeBehaviors(for: Date())
    }
    
    /// Analyzes all behavioral files for a specific date
    func analyzeBehaviors(for date: Date) async {
        // Cancel any existing analysis
        cancelAnalysis()
        
        currentAnalysisTask = Task {
            await MainActor.run {
                isAnalyzing = true
                statusMessage = "Starting daily analysis..."
            }
            
            do {
                let summary = try await performDailyAnalysis(for: date)
                
                // Check for cancellation before updating state
                guard !Task.isCancelled else { return }
                
                await MainActor.run {
                    self.summary = summary
                    statusMessage = "✅ Daily analysis complete: \(summary.totalCount) behaviors found"
                    isAnalyzing = false
                }
            } catch {
                if !Task.isCancelled {
                    await MainActor.run {
                        statusMessage = "❌ Daily analysis failed: \(error.localizedDescription)"
                        isAnalyzing = false
                    }
                }
            }
        }
    }
    
    /// Cancels any ongoing analysis
    func cancelAnalysis() {
        currentAnalysisTask?.cancel()
        currentAnalysisTask = nil
        
        Task { @MainActor in
            isAnalyzing = false
            statusMessage = ""
        }
    }
    
    // MARK: - Private Implementation
    
    /// Performs the complete daily analysis workflow
    private func performDailyAnalysis(for date: Date) async throws -> DailySummary {
        // Step 1: Find behavioral files for the date
        let files = findBehavioralFiles(for: date)
        
        await MainActor.run {
            statusMessage = "Found \(files.count) behavioral analysis files"
        }
        
        guard !files.isEmpty else {
            throw AnalysisError.noFilesFound(date: date)
        }
        
        // Step 2: Extract analysis content from each file
        let analyses = files.compactMap { extractAnalysisContent(from: $0) }
        
        await MainActor.run {
            statusMessage = "Extracted content from \(analyses.count) files"
        }
        
        // Step 3: Count behaviors using text pattern matching
        let behaviorCounts = countBehaviors(from: analyses)
        
        await MainActor.run {
            statusMessage = "Counted \(behaviorCounts.total) behaviors across \(analyses.count) sessions"
        }
        
        // Step 4: Create aggregated content
        let aggregatedContent = createAggregatedContent(analyses: analyses, date: date)
        
        let summary = DailySummary(
            date: date,
            multiplyingCount: behaviorCounts.multiplying,
            diminishingCount: behaviorCounts.diminishing,
            accidentallyDiminishingCount: behaviorCounts.accidentallyDiminishing,
            totalBehaviors: behaviorCounts.total,
            keyInsights: behaviorCounts.patterns.isEmpty ? ["No patterns detected"] : behaviorCounts.patterns,
            rawAnalysisContent: aggregatedContent,
            sessionsAnalyzed: analyses.count
        )
        
        await MainActor.run {
            self.summary = summary
        }
        
        return summary
    }
    
    /// Finds all behavioral analysis files for a specific date
    private func findBehavioralFiles(for date: Date) -> [URL] {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: date)
        
        do {
            let files = try FileManager.default.contentsOfDirectory(at: documentsPath, includingPropertiesForKeys: nil)
            
            return files.filter { url in
                let filename = url.lastPathComponent
                return filename.hasPrefix("Behavioral-\(dateString)-") && filename.hasSuffix(".txt")
            }
        } catch {
            print("❌ Error reading documents directory: \(error)")
            return []
        }
    }
    
    /// Extracts analysis content after the second </think> tag
    private func extractAnalysisContent(from fileURL: URL) -> String? {
        do {
            let content = try String(contentsOf: fileURL)
            
            // Find content after second </think>
            let thinkTags = content.components(separatedBy: "</think>")
            guard thinkTags.count >= 3 else {
                print("⚠️ File \(fileURL.lastPathComponent) doesn't have expected </think> structure")
                return content // Return full content as fallback
            }
            
            // Join everything after the second </think>
            return thinkTags[2...].joined(separator: "</think>").trimmingCharacters(in: .whitespacesAndNewlines)
            
        } catch {
            print("❌ Error reading file \(fileURL.lastPathComponent): \(error)")
            return nil
        }
    }
    
    /// Creates aggregated content from all analyses
    private func createAggregatedContent(analyses: [String], date: Date) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .full
        
        return """
        === DAILY BEHAVIORAL ANALYSES FOR \(dateFormatter.string(from: date)) ===
        Total Sessions: \(analyses.count)
        
        === INDIVIDUAL SESSION ANALYSES ===
        
        \(analyses.joined(separator: "\n\n---\n\n"))
        """
    }
    
    /// Counts behaviors using text pattern matching
    private func countBehaviors(from analyses: [String]) -> BehaviorCounts {
        var multiplying = 0
        var diminishing = 0
        var accidentallyDiminishing = 0
        var patterns = Set<String>()
        
        for analysis in analyses {
            // Count Net Tilt patterns
            if let netTiltRange = analysis.range(of: #"\*\*Net Tilt:\*\*\s*(\d+)M,\s*(\d+)D,\s*(\d+)AD"#, options: .regularExpression) {
                let netTiltString = String(analysis[netTiltRange])
                let numbers = netTiltString.components(separatedBy: CharacterSet.decimalDigits.inverted)
                                        .compactMap { Int($0) }
                
                if numbers.count >= 3 {
                    multiplying += numbers[0]
                    diminishing += numbers[1]
                    accidentallyDiminishing += numbers[2]
                }
            }
            
            // Extract dominant patterns
            if let dominantRange = analysis.range(of: #"\(Dominant: (Accidental Diminishers|Diminishers|Multipliers)\)"#, options: .regularExpression) {
                patterns.insert(String(analysis[dominantRange]))
            }
        }
        
        return BehaviorCounts(
            multiplying: multiplying,
            diminishing: diminishing,
            accidentallyDiminishing: accidentallyDiminishing,
            patterns: Array(patterns)
        )
    }
    
    // MARK: - Error Types
    
    enum AnalysisError: LocalizedError {
        case noFilesFound(date: Date)
        
        var errorDescription: String? {
            switch self {
            case .noFilesFound(let date):
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                return "No behavioral analysis files found for \(formatter.string(from: date))"
            }
        }
    }
}
