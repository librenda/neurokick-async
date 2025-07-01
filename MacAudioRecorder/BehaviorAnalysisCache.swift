import Foundation

@available(macOS 12.0, *)
struct DailyAnalysisCache: Codable {
    let date: Date
    let multiplyingCount: Int
    let diminishingCount: Int
    let accidentallyDiminishingCount: Int
    let totalBehaviors: Int
    let sessionsAnalyzed: Int
    
    init(from summary: DailyBehaviorAnalyzer.DailySummary) {
        self.date = summary.date
        self.multiplyingCount = summary.multiplyingCount
        self.diminishingCount = summary.diminishingCount
        self.accidentallyDiminishingCount = summary.accidentallyDiminishingCount
        self.totalBehaviors = summary.totalBehaviors
        self.sessionsAnalyzed = summary.sessionsAnalyzed
    }
}

@available(macOS 12.0, *)
class BehaviorAnalysisCache {
    static let shared = BehaviorAnalysisCache()
    private let cacheFileName = "behavior-cache.json"
    private var cache: [String: DailyAnalysisCache] = [:]
    
    private var cacheFileURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(cacheFileName)
    }
    
    private init() {
        loadCache()
    }
    
    // MARK: - Public Methods
    
    func addAnalysis(_ summary: DailyBehaviorAnalyzer.DailySummary) {
        let dateKey = formatDate(summary.date)
        let cacheEntry = DailyAnalysisCache(from: summary)
        cache[dateKey] = cacheEntry
        saveCache()
    }
    
    func getAnalysis(for date: Date) -> DailyAnalysisCache? {
        let dateKey = formatDate(date)
        return cache[dateKey]
    }
    
    func getAnalyses(from startDate: Date, to endDate: Date) -> [DailyAnalysisCache] {
        let calendar = Calendar.current
        var currentDate = startDate
        var analyses: [DailyAnalysisCache] = []
        
        while currentDate <= endDate {
            if let analysis = getAnalysis(for: currentDate) {
                analyses.append(analysis)
            }
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }
        
        return analyses
    }
    
    // MARK: - Private Methods
    
    private func loadCache() {
        do {
            let data = try Data(contentsOf: cacheFileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            cache = try decoder.decode([String: DailyAnalysisCache].self, from: data)
        } catch {
            print("📝 No existing cache found or error loading cache: \(error). Starting with empty cache.")
            cache = [:]
        }
    }
    
    private func saveCache() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(cache)
            try data.write(to: cacheFileURL)
        } catch {
            print("❌ Error saving cache: \(error)")
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
} 