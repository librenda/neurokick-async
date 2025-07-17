import SwiftUI
import Charts
import SwiftData

/// Analytics view showing behavioral trends and session insights
@available(macOS 12.0, *)
struct AnalyticsView: View {
    @StateObject private var behaviorAnalyzer = DailyBehaviorAnalyzer()
    @Query private var sessions: [RecordingSession]
    
    // Chart data state
    @State private var weeklyData: [DailyBehaviorData] = []
    @State private var isLoadingWeeklyData = false
    
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
                
                // Behavioral Trends Chart
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("📊 Behavioral Trends (Last 7 Days)")
                            .font(.headline)
                        
                        Spacer()
                        
                        if isLoadingWeeklyData {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                    }
                    
                    if weeklyData.isEmpty {
                        VStack {
                            Text("No behavioral data available")
                                .foregroundColor(.secondary)
                            
                            Button("Load Weekly Data") {
                                Task {
                                    await loadWeeklyData()
                                }
                            }
                            .buttonStyle(.bordered)
                        }
                        .frame(height: 200)
                        .frame(maxWidth: .infinity)
                    } else {
                        // Simple chart placeholder - we'll add the actual Chart in Step 3
                        BehavioralTrendsChart(data: weeklyData)
                            .frame(height: 250)
                    }
                }
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(12)
                
                // Current Session Info
                VStack {
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
                                Text("Today's Behaviors")
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
                
                Spacer()
            }
            .padding()
        }
        .navigationTitle("Analytics")
        .task {
            // Auto-load data when view appears
            await behaviorAnalyzer.analyzeTodaysBehaviors()
            await loadWeeklyData()
        }
    }
    
    // MARK: - Data Loading
    
    private func loadWeeklyData() async {
        isLoadingWeeklyData = true
        
        let calendar = Calendar.current
        let today = Date()
        let weekAgo = calendar.date(byAdding: .day, value: -6, to: today) ?? today
        
        var weeklyResults: [DailyBehaviorData] = []
        
        // Load data for each day in the last 7 days
        for i in 0..<7 {
            let date = calendar.date(byAdding: .day, value: i, to: weekAgo) ?? today
            let analyses = behaviorAnalyzer.getAnalysisForRange(from: date, to: date)
            
            let dailyData: DailyBehaviorData
            if let analysis = analyses.first {
                dailyData = DailyBehaviorData(
                    date: date,
                    multiplying: analysis.multiplyingCount,
                    diminishing: analysis.diminishingCount,
                    accidental: analysis.accidentallyDiminishingCount
                )
            } else {
                // No data for this day
                dailyData = DailyBehaviorData(
                    date: date,
                    multiplying: 0,
                    diminishing: 0,
                    accidental: 0
                )
            }
            weeklyResults.append(dailyData)
        }
        
        await MainActor.run {
            weeklyData = weeklyResults
            isLoadingWeeklyData = false
        }
    }
}

// MARK: - Data Models

/// Simple data structure for daily behavioral counts
struct DailyBehaviorData: Identifiable {
    let id = UUID()
    let date: Date
    let multiplying: Int
    let diminishing: Int
    let accidental: Int
    
    var total: Int {
        multiplying + diminishing + accidental
    }
}

// MARK: - Chart Component

struct BehavioralTrendsChart: View {
    let data: [DailyBehaviorData]
    
    var body: some View {
        if data.allSatisfy({ $0.total == 0 }) {
            // No data available
            VStack(spacing: 12) {
                Image(systemName: "chart.bar")
                    .font(.system(size: 40))
                    .foregroundColor(.secondary)
                
                Text("No behavioral data yet")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Text("Create some behavioral analyses to see trends here")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(height: 200)
        } else {
            // Real Swift Chart
            Chart {
                ForEach(data) { dayData in
                    // Multiplying behaviors (green)
                    BarMark(
                        x: .value("Date", dayData.date, unit: .day),
                        y: .value("Count", dayData.multiplying)
                    )
                    .foregroundStyle(.green)
                    .position(by: .value("Type", "Multiplying"))
                    
                    // Diminishing behaviors (red)
                    BarMark(
                        x: .value("Date", dayData.date, unit: .day),
                        y: .value("Count", dayData.diminishing)
                    )
                    .foregroundStyle(.red)
                    .position(by: .value("Type", "Diminishing"))
                    
                    // Accidental diminishing (orange)
                    BarMark(
                        x: .value("Date", dayData.date, unit: .day),
                        y: .value("Count", dayData.accidental)
                    )
                    .foregroundStyle(.orange)
                    .position(by: .value("Type", "Accidental"))
                }
            }
            .frame(height: 200)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { value in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.month().day())
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine()
                    AxisValueLabel()
                }
            }
            .chartLegend(position: .bottom, alignment: .center) {
                HStack(spacing: 20) {
                    Label("Multiplying", systemImage: "circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                    
                    Label("Diminishing", systemImage: "circle.fill")
                        .foregroundColor(.red)
                        .font(.caption)
                    
                    Label("Accidental", systemImage: "circle.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                }
            }
            .chartBackground { _ in
                RoundedRectangle(cornerRadius: 8)
                    .fill(.background.secondary.opacity(0.1))
            }
        }
    }
}

#Preview {
    AnalyticsView()
        .modelContainer(for: RecordingSession.self)
} 