import SwiftUI
import Charts
import SwiftData

/// Analytics view showing behavioral trends and session insights
@available(macOS 12.0, *)
struct AnalyticsView: View {
    @StateObject private var behaviorAnalyzer = DailyBehaviorAnalyzer()
    @Query private var sessions: [RecordingSession]
    
    // Enhanced chart data state
    @State private var timelineData: [DailyBehaviorData] = []
    @State private var isLoadingData = false
    
    // Timeline controls
    @State private var selectedTimeRange: TimeRange = .month
    @State private var startDate = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @State private var endDate = Date()
    @State private var scrollPosition: Date = Date()
    
    enum TimeRange: String, CaseIterable {
        case week = "1 Week"
        case month = "1 Month"
        case quarter = "3 Months"
        case year = "1 Year"
        case all = "All Time"
        
        var days: Int {
            switch self {
            case .week: return 7
            case .month: return 30
            case .quarter: return 90
            case .year: return 365
            case .all: return 1000 // Large number for all-time
            }
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Analytics Dashboard")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Behavioral patterns and session insights")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                
                // Timeline Controls
                timelineControlsSection
                
                // Scrollable Behavioral Trends Chart
                behavioralTimelineSection
                
                // Behavior Breakdown (Debug)
                behaviorBreakdownSection
                
                // Session Summary
                sessionSummarySection
                
                Spacer()
            }
            .padding()
        }
        .navigationTitle("Analytics")
        .task {
            await loadInitialData()
        }
        .onChange(of: selectedTimeRange) { oldValue, newValue in
            Task {
                await updateDateRange(for: newValue)
            }
        }
    }
    
    // MARK: - Timeline Controls Section
    
    private var timelineControlsSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("📅 Timeline Controls")
                    .font(.headline)
                
                Spacer()
                
                if isLoadingData {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            
            HStack {
                // Time Range Picker
                Picker("Time Range", selection: $selectedTimeRange) {
                    ForEach(TimeRange.allCases, id: \.self) { range in
                        Text(range.rawValue).tag(range)
                    }
                }
                .pickerStyle(.segmented)
                
                Spacer()
                
                // Custom Date Range (for advanced users)
                if selectedTimeRange == .all {
                    HStack {
                        DatePicker("From", selection: $startDate, in: ...endDate, displayedComponents: .date)
                            .labelsHidden()
                        
                        Text("to")
                            .foregroundColor(.secondary)
                        
                        DatePicker("To", selection: $endDate, in: startDate...Date(), displayedComponents: .date)
                            .labelsHidden()
                        
                        Button("Load") {
                            Task { await loadTimelineData() }
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            
            // Data Summary
            if !timelineData.isEmpty {
                HStack {
                    Text("Showing \(timelineData.count) days")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    let totalBehaviors = timelineData.reduce(0) { $0 + $1.total }
                    Text("\(totalBehaviors) total behaviors")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }
    
    // MARK: - Behavioral Timeline Section
    
    private var behavioralTimelineSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("📊 Behavioral Timeline")
                .font(.headline)
            
            if timelineData.isEmpty {
                emptyTimelineView
            } else {
                ScrollableTimelineChart(data: timelineData, scrollPosition: $scrollPosition)
                    .frame(height: 300)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }
    
    private var emptyTimelineView: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            
            Text("No behavioral data for selected period")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Try selecting a different time range or create some behavioral analyses")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(height: 250)
    }
    
    // MARK: - Session Summary Section
    
    private var sessionSummarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("📈 Session Summary")
                .font(.headline)
            
            HStack {
                VStack {
                    Text("\(sessions.count)")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Total Sessions")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if let summary = behaviorAnalyzer.summary {
                    VStack {
                        Text("\(summary.totalCount)")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("Recent Behaviors")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                if !timelineData.isEmpty {
                    VStack {
                        let avgPerDay = timelineData.reduce(0) { $0 + $1.total } / timelineData.count
                        Text("\(avgPerDay)")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("Avg/Day")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }
    
    // MARK: - Behavior Breakdown Section
    
    private var behaviorBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("🎯 Behavior Breakdown")
                .font(.headline)
            
            if !timelineData.isEmpty {
                let totalMultiplying = timelineData.reduce(0) { $0 + $1.multiplying }
                let totalDiminishing = timelineData.reduce(0) { $0 + $1.diminishing }
                let totalAccidental = timelineData.reduce(0) { $0 + $1.accidentallyDiminishing }
                
                HStack(spacing: 20) {
                    VStack {
                        HStack {
                            Circle().fill(.green).frame(width: 12, height: 12)
                            Text("\(totalMultiplying)")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.green)
                        }
                        Text("Multiplying")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack {
                        HStack {
                            Circle().fill(.red).frame(width: 12, height: 12)
                            Text("\(totalDiminishing)")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.red)
                        }
                        Text("Diminishing")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack {
                        HStack {
                            Circle().fill(.orange).frame(width: 12, height: 12)
                            Text("\(totalAccidental)")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.orange)
                        }
                        Text("Accidental")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                .padding()
                
                // Debug Information
                VStack(alignment: .leading, spacing: 4) {
                    Text("🔍 Debug Info:")
                        .font(.caption)
                        .fontWeight(.bold)
                    
                    Text("Days with data: \(timelineData.filter { $0.total > 0 }.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("Date range: \(formatDate(startDate)) to \(formatDate(endDate))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let firstDataDay = timelineData.first(where: { $0.total > 0 }) {
                        Text("First data: \(formatDate(firstDataDay.date)) - M:\(firstDataDay.multiplying) D:\(firstDataDay.diminishing) AD:\(firstDataDay.accidentallyDiminishing)")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                    
                    Button("🗂️ List Documents Files") {
                        Task {
                            await listDocumentFiles()
                        }
                    }
                    .buttonStyle(.bordered)
                    .font(.caption)
                }
                .padding(.horizontal)
            } else {
                Text("No timeline data loaded")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding()
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }
    
    // Helper function for date formatting
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    
    /// Lists all files in Documents directory for debugging
    private func listDocumentFiles() async {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        
        do {
            let files = try FileManager.default.contentsOfDirectory(at: documentsPath, includingPropertiesForKeys: nil)
            
            print("📁 Documents Directory: \(documentsPath.path)")
            print("📂 Total files: \(files.count)")
            print("📋 File listing:")
            
            let behaviorFiles = files.filter { $0.lastPathComponent.hasPrefix("Behavioral-") }
            print("🎯 Behavioral files found: \(behaviorFiles.count)")
            
            for file in files.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
                let isBehavioral = file.lastPathComponent.hasPrefix("Behavioral-")
                let marker = isBehavioral ? "🎯" : "📄"
                print("   \(marker) \(file.lastPathComponent)")
            }
            
        } catch {
            print("❌ Error listing files: \(error)")
        }
    }
    
    // MARK: - Data Loading
    
    private func loadInitialData() async {
        await behaviorAnalyzer.analyzeTodaysBehaviors()
        await updateDateRange(for: selectedTimeRange)
    }
    
    private func updateDateRange(for timeRange: TimeRange) async {
        let calendar = Calendar.current
        let today = Date()
        
        switch timeRange {
        case .week:
            startDate = calendar.date(byAdding: .day, value: -6, to: today) ?? today
            endDate = today
        case .month:
            startDate = calendar.date(byAdding: .month, value: -1, to: today) ?? today
            endDate = today
        case .quarter:
            startDate = calendar.date(byAdding: .month, value: -3, to: today) ?? today
            endDate = today
        case .year:
            startDate = calendar.date(byAdding: .year, value: -1, to: today) ?? today
            endDate = today
        case .all:
            // Keep current start/end dates - user controls them
            break
        }
        
        scrollPosition = endDate // Start scroll position at the end (most recent)
        await loadTimelineData()
    }
    
    private func loadTimelineData() async {
        isLoadingData = true
        
        let calendar = Calendar.current
        var results: [DailyBehaviorData] = []
        
        // Generate date range
        var currentDate = startDate
        while currentDate <= endDate {
            // First try to get cached analysis
            let analyses = behaviorAnalyzer.getAnalysisForRange(from: currentDate, to: currentDate)
            
            let dailyData: DailyBehaviorData
            if let analysis = analyses.first {
                // Use cached data
                dailyData = DailyBehaviorData(
                    date: currentDate,
                    multiplying: analysis.multiplyingCount,
                    diminishing: analysis.diminishingCount,
                    accidentallyDiminishing: analysis.accidentallyDiminishingCount
                )
            } else {
                // No cached data - scan files directly for this date
                let behaviorCounts = await scanBehaviorFilesForDate(currentDate)
                dailyData = DailyBehaviorData(
                    date: currentDate,
                    multiplying: behaviorCounts.multiplying,
                    diminishing: behaviorCounts.diminishing,
                    accidentallyDiminishing: behaviorCounts.accidentallyDiminishing
                )
            }
            results.append(dailyData)
            
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }
        
        await MainActor.run {
            timelineData = results
            isLoadingData = false
            
            // Update summary to reflect the timeline data instead of just "today"
            updateSummaryFromTimelineData()
        }
    }
    
    /// Scans behavior files directly for a specific date (bypasses cache)
    private func scanBehaviorFilesForDate(_ date: Date) async -> (multiplying: Int, diminishing: Int, accidentallyDiminishing: Int) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: date)
        
        // Use the same document directory as the app for consistency
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        
        do {
            let files = try FileManager.default.contentsOfDirectory(at: documentsPath, includingPropertiesForKeys: nil)
            
            let behaviorFiles = files.filter { url in
                let filename = url.lastPathComponent
                return filename.hasPrefix("Behavioral-\(dateString)-") && filename.hasSuffix(".txt")
            }
            
            // Debug: Print what we're looking for and what we found
            print("🔍 Scanning for date: \(dateString)")
            print("📁 Documents path: \(documentsPath.path)")
            print("📂 Total files in documents: \(files.count)")
            print("🎯 Looking for pattern: Behavioral-\(dateString)-*.txt")
            print("✅ Found behavioral files: \(behaviorFiles.count)")
            
            // Debug: List first few files to see what's there
            let fileNames = files.prefix(10).map { $0.lastPathComponent }
            print("📄 Sample files: \(fileNames)")
            
            for file in behaviorFiles {
                print("   📄 \(file.lastPathComponent)")
            }
            
            var totalMultiplying = 0
            var totalDiminishing = 0
            var totalAccidental = 0
            
            // Process each file
            for fileURL in behaviorFiles {
                if let content = try? String(contentsOf: fileURL) {
                    let counts = extractBehaviorCounts(from: content)
                    print("   📊 \(fileURL.lastPathComponent): M:\(counts.multiplying) D:\(counts.diminishing) AD:\(counts.accidentallyDiminishing)")
                    totalMultiplying += counts.multiplying
                    totalDiminishing += counts.diminishing
                    totalAccidental += counts.accidentallyDiminishing
                }
            }
            
            print("📈 Total for \(dateString): M:\(totalMultiplying) D:\(totalDiminishing) AD:\(totalAccidental)")
            return (totalMultiplying, totalDiminishing, totalAccidental)
            
        } catch {
            print("❌ Error scanning files: \(error)")
            return (0, 0, 0)
        }
    }
    
    /// Extracts behavior counts from analysis content using regex
    private func extractBehaviorCounts(from content: String) -> (multiplying: Int, diminishing: Int, accidentallyDiminishing: Int) {
        let netTiltPattern = #"\*\*Net Tilt:\*\*\s*(\d+)M,\s*(\d+)D,\s*(\d+)AD"#
        
        do {
            let regex = try NSRegularExpression(pattern: netTiltPattern, options: [])
            let nsContent = content as NSString
            let matches = regex.matches(in: content, options: [], range: NSRange(location: 0, length: nsContent.length))
            
            print("      🔍 Looking for pattern: \(netTiltPattern)")
            print("      📝 Content length: \(content.count) chars")
            print("      🎯 Regex matches found: \(matches.count)")
            
            if let match = matches.first {
                let fullMatch = nsContent.substring(with: match.range)
                let multiplying = Int(nsContent.substring(with: match.range(at: 1))) ?? 0
                let diminishing = Int(nsContent.substring(with: match.range(at: 2))) ?? 0
                let accidentallyDiminishing = Int(nsContent.substring(with: match.range(at: 3))) ?? 0
                
                print("      ✅ Found: '\(fullMatch)'")
                print("      📊 Extracted: M:\(multiplying) D:\(diminishing) AD:\(accidentallyDiminishing)")
                
                return (multiplying, diminishing, accidentallyDiminishing)
            } else {
                print("      ❌ No Net Tilt pattern found")
                // Show a snippet of the content to help debug
                let snippet = String(content.prefix(200))
                print("      📄 Content preview: \(snippet)...")
            }
        } catch {
            print("      💥 Regex error: \(error)")
        }
        
        return (0, 0, 0)
    }
    
    /// Updates the behavior analyzer summary to reflect timeline data
    private func updateSummaryFromTimelineData() {
        let totalBehaviors = timelineData.reduce(0) { $0 + $1.total }
        let totalMultiplying = timelineData.reduce(0) { $0 + $1.multiplying }
        let totalDiminishing = timelineData.reduce(0) { $0 + $1.diminishing }
        let totalAccidental = timelineData.reduce(0) { $0 + $1.accidentallyDiminishing }
        
        // Create a summary that matches the timeline data
        let timelineStartDate = timelineData.first?.date ?? Date()
        let summary = DailyBehaviorAnalyzer.DailySummary(
            date: timelineStartDate,
            multiplyingCount: totalMultiplying,
            diminishingCount: totalDiminishing,
            accidentallyDiminishingCount: totalAccidental,
            totalBehaviors: totalBehaviors,
            keyInsights: totalBehaviors > 0 ? ["Data from selected timeline range"] : ["No behaviors in selected range"],
            rawAnalysisContent: "Timeline analysis for \(timelineData.count) days",
            sessionsAnalyzed: timelineData.filter { $0.total > 0 }.count
        )
        
        // Update the behavior analyzer summary
        behaviorAnalyzer.summary = summary
    }
}

// MARK: - Scrollable Timeline Chart

struct ScrollableTimelineChart: View {
    let data: [DailyBehaviorData]
    @Binding var scrollPosition: Date
    
    // Define chart series for proper legend mapping
    private let behaviorTypes = ["Multiplying", "Diminishing", "Accidental"]
    
    // Flattened data structure for proper Swift Charts series identification
    private var chartData: [BehaviorDataPoint] {
        data.flatMap { dayData in
            [
                BehaviorDataPoint(date: dayData.date, count: dayData.multiplying, type: "Multiplying"),
                BehaviorDataPoint(date: dayData.date, count: dayData.diminishing, type: "Diminishing"),
                BehaviorDataPoint(date: dayData.date, count: dayData.accidentallyDiminishing, type: "Accidental")
            ]
        }
    }
    
    private var hasData: Bool {
        data.contains { $0.total > 0 }
    }
    
    private var totalBehaviors: Int {
        data.reduce(0) { $0 + $1.total }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Debug info
            Text("Chart Data: \(data.count) days, \(totalBehaviors) total behaviors")
                .font(.caption)
                .foregroundColor(.secondary)
            
            if !hasData {
                // Empty state
                VStack(spacing: 8) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("No behavioral data to display")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    Text("Start recording sessions to see behavioral trends")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(height: 280)
                .frame(maxWidth: .infinity)
            } else {
                // Beautiful Swift Charts implementation
                Chart {
                    ForEach(chartData, id: \.id) { dataPoint in
                        LineMark(
                            x: .value("Date", dataPoint.date),
                            y: .value("Count", dataPoint.count)
                        )
                        .foregroundStyle(by: .value("Behavior Type", dataPoint.type))
                        .lineStyle(StrokeStyle(lineWidth: 3))
                        .symbol(by: .value("Behavior Type", dataPoint.type))
                        .symbolSize(60)
                        .interpolationMethod(.catmullRom)
                    }
                }
                .frame(height: 280)
                .chartScrollableAxes(.horizontal)
                .chartXVisibleDomain(length: 3600 * 24 * 14) // Show 14 days at once
                .chartScrollPosition(x: $scrollPosition)
                .chartForegroundStyleScale([
                    "Multiplying": .green,
                    "Diminishing": .red,
                    "Accidental": .orange
                ])
                .chartSymbolScale([
                    "Multiplying": .circle,
                    "Diminishing": .square,
                    "Accidental": .diamond
                ])
                .chartXAxis {
                    AxisMarks(preset: .aligned, values: .stride(by: .day, count: 1)) { value in
                        AxisGridLine(centered: true, stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(.secondary.opacity(0.3))
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day(), centered: true)
                            .font(.caption)
                    }
                }
                .chartYAxis {
                    AxisMarks(preset: .aligned, position: .leading) { value in
                        AxisGridLine(centered: true, stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(.secondary.opacity(0.3))
                        AxisValueLabel()
                            .font(.caption)
                    }
                }
                .chartLegend(position: .bottom, alignment: .center) {
                    HStack(spacing: 24) {
                        ForEach(behaviorTypes, id: \.self) { type in
                            HStack(spacing: 6) {
                                let color: Color = type == "Multiplying" ? .green : 
                                                  type == "Diminishing" ? .red : .orange
                                let count = data.reduce(0) { sum, day in
                                    sum + (type == "Multiplying" ? day.multiplying :
                                           type == "Diminishing" ? day.diminishing : day.accidentallyDiminishing)
                                }
                                
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(color)
                                    .frame(width: 16, height: 3)
                                
                                Text("\(type) (\(count))")
                                    .font(.caption)
                                    .foregroundColor(.primary)
                            }
                        }
                    }
                    .padding(.top, 8)
                }
                .animation(.easeInOut(duration: 0.3), value: data.count)
            }
        }
    }
}

// MARK: - Data Models

/// Data point for Swift Charts series identification
struct BehaviorDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let count: Int
    let type: String
}

/// Simple data structure for daily behavioral counts
struct DailyBehaviorData: Identifiable {
    let id = UUID()
    let date: Date
    let multiplying: Int
    let diminishing: Int
    let accidentallyDiminishing: Int
    
    var total: Int {
        multiplying + diminishing + accidentallyDiminishing
    }
}

#Preview {
    AnalyticsView()
        .modelContainer(for: RecordingSession.self)
} 