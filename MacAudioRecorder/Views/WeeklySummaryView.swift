import SwiftUI

@available(macOS 12.0, *)
struct WeeklySummaryView: View {
    let weekStart: Date
    @StateObject private var dailyAnalyzer = DailyBehaviorAnalyzer()
    @State private var weeklyData: [DailyAnalysisCache] = []
    
    private var weekEnd: Date {
        Calendar.current.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart
    }
    
    private var totalCounts: (multiplying: Int, diminishing: Int, accidental: Int) {
        weeklyData.reduce((0, 0, 0)) { result, day in
            (
                result.0 + day.multiplyingCount,
                result.1 + day.diminishingCount,
                result.2 + day.accidentallyDiminishingCount
            )
        }
    }
    
    private var averageCounts: (multiplying: Double, diminishing: Double, accidental: Double) {
        let days = Double(weeklyData.count)
        guard days > 0 else { return (0, 0, 0) }
        return (
            Double(totalCounts.multiplying) / days,
            Double(totalCounts.diminishing) / days,
            Double(totalCounts.accidental) / days
        )
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Date Range Header
            HStack {
                Text(formatDate(weekStart))
                Text("-")
                Text(formatDate(weekEnd))
            }
            .font(.headline)
            
            // Weekly Totals
            VStack(spacing: 12) {
                Text("Weekly Totals")
                    .font(.title3)
                    .bold()
                
                HStack(spacing: 20) {
                    StatBox(
                        title: "Multipliers",
                        total: totalCounts.multiplying,
                        average: averageCounts.multiplying,
                        color: .green
                    )
                    
                    StatBox(
                        title: "Diminishers",
                        total: totalCounts.diminishing,
                        average: averageCounts.diminishing,
                        color: .red
                    )
                    
                    StatBox(
                        title: "Accidental",
                        total: totalCounts.accidental,
                        average: averageCounts.accidental,
                        color: .orange
                    )
                }
            }
            .padding()
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(10)
        }
        .onAppear {
            loadWeeklyData()
        }
    }
    
    private func loadWeeklyData() {
        weeklyData = dailyAnalyzer.getAnalysisForRange(from: weekStart, to: weekEnd)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}

@available(macOS 12.0, *)
private struct StatBox: View {
    let title: String
    let total: Int
    let average: Double
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundColor(color)
            
            VStack(spacing: 4) {
                Text("Total: \(total)")
                    .bold()
                Text("Avg: \(String(format: "%.1f", average))")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
} 